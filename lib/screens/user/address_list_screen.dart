// lib/screens/user/address_list_screen.dart
import 'package:flutter/material.dart';
import 'package:test_databse/model/address.dart';
import 'package:test_databse/screens/user/add_address_screen.dart';
import 'package:test_databse/service/db_service.dart';
import 'package:test_databse/screens/user/view_address_map_screen.dart';
class AddressListScreen extends StatefulWidget {
  const AddressListScreen({super.key});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  final DbService _dbService = DbService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ที่อยู่ของฉัน'),
      ),
      body: StreamBuilder<List<UserAddress>>(
        stream: _dbService.streamUserAddresses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'คุณยังไม่มีที่อยู่บันทึกไว้\nกด "+" เพื่อเพิ่มที่อยู่ใหม่',
                textAlign: TextAlign.center,
              ),
            );
          }

          final addresses = snapshot.data!;

          return ListView.builder(
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final address = addresses[index];
              return ListTile(
                leading: Icon(
                  address.name.toLowerCase().contains('บ้าน')
                      ? Icons.home
                      : address.name.toLowerCase().contains('ที่ทำ')
                          ? Icons.work
                          : Icons.location_on,
                ),
                title: Text(address.name),
                subtitle: Text(address.details),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _dbService.deleteAddress(address.id),
                ),
                onTap: () {
                  // เมื่อกด ให้เด้งไปหน้า ViewAddressMapScreen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewAddressMapScreen(
                        location: address.location, // ส่งพิกัด
                        addressName: address.name,   // ส่งชื่อ
                      ),
                    ),
                  );
                },
                // ‼️ 4. (Optional) เพิ่ม visual feedback
                splashColor: Colors.blue.withOpacity(0.1),
              );
              
            },
          );
          
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddAddressScreen()),
          );
        },
        backgroundColor: Colors.green.shade700,
        child: const Icon(Icons.add),
      ),
    );
  }
}