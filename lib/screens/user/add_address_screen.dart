// lib/screens/user/add_address_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:test_databse/screens/user/select_location_screen.dart';
import 'package:test_databse/service/db_service.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbService = DbService();
  final _nameController = TextEditingController();
  final _detailsController = TextEditingController();

  LatLng? _selectedLocation;
  bool _isLoading = false;

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (context) => const SelectLocationScreen()),
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result;
      });
    }
  }

  Future<void> _saveAddress() async {
    if (_formKey.currentState!.validate() && _selectedLocation != null) {
      setState(() => _isLoading = true);
      try {
        await _dbService.addAddress(
          _nameController.text,
          _detailsController.text,
          GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('บันทึกที่อยู่เรียบร้อย')),
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
        setState(() => _isLoading = false);
      }
    } else if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกพิกัดบนแผนที่')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เพิ่มที่อยู่ใหม่')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อที่อยู่',
                  hintText: 'เช่น บ้าน, ที่ทำงาน, คอนโด',
                  icon: Icon(Icons.label),
                ),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'กรุณากรอกชื่อ' : null,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _detailsController,
                decoration: const InputDecoration(
                  labelText: 'รายละเอียด (ไม่จำเป็น)',
                  hintText: 'เช่น ตึก A, ชั้น 5, ห้อง 501',
                  icon: Icon(Icons.details),
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                icon: Icon(
                  _selectedLocation == null
                      ? Icons.map_outlined
                      : Icons.check_circle,
                  color: _selectedLocation == null ? Colors.grey : Colors.green,
                ),
                label: Text(
                  _selectedLocation == null
                      ? 'เลือกพิกัดจากแผนที่'
                      : 'เลือกพิกัดแล้ว',
                ),
                onPressed: _openMapPicker,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading ? null : _saveAddress,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Text('บันทึกที่อยู่'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}