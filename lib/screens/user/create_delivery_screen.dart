// lib/screens/user/create_delivery_screen.dart
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:image_picker/image_picker.dart';
import 'package:test_databse/model/address.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:test_databse/model/profile.dart';
import 'package:test_databse/service/clouddinary_service.dart';
import 'package:test_databse/service/db_service.dart';
import 'package:test_databse/screens/user/select_location_screen.dart';
// ‼️ เอา Imports ของ OSRM ออก ‼️
// import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

class CreateDeliveryScreen extends StatefulWidget {
  const CreateDeliveryScreen({super.key});

  @override
  State<CreateDeliveryScreen> createState() => _CreateDeliveryScreenState();
}

class _CreateDeliveryScreenState extends State<CreateDeliveryScreen> {
  final _dbService = DbService();
  final _phoneController = TextEditingController();
  final _picker = ImagePicker();
  // ‼️ เพิ่ม Controllers สำหรับช่องใหม่ ‼️
  final _itemNameController = TextEditingController();
  final _itemDetailsController = TextEditingController();


  UserAddress? _selectedSenderAddress;
  Profile? _foundReceiver;
  UserAddress? _selectedReceiverAddress;
  File? _pickedImage;
  String? _pickedImageUrl;

  bool _isSearchingReceiver = false;
  List<UserAddress> _receiverAddresses = [];
  bool _isCreatingOrder = false;

  final Completer<GoogleMapController> _mapController = Completer();
  final Set<Marker> _markers = {};
  static const LatLng _center = LatLng(13.736717, 100.523186);

  // ‼️ เอา State ของ OSRM ออก ‼️
  // final Set<Polyline> _polylines = {};
  // PolylinePoints polylinePoints = PolylinePoints();

  @override
  void initState() {
    super.initState();
     // No marker loading needed for default markers
  }

  // (ฟังก์ชัน _searchReceiver, _takePicture, _submitOrder เหมือนเดิม)
   Future<void> _searchReceiver() async {
    if (_phoneController.text.isEmpty) return;
    setState(() {
      _isSearchingReceiver = true;
      _foundReceiver = null;
      _receiverAddresses = [];
      _selectedReceiverAddress = null; // Clear selected receiver address
      _updateMarkers(); // Update map (clears B marker)
    });

    try {
      final receiver =
          await _dbService.findReceiverByPhone(_phoneController.text.trim());
      if (receiver != null) {
        final addresses = await _dbService.getReceiverAddresses(receiver.uid);
         if (mounted) {
           setState(() {
             _foundReceiver = receiver;
             _receiverAddresses = addresses;
           });
         }
      } else {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('ไม่พบผู้รับ หรือเบอร์โทรเป็นของคุณเอง'),
               backgroundColor: Colors.red,
             ),
           );
         }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
       if (mounted) {
         setState(() => _isSearchingReceiver = false);
       }
    }
   }
   Future<void> _takePicture() async {
      final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );
    if (photo == null) return;
    if (mounted) { // Check mount status
       setState(() => _pickedImage = File(photo.path));
    }
   }
   Future<void> _submitOrder() async {
     if (_selectedSenderAddress == null ||
        _foundReceiver == null ||
        _selectedReceiverAddress == null ||
        _pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกข้อมูลให้ครบทุกส่วน'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if(mounted) setState(() => _isCreatingOrder = true);

    try {
      final tempResult = FilePickerResult([
        PlatformFile(
          name: _pickedImage!.path.split('/').last,
          path: _pickedImage!.path,
          size: _pickedImage!.lengthSync(),
        ),
      ]);
      final imageUrl = await uploadTocloud(tempResult);
       if (imageUrl == null) throw Exception("ไม่สามารถอัปโหลดรูปภาพได้");
      _pickedImageUrl = imageUrl;

      await _dbService.createDeliveryOrder(
        senderAddress: _selectedSenderAddress!,
        receiverProfile: _foundReceiver!,
        receiverAddress: _selectedReceiverAddress!,
        pickupPhotoUrl: imageUrl,
        
        itemName: _itemNameController.text, // ส่งชื่อสินค้าจาก TextField
        itemDetails: _itemDetailsController.text, // ส่งข้อมูลสินค้าจาก TextField
      );

       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('✅ สร้างงานส่งของสำเร็จ!'),
             backgroundColor: Colors.green,
           ),
         );
         Navigator.pop(context);
       }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
         );
       }
    } finally {
      if (mounted) setState(() => _isCreatingOrder = false);
    }
   }


  // --- ‼️ ฟังก์ชันอัปเดตหมุด (ใช้ default icon) ‼️ ---
  void _updateMarkers() {
    _markers.clear();
    print("🔄 Updating markers...");
     bool needsRedraw = false;

    if (_selectedSenderAddress != null) {
      LatLng pickupPos = LatLng(
        _selectedSenderAddress!.location.latitude,
        _selectedSenderAddress!.location.longitude,
      );
      print("📍 Pickup Marker: $pickupPos");
      _markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: pickupPos,
        infoWindow: const InfoWindow(title: 'รับพัสดุที่นี่'), // Text ตามรูป
        // ‼️ ใช้ default icon สีแดง ‼️
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
       needsRedraw = true;
    }

    if (_selectedReceiverAddress != null) {
      LatLng deliveryPos = LatLng(
        _selectedReceiverAddress!.location.latitude,
        _selectedReceiverAddress!.location.longitude,
      );
      print("📍 Delivery Marker: $deliveryPos");
      _markers.add(Marker(
        markerId: const MarkerId('delivery'),
        position: deliveryPos,
        infoWindow: const InfoWindow(title: 'พิกัดจัดส่ง'), // Text ตามรูป
        // ‼️ ใช้ default icon สีฟ้า ‼️
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      ));
       needsRedraw = true;
    }

    // ‼️ เอา _getRoutePolyline() ออก ‼️
    _fitBounds(); // ซูมแผนที่

     // Call setState once after all updates if needed
     if (mounted && needsRedraw) {
       setState(() {});
     }
      // If markers were removed, potentially reset map view via _fitBounds
     else if (mounted && !needsRedraw ) {
       _fitBounds(); // Call fitBounds to reset zoom if necessary
       setState(() {}); // Ensure UI updates if only markers were removed
     }
  }


  // (ฟังก์ชัน _fitBounds เหมือนเดิม)
  Future<void> _fitBounds() async {
    if (!_mapController.isCompleted) { print("..."); return; }
    final controller = await _mapController.future;

    if (_selectedSenderAddress != null && _selectedReceiverAddress != null) {
      LatLng pickup = LatLng(
        _selectedSenderAddress!.location.latitude,
        _selectedSenderAddress!.location.longitude,
      );
      LatLng delivery = LatLng(
        _selectedReceiverAddress!.location.latitude,
        _selectedReceiverAddress!.location.longitude,
      );
      if (pickup == delivery) {
        controller.animateCamera(CameraUpdate.newLatLngZoom(pickup, 16));
        return;
      }
      final double swLat = math.min(pickup.latitude, delivery.latitude);
      final double swLng = math.min(pickup.longitude, delivery.longitude);
      final double neLat = math.max(pickup.latitude, delivery.latitude);
      final double neLng = math.max(pickup.longitude, delivery.longitude);
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(swLat, swLng),
        northeast: LatLng(neLat, neLng),
      );
      try {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70.0));
      } catch (e) {
        print("🚨 Error animating bounds: $e");
         if (mounted) controller.animateCamera(CameraUpdate.newLatLngZoom(pickup, 15));
      }
    } else if (_selectedSenderAddress != null) {
      LatLng pickup = LatLng(
        _selectedSenderAddress!.location.latitude,
        _selectedSenderAddress!.location.longitude,
      );
      controller.animateCamera(CameraUpdate.newLatLngZoom(pickup, 15));
    } else if (_selectedReceiverAddress != null) {
      LatLng delivery = LatLng(
        _selectedReceiverAddress!.location.latitude,
        _selectedReceiverAddress!.location.longitude,
      );
      controller.animateCamera(CameraUpdate.newLatLngZoom(delivery, 15));
    } else {
      controller.animateCamera(CameraUpdate.newLatLngZoom(_center, 11));
    }
     // No explicit setState needed here as _updateMarkers calls it
  }


  // ‼️ เอา _getRoutePolyline() ออก ‼️

  @override
  Widget build(BuildContext context) {
    // ‼️ ใช้ Theme โดยรวม ‼️
    final theme = Theme.of(context);
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade100, // สีพื้นหลังช่อง Input
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30.0), // ทำให้โค้งมนมากๆ
        borderSide: BorderSide.none, // ไม่มีเส้นขอบ
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30.0),
        borderSide: BorderSide(color: theme.primaryColor.withOpacity(0.5), width: 1.5), // เส้นขอบเมื่อ Focus (สีอ่อนลง)
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 50), // จัดระยะ Icon
       hintStyle: GoogleFonts.prompt(color: Colors.grey.shade500), // Font สำหรับ Hint Text
    );

    return Scaffold(
      // ‼️ AppBar ใหม่ ‼️
      appBar: AppBar(
        // title: Text('สร้างรายการส่งของ', style: GoogleFonts.prompt()), // เอา Title ออกตามรูป
        backgroundColor: Colors.white,
        foregroundColor: Colors.black, // สีลูกศรย้อนกลับ
        elevation: 0, // ไม่มีเงา
      ),
      backgroundColor: Colors.white, // พื้นหลังขาว
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0), // เพิ่ม Padding รอบนอก
        physics: const BouncingScrollPhysics(), // ทำให้ Scroll เด้งๆได้
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- ‼️ ส่วนเลือกที่อยู่ (UI ใหม่) ‼️ ---
            Text('พิกัดจัดส่ง', style: GoogleFonts.prompt(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildAddressPickerButton( // ปุ่มเลือกปลายทาง (พิกัดจัดส่ง)
              label: _selectedReceiverAddress == null
                  ? 'พิกัดจัดส่ง'
                  : _selectedReceiverAddress!.name,
              icon: Icons.location_pin, // ไอคอนหมุดฟ้า (ตัวอย่าง)
              iconColor: Colors.cyan.shade700,
              onTap: _showReceiverAddressOptions, // (สร้างฟังก์ชันนี้แล้ว)
            ),
            const SizedBox(height: 16),
            _buildAddressPickerButton( // ปุ่มเลือกต้นทาง (รับพัสดุ)
              label: _selectedSenderAddress == null
                  ? 'รับพัสดุที่ไหน'
                  : _selectedSenderAddress!.name,
              icon: Icons.pin_drop, // ไอคอนหมุดแดง
              iconColor: Colors.red.shade700,
              onTap: _showSenderAddressOptions, // (ใช้ฟังก์ชันเดิม)
            ),
            const SizedBox(height: 24),

            // --- ‼️ ส่วนค้นหาผู้รับ (UI ใหม่) ‼️ ---
             Text('หมายเลขโทรศัพท์ของผู้รับ', style: GoogleFonts.prompt(fontSize: 16, fontWeight: FontWeight.w600)),
             const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start, // ให้ปุ่ม Search อยู่บน
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    decoration: inputDecoration.copyWith(
                       hintText: '0812345678',
                       prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey.shade600),
                    ),
                    keyboardType: TextInputType.phone,
                     style: GoogleFonts.prompt(), // Apply font
                  ),
                ),
                const SizedBox(width: 8),
                // ทำให้ปุ่ม Search สูงเท่า TextField
                SizedBox(
                  height: 58, // ความสูงเท่า TextField โดยประมาณ (อาจต้องปรับ)
                  child: IconButton(
                    icon: Icon(Icons.search, color: Colors.grey.shade700, size: 30), // สีเทาตามรูป
                    onPressed: _isSearchingReceiver ? null : _searchReceiver,
                    padding: EdgeInsets.zero, // เอา Padding ออก
                     splashRadius: 24, // ลดขนาด Splash
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

             // --- ‼️ แสดงชื่อผู้รับ (UI ใหม่) ‼️ ---
             Text('ชื่อผู้รับ', style: GoogleFonts.prompt(fontSize: 16, fontWeight: FontWeight.w600)),
             const SizedBox(height: 8),
             Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(30.0),
                ),
                child: Text(
                  _foundReceiver?.name ?? ' ', // แสดงชื่อ หรือเว้นว่าง
                   style: GoogleFonts.prompt(
                     fontSize: 16,
                     color: _foundReceiver != null ? Colors.black : Colors.grey.shade500
                   ),
                ),
             ),
             const SizedBox(height: 24),


             // --- ‼️ เพิ่มช่อง ชื่อ/ข้อมูล สินค้า (แบบใหม่) ‼️ ---
              Text('ชื่อสินค้า', style: GoogleFonts.prompt(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                  controller: _itemNameController,
                  // ‼️ ใช้ InputDecoration ที่ต่างออกไป (มีเส้นใต้) ‼️
                  decoration: InputDecoration(
                     hintText: 'เช่น เอกสาร, เสื้อผ้า',
                     hintStyle: GoogleFonts.prompt(color: Colors.grey.shade500),
                     enabledBorder: UnderlineInputBorder( // เส้นใต้ปกติ
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                     focusedBorder: UnderlineInputBorder( // เส้นใต้เมื่อ focus
                        borderSide: BorderSide(color: theme.primaryColor),
                      ),
                       contentPadding: const EdgeInsets.symmetric(vertical: 10), // ปรับระยะห่างแนวตั้ง
                  ),
                   style: GoogleFonts.prompt(), // Apply font
              ),
              const SizedBox(height: 24), // เพิ่มระยะห่าง
              Text('ข้อมูลสินค้า', style: GoogleFonts.prompt(fontSize: 16, fontWeight: FontWeight.w600)),
               const SizedBox(height: 8),
              TextFormField(
                  controller: _itemDetailsController,
                   decoration: InputDecoration(
                     hintText: '(ไม่บังคับ) เช่น ระวังแตก',
                     hintStyle: GoogleFonts.prompt(color: Colors.grey.shade500),
                     enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                     focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: theme.primaryColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                   maxLines: 2, // ให้กรอกได้หลายบรรทัด
                    style: GoogleFonts.prompt(), // Apply font
              ),
              const SizedBox(height: 24),


            // --- ‼️ Map (เอา Title ออก, ไม่เอาเส้นขอบ) ‼️ ---
            Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                // border: Border.all(color: Colors.grey.shade300), // เอาเส้นขอบออก
              ),
              clipBehavior: Clip.antiAlias,
              child: GoogleMap(
                initialCameraPosition: const CameraPosition( target: _center, zoom: 11 ),
                onMapCreated: (controller) {
                    if (!_mapController.isCompleted) {
                     _mapController.complete(controller);
                     _updateMarkers(); // Call fitBounds inside
                   }
                },
                markers: _markers,
                // ‼️ เอา polylines ออก ‼️
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),
            ),
            const SizedBox(height: 24),

            // --- ‼️ Image Picker (UI ใหม่) ‼️ ---
             // Text('รูปถ่ายสินค้า', ...), // ไม่ต้องมี Title ซ้ำ
             // const SizedBox(height: 8),
            _buildImagePicker(),
            const SizedBox(height: 32),

            // --- ‼️ ปุ่มยืนยัน (UI ใหม่) ‼️ ---
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                ),
                textStyle: GoogleFonts.prompt(fontSize: 18, fontWeight: FontWeight.bold)
              ),
              onPressed: _isCreatingOrder ? null : _submitOrder,
              child: _isCreatingOrder
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                    )
                  : const Text('ยืนยัน'),
            ),
            const SizedBox(height: 16), // เพิ่มระยะห่างด้านล่าง
          ],
        ),
      ),
    );
  }

  // --- Widgets ย่อย ---

  // ‼️ Widget ใหม่สำหรับปุ่มเลือกที่อยู่ ‼️
  Widget _buildAddressPickerButton({
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
     return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30.0), // ให้ InkWell โค้งตาม
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade100, // พื้นหลังเทาอ่อน
          borderRadius: BorderRadius.circular(30.0), // โค้งมน
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.prompt(
                    fontSize: 16,
                    // ทำให้ข้อความเริ่มต้นเป็นสีเทา
                    color: label == 'พิกัดจัดส่ง' || label == 'รับพัสดุที่ไหน'
                           ? Colors.grey.shade600
                           : Colors.black,
                  ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
             // ไม่ต้องมี Icon Dropdown
          ],
        ),
      ),
    );
  }


  // (ฟังก์ชัน _showSenderAddressOptions, _showSavedAddressPicker เหมือนเดิม)
   Future<void> _showSenderAddressOptions() async {
      final savedAddresses = await _dbService.streamUserAddresses().first;
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
       shape: const RoundedRectangleBorder( // ทำให้ BottomSheet โค้ง
         borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
       ),
      builder: (context) {
        return SafeArea( child: Wrap( children: <Widget>[
           if (savedAddresses.isNotEmpty) ListTile(
             leading: const Icon(Icons.list_alt),
             title: Text('เลือกจากที่อยู่บันทึกไว้', style: GoogleFonts.prompt()),
             onTap: () { Navigator.pop(context); _showSavedAddressPicker(savedAddresses); },
           ),
           ListTile(
             leading: const Icon(Icons.add_location_alt_outlined),
             title: Text('ปักหมุดใหม่จากแผนที่', style: GoogleFonts.prompt()),
             onTap: () async {
               Navigator.pop(context);
               final LatLng? result = await Navigator.push<LatLng>(context, MaterialPageRoute(builder: (_) => const SelectLocationScreen()));
               if (result != null) {
                 final tempAddress = UserAddress(
                    id: DateTime.now().toString(), 
                    name: 'พิกัดรับพัสดุใหม่',
                    details: 'Lat: ${result.latitude}, Lng: ${result.longitude}',
                    location: GeoPoint(result.latitude, result.longitude),
                  );
                  if (mounted) {
                    setState(() { _selectedSenderAddress = tempAddress; });
                    _updateMarkers();
                  }
               }
             },
           ),
        ] ) );
      },
    );
   }
   Future<void> _showSavedAddressPicker(List<UserAddress> addresses) async {
     showModalBottomSheet(
       context: context,
        shape: const RoundedRectangleBorder(
         borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
       ),
       builder: (context) {
         return SafeArea( child: Column( mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0), // Adjust padding
              child: Text('เลือกที่อยู่ต้นทาง', style: GoogleFonts.prompt(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
             const Divider(height: 1), // Add a divider
            Flexible( child: ListView.builder(
              shrinkWrap: true,
              itemCount: addresses.length,
              itemBuilder: (context, index) {
                final address = addresses[index];
                return ListTile(
                  title: Text(address.name, style: GoogleFonts.prompt()),
                  subtitle: Text(address.details, style: GoogleFonts.prompt()),
                  onTap: () {
                    if (mounted) {
                       setState(() { _selectedSenderAddress = address; });
                       _updateMarkers();
                     }
                    Navigator.pop(context);
                  },
                );
              },
            ) ),
             const SizedBox(height: 16), // Add bottom padding
         ] ) );
       },
     );
   }

  // ‼️ ฟังก์ชันใหม่สำหรับเลือกที่อยู่ปลายทาง ‼️
   Future<void> _showReceiverAddressOptions() async {
     if (_foundReceiver == null || _receiverAddresses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('กรุณาค้นหาและเลือกผู้รับก่อน')),
        );
        return;
     }

      showModalBottomSheet(
        context: context,
         shape: const RoundedRectangleBorder(
           borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
         ),
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                   padding: const EdgeInsets.symmetric(vertical: 20.0),
                   child: Text('เลือกพิกัดจัดส่งสำหรับ ${_foundReceiver!.name}',
                      style: GoogleFonts.prompt(fontSize: 18, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center, // Center title
                      ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _receiverAddresses.length,
                    itemBuilder: (context, index) {
                      final address = _receiverAddresses[index];
                      return ListTile(
                        title: Text(address.name, style: GoogleFonts.prompt()),
                        subtitle: Text(address.details, style: GoogleFonts.prompt()),
                        onTap: () {
                          if (mounted) {
                             setState(() {
                               _selectedReceiverAddress = address;
                             });
                             _updateMarkers();
                           }
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
                 const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
   }

  // (Widget _buildReceiverSearch - ไม่ได้ใช้แล้ว ลบได้)
  // Widget _buildReceiverSearch() { /* ... */ }

  // (Widget _buildReceiverAddressSelector - ไม่ได้ใช้แล้ว ลบได้)
  // Widget _buildReceiverAddressSelector() { /* ... */ }

  // ‼️ แก้ไข _buildImagePicker ให้เหมือนในรูป ‼️
  Widget _buildImagePicker() {
    return InkWell(
      onTap: _takePicture,
      borderRadius: BorderRadius.circular(12), // Add border radius to InkWell
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
           color: Colors.grey.shade100, // พื้นหลังเทาอ่อน
           borderRadius: BorderRadius.circular(12),
           border: Border.all(color: Colors.grey.shade300, width: 1.5), // เส้นขอบปกติ
           // Consider using a package like 'dotted_border' for actual dashed border
        ),
        child: _pickedImage != null
            ? ClipRRect( // ทำให้รูปโค้งตามกรอบ
                 borderRadius: BorderRadius.circular(11), // Slightly smaller than container
                 child: Image.file(_pickedImage!, fit: BoxFit.cover)
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey.shade500),
                  const SizedBox(height: 8),
                  Text('รูปภาพสินค้า', style: GoogleFonts.prompt(color: Colors.grey.shade600)),
                ],
              ),
      ),
    );
  }

} // <--- สิ้นสุด State Class