// lib/screens/rider/delivery_tracking_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:test_databse/controller/rider/rider_controller.dart';
import 'package:test_databse/screens/rider/rider_screen.dart'; // For RiderHomePage navigation
import 'package:collection/collection.dart'; // Import collection package for SetEquality

// --- ‼️ Imports เพิ่มเติมสำหรับ OSRM ‼️ ---
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // For jsonDecode

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
  // --- ‼️ State สำหรับเส้นทาง ‼️ ---
  final Set<Polyline> _polylines = {};
  PolylinePoints polylinePoints = PolylinePoints();
  bool _routeDrawn = false; // ‼️ 1. เพิ่ม Flag ป้องกันการวาดซ้ำ

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  // --- ‼️ ฟังก์ชัน Initialize ใหม่ (ปรับปรุง) ‼️ ---
  Future<void> _initializeLocation() async {
    bool hasPermission = await _checkAndRequestPermissions();
    if (hasPermission) {
      // 1. เริ่มฟังข้อมูลงาน *ก่อน*
      _listenDeliveryStream();
      // 2. เริ่มฟังตำแหน่ง Rider *ทีหลัง*
      _startListeningToLocationUI();
      // 3. สั่งให้ Controller เริ่มอัปเดตตำแหน่งลง DB
      _controller.startLocationUpdates();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('แอปต้องการสิทธิ์ตำแหน่งเพื่อทำงาน')));
      }
    }
  }

  // --- ‼️ ฟังก์ชันเช็ค Permission (เหมือนเดิม) ‼️ ---
  Future<bool> _checkAndRequestPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services ปิดอยู่');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('User ปฏิเสธสิทธิ์');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('User ปฏิเสธสิทธิ์ถาวร');
      return false;
    }

    return true;
  }


  @override
  void dispose() {
    _controller.stopLocationUpdates();
    _positionSubscription?.cancel();
    super.dispose();
  }

  // (โค้ดคำนวณ _toRadians, _toDegrees, _calculateBearing เหมือนเดิม)
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


  // --- ‼️ Listener ตำแหน่ง Rider (ไม่เรียก _getRoutePolyline แล้ว) ‼️ ---
  void _startListeningToLocationUI() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (mounted) {
        final newPosition = LatLng(position.latitude, position.longitude);
        
        if ((newPosition.latitude != 0 || newPosition.longitude != 0) && _riderPosition != newPosition) {
            LatLng? previousPosition = _riderPosition;
            _riderPosition = newPosition; // อัปเดตตำแหน่ง

            if (previousPosition != null) {
              _riderRotation = _calculateBearing(previousPosition, _riderPosition!);
            }

             setState(() {
               _updateMarkers(); // อัปเดตหมุด Rider
             });

             // ‼️ ไม่ต้องเรียก _getRoutePolyline() ที่นี่ ‼️
             _animateCameraToRider(); // ขยับกล้องตาม
         }
      }
    });
  }

  // --- ‼️ Listener ข้อมูลงาน (เรียก _getRoutePolyline แค่ครั้งเดียว) ‼️ ---
  void _listenDeliveryStream() {
    _controller.getDeliveryStream(widget.deliveryId).listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data() as Map<String, dynamic>;

      final newStatus = data['status'];
      final pickupGeoPoint = data['pickup_location'] as GeoPoint?;
      final deliveryGeoPoint = data['delivery_location'] as GeoPoint?;

      bool positionsChanged = false;

      // อัปเดต Pickup LatLng
      LatLng? tempPickup;
      if (pickupGeoPoint != null && (pickupGeoPoint.latitude != 0 || pickupGeoPoint.longitude != 0)) {
         tempPickup = LatLng(pickupGeoPoint.latitude, pickupGeoPoint.longitude);
         if (_pickupLatLng != tempPickup) positionsChanged = true;
      } else {
         if (_pickupLatLng != null) positionsChanged = true;
         tempPickup = null;
      }
       _pickupLatLng = tempPickup;

      // อัปเดต Delivery LatLng
      LatLng? tempDelivery;
      if (deliveryGeoPoint != null && (deliveryGeoPoint.latitude != 0 || deliveryGeoPoint.longitude != 0)) {
         tempDelivery = LatLng(deliveryGeoPoint.latitude, deliveryGeoPoint.longitude);
         if (_deliveryLatLng != tempDelivery) positionsChanged = true;
      } else {
          if (_deliveryLatLng != null) positionsChanged = true;
          tempDelivery = null;
      }
      _deliveryLatLng = tempDelivery;

      if (mounted) {
        _status = newStatus;
        _updateMarkers(); // อัปเดตหมุด (Pickup/Delivery)

        // ‼️ เรียกวาดเส้นทาง (A -> B) *แค่ครั้งเดียว* ถ้ายังไม่เคยวาด และพิกัดพร้อม ‼️
        if (positionsChanged && !_routeDrawn) {
           _getRoutePolyline();
        }
      }
    });
  }


  // --- ‼️ ฟังก์ชันเรียก OSRM API (A -> B) ‼️ ---
  Future<void> _getRoutePolyline() async {
    // ‼️ 2. เปลี่ยน Logic: ใช้จุด A และ B ‼️
    LatLng? origin = _pickupLatLng;
    LatLng? destination = _deliveryLatLng;

    // 3. เช็คเงื่อนไข:
    // 1. ถ้าเคยวาดแล้ว ออก
    // 2. ถ้าไม่มีจุด A หรือ B
    // 3. ถ้า A หรือ B ไม่ถูกต้อง (0,0)
    // 4. ถ้า A กับ B ซ้ำกัน
    if (_routeDrawn || origin == null || destination == null ||
        (origin.latitude == 0 && origin.longitude == 0) ||
        (destination.latitude == 0 && destination.longitude == 0) ||
        origin == destination )
    {
      print("Polyline check: Route already drawn, points missing, invalid, or identical. Skipping.");
      if (mounted && _polylines.isNotEmpty) setState(() => _polylines.clear());
      return; // ออกจากฟังก์ชัน
    }

    // ‼️ 4. ตั้งค่าว่ากำลังจะวาด (กันการเรียกซ้ำ) ‼️
    _routeDrawn = true;

    final osrmBaseUrl = 'https://router.project-osrm.org'; // DEMO SERVER!
    final profile = 'driving';
    
    // ‼️ 5. ใช้พิกัด A -> B ‼️
    final coordinates =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final url = Uri.parse('$osrmBaseUrl/route/v1/$profile/$coordinates?overview=full&geometries=polyline');

    print("Calling OSRM (A -> B): $url");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty && data['routes'][0]['geometry'] != null) {
          final encodedPolyline = data['routes'][0]['geometry'];
          List<PointLatLng> result = polylinePoints.decodePolyline(encodedPolyline);
          List<LatLng> polylineCoordinates = result.map((p) => LatLng(p.latitude, p.longitude)).toList();

          final newPolyline = Polyline(
                  polylineId: const PolylineId('route'),
                  points: polylineCoordinates,
                  color: Colors.blueAccent, // สีเส้นทาง
                  width: 5,             // ความหนา
                );

          if (mounted) {
            setState(() {
              _polylines.clear(); // ล้างเส้นเก่า (ถ้ามี)
              _polylines.add(newPolyline);
            });
             print("✅ OSRM A->B route drawn.");
          }
        } else {
           print("No routes found by OSRM API (A -> B).");
           _routeDrawn = false; // ‼️ อนุญาตให้ลองใหม่ครั้งหน้า ถ้า API หาไม่เจอ ‼️
           if (mounted && _polylines.isNotEmpty) setState(() => _polylines.clear());
        }
      } else {
         print("OSRM API request failed (A -> B): ${response.statusCode}");
         _routeDrawn = false; // ‼️ อนุญาตให้ลองใหม่ครั้งหน้า ถ้า API error ‼️
         if (mounted && _polylines.isNotEmpty) setState(() => _polylines.clear());
      }
    } catch (e) {
      print("🚨 Error calling OSRM API (A -> B): $e");
       _routeDrawn = false; // ‼️ อนุญาตให้ลองใหม่ครั้งหน้า ถ้า Exception ‼️
       if (mounted && _polylines.isNotEmpty) setState(() => _polylines.clear());
    }
  }


  // --- ‼️ ฟังก์ชันอัปเดตหมุด (กลับไปใช้ตัวเดิม + เช็ค 0,0) ‼️ ---
  void _updateMarkers() {
    if (!mounted) return;
    Set<Marker> updatedMarkers = {};

    // หมุด: ต้นทาง (Blue)
    if (_pickupLatLng != null && (_pickupLatLng!.latitude != 0 || _pickupLatLng!.longitude != 0)) {
      updatedMarkers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'จุดรับสินค้า'),
         anchor: const Offset(0.5, 0.5),
      ));
    }
    // หมุด: ปลายทาง (Green)
    if (_deliveryLatLng != null && (_deliveryLatLng!.latitude != 0 || _deliveryLatLng!.longitude != 0)) {
      updatedMarkers.add(Marker(
        markerId: const MarkerId('delivery'),
        position: _deliveryLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'จุดส่งสินค้า'),
         anchor: const Offset(0.5, 0.5),
      ));
    }
    // หมุด: ไรเดอร์ (Orange)
    if (_riderPosition != null && (_riderPosition!.latitude != 0 || _riderPosition!.longitude != 0)) {
      updatedMarkers.add(Marker(
        markerId: const MarkerId('rider'),
        position: _riderPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: const InfoWindow(title: 'ตำแหน่งของคุณ'),
        flat: true,
        rotation: _riderRotation,
         anchor: const Offset(0.5, 0.5),
      ));
    }

    // Only call setState if markers actually changed
    if(!const SetEquality().equals(_markers, updatedMarkers)){
       setState(() {
         _markers.clear();
         _markers.addAll(updatedMarkers);
       });
    }
  }


  // (ฟังก์ชัน _animateCameraToRider เหมือนเดิม)
  Future<void> _animateCameraToRider() async {
     if (_riderPosition != null && _mapController.isCompleted && (_riderPosition!.latitude != 0 || _riderPosition!.longitude != 0)) {
       try {
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
       } catch (e) { print("Error animating camera: $e"); }
     }
  }

  // (ฟังก์ชัน _zoomIn, _zoomOut เหมือนเดิม)
  Future<void> _zoomIn() async {
    try {
        final controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.zoomIn());
    } catch (e) { print("Error zooming in: $e");}
  }
  Future<void> _zoomOut() async {
     try {
       final controller = await _mapController.future;
       controller.animateCamera(CameraUpdate.zoomOut());
     } catch (e) { print("Error zooming out: $e");}
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('กำลังจัดส่งสินค้า'),
          automaticallyImplyLeading: false,
          actions: [
             if (_status == 'rider_accepted' || _status == 'picked_up')
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton(
                  onPressed: _showCancelConfirmationDialog,
                  child: const Text( 'ยกเลิกงาน', style: TextStyle( color: Colors.red, fontWeight: FontWeight.bold,),),
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _riderPosition ?? _pickupLatLng ?? const LatLng(13.736717, 100.523186),
                zoom: 15,
              ),
              onMapCreated: (controller) {
                if (!_mapController.isCompleted) {
                  _mapController.complete(controller);
                   // พยายามวาดเส้นทาง A->B ครั้งแรก (ถ้าพิกัดพร้อมแล้ว)
                  _getRoutePolyline();
                }
                 _animateCameraToRider(); // ขยับกล้อง (ถ้ามีตำแหน่ง Rider แล้ว)
              },
              markers: _markers,
              polylines: _polylines, // ‼️ แสดงเส้นทาง OSRM ‼️
              zoomControlsEnabled: true, // ‼️ เปิดปุ่ม +/- กลับมา (ตามรูป) ‼️
              myLocationEnabled: false,
               compassEnabled: true,
               mapToolbarEnabled: false,
            ),
             Positioned( // ‼️ เอาปุ่ม Zoom Custom ออก ‼️
              top: 16,
              right: 16,
              child: Column(
                // children: [
                //   _buildZoomButton(Icons.add, _zoomIn),
                //   const SizedBox(height: 8),
                //   _buildZoomButton(Icons.remove, _zoomOut),
                // ],
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

  // --- ‼️ ฟังก์ชันย่อย (_buildZoomButton, _buildBottomCard, Dialogs, _getImageAndUpload) ‼️ ---
   Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
     return Material(
       color: Colors.white.withOpacity(0.9),
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

   Widget _buildBottomCard() {
     String title = '';
     String buttonText = '';
     IconData icon = Icons.camera_alt;
     VoidCallback? onPressed;
     String distanceText = '';

     LatLng? currentTarget = (_status == 'rider_accepted') ? _pickupLatLng : (_status == 'picked_up' ? _deliveryLatLng : null);
     if (_riderPosition != null && currentTarget != null &&
         (_riderPosition!.latitude != 0 || _riderPosition!.longitude != 0) &&
         (currentTarget.latitude != 0 || currentTarget.longitude != 0))
     {
         double distance = Geolocator.distanceBetween(
           _riderPosition!.latitude,
           _riderPosition!.longitude,
           currentTarget.latitude,
           currentTarget.longitude,
         );
         distanceText = ' (ห่าง ${distance.toStringAsFixed(0)} ม.)';
     }


     if (_status == 'rider_accepted') {
       title = 'เดินทางไปที่จุดรับสินค้า';
       buttonText = 'ถึงแล้ว (ยืนยันด้วยรูป)';
       onPressed = (_pickupLatLng == null) ? null : () => _showImageSourceDialog(
         expectedStatus: 'rider_accepted',
         newStatus: 'picked_up',
         targetLocation: _pickupLatLng!,
         imageFieldName: 'pickup_photo_url',
       );
     } else if (_status == 'picked_up') {
       title = 'กำลังนำส่งสินค้า';
       buttonText = 'ส่งของสำเร็จ (ยืนยันด้วยรูป)';
       onPressed = (_deliveryLatLng == null) ? null : () => _showImageSourceDialog(
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
         if (mounted) Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const RiderHomePage()),
              (Route<dynamic> route) => false,
            );
       };
     } else {
        title = 'สถานะ: $_status';
        buttonText = '';
        onPressed = null;
     }

     return Card(
       margin: const EdgeInsets.all(12.0),
       elevation: 8,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
             Text(
               '$title$distanceText',
               style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
             ),
             const SizedBox(height: 16),
              if (onPressed != null || _status == 'delivered')
                ElevatedButton.icon(
                  icon: Icon(icon, size: 20),
                  label: Text(buttonText),
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: (_status == 'delivered') ? Colors.green : Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

   Future<void> _showCancelConfirmationDialog() async {
      if (!mounted) return;
      final confirm = await showDialog<bool>(
         context: context,
         barrierDismissible: false,
         builder: (BuildContext context) {
           return AlertDialog(
             title: const Text('ยืนยันการยกเลิกงาน'),
             content: const Text('คุณแน่ใจหรือไม่ว่าต้องการยกเลิกงานนี้?\n(งานจะกลับไปอยู่ในสถานะรอไรเดอร์)'),
             actions: <Widget>[
               TextButton(
                 child: const Text('ไม่ยกเลิก'),
                 onPressed: () => Navigator.of(context).pop(false),
               ),
               TextButton(
                 child: const Text('ยืนยันยกเลิก', style: TextStyle(color: Colors.red)),
                 onPressed: () => Navigator.of(context).pop(true),
               ),
             ],
           );
         },
       );

       if (!mounted) return;
       if (confirm == true) {
         showDialog(
           context: context,
           barrierDismissible: false,
           builder: (_) => const Center(child: CircularProgressIndicator()),
         );

         final result = await _controller.cancelDeliveryByRider(widget.deliveryId);

         if (!mounted) return;
         Navigator.pop(context); // Close loading

         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text(result),
             backgroundColor: result == "ยกเลิกงานสำเร็จ" ? Colors.green : Colors.red,
           ),
         );

         if (result == "ยกเลิกงานสำเร็จ") {
           Navigator.pushAndRemoveUntil(
             context,
             MaterialPageRoute(builder: (context) => const RiderHomePage()),
             (Route<dynamic> route) => false,
           );
         }
       }
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
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result)));

         if (newStatus == 'delivered' && result.contains("สำเร็จ")) {
           await Future.delayed(const Duration(seconds: 1));
            if (mounted) {
               Navigator.pushAndRemoveUntil(
                 context,
                 MaterialPageRoute(builder: (context) => const RiderHomePage()),
                  (Route<dynamic> route) => false,
                );
            }
         }

      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading on error
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
        }
      }
   }

} // <--- สิ้นสุด State Class