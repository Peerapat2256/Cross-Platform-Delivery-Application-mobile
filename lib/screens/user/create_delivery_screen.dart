// lib/screens/user/create_delivery_screen.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:test_databse/model/address.dart';
import 'package:test_databse/model/profile.dart';
import 'package:test_databse/service/clouddinary_service.dart';
import 'package:test_databse/service/db_service.dart';

class CreateDeliveryScreen extends StatefulWidget {
  const CreateDeliveryScreen({super.key});

  @override
  State<CreateDeliveryScreen> createState() => _CreateDeliveryScreenState();
}

class _CreateDeliveryScreenState extends State<CreateDeliveryScreen> {
  final _dbService = DbService();
  final _phoneController = TextEditingController();
  final _picker = ImagePicker();

  // 1. สถานะของฟอร์ม
  UserAddress? _selectedSenderAddress;
  Profile? _foundReceiver;
  UserAddress? _selectedReceiverAddress;
  File? _pickedImage;
  String? _pickedImageUrl;

  // 2. สถานะการค้นหา
  bool _isSearchingReceiver = false;
  List<UserAddress> _receiverAddresses = []; // ที่อยู่ของผู้รับ
  bool _isCreatingOrder = false;

  // 3. ฟังก์ชันค้นหาผู้รับ
  Future<void> _searchReceiver() async {
    if (_phoneController.text.isEmpty) return;
    setState(() {
      _isSearchingReceiver = true;
      _foundReceiver = null;
      _receiverAddresses = [];
      _selectedReceiverAddress = null;
    });

    try {
      final receiver =
          await _dbService.findReceiverByPhone(_phoneController.text.trim());
      if (receiver != null) {
        // ถ้าเจอ
        final addresses = await _dbService.getReceiverAddresses(receiver.uid);
        setState(() {
          _foundReceiver = receiver;
          _receiverAddresses = addresses;
        });
      } else {
        // ถ้าไม่เจอ
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
      setState(() => _isSearchingReceiver = false);
    }
  }

  // 4. ฟังก์ชันถ่ายรูป
  Future<void> _takePicture() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );
    if (photo == null) return;
    setState(() => _pickedImage = File(photo.path));
  }

  // 5. ฟังก์ชันสร้างงาน
  Future<void> _submitOrder() async {
    // ตรวจสอบว่ากรอกครบ
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

    setState(() => _isCreatingOrder = true);

    try {
      // 5.1 อัปโหลดรูปไป Cloudinary
      final tempResult = FilePickerResult([
        PlatformFile(
          name: _pickedImage!.path.split('/').last,
          path: _pickedImage!.path,
          size: _pickedImage!.lengthSync(),
        ),
      ]);
      final imageUrl = await uploadTocloud(tempResult);

      if (imageUrl == null) {
        throw Exception("ไม่สามารถอัปโหลดรูปภาพได้");
      }
      _pickedImageUrl = imageUrl; // เก็บ URL ไว้ (ถ้าจำเป็น)

      // 5.2 สร้างออเดอร์
      await _dbService.createDeliveryOrder(
        senderAddress: _selectedSenderAddress!,
        receiverProfile: _foundReceiver!,
        receiverAddress: _selectedReceiverAddress!,
        pickupPhotoUrl: imageUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ สร้างงานส่งของสำเร็จ!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // กลับหน้าหลัก
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      setState(() => _isCreatingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สร้างรายการส่งของ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 1. ส่วนต้นทาง (ผู้ส่ง) ---
            _buildSectionTitle('1. ต้นทาง (ที่อยู่ของคุณ)'),
            _buildSenderAddressSelector(),
            const Divider(height: 32),

            // --- 2. ส่วนปลายทาง (ผู้รับ) ---
            _buildSectionTitle('2. ปลายทาง (ค้นหาผู้รับ)'),
            _buildReceiverSearch(),
            if (_isSearchingReceiver) const LinearProgressIndicator(),
            if (_foundReceiver != null) ...[
              const SizedBox(height: 16),
              _buildReceiverAddressSelector(),
            ],
            const Divider(height: 32),

            // --- 3. ส่วนรูปภาพสินค้า ---
            _buildSectionTitle('3. รูปถ่ายสินค้า (สถานะ [1])'),
            _buildImagePicker(),
            const SizedBox(height: 32),

            // --- 4. ปุ่มยืนยัน ---
            ElevatedButton.icon(
              icon: const Icon(Icons.send_rounded),
              label: const Text('ยืนยันการสร้างงาน'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: _isCreatingOrder ? null : _submitOrder,
            ),
            if (_isCreatingOrder) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  // --- Widgets ย่อย ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildSenderAddressSelector() {
    // ใช้ StreamBuilder ดึงที่อยู่ "ของเรา"
    return StreamBuilder<List<UserAddress>>(
      stream: _dbService.streamUserAddresses(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('กำลังโหลดที่อยู่...');
        }
        if (snapshot.data!.isEmpty) {
          return const Text(
            'คุณยังไม่มีที่อยู่, กรุณาไปเพิ่มที่ "จัดการที่อยู่" ก่อน',
            style: TextStyle(color: Colors.red),
          );
        }

        return DropdownButtonFormField<UserAddress>(
          value: _selectedSenderAddress,
          hint: const Text('เลือกที่อยู่ต้นทาง'),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: snapshot.data!.map((address) {
            return DropdownMenuItem(
              value: address,
              child: Text(address.name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedSenderAddress = value);
          },
        );
      },
    );
  }

  Widget _buildReceiverSearch() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'เบอร์โทรผู้รับ',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.search, color: Colors.blue),
          onPressed: _isSearchingReceiver ? null : _searchReceiver,
          iconSize: 30,
        ),
      ],
    );
  }

  Widget _buildReceiverAddressSelector() {
    // แสดงชื่อผู้รับที่เจอ
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ผู้รับ: ${_foundReceiver!.name}',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (_receiverAddresses.isEmpty)
          const Text(
            'ผู้รับคนนี้ยังไม่มีที่อยู่บันทึกไว้',
            style: TextStyle(color: Colors.red),
          ),
        if (_receiverAddresses.isNotEmpty)
          DropdownButtonFormField<UserAddress>(
            value: _selectedReceiverAddress,
            hint: const Text('เลือกที่อยู่ปลายทาง'),
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: _receiverAddresses.map((address) {
              return DropdownMenuItem(
                value: address,
                child: Text(address.name),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedReceiverAddress = value);
            },
          ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return InkWell(
      onTap: _takePicture,
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _pickedImage != null
            ? Image.file(_pickedImage!, fit: BoxFit.cover)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                  Text('แตะเพื่อถ่ายรูปสินค้า'),
                ],
              ),
      ),
    );
  }
}