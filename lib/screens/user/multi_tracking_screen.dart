// lib/screens/user/multi_tracking_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:test_databse/service/db_service.dart';
import 'package:test_databse/model/rider.dart'; 

class MultiTrackingScreen extends StatefulWidget {
  const MultiTrackingScreen({super.key});

  @override
  State<MultiTrackingScreen> createState() => _MultiTrackingScreenState();
}

class _MultiTrackingScreenState extends State<MultiTrackingScreen> {
  final DbService _dbService = DbService();
  final Completer<GoogleMapController> _mapController = Completer();
  final Set<Marker> _markers = {};

  // --- State Management ---
  // 1. State ที่เก็บรายการงาน
  List<Delivery> _sentDeliveries = [];
  List<Delivery> _receivedDeliveries = [];
  List<Delivery> _allActiveDeliveries = [];

  // 2. State ที่เก็บตำแหน่งไรเดอร์
  // Key: riderId, Value: LatLng
  final Map<String, LatLng> _riderLocations = {};
  // Key: riderId, Value: Name
  final Map<String, String> _riderNames = {};

  // 3. State ที่ใช้จัดการ Stream (สำคัญมาก)
  StreamSubscription? _sentSub;
  StreamSubscription? _receivedSub;
  // Key: riderId, Value: Subscription
  final Map<String, StreamSubscription> _riderSubs = {};

  // --- Center Map ---
  static const LatLng _center = LatLng(13.736717, 100.523186); // Bangkok

  @override
  void initState() {
    super.initState();

    // 1. เริ่มฟัง Stream งานที่ "ส่งไป"
    _sentSub = _dbService.getMySentDeliveries().listen((list) {
      _sentDeliveries = list;
      _updateCombinedList(); // 2. เมื่อข้อมูลเปลี่ยน -> อัปเดตลิสต์รวม
    });

    // 1. เริ่มฟัง Stream งานที่ "ส่งมา"
    _receivedSub = _dbService.getMyReceivedDeliveries().listen((list) {
      _receivedDeliveries = list;
      _updateCombinedList(); // 2. เมื่อข้อมูลเปลี่ยน -> อัปเดตลิสต์รวม
    });
  }

  @override
  void dispose() {
    // ‼️ สำคัญมาก: ปิดการฟัง Stream ทั้งหมดเมื่อออกจากหน้า
    _sentSub?.cancel();
    _receivedSub?.cancel();
    _riderSubs.values.forEach((sub) => sub.cancel());
    super.dispose();
  }

  /// 2. ฟังก์ชันรวมลิสต์ (หัวใจหลัก)
  void _updateCombinedList() {
    // กรองเอาเฉพาะงานที่ Active (มีไรเดอร์แล้ว และยังไม่จบ)
    _allActiveDeliveries = [..._sentDeliveries, ..._receivedDeliveries]
        .where((d) =>
            d.status == 'rider_accepted' || d.status == 'picked_up')
        .toList();

    // 3. อัปเดตการฟังตำแหน่งไรเดอร์ (ตามลิสต์ใหม่)
    _updateRiderSubscriptions();
    // 4. วาดหมุดใหม่ทั้งหมด
    _updateAllMarkers();
  }

  /// 3. ฟังก์ชันจัดการการฟังตำแหน่งไรเดอร์
  void _updateRiderSubscriptions() {
    // 3.1. หา ID ไรเดอร์ "ชุดใหม่"
    final newRiderIds = _allActiveDeliveries
        .map((d) => d.riderId)
        .where((id) => id != null)
        .toSet();

    // 3.2. หา ID ไรเดอร์ "ชุดเก่า" (ที่กำลังฟังอยู่)
    final oldRiderIds = _riderSubs.keys.toSet();

    // 3.3. หาไรเดอร์ที่ "ต้องลบ" (อยู่ในชุดเก่า แต่ไม่อยู่ในชุดใหม่)
    final ridersToRemove = oldRiderIds.difference(newRiderIds);
    for (final riderId in ridersToRemove) {
      _riderSubs[riderId]?.cancel(); // หยุดฟัง
      _riderSubs.remove(riderId); // ลบออกจาก Map
      _riderLocations.remove(riderId); // ลบตำแหน่ง
      _riderNames.remove(riderId);
    }

    // 3.4. หาไรเดอร์ที่ "ต้องเพิ่ม" (อยู่ในชุดใหม่ แต่ไม่อยู่ในชุดเก่า)
    final ridersToAdd = newRiderIds.difference(oldRiderIds);
    for (final riderId in ridersToAdd) {
      if (riderId == null) continue;
      _riderSubs[riderId] =
          _dbService.getRiderStream(riderId).listen((snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data() as Map<String, dynamic>;
          final newPos = LatLng(
            data['current_latitude'] ?? 0,
            data['current_longitude'] ?? 0,
          );

          // อัปเดต State ตำแหน่ง
          _riderLocations[riderId] = newPos;
          _riderNames[riderId] = data['name'] ?? 'Rider';

          // 4. วาดหมุดใหม่
          _updateAllMarkers();
        }
      });
    }
  }

  /// 4. ฟังก์ชันวาดหมุดทั้งหมดลงแผนที่
  void _updateAllMarkers() {
    _markers.clear(); // ล้างของเก่าทิ้ง

    // 4.1. วาดหมุด "ไรเดอร์" (สีส้ม)
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

    // 4.2. วาดหมุด "จุดรับ" (สีน้ำเงิน) และ "จุดส่ง" (สีเขียว)
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
      setState(() {}); // สั่งให้ UI วาดใหม่
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ติดตามงานทั้งหมด (Real-time)'),
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _center,
          zoom: 12,
        ),
        onMapCreated: (controller) => _mapController.complete(controller),
        markers: _markers,
      ),
    );
  }
}