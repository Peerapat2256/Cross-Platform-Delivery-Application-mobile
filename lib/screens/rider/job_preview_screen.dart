// lib/screens/rider/job_preview_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:test_databse/controller/rider/rider_controller.dart';
import 'package:test_databse/model/rider.dart'; 
import 'package:test_databse/screens/rider/delivery_tracking_screen.dart';

class JobPreviewScreen extends StatefulWidget {
  final Delivery delivery; // รับ Delivery object มาทั้งก้อน
  const JobPreviewScreen({super.key, required this.delivery});

  @override
  State<JobPreviewScreen> createState() => _JobPreviewScreenState();
}

class _JobPreviewScreenState extends State<JobPreviewScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final Set<Marker> _markers = {};
  LatLng? _pickupLatLng;
  LatLng? _deliveryLatLng;
  bool _isLoading = false; // สถานะตอนกดยืนยัน

  @override
  void initState() {
    super.initState();
    _setMarkers();
  }

  void _setMarkers() {
    // เราต้องดึง LatLng จาก Model (ซึ่งตอนนี้ยังไม่มี)
    // ***ชั่วคราว: เราต้องไปแก้ Model ก่อน***
    // (เดี๋ยวขั้นที่ 2 เราจะไปเพิ่ม GeoPoint ใน Model)

    // ***อัปเดต: หลังจากแก้ Model ในขั้นที่ 2 แล้ว โค้ดนี้จะทำงานได้***
    _pickupLatLng = LatLng(
      widget.delivery.pickupLocation.latitude,
      widget.delivery.pickupLocation.longitude,
    );
    _deliveryLatLng = LatLng(
      widget.delivery.deliveryLocation.latitude,
      widget.delivery.deliveryLocation.longitude,
    );

    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLatLng!,
          infoWindow: const InfoWindow(title: 'จุดรับสินค้า (A)'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
      _markers.add(
        Marker(
          markerId: const MarkerId('delivery'),
          position: _deliveryLatLng!,
          infoWindow: const InfoWindow(title: 'จุดส่งสินค้า (B)'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    });
  }

  // ฟังก์ชันสำหรับ Zoom ให้เห็นหมุดทั้งหมด
  void _fitBounds(GoogleMapController controller) {
    if (_pickupLatLng == null || _deliveryLatLng == null) return;

    LatLngBounds bounds;
    if (_pickupLatLng!.latitude > _deliveryLatLng!.latitude) {
      bounds = LatLngBounds(
        southwest: _deliveryLatLng!,
        northeast: _pickupLatLng!,
      );
    } else {
      bounds = LatLngBounds(
        southwest: _pickupLatLng!,
        northeast: _deliveryLatLng!,
      );
    }
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
  }

  // ฟังก์ชันกดยืนยันรับงาน
  Future<void> _confirmAcceptJob() async {
    setState(() => _isLoading = true);
    final controller = RiderHomeController();

    final result = await controller.acceptJob(widget.delivery.deliveryId);

    if (!mounted) return;

    if (result == "รับงานสำเร็จ") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("รับงานสำเร็จ!"), backgroundColor: Colors.green),
      );
      // เด้งไปหน้า Tracking (แทนที่หน้าพรีวิวนี้)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DeliveryTrackingPage(
            deliveryId: widget.delivery.deliveryId,
          ),
        ),
      );
    } else {
      // ถ้าไม่สำเร็จ (เช่น งานโดนตัดหน้า)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), backgroundColor: Colors.red),
      );
      // เด้งกลับไปหน้า List (หน้ารวมงาน)
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตรวจสอบงานก่อนรับ'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickupLatLng ?? const LatLng(13.736717, 100.523186),
              zoom: 11,
            ),
            markers: _markers,
            onMapCreated: (controller) {
              _mapController.complete(controller);
              _fitBounds(controller); // สั่งให้ Map ซูมพอดีหมุด
            },
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Card(
              margin: const EdgeInsets.all(12),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('รับ: ${widget.delivery.pickupAddress}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('ส่ง: ${widget.delivery.deliveryAddress}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _confirmAcceptJob,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'ยืนยันรับงาน',
                              style: TextStyle(color: Colors.white),
                            ),
                    )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}