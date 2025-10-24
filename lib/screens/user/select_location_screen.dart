// lib/screens/user/select_location_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({super.key});

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  LatLng? _selectedLocation;
  LatLng _initialPosition = const LatLng(13.736717, 100.523186); // Bangkok

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
        _selectedLocation = _initialPosition;
      });
      _animateCamera(_initialPosition);
    } catch (e) {
      print("Error getting location: $e");
      // ถ้าไม่ได้ ก็ใช้ กทม. เป็นค่าเริ่มต้น
      setState(() {
        _selectedLocation = _initialPosition;
      });
    }
  }

  Future<void> _animateCamera(LatLng target) async {
    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
  }

  void _onMapTapped(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกพิกัด'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 16,
            ),
            onMapCreated: (controller) {
              _mapController.complete(controller);
            },
            onTap: _onMapTapped,
            markers: _selectedLocation == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('selectedLocation'),
                      position: _selectedLocation!,
                      draggable: true,
                      onDragEnd: (newPosition) {
                        setState(() {
                          _selectedLocation = newPosition;
                        });
                      },
                    ),
                  },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('ยืนยันตำแหน่งนี้'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: _selectedLocation == null
                  ? null
                  : () {
                      // ส่งค่า LatLng กลับไปหน้าก่อนหน้า
                      Navigator.pop(context, _selectedLocation);
                    },
            ),
          ),
        ],
      ),
    );
  }
}