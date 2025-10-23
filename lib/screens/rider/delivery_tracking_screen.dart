// import 'dart:async';
// import 'dart:io';
// import 'dart:math' as Math;

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:test_databse/controller/rider/rider_controller.dart'; // ตรวจสอบ Path

// class DeliveryTrackingPage extends StatefulWidget {
//   final String deliveryId;
//   const DeliveryTrackingPage({Key? key, required this.deliveryId})
//     : super(key: key);

//   @override
//   State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
// }

// class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
//   final RiderHomeController _controller = RiderHomeController();
//   final Completer<GoogleMapController> _mapController = Completer();
//   final ImagePicker _picker = ImagePicker();

//   StreamSubscription<Position>? _positionSubscription;
//   LatLng? _riderPosition;
//   double _riderRotation = 0.0; // ‼️ 2. เพิ่มตัวแปรเก็บองศาการหมุน
//   LatLng? _pickupLatLng;
//   LatLng? _deliveryLatLng;
//   String _status = '';
//   final Set<Marker> _markers = {};

//   @override
//   void initState() {
//     super.initState();
//     _controller.startLocationUpdates();
//     _startListeningToLocationUI();
//     _listenDeliveryStream();
//   }

//   @override
//   void dispose() {
//     _controller.stopLocationUpdates();
//     _positionSubscription?.cancel();
//     super.dispose();
//   }

//   // ‼️ 3. เพิ่มฟังก์ชันสำหรับคำนวณองศา
//   double _toRadians(double degrees) => degrees * (Math.pi / 180.0);
//   double _toDegrees(double radians) => radians * (180.0 / Math.pi);

//   double _calculateBearing(LatLng startPoint, LatLng endPoint) {
//     final double startLat = _toRadians(startPoint.latitude);
//     final double startLng = _toRadians(startPoint.longitude);
//     final double endLat = _toRadians(endPoint.latitude);
//     final double endLng = _toRadians(endPoint.longitude);
//     final double deltaLng = endLng - startLng;
//     final double y = Math.sin(deltaLng) * Math.cos(endLat);
//     final double x =
//         Math.cos(startLat) * Math.sin(endLat) -
//         Math.sin(startLat) * Math.cos(endLat) * Math.cos(deltaLng);
//     final double bearing = Math.atan2(y, x);
//     return (_toDegrees(bearing) + 360) % 360;
//   }

//   // ‼️ 4. แก้ไขฟังก์ชันนี้เพื่อคำนวณองศา
//   void _startListeningToLocationUI() {
//     _positionSubscription =
//         Geolocator.getPositionStream(
//           locationSettings: const LocationSettings(
//             accuracy: LocationAccuracy.high,
//             distanceFilter: 5, // ลดระยะทางเพื่อการอัปเดตที่ถี่ขึ้น
//           ),
//         ).listen((Position position) {
//           if (mounted) {
//             final newPosition = LatLng(position.latitude, position.longitude);

//             // คำนวณองศา ถ้ามีตำแหน่งเก่าอยู่แล้ว
//             if (_riderPosition != null) {
//               _riderRotation = _calculateBearing(_riderPosition!, newPosition);
//             }

//             _riderPosition = newPosition; // อัปเดตตำแหน่งใหม่

//             setState(() {
//               _updateMarkers(); // สั่งให้วาดหมุดใหม่ (ซึ่งตอนนี้จะมี rotation แล้ว)
//             });

//             _animateCameraToRider();
//           }
//         });
//   }

//   void _listenDeliveryStream() {
//     _controller.getDeliveryStream(widget.deliveryId).listen((snapshot) {
//       if (!snapshot.exists || !mounted) return;
//       final data = snapshot.data() as Map<String, dynamic>;
//       _status = data['status'];
//       final pickupGeoPoint = data['pickup_location'] as GeoPoint;
//       final deliveryGeoPoint = data['delivery_location'] as GeoPoint;

//       _pickupLatLng = LatLng(pickupGeoPoint.latitude, pickupGeoPoint.longitude);
//       _deliveryLatLng = LatLng(
//         deliveryGeoPoint.latitude,
//         deliveryGeoPoint.longitude,
//       );

//       _updateMarkers();
//     });
//   }

//   void _updateMarkers() {
//     // ใช้ Set ใหม่เพื่อป้องกันการแก้ไขขณะวนลูป
//     Set<Marker> updatedMarkers = {};

//     if (_pickupLatLng != null) {
//       updatedMarkers.add(
//         Marker(
//           markerId: const MarkerId('pickup'),
//           position: _pickupLatLng!,
//           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//           infoWindow: const InfoWindow(title: 'จุดรับสินค้า'),
//         ),
//       );
//     }

//     if (_deliveryLatLng != null) {
//       updatedMarkers.add(
//         Marker(
//           markerId: const MarkerId('delivery'),
//           position: _deliveryLatLng!,
//           icon: BitmapDescriptor.defaultMarkerWithHue(
//             BitmapDescriptor.hueGreen,
//           ),
//           infoWindow: const InfoWindow(title: 'จุดส่งสินค้า'),
//         ),
//       );
//     }

//     // ‼️ 5. แก้ไขการสร้าง Marker ของไรเดอร์
//     if (_riderPosition != null) {
//       updatedMarkers.add(
//         Marker(
//           markerId: const MarkerId('rider'),
//           position: _riderPosition!,
//           icon: BitmapDescriptor.defaultMarkerWithHue(
//             BitmapDescriptor.hueOrange,
//           ),
//           infoWindow: const InfoWindow(title: 'ตำแหน่งของคุณ'),
//           flat: true, // ทำให้ไอคอนแบนราบไปกับแผนที่
//           rotation: _riderRotation, // ใช้ค่าองศาที่เราคำนวณได้
//         ),
//       );
//     }

//     if (mounted) {
//       setState(() {
//         _markers.clear();
//         _markers.addAll(updatedMarkers);
//       });
//     }
//   }

//   // ‼️ 6. แก้ไขการเคลื่อนที่ของกล้อง
//   Future<void> _animateCameraToRider() async {
//     if (_riderPosition != null && _mapController.isCompleted) {
//       final controller = await _mapController.future;
//       controller.animateCamera(
//         CameraUpdate.newCameraPosition(
//           CameraPosition(
//             target: _riderPosition!,
//             zoom: 17.5, // ซูมเข้าไปอีกนิด
//             tilt: 45.0, // เพิ่มมุมมองเอียง 45 องศา
//             bearing: _riderRotation, // ให้กล้องหันตามทิศทางของรถ
//           ),
//         ),
//       );
//     }
//   }

//   // Zoom In / Out
//   Future<void> _zoomIn() async {
//     final controller = await _mapController.future;
//     controller.animateCamera(CameraUpdate.zoomIn());
//   }

//   Future<void> _zoomOut() async {
//     final controller = await _mapController.future;
//     controller.animateCamera(CameraUpdate.zoomOut());
//   }

//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: () async => false,
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('กำลังจัดส่งสินค้า'),
//           automaticallyImplyLeading: false,
//         ),
//         body: Stack(
//           children: [
//             GoogleMap(
//               initialCameraPosition: CameraPosition(
//                 target:
//                     _pickupLatLng ?? LatLng(13.736717, 100.523186), // Bangkok
//                 zoom: 15,
//               ),
//               onMapCreated: (controller) {
//                 if (!_mapController.isCompleted) {
//                   _mapController.complete(controller);
//                 }
//               },
//               markers: _markers,
//               zoomControlsEnabled: false,
//               myLocationEnabled: false,
//             ),
//             // ปุ่ม Zoom
//             Positioned(
//               top: 16,
//               right: 16,
//               child: Column(
//                 children: [
//                   _buildZoomButton(Icons.add, _zoomIn),
//                   const SizedBox(height: 8),
//                   _buildZoomButton(Icons.remove, _zoomOut),
//                 ],
//               ),
//             ),
//             // Bottom Card
//             if (_status.isNotEmpty)
//               Positioned(
//                 left: 0,
//                 right: 0,
//                 bottom: 0,
//                 child: _buildBottomCard(context),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
//     return Material(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(8),
//       elevation: 4,
//       child: InkWell(
//         onTap: onPressed,
//         borderRadius: BorderRadius.circular(8),
//         child: Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: Icon(icon, color: Colors.black54),
//         ),
//       ),
//     );
//   }

//   Widget _buildBottomCard(BuildContext context) {
//     String title = '';
//     String buttonText = '';
//     IconData icon = Icons.camera_alt;
//     VoidCallback? onPressed;

//     if (_status == 'rider_accepted') {
//       title = 'เดินทางไปที่จุดรับสินค้า';
//       buttonText = 'ถึงแล้ว (ถ่ายรูปยืนยัน)';
//       onPressed = () => _takePictureAndUpdateStatus(
//         expectedStatus: 'rider_accepted',
//         newStatus: 'picked_up',
//         targetLocation: _pickupLatLng!,
//         imageFieldName: 'pickup_photo_url',
//       );
//     } else if (_status == 'picked_up') {
//       title = 'กำลังนำส่งสินค้าให้คุณ';
//       buttonText = 'ส่งของสำเร็จ (ถ่ายรูปยืนยัน)';
//       onPressed = () => _takePictureAndUpdateStatus(
//         expectedStatus: 'picked_up',
//         newStatus: 'delivered',
//         targetLocation: _deliveryLatLng!,
//         imageFieldName: 'delivery_photo_url',
//       );
//     } else if (_status == 'delivered') {
//       title = 'จัดส่งสินค้าสำเร็จ!';
//       buttonText = 'กลับไปหน้าหลัก';
//       icon = Icons.check_circle_outline;
//       onPressed = () => Navigator.of(context).pop();
//     }

//     return Card(
//       margin: const EdgeInsets.all(12.0),
//       elevation: 8,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Text(title, style: Theme.of(context).textTheme.titleLarge),
//             const SizedBox(height: 16),
//             ElevatedButton.icon(
//               icon: Icon(icon),
//               label: Text(buttonText),
//               onPressed: onPressed,
//               style: ElevatedButton.styleFrom(
//                 padding: const EdgeInsets.symmetric(vertical: 14),
//                 backgroundColor: (_status == 'delivered')
//                     ? Colors.green
//                     : Colors.blue,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:test_databse/controller/rider/rider_controller.dart';

class DeliveryTrackingPage extends StatefulWidget {
  final String deliveryId;
  const DeliveryTrackingPage({super.key, required this.deliveryId});

  @override
  State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
  final RiderHomeController _controller = RiderHomeController();
  final Completer<GoogleMapController> _mapController = Completer();
  final ImagePicker _picker = ImagePicker();

  StreamSubscription<Position>? _positionSubscription;
  LatLng? _riderPosition;
  double _riderRotation = 0.0;
  LatLng? _pickupLatLng;
  LatLng? _deliveryLatLng;
  String _status = '';

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _controller.startLocationUpdates();
    _startListeningToLocationUI();
    _listenDeliveryStream();
  }

  @override
  void dispose() {
    _controller.stopLocationUpdates();
    _positionSubscription?.cancel();
    super.dispose();
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180.0);
  double _toDegrees(double radians) => radians * (180.0 / math.pi);

  double _calculateBearing(LatLng startPoint, LatLng endPoint) {
    final double startLat = _toRadians(startPoint.latitude);
    final double startLng = _toRadians(startPoint.longitude);
    final double endLat = _toRadians(endPoint.latitude);
    final double endLng = _toRadians(endPoint.longitude);
    final double deltaLng = endLng - startLng;
    final double y = math.sin(deltaLng) * math.cos(endLat);
    final double x =
        math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(deltaLng);
    final double bearing = math.atan2(y, x);
    return (_toDegrees(bearing) + 360) % 360;
  }

  void _startListeningToLocationUI() {
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((Position position) {
          if (mounted) {
            final newPosition = LatLng(position.latitude, position.longitude);
            if (_riderPosition != null) {
              _riderRotation = _calculateBearing(_riderPosition!, newPosition);
            }
            _riderPosition = newPosition;
            setState(() {
              _updateMarkers();
              _drawStraightLineToDestination();
            });
            _animateCameraToRider();
          }
        });
  }

  void _listenDeliveryStream() {
    _controller.getDeliveryStream(widget.deliveryId).listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data() as Map<String, dynamic>;

      final newStatus = data['status'];
      final pickupGeoPoint = data['pickup_location'] as GeoPoint;
      final deliveryGeoPoint = data['delivery_location'] as GeoPoint;

      _pickupLatLng = LatLng(pickupGeoPoint.latitude, pickupGeoPoint.longitude);
      _deliveryLatLng = LatLng(
        deliveryGeoPoint.latitude,
        deliveryGeoPoint.longitude,
      );

      if (mounted) {
        setState(() {
          _status = newStatus;
          _updateMarkers();
          _drawStraightLineToDestination();
        });
      }
    });
  }

  void _drawStraightLineToDestination() {
    _polylines.clear();
    LatLng? destination;

    if (_status == 'rider_accepted') {
      destination = _pickupLatLng;
    } else if (_status == 'picked_up') {
      destination = _deliveryLatLng;
    }

    if (_riderPosition != null && destination != null) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('destination_line'),
          points: [_riderPosition!, destination],
          color: Colors.amber,
          width: 5,
          patterns: [PatternItem.dot, PatternItem.gap(10)],
        ),
      );
    }
  }

  void _updateMarkers() {
    Set<Marker> updatedMarkers = {};
    if (_pickupLatLng != null) {
      updatedMarkers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'จุดรับสินค้า'),
        ),
      );
    }
    if (_deliveryLatLng != null) {
      updatedMarkers.add(
        Marker(
          markerId: const MarkerId('delivery'),
          position: _deliveryLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'จุดส่งสินค้า'),
        ),
      );
    }
    if (_riderPosition != null) {
      updatedMarkers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: _riderPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: const InfoWindow(title: 'ตำแหน่งของคุณ'),
          flat: true,
          rotation: _riderRotation,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers.clear();
        _markers.addAll(updatedMarkers);
      });
    }
  }

  Future<void> _animateCameraToRider() async {
    if (_riderPosition != null && _mapController.isCompleted) {
      final controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _riderPosition!,
            zoom: 17.5,
            tilt: 45.0,
            bearing: _riderRotation,
          ),
        ),
      );
    }
  }

  Future<void> _zoomIn() async {
    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> _zoomOut() async {
    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.zoomOut());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('กำลังจัดส่งสินค้า'),
          automaticallyImplyLeading: false,
        ),
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _pickupLatLng ?? const LatLng(13.736717, 100.523186),
                zoom: 15,
              ),
              onMapCreated: (controller) {
                if (!_mapController.isCompleted) {
                  _mapController.complete(controller);
                }
              },
              markers: _markers,
              polylines: _polylines,
              zoomControlsEnabled: false,
              myLocationEnabled: false,
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Column(
                children: [
                  _buildZoomButton(Icons.add, _zoomIn),
                  const SizedBox(height: 8),
                  _buildZoomButton(Icons.remove, _zoomOut),
                ],
              ),
            ),
            if (_status.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomCard(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: Colors.black54),
        ),
      ),
    );
  }

  // ‼️ นี่คือฟังก์ชัน _buildBottomCard ที่เรียกใช้ Dialog ‼️
  Widget _buildBottomCard() {
    String title = '';
    String buttonText = '';
    IconData icon = Icons.camera_alt;
    VoidCallback? onPressed;
    String distanceText = '';

    if (_riderPosition != null) {
      if (_status == 'rider_accepted' && _pickupLatLng != null) {
        double distance = Geolocator.distanceBetween(
          _riderPosition!.latitude,
          _riderPosition!.longitude,
          _pickupLatLng!.latitude,
          _pickupLatLng!.longitude,
        );
        distanceText = ' (ห่าง ${distance.toStringAsFixed(0)} ม.)';
      } else if (_status == 'picked_up' && _deliveryLatLng != null) {
        double distance = Geolocator.distanceBetween(
          _riderPosition!.latitude,
          _riderPosition!.longitude,
          _deliveryLatLng!.latitude,
          _deliveryLatLng!.longitude,
        );
        distanceText = ' (ห่าง ${distance.toStringAsFixed(0)} ม.)';
      }
    }

    if (_status == 'rider_accepted') {
      title = 'เดินทางไปที่จุดรับสินค้า';
      buttonText = 'ถึงแล้ว (ยืนยันด้วยรูป)';
      onPressed = () => _showImageSourceDialog(
        expectedStatus: 'rider_accepted',
        newStatus: 'picked_up',
        targetLocation: _pickupLatLng!,
        imageFieldName: 'pickup_photo_url',
      );
    } else if (_status == 'picked_up') {
      title = 'กำลังนำส่งสินค้า';
      buttonText = 'ส่งของสำเร็จ (ยืนยันด้วยรูป)';
      onPressed = () => _showImageSourceDialog(
        expectedStatus: 'picked_up',
        newStatus: 'delivered',
        targetLocation: _deliveryLatLng!,
        imageFieldName: 'delivery_photo_url',
      );
    } else if (_status == 'delivered') {
      title = 'จัดส่งสินค้าสำเร็จ!';
      buttonText = 'กลับไปหน้าหลัก';
      icon = Icons.check_circle_outline;
      onPressed = () {
        if (mounted) Navigator.of(context).pop();
      };
    }

    return Card(
      margin: const EdgeInsets.all(12.0),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$title$distanceText',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(icon),
              label: Text(buttonText),
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: (_status == 'delivered')
                    ? Colors.green
                    : Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImageSourceDialog({
    required String expectedStatus,
    required String newStatus,
    required LatLng targetLocation,
    required String imageFieldName,
  }) async {
    // ตรวจสอบ `mounted` ก่อนใช้ `context`
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('ถ่ายรูป'),
                onTap: () {
                  Navigator.of(context).pop();
                  _getImageAndUpload(
                    ImageSource.camera,
                    expectedStatus: expectedStatus,
                    newStatus: newStatus,
                    targetLocation: targetLocation,
                    imageFieldName: imageFieldName,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('เลือกจากแกลเลอรี'),
                onTap: () {
                  Navigator.of(context).pop();
                  _getImageAndUpload(
                    ImageSource.gallery,
                    expectedStatus: expectedStatus,
                    newStatus: newStatus,
                    targetLocation: targetLocation,
                    imageFieldName: imageFieldName,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getImageAndUpload(
    ImageSource source, {
    required String expectedStatus,
    required String newStatus,
    required LatLng targetLocation,
    required String imageFieldName,
  }) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 50,
      );
      if (photo == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final result = await _controller.confirmPickupOrDelivery(
        deliveryId: widget.deliveryId,
        expectedStatus: expectedStatus,
        newStatus: newStatus,
        targetLocation: GeoPoint(
          targetLocation.latitude,
          targetLocation.longitude,
        ),
        imageFile: File(photo.path),
        imageFieldName: imageFieldName,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }
}
