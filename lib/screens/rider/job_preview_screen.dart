// lib/screens/rider/job_preview_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:test_databse/controller/rider/rider_controller.dart';
import 'package:test_databse/model/rider.dart'; // (Delivery Model)
import 'package:test_databse/screens/rider/delivery_tracking_screen.dart';
// --- ‼️ Imports เพิ่มเติม ‼️ ---
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // For jsonDecode
import 'dart:math' as math; // For min/max in _fitBounds


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

  // --- ‼️ State สำหรับเส้นทาง ‼️ ---
  final Set<Polyline> _polylines = {};
  PolylinePoints polylinePoints = PolylinePoints();

  @override
  void initState() {
    super.initState();
    // ‼️ แยกการตั้งค่าหมุด กับ การวาดเส้นทาง ‼️
    _setInitialMarkers(); // ตั้งหมุด A, B ก่อน
    // การวาดเส้นทางจะถูกเรียกใน onMapCreated หลังจากแผนที่พร้อม
  }

  // --- ‼️ แก้ชื่อฟังก์ชันนี้ ‼️ ---
  void _setInitialMarkers() {
      // Ensure GeoPoints are valid before creating LatLng
      if (widget.delivery.pickupLocation.latitude != 0 || widget.delivery.pickupLocation.longitude != 0) {
        _pickupLatLng = LatLng(
          widget.delivery.pickupLocation.latitude,
          widget.delivery.pickupLocation.longitude,
        );
      } else {
         print("⚠️ Invalid pickup location data from delivery object.");
      }

      if (widget.delivery.deliveryLocation.latitude != 0 || widget.delivery.deliveryLocation.longitude != 0) {
        _deliveryLatLng = LatLng(
          widget.delivery.deliveryLocation.latitude,
          widget.delivery.deliveryLocation.longitude,
        );
      } else {
         print("⚠️ Invalid delivery location data from delivery object.");
      }


      // Only update markers if at least one location is valid
      if (_pickupLatLng != null || _deliveryLatLng != null) {
        setState(() {
          _markers.clear(); // Clear previous markers
          if (_pickupLatLng != null) {
              _markers.add(
                Marker(
                  markerId: const MarkerId('pickup'),
                  position: _pickupLatLng!,
                  infoWindow: const InfoWindow(title: 'จุดรับสินค้า (A)'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                ),
              );
          }
          if (_deliveryLatLng != null) {
             _markers.add(
                Marker(
                  markerId: const MarkerId('delivery'),
                  position: _deliveryLatLng!,
                  infoWindow: const InfoWindow(title: 'จุดส่งสินค้า (B)'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                ),
              );
          }
        });
      }
  }


  // --- ฟังก์ชันสำหรับ Zoom ให้เห็นหมุดทั้งหมด (แก้ไขให้แม่นยำขึ้น) ---
  void _fitBounds(GoogleMapController controller) {
    if (_pickupLatLng == null || _deliveryLatLng == null) {
       // If only one marker exists, zoom to it
       LatLng? singleMarker = _pickupLatLng ?? _deliveryLatLng;
       if (singleMarker != null) {
          controller.animateCamera(CameraUpdate.newLatLngZoom(singleMarker, 15));
       }
       return;
    }

     // Handle identical points
     if (_pickupLatLng == _deliveryLatLng) {
        controller.animateCamera(CameraUpdate.newLatLngZoom(_pickupLatLng!, 16));
        return;
     }

    // Calculate bounds correctly
    final double swLat = math.min(_pickupLatLng!.latitude, _deliveryLatLng!.latitude);
    final double swLng = math.min(_pickupLatLng!.longitude, _deliveryLatLng!.longitude);
    final double neLat = math.max(_pickupLatLng!.latitude, _deliveryLatLng!.latitude);
    final double neLng = math.max(_pickupLatLng!.longitude, _deliveryLatLng!.longitude);
    LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(swLat, swLng),
        northeast: LatLng(neLat, neLng),
    );

     // Add padding
     double padding = 70.0;

     try {
       // Add a slight delay for safety, although might not be strictly necessary here
       Future.delayed(Duration(milliseconds: 50), () {
          if(mounted) {
             controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, padding));
          }
       });
     } catch (e) {
        print("🚨 Error animating bounds in Preview: $e");
         // Fallback zoom
        controller.animateCamera(CameraUpdate.newLatLngZoom(_pickupLatLng!, 14));
     }
  }

  // --- ‼️ ฟังก์ชันใหม่: เรียก OSRM API (A -> B) ‼️ ---
  Future<void> _getRoutePolyline() async {
    // ใช้ _pickupLatLng และ _deliveryLatLng ที่มีอยู่แล้ว
    if (_pickupLatLng == null || _deliveryLatLng == null || _pickupLatLng == _deliveryLatLng ) {
       if (mounted) setState(() => _polylines.clear());
      return;
    }

    final osrmBaseUrl = 'https://router.project-osrm.org'; // DEMO SERVER!
    final profile = 'driving';
    final coordinates =
        '${_pickupLatLng!.longitude},${_pickupLatLng!.latitude};${_deliveryLatLng!.longitude},${_deliveryLatLng!.latitude}';
    final url = Uri.parse(
        '$osrmBaseUrl/route/v1/$profile/$coordinates?overview=full&geometries=polyline');

    print("Calling OSRM (Preview): $url");

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
                  color: Colors.deepPurpleAccent, // สีเส้นทาง A->B
                  width: 5,
                ),
              );
            });
             print("✅ OSRM route drawn (Preview).");
          }
        } else {
           print("No routes found by OSRM API (Preview).");
           if (mounted) setState(() => _polylines.clear());
        }
      } else {
         print("OSRM API request failed (Preview): ${response.statusCode}");
         if (mounted) setState(() => _polylines.clear());
      }
    } catch (e) {
      print("🚨 Error calling OSRM API (Preview): $e");
       if (mounted) setState(() => _polylines.clear());
    }
  }


  // (ฟังก์ชันกดยืนยันรับงาน เหมือนเดิม)
  Future<void> _confirmAcceptJob() async {
    // ... (โค้ดเดิม) ...
     setState(() => _isLoading = true);
    final controller = RiderHomeController();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );


    final result = await controller.acceptJob(widget.delivery.deliveryId);

    if (!mounted) return;

     Navigator.pop(context); // Dismiss loading dialog

    setState(() => _isLoading = false); // Reset loading state

    if (result == "รับงานสำเร็จ") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("รับงานสำเร็จ!"), backgroundColor: Colors.green),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DeliveryTrackingPage(
            deliveryId: widget.delivery.deliveryId,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), backgroundColor: Colors.red),
      );
      Navigator.pop(context); // Go back to the job list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตรวจสอบงานก่อนรับ'),
         backgroundColor: Colors.white, // Optional: Match theme
         foregroundColor: Colors.black, // Optional: Match theme
         elevation: 1, // Optional: Add subtle shadow
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickupLatLng ?? const LatLng(13.736717, 100.523186),
              zoom: 11,
            ),
            markers: _markers,
            polylines: _polylines, // ‼️ แสดงเส้นทาง OSRM ‼️
            onMapCreated: (controller) {
              if(!_mapController.isCompleted){
                 _mapController.complete(controller);
                 // ‼️ เรียกวาดเส้นทาง & ซูม เมื่อ Map พร้อม ‼️
                  Future.wait([
                     _getRoutePolyline(), // Start fetching route
                     // Ensure fitBounds runs after markers are likely set
                     Future.delayed(const Duration(milliseconds: 200)).then((_) {
                       if (mounted) _fitBounds(controller);
                     })
                   ]);
              }
            },
              zoomControlsEnabled: true, // Enable zoom controls for preview
              myLocationButtonEnabled: true, // Allow rider to see their location relative to job
              myLocationEnabled: true,
          ),
          // (Bottom Card เหมือนเดิม)
           Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Card(
              margin: const EdgeInsets.all(12),
              elevation: 8,
              shape: RoundedRectangleBorder( // Add rounded corners
                 borderRadius: BorderRadius.circular(12),
               ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min, // Important for Column in Stack
                  children: [
                    // Use RichText for better formatting if needed
                    Text('รับ: ${widget.delivery.pickupAddress}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 2, // Prevent overflow
                        overflow: TextOverflow.ellipsis,
                        ),
                    const SizedBox(height: 8),
                    Text('ส่ง: ${widget.delivery.deliveryAddress}',
                         maxLines: 2,
                         overflow: TextOverflow.ellipsis,
                         ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _confirmAcceptJob,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                         foregroundColor: Colors.white, // Text color
                        padding: const EdgeInsets.symmetric(vertical: 14),
                         shape: RoundedRectangleBorder( // Match card corners
                            borderRadius: BorderRadius.circular(8),
                         ),
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
                          : const Text('ยืนยันรับงาน'),
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