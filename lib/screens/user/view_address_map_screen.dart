// lib/screens/user/view_address_map_screen.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ViewAddressMapScreen extends StatefulWidget {
  final GeoPoint location;
  final String addressName;

  const ViewAddressMapScreen({
    Key? key,
    required this.location,
    required this.addressName,
  }) : super(key: key);

  @override
  State<ViewAddressMapScreen> createState() => _ViewAddressMapScreenState();
}

class _ViewAddressMapScreenState extends State<ViewAddressMapScreen> {
  late LatLng _markerPosition;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    // 1. แปลง GeoPoint ที่รับมา เป็น LatLng
    _markerPosition = LatLng(
      widget.location.latitude,
      widget.location.longitude,
    );

    // 2. สร้าง Marker เตรียมไว้
    _markers.add(
      Marker(
        markerId: MarkerId(widget.addressName), // ใช้ชื่อที่อยู่เป็น ID
        position: _markerPosition,
        infoWindow: InfoWindow(title: widget.addressName), // แสดงชื่อบนหมุด
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('พิกัด: ${widget.addressName}'), // แสดงชื่อที่อยู่บน AppBar
      ),
      body: GoogleMap(
        // 3. ตั้งค่ากล้องให้ซูมไปที่พิกัดนั้น
        initialCameraPosition: CameraPosition(
          target: _markerPosition,
          zoom: 16, // ซูมเข้าไปใกล้ๆ
        ),
        markers: _markers, // 4. แสดง Marker ที่เราสร้างไว้
        myLocationButtonEnabled: false,
        mapToolbarEnabled: false,
      ),
    );
  }
}