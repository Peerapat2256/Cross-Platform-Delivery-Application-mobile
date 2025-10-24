// lib/screens/user/user_tracking_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:test_databse/service/db_service.dart';
import 'dart:math' as math; 

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

  // Stream Subscriptions (สำคัญมาก ต้อง dispose)
  StreamSubscription? _deliverySub;
  StreamSubscription? _riderSub;

  @override
  void initState() {
    super.initState();
    _listenToDelivery();
  }

  @override
  void dispose() {
    // ‼️ ยกเลิกการฟัง Stream ทั้งหมด ‼️
    _deliverySub?.cancel();
    _riderSub?.cancel();
    super.dispose();
  }

  // 1. ฟังข้อมูลงาน
  void _listenToDelivery() {
    _deliverySub =
        _dbService.getDeliveryStream(widget.deliveryId).listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data() as Map<String, dynamic>;

      // อัปเดตข้อมูลงาน
      setState(() {
        _deliveryStatus = data['status'] ?? 'N/A';
        _pickupLatLng = _geoPointToLatLng(data['pickup_location']);
        _deliveryLatLng = _geoPointToLatLng(data['delivery_location']);
      });

      // อัปเดต Marker
      _updateMarkers();

      // ตรวจสอบ Rider ID
      final newRiderId = data['rider_id'] as String?;
      if (newRiderId != null && newRiderId != _riderId) {
        // ถ้ามี Rider ID ใหม่ (เพิ่งรับงาน) หรือ Rider ID เปลี่ยน
        setState(() => _riderId = newRiderId);
        _listenToRider(newRiderId); // ‼️ ให้เริ่มฟังตำแหน่ง Rider
      }
    });
  }

  // 2. ฟังข้อมูลไรเดอร์ (จะถูกเรียกเมื่อมี riderId)
  void _listenToRider(String riderId) {
    // ยกเลิกการฟังคนเก่า (ถ้ามี)
    _riderSub?.cancel();

    _riderSub = _dbService.getRiderStream(riderId).listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data() as Map<String, dynamic>;

      // ดึงพิกัด
      final newPosition = _geoPointToLatLng(GeoPoint(
        data['current_latitude'] ?? 0,
        data['current_longitude'] ?? 0,
      ));

      // คำนวณการหมุน
      if (_riderPosition != null && newPosition != _riderPosition) {
        _riderRotation = _calculateBearing(_riderPosition!, newPosition!);
      }

      setState(() {
        _riderName = data['name'] ?? 'Rider';
        _riderPhotoUrl = data['photoUrl']; // (ต้องตรงกับ field ที่คุณเก็บรูป)
        _riderPosition = newPosition;
      });

      _updateMarkers();
      _animateCameraToRider(); // ขยับกล้องตาม
    });
  }

  // --- (Helper Functions) ---

  void _updateMarkers() {
    if (!mounted) return;
    setState(() {
      _markers.clear(); // ล้างของเก่า

      // หมุด: ต้นทาง
      if (_pickupLatLng != null) {
        _markers.add(Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLatLng!,
          infoWindow: const InfoWindow(title: 'จุดรับสินค้า'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ));
      }

      // หมุด: ปลายทาง
      if (_deliveryLatLng != null) {
        _markers.add(Marker(
          markerId: const MarkerId('delivery'),
          position: _deliveryLatLng!,
          infoWindow: const InfoWindow(title: 'จุดส่งสินค้า'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ));
      }

      // หมุด: ไรเดอร์
      if (_riderPosition != null) {
        _markers.add(Marker(
          markerId: const MarkerId('rider'),
          position: _riderPosition!,
          infoWindow: InfoWindow(title: _riderName),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          rotation: _riderRotation,
          flat: true,
        ));
      }
    });
  }

  Future<void> _animateCameraToRider() async {
    if (_riderPosition != null && _mapController.isCompleted) {
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLng(_riderPosition!));
    }
  }

  LatLng? _geoPointToLatLng(dynamic geoPoint) {
    if (geoPoint is! GeoPoint) return null;
    return LatLng(geoPoint.latitude, geoPoint.longitude);
  }

  // ... (โค้ดคำนวณองศา _calculateBearing, _toRadians, _toDegrees) ...
  // (คัดลอกจาก `delivery_tracking_screen.dart` ของ Rider มาได้เลย)
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
            onMapCreated: (controller) => _mapController.complete(controller),
            markers: _markers,
            myLocationEnabled: false,
          ),
          // กล่องแสดงสถานะ
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

  Widget _buildBottomStatusCard() {
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
                leading: CircleAvatar(
                  backgroundImage: (_riderPhotoUrl != null)
                      ? NetworkImage(_riderPhotoUrl!)
                      : null,
                  child: (_riderPhotoUrl == null)
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text('Rider: $_riderName'),
                subtitle: const Text('กำลังเดินทาง...'),
              )
            else
              const Text('กำลังค้นหา Rider...'),
          ],
        ),
      ),
    );
  }
}