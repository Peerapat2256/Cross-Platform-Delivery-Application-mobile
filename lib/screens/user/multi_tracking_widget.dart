// lib/screens/user/multi_tracking_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:test_databse/service/db_service.dart';
import 'package:test_databse/model/rider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:collection/collection.dart'; // ‼️ 1. Import ที่อาจต้องใช้

// --- ‼️ Imports เพิ่มเติมสำหรับ OSRM ‼️ ---
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // For jsonDecode

class MultiTrackingWidget extends StatefulWidget {
  const MultiTrackingWidget({super.key});

  @override
  State<MultiTrackingWidget> createState() => _MultiTrackingWidgetState();
}

class _MultiTrackingWidgetState extends State<MultiTrackingWidget> {
  final DbService _dbService = DbService();
  final Completer<GoogleMapController> _mapController = Completer();
  final Set<Marker> _markers = {};

  // --- State Management ---
  List<Delivery> _sentDeliveries = [];
  List<Delivery> _receivedDeliveries = [];
  List<Delivery> _allActiveDeliveries = []; // (สำหรับหมุด Rider ที่กำลังวิ่ง)
  final Map<String, LatLng> _riderLocations = {};
  final Map<String, String> _riderNames = {};
  StreamSubscription? _sentSub;
  StreamSubscription? _receivedSub;
  final Map<String, StreamSubscription> _riderSubs = {};

  // --- State แผนที่ ---
  LatLng _initialCameraPosition = const LatLng(13.736717, 100.523186); // Default Bangkok
  bool _isLoadingLocation = true;

  // --- ‼️ State สำหรับเส้นทาง OSRM ‼️ ---
  // Key: deliveryId (เพื่อให้รู้ว่าเส้นทางนี้ของงานไหน), Value: Polyline object
  final Map<String, Polyline> _polylines = {};
  PolylinePoints polylinePoints = PolylinePoints();


  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndStartListeners();
  }

  // (ฟังก์ชัน _getCurrentLocationAndStartListeners เหมือนเดิม)
  Future<void> _getCurrentLocationAndStartListeners() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoadingLocation = false);
      } else {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        if (mounted) {
          setState(() {
            _initialCameraPosition = LatLng(position.latitude, position.longitude);
            _isLoadingLocation = false;
          });
          _animateCameraToCurrentLocation();
        }
      }
    } catch (e) {
      print("Error getting current location: $e");
      if (mounted) setState(() => _isLoadingLocation = false);
    }

    // ฟัง Stream งานที่เราส่ง
    _sentSub = _dbService.getMySentDeliveries().listen((list) {
      _sentDeliveries = list;
      _updateCombinedList();
    });
    // ฟัง Stream งานที่เราได้รับ
    _receivedSub = _dbService.getMyReceivedDeliveries().listen((list) {
      _receivedDeliveries = list;
      _updateCombinedList();
    });
  }
  
  // (ฟังก์ชัน _animateCameraToCurrentLocation เหมือนเดิม)
  Future<void> _animateCameraToCurrentLocation() async {
    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(_initialCameraPosition, 15),
    );
  }

  @override
  void dispose() {
    _sentSub?.cancel();
    _receivedSub?.cancel();
    _riderSubs.values.forEach((sub) => sub.cancel());
    super.dispose();
  }

  // --- ‼️ 3. แก้ไข _updateCombinedList ‼️ ---
  void _updateCombinedList() {
    // หา deliveryId ของงานที่ Active อยู่เดิม (ก่อนอัปเดต)
    final oldActiveDeliveryIds = _allActiveDeliveries.map((d) => d.deliveryId).toSet();

    // กรองเอางานที่ Active (มี Rider รับแล้ว)
    _allActiveDeliveries = [..._sentDeliveries, ..._receivedDeliveries]
        .where((d) =>
            (d.status == 'rider_accepted' || d.status == 'picked_up') && d.riderId != null)
        .toList();

     // หา deliveryId ของงานที่ Active ใหม่
    final newActiveDeliveryIds = _allActiveDeliveries.map((d) => d.deliveryId).toSet();

    // หางานที่หายไป (ต้องลบเส้นทาง)
    final deliveriesToRemove = oldActiveDeliveryIds.difference(newActiveDeliveryIds);
     if (deliveriesToRemove.isNotEmpty && mounted) {
        setState(() {
           // ลบเส้นทางของงานที่จบไปแล้ว
           deliveriesToRemove.forEach((id) => _polylines.remove(id));
        });
     }
    
    // (ส่วนนี้เหมือนเดิม)
    _updateRiderSubscriptions(); // อัปเดตการฟังตำแหน่ง Rider
    _updateAllMarkers();         // อัปเดตหมุด A, B, Rider
    
    // ‼️ เรียกวาดเส้นทาง A -> B ‼️
    _updateAllRoutes();
  }

  // (ฟังก์ชัน _updateRiderSubscriptions เหมือนเดิม)
  void _updateRiderSubscriptions() {
    final newRiderIds = _allActiveDeliveries
        .map((d) => d.riderId!)
        .toSet();
    final oldRiderIds = _riderSubs.keys.toSet();

    // (Logic ลบ/เพิ่ม Rider Subscriptions เหมือนเดิม)
    final ridersToRemove = oldRiderIds.difference(newRiderIds);
    for (final riderId in ridersToRemove) {
      _riderSubs[riderId]?.cancel();
      _riderSubs.remove(riderId);
      _riderLocations.remove(riderId);
      _riderNames.remove(riderId);
       // Also remove polylines associated with deliveries handled by this rider
       if (mounted) {
         setState(() {
            _polylines.removeWhere((deliveryId, polyline) =>
               _allActiveDeliveries.any((d) => d.deliveryId == deliveryId && d.riderId == riderId)
            );
         });
       }
    }
    
    final ridersToAdd = newRiderIds.difference(oldRiderIds);
    for (final riderId in ridersToAdd) {
        _riderSubs[riderId] = _dbService.getRiderStream(riderId).listen((snapshot) {
          if (snapshot.exists && mounted) {
            final data = snapshot.data() as Map<String, dynamic>;
            final newPos = LatLng(
              data['current_latitude'] ?? 0,
              data['current_longitude'] ?? 0,
            );
             if (_riderLocations[riderId] != newPos) {
                _riderLocations[riderId] = newPos;
                _riderNames[riderId] = data['name'] ?? 'Rider';
                _updateAllMarkers(); // วาดหมุดใหม่
                // ‼️ ไม่ต้องเรียก _updateRoutes() ที่นี่ (ปล่อยให้เส้นทาง A->B คงที่) ‼️
             }
          }
        });
    }
  }

  // (ฟังก์ชัน _updateAllMarkers เหมือนเดิม - ถูกต้องแล้ว)
  void _updateAllMarkers() {
    if (!mounted) return;
    Set<Marker> updatedMarkers = {}; // สร้าง Set ใหม่

    // 1. วาดหมุด Rider (ส้ม)
    for (final riderId in _riderLocations.keys) {
       final pos = _riderLocations[riderId];
       if (pos != null && (pos.latitude != 0 || pos.longitude != 0)) {
         updatedMarkers.add(
           Marker(
             markerId: MarkerId('rider_$riderId'),
             position: pos,
             infoWindow: InfoWindow(title: _riderNames[riderId] ?? 'Rider'),
             icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
             flat: true,
           ),
         );
       }
    }

    // 2. วาดหมุด A, B (น้ำเงิน, เขียว) - (ใช้ _allActiveDeliveries ถูกต้องแล้ว)
    for (final delivery in _allActiveDeliveries) {
       // Add Pickup marker (Blue)
       if(delivery.pickupLocation.latitude != 0 || delivery.pickupLocation.longitude != 0) {
         updatedMarkers.add(Marker(
           markerId: MarkerId('pickup_${delivery.deliveryId}'),
           position: LatLng(delivery.pickupLocation.latitude, delivery.pickupLocation.longitude),
           infoWindow: InfoWindow(title: 'รับของ (งาน: ${delivery.receiverName})'),
           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
         ));
       }
       // Add Delivery marker (Green)
       if(delivery.deliveryLocation.latitude != 0 || delivery.deliveryLocation.longitude != 0) {
         updatedMarkers.add(Marker(
           markerId: MarkerId('delivery_${delivery.deliveryId}'),
           position: LatLng(delivery.deliveryLocation.latitude, delivery.deliveryLocation.longitude),
           infoWindow: InfoWindow(title: 'ส่งของ (งาน: ${delivery.receiverName})'),
           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
         ));
       }
    }

    // 3. อัปเดต State ทีเดียว ถ้ามีการเปลี่ยนแปลง
    if (!const SetEquality().equals(_markers, updatedMarkers)) {
       setState(() {
         _markers.clear();
         _markers.addAll(updatedMarkers);
       });
    }
  }


  // --- ‼️ ฟังก์ชันใหม่: วาด/อัปเดตเส้นทาง OSRM ทั้งหมด (A -> B) ‼️ ---
  Future<void> _updateAllRoutes() async {
    // วน Loop สร้างเส้นทางสำหรับแต่ละงานที่ Active
    for (final delivery in _allActiveDeliveries) {
      // ถ้ายังไม่เคยวาดเส้นทางนี้ (เช็คจาก Key ใน Map)
      if (!_polylines.containsKey(delivery.deliveryId)) {
        
        LatLng? origin = LatLng(delivery.pickupLocation.latitude, delivery.pickupLocation.longitude);
        LatLng? destination = LatLng(delivery.deliveryLocation.latitude, delivery.deliveryLocation.longitude);

        // เช็คว่าพิกัด A, B ถูกต้อง (ไม่เป็น 0,0 และไม่ซ้ำกัน)
        if ((origin.latitude != 0 || origin.longitude != 0) &&
            (destination.latitude != 0 || destination.longitude != 0) &&
            origin != destination)
        {
           // เรียก OSRM (A -> B)
           final polylineCoordinates = await _fetchOsrmRoute(origin, destination);
           
           if (polylineCoordinates != null && polylineCoordinates.isNotEmpty && mounted) {
               setState(() {
                 // เก็บเส้นทางโดยใช้ deliveryId เป็น Key
                 _polylines[delivery.deliveryId] = Polyline(
                   polylineId: PolylineId('route_${delivery.deliveryId}'), // ID ไม่ซ้ำ
                   points: polylineCoordinates,
                   color: Colors.primaries[delivery.deliveryId.hashCode % Colors.primaries.length].withOpacity(0.8), // สุ่มสี
                   width: 4, // เส้นบางลงเล็กน้อย
                 );
               });
               print("✅ OSRM A->B route drawn for ${delivery.deliveryId}.");
           }
        }
      }
    }
  }

  // --- ‼️ ฟังก์ชันใหม่: เรียก OSRM API (แยกออกมา) ‼️ ---
  Future<List<LatLng>?> _fetchOsrmRoute(LatLng origin, LatLng destination) async {
    final osrmBaseUrl = 'https://router.project-osrm.org'; // DEMO SERVER!
    final profile = 'driving';
    final coordinates = '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final url = Uri.parse('$osrmBaseUrl/route/v1/$profile/$coordinates?overview=full&geometries=polyline');

    print("Calling OSRM (Multi A->B): $url");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty && data['routes'][0]['geometry'] != null) {
          final encodedPolyline = data['routes'][0]['geometry'];
          List<PointLatLng> result = polylinePoints.decodePolyline(encodedPolyline);
          return result.map((p) => LatLng(p.latitude, p.longitude)).toList();
        } else {
           print("No route found between $origin and $destination");
        }
      } else {
         print("OSRM API request failed: ${response.statusCode}");
      }
    } catch (e) {
      print("🚨 Error calling OSRM API (Fetch): $e");
    }
    return null; // คืนค่า null ถ้า Error หรือไม่เจอเส้นทาง
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialCameraPosition,
              zoom: 12,
            ),
            onMapCreated: (controller) {
              if (!_mapController.isCompleted) {
                 _mapController.complete(controller);
              }
              if (!_isLoadingLocation) {
                _animateCameraToCurrentLocation();
              }
               // พยายามวาดเส้นทาง A->B ครั้งแรก (ถ้าพิกัดพร้อมแล้ว)
              _updateAllRoutes();
            },
            markers: _markers,
            polylines: Set<Polyline>.of(_polylines.values), 
            zoomControlsEnabled: false,
            myLocationEnabled: true,
            myLocationButtonEnabled: true, 
          ),

          if (_isLoadingLocation)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}