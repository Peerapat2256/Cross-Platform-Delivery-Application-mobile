// lib/screens/user/user_tracking_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:test_databse/service/db_service.dart';
import 'dart:math' as math;
// --- ‼️ Imports เพิ่มเติม ‼️ ---
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // For jsonDecode


class UserTrackingScreen extends StatefulWidget {
  final String deliveryId;
  const UserTrackingScreen({super.key, required this.deliveryId});

  @override
  State<UserTrackingScreen> createState() => _UserTrackingScreenState();
}

class _UserTrackingScreenState extends State<UserTrackingScreen> {
  final DbService _dbService = DbService();
  final Completer<GoogleMapController> _mapController = Completer();
  final Set<Marker> _markers = {};

  // ข้อมูลจาก Stream 1 (Delivery)
  String _deliveryStatus = 'กำลังโหลด...';
  String? _riderId;
  LatLng? _pickupLatLng;
  LatLng? _deliveryLatLng;

  // ข้อมูลจาก Stream 2 (Rider)
  LatLng? _riderPosition;
  double _riderRotation = 0.0;
  String _riderName = '';
  String? _riderPhotoUrl;

  // Stream Subscriptions
  StreamSubscription? _deliverySub;
  StreamSubscription? _riderSub;

  // --- ‼️ State สำหรับเส้นทาง ‼️ ---
  final Set<Polyline> _polylines = {};
  PolylinePoints polylinePoints = PolylinePoints();

  @override
  void initState() {
    super.initState();
    _listenToDelivery(); // ฟังข้อมูลงาน (ซึ่งจะเรียก _listenToRider ถ้ามี riderId)
  }

  @override
  void dispose() {
    _deliverySub?.cancel();
    _riderSub?.cancel();
    super.dispose();
  }

  void _listenToDelivery() {
    _deliverySub =
        _dbService.getDeliveryStream(widget.deliveryId).listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data() as Map<String, dynamic>;

      // เก็บสถานะและพิกัดเดิมเพื่อเปรียบเทียบ
      final oldRiderId = _riderId;
      final oldStatus = _deliveryStatus;
      final oldPickup = _pickupLatLng;
      final oldDelivery = _deliveryLatLng;

      // ดึงข้อมูลใหม่
      final newStatus = data['status'] ?? 'N/A';
      final pickupGeo = data['pickup_location'] as GeoPoint?;
      final deliveryGeo = data['delivery_location'] as GeoPoint?;
      final newRiderId = data['rider_id'] as String?;

      bool positionsUpdated = false;
      LatLng? tempPickup;
      LatLng? tempDelivery;

      if (pickupGeo != null) {
         tempPickup = LatLng(pickupGeo.latitude, pickupGeo.longitude);
         if (_pickupLatLng != tempPickup) positionsUpdated = true;
      }
      if (deliveryGeo != null) {
          tempDelivery = LatLng(deliveryGeo.latitude, deliveryGeo.longitude);
           if (_deliveryLatLng != tempDelivery) positionsUpdated = true;
      }

      // อัปเดต State หลัก
       setState(() {
         _deliveryStatus = newStatus;
         _pickupLatLng = tempPickup;
         _deliveryLatLng = tempDelivery;
          // อัปเดตหมุดทันที
         _updateMarkers();
       });


      // ตรวจสอบ Rider ID
      if (newRiderId != null && newRiderId != oldRiderId) {
        setState(() => _riderId = newRiderId);
        _listenToRider(newRiderId); // เริ่ม/เปลี่ยนการฟังตำแหน่ง Rider (ซึ่งจะเรียก _getRoutePolyline)
      } else if (newRiderId == null && oldRiderId != null) {
         // กรณี Rider ถูกลบ (เช่น ยกเลิกงาน)
         setState(() {
           _riderId = null;
           _riderPosition = null; // ลบตำแหน่ง rider
           _riderName = '';
           _riderPhotoUrl = null;
           _polylines.clear(); // ลบเส้นทาง
         });
         _riderSub?.cancel();
         _updateMarkers(); // อัปเดตหมุด (เอา rider ออก)
      } else if (positionsUpdated || oldStatus != newStatus) {
         // ถ้าแค่ตำแหน่ง A/B หรือสถานะเปลี่ยน ให้วาดเส้นทางใหม่
         _getRoutePolyline();
      }
    });
  }


  void _listenToRider(String riderId) {
    _riderSub?.cancel();
    _riderSub = _dbService.getRiderStream(riderId).listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data() as Map<String, dynamic>;

      final newPosition = LatLng(
        data['current_latitude'] ?? 0,
        data['current_longitude'] ?? 0,
      );

       // ทำงานต่อเมื่อตำแหน่งใหม่ไม่เป็น 0,0 และต่างจากเดิม
      if ((newPosition.latitude != 0 || newPosition.longitude != 0) && _riderPosition != newPosition) {
          LatLng? previousPosition = _riderPosition; // เก็บตำแหน่งเก่าไว้คำนวณ rotation
          _riderPosition = newPosition; // อัปเดตตำแหน่งใหม่

          // คำนวณ Rotation
          if (previousPosition != null) {
            _riderRotation = _calculateBearing(previousPosition, _riderPosition!);
          }

           setState(() {
             _riderName = data['name'] ?? 'Rider';
             _riderPhotoUrl = data['photoUrl'];
             _updateMarkers(); // อัปเดตหมุด Rider
           });

           _getRoutePolyline(); // ‼️ เรียกวาดเส้นทาง OSRM ‼️
           _animateCameraToRider(); // ขยับกล้องตาม
       }
    });
  }

  // --- ‼️ ฟังก์ชันใหม่: เรียก OSRM API (เหมือนของ Rider) ‼️ ---
  Future<void> _getRoutePolyline() async {
    LatLng? destination;
    // User จะเห็นเส้นทาง Rider -> จุดรับ หรือ Rider -> จุดส่ง
    if (_deliveryStatus == 'rider_accepted') {
      destination = _pickupLatLng;
    } else if (_deliveryStatus == 'picked_up') {
      destination = _deliveryLatLng;
    }
    // ไม่วาดถ้าไม่มีตำแหน่ง Rider หรือ จุดหมาย หรือ จุดหมายไม่ถูกต้อง
    if (_riderPosition == null || destination == null || destination.latitude == 0 || destination.longitude == 0) {
      if (mounted) setState(() => _polylines.clear());
      return;
    }

    final osrmBaseUrl = 'https://router.project-osrm.org'; // DEMO SERVER!
    final profile = 'driving';
    final coordinates =
        '${_riderPosition!.longitude},${_riderPosition!.latitude};${destination.longitude},${destination.latitude}';
    final url = Uri.parse(
        '$osrmBaseUrl/route/v1/$profile/$coordinates?overview=full&geometries=polyline');

    print("Calling OSRM (User Tracking): $url");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty && data['routes'][0]['geometry'] != null) {
          final encodedPolyline = data['routes'][0]['geometry'];
          List<PointLatLng> result = polylinePoints.decodePolyline(encodedPolyline);
          List<LatLng> polylineCoordinates = result.map((p) => LatLng(p.latitude, p.longitude)).toList();

          if (mounted) {
            setState(() {
              _polylines.clear();
              _polylines.add(
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: polylineCoordinates,
                  color: Colors.blueAccent,
                  width: 5,
                ),
              );
            });
             print("✅ OSRM route drawn (User Tracking).");
          }
        } else {
           print("No routes found by OSRM API (User Tracking).");
           if (mounted) setState(() => _polylines.clear());
        }
      } else {
         print("OSRM API request failed (User Tracking): ${response.statusCode}");
         if (mounted) setState(() => _polylines.clear());
      }
    } catch (e) {
      print("🚨 Error calling OSRM API (User Tracking): $e");
       if (mounted) setState(() => _polylines.clear());
    }
  }


  // (ฟังก์ชัน _updateMarkers เหมือนเดิม)
  void _updateMarkers() {
    if (!mounted) return;
    // ใช้ Set ใหม่เพื่อป้องกันการแก้ไขขณะวนลูป และเรียก setState ครั้งเดียวท้ายสุด
    Set<Marker> updatedMarkers = {};

    // หมุด: ต้นทาง
    if (_pickupLatLng != null && _pickupLatLng!.latitude != 0 && _pickupLatLng!.longitude != 0) {
      updatedMarkers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLatLng!,
        infoWindow: const InfoWindow(title: 'จุดรับสินค้า'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }

    // หมุด: ปลายทาง
    if (_deliveryLatLng != null && _deliveryLatLng!.latitude != 0 && _deliveryLatLng!.longitude != 0) {
      updatedMarkers.add(Marker(
        markerId: const MarkerId('delivery'),
        position: _deliveryLatLng!,
        infoWindow: const InfoWindow(title: 'จุดส่งสินค้า'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }

    // หมุด: ไรเดอร์
    if (_riderPosition != null && _riderPosition!.latitude != 0 && _riderPosition!.longitude != 0) {
      updatedMarkers.add(Marker(
        markerId: const MarkerId('rider'),
        position: _riderPosition!,
        infoWindow: InfoWindow(title: _riderName),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        rotation: _riderRotation,
        flat: true,
      ));
    }
     // อัปเดต State ทีเดียว
     setState(() {
       _markers.clear();
       _markers.addAll(updatedMarkers);
     });
  }

  // (ฟังก์ชัน _animateCameraToRider เหมือนเดิม)
   Future<void> _animateCameraToRider() async {
     if (_riderPosition != null && _mapController.isCompleted && (_riderPosition!.latitude != 0 || _riderPosition!.longitude != 0)) {
       final controller = await _mapController.future;
       controller.animateCamera(CameraUpdate.newLatLng(_riderPosition!));
     }
   }

  // (ฟังก์ชัน _geoPointToLatLng เหมือนเดิม)
   LatLng? _geoPointToLatLng(dynamic geoPoint) {
     if (geoPoint is! GeoPoint) return null;
     // Return null or a default LatLng if coordinates are invalid (e.g., 0,0)
     if (geoPoint.latitude == 0 && geoPoint.longitude == 0) return null; // Or return const LatLng(DEFAULT_LAT, DEFAULT_LON);
     return LatLng(geoPoint.latitude, geoPoint.longitude);
   }

   // (ฟังก์ชันคำนวณ Bearing เหมือนเดิม)
    double _toRadians(double degrees) => degrees * (math.pi / 180.0);
    double _toDegrees(double radians) => radians * (180.0 / math.pi);
    double _calculateBearing(LatLng startPoint, LatLng endPoint) {
       final double startLat = _toRadians(startPoint.latitude);
       final double startLng = _toRadians(startPoint.longitude);
       final double endLat = _toRadians(endPoint.latitude);
       final double endLng = _toRadians(endPoint.longitude);
       final double deltaLng = endLng - startLng;
       final double y = math.sin(deltaLng) * math.cos(endLat);
       final double x = math.cos(startLat) * math.sin(endLat) -
           math.sin(startLat) * math.cos(endLat) * math.cos(deltaLng);
       final double bearing = math.atan2(y, x);
       return (_toDegrees(bearing) + 360) % 360;
    }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ติดตามการจัดส่ง'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickupLatLng ?? const LatLng(13.736717, 100.523186),
              zoom: 14,
            ),
            onMapCreated: (controller) {
               if(!_mapController.isCompleted) {
                 _mapController.complete(controller);
                 // วาดเส้นทางครั้งแรกเมื่อแผนที่พร้อม
                  _getRoutePolyline();
               }
            },
            markers: _markers,
            polylines: _polylines, // ‼️ แสดงเส้นทาง OSRM ‼️
            myLocationEnabled: false,
             zoomControlsEnabled: true, // Optionally re-enable zoom controls for user convenience
          ),
          // (Bottom Status Card เหมือนเดิม)
           Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomStatusCard(),
          ),
        ],
      ),
    );
  }

  // (Widget _buildBottomStatusCard เหมือนเดิม)
  Widget _buildBottomStatusCard() {
    // ... (โค้ดเดิม) ...
      return Card(
      margin: const EdgeInsets.all(12),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'สถานะ: $_deliveryStatus',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_riderId != null)
              ListTile(
                contentPadding: EdgeInsets.zero, // Remove default padding
                leading: CircleAvatar(
                  radius: 25, // Slightly larger avatar
                  backgroundImage: (_riderPhotoUrl != null)
                      ? NetworkImage(_riderPhotoUrl!)
                      : null,
                  child: (_riderPhotoUrl == null)
                      ? const Icon(Icons.person, size: 30) // Larger icon
                      : null,
                ),
                title: Text('Rider: $_riderName', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_deliveryStatus == 'rider_accepted'
                    ? 'กำลังเดินทางไปรับสินค้า...'
                    : 'กำลังนำส่งสินค้าถึงคุณ...'), // More specific subtitle
              )
            else
              const Padding( // Add padding for consistency
                 padding: EdgeInsets.symmetric(vertical: 8.0),
                 child: Text('กำลังค้นหา Rider...', style: TextStyle(fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
    );
  }
} 