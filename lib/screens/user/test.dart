// lib/screens/user/multi_tracking_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:test_databse/service/db_service.dart';
import 'package:test_databse/model/rider.dart';
import 'package:geolocator/geolocator.dart'; 

class MultiTrackingWidget extends StatefulWidget {
  const MultiTrackingWidget({super.key});

  @override
  State<MultiTrackingWidget> createState() => _MultiTrackingWidgetState();
}

class _MultiTrackingWidgetState extends State<MultiTrackingWidget> {
  final DbService _dbService = DbService();
  final Completer<GoogleMapController> _mapController = Completer();
  final Set<Marker> _markers = {};

  // --- State Management (เดิม) ---
  List<Delivery> _sentDeliveries = [];
  List<Delivery> _receivedDeliveries = [];
  List<Delivery> _allActiveDeliveries = [];
  final Map<String, LatLng> _riderLocations = {};
  final Map<String, String> _riderNames = {};
  StreamSubscription? _sentSub;
  StreamSubscription? _receivedSub;
  final Map<String, StreamSubscription> _riderSubs = {};

  // --- ‼️ 2. แก้ไข State ของแผนที่ ---
  LatLng _initialCameraPosition =
      const LatLng(13.736717, 100.523186); // (Default Bangkok)
  bool _isLoadingLocation = true; // (สถานะโหลดตำแหน่ง)

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndStartListeners(); // ‼️ 3. เรียกฟังก์ชันใหม่
  }

  // ‼️ 4. สร้างฟังก์ชันใหม่สำหรับดึงตำแหน่ง
  Future<void> _getCurrentLocationAndStartListeners() async {
    try {
      // 4.1 เช็คและขอสิทธิ์
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // ถ้าไม่ให้สิทธิ์ ก็ใช้ กทม. ต่อไป
        if (mounted) setState(() => _isLoadingLocation = false);
      } else {
        // 4.2 ถ้าให้สิทธิ์ -> ดึงตำแหน่ง
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        if (mounted) {
          setState(() {
            // 4.3 อัปเดตตำแหน่งเริ่มต้น
            _initialCameraPosition = LatLng(position.latitude, position.longitude);
            _isLoadingLocation = false;
          });
          _animateCameraToCurrentLocation(); // (ขยับกล้องไปที่นั่น)
        }
      }
    } catch (e) {
      print("Error getting current location: $e");
      if (mounted) setState(() => _isLoadingLocation = false);
    }

    // 4.4 เริ่มฟัง Stream (เหมือนเดิม)
    _sentSub = _dbService.getMySentDeliveries().listen((list) {
      _sentDeliveries = list;
      _updateCombinedList();
    });

    _receivedSub = _dbService.getMyReceivedDeliveries().listen((list) {
      _receivedDeliveries = list;
      _updateCombinedList();
    });
  }
  
  // ‼️ 5. เพิ่มฟังก์ชันขยับกล้อง
  Future<void> _animateCameraToCurrentLocation() async {
    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(_initialCameraPosition, 15), // ซูมเข้าไปใกล้ๆ
    );
  }

  @override
  void dispose() {
    // ... (โค้ด dispose เดิม) ...
  }

  // ... (โค้ด _updateCombinedList เดิม) ...
  // ... (โค้ด _updateRiderSubscriptions เดิม) ...
  // ... (โค้ด _updateAllMarkers เดิม) ...

  void _updateCombinedList() {
    _allActiveDeliveries = [..._sentDeliveries, ..._receivedDeliveries]
        .where((d) =>
            d.status == 'rider_accepted' || d.status == 'picked_up')
        .toList();
    _updateRiderSubscriptions();
    _updateAllMarkers();
  }

  void _updateRiderSubscriptions() {
    final newRiderIds = _allActiveDeliveries
        .map((d) => d.riderId)
        .where((id) => id != null)
        .toSet();
    final oldRiderIds = _riderSubs.keys.toSet();
    final ridersToRemove = oldRiderIds.difference(newRiderIds);
    for (final riderId in ridersToRemove) {
      _riderSubs[riderId]?.cancel();
      _riderSubs.remove(riderId);
      _riderLocations.remove(riderId);
      _riderNames.remove(riderId);
    }
    final ridersToAdd = newRiderIds.difference(oldRiderIds);
    for (final riderId in ridersToAdd) {
      if (riderId != null) {  
        _riderSubs[riderId] =
            _dbService.getRiderStream(riderId).listen((snapshot) {
          if (snapshot.exists && mounted) {
            final data = snapshot.data() as Map<String, dynamic>;
            final newPos = LatLng(
              data['current_latitude'] ?? 0,
              data['current_longitude'] ?? 0,
            );
            _riderLocations[riderId] = newPos;
            _riderNames[riderId] = data['name'] ?? 'Rider';
            _updateAllMarkers();
          }
        });
      }
    }
  }

  void _updateAllMarkers() {
    _markers.clear();
    for (final riderId in _riderLocations.keys) {
      _markers.add(
        Marker(
          markerId: MarkerId('rider_$riderId'),
          position: _riderLocations[riderId]!,
          infoWindow: InfoWindow(title: _riderNames[riderId] ?? 'Rider'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          flat: true,
        ),
      );
    }
    for (final delivery in _allActiveDeliveries) {
      _markers.add(
        Marker(
          markerId: MarkerId('pickup_${delivery.deliveryId}'),
          position: LatLng(delivery.pickupLocation.latitude,
              delivery.pickupLocation.longitude),
          infoWindow:
              InfoWindow(title: 'รับของ (งาน: ${delivery.receiverName})'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
      _markers.add(
        Marker(
          markerId: MarkerId('delivery_${delivery.deliveryId}'),
          position: LatLng(delivery.deliveryLocation.latitude,
              delivery.deliveryLocation.longitude),
          infoWindow:
              InfoWindow(title: 'ส่งของ (งาน: ${delivery.receiverName})'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      // ‼️ 6. หุ้มด้วย Stack เพื่อแสดง Loading
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialCameraPosition, // ‼️ 7. ใช้ตำแหน่งเริ่มต้นใหม่
              zoom: 12,
            ),
            onMapCreated: (controller) {
              _mapController.complete(controller);
              // ‼️ 8. ถ้าโหลดตำแหน่งเสร็จแล้ว ค่อยขยับกล้อง
              if (!_isLoadingLocation) {
                _animateCameraToCurrentLocation();
              }
            },
            markers: _markers,
            zoomControlsEnabled: false,
            myLocationEnabled: true, // ‼️ 9. แสดงจุดสีฟ้า (ตำแหน่งของเรา)
            myLocationButtonEnabled: true, // ‼️ 10. แสดงปุ่มขยับไปหาเรา
          ),

          // ‼️ 11. แสดง Loading ขณะดึงตำแหน่ง
          if (_isLoadingLocation)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}