// lib/screens/user/delivery_history_screen.dart
import 'package:flutter/material.dart';
import 'package:test_databse/model/rider.dart'; // (ไฟล์ Delivery model)
import 'package:test_databse/screens/user/user_tracking_screen.dart'; // (เดี๋ยวเราจะสร้างไฟล์นี้ต่อ)
import 'package:test_databse/service/db_service.dart';

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DbService _dbService = DbService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติการส่งของ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'กำลังส่งไป'),
            Tab(text: 'กำลังส่งมา'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- แท็บ 1: รายการที่เรา "ส่ง" ---
          _buildDeliveryList(stream: _dbService.getMySentDeliveries()),
          // --- แท็บ 2: รายการที่เรา "รับ" ---
          _buildDeliveryList(stream: _dbService.getMyReceivedDeliveries()),
        ],
      ),
    );
  }

  // Widget สำหรับสร้าง List
  Widget _buildDeliveryList({required Stream<List<Delivery>> stream}) {
    return StreamBuilder<List<Delivery>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('ไม่พบรายการ'));
        }

        final deliveries = snapshot.data!;

        return ListView.builder(
          itemCount: deliveries.length,
          itemBuilder: (context, index) {
            final delivery = deliveries[index];
           bool isActive = delivery.status != 'delivered' &&
                delivery.status != 'cancelled_by_user'; 

            // สร้าง Widget trailing
            Widget? trailingWidget;
            if (delivery.status == 'waiting_for_rider') {
              // ถ้ายังไม่มีคนรับ -> ให้ยกเลิกได้
              trailingWidget = TextButton(
                child: const Text('ยกเลิก', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  final result = await _dbService.cancelDelivery(delivery.deliveryId);
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(result)));
                  }
                },
              );
            } else if (isActive) {
              // ถ้ารับไปแล้ว แต่ยังไม่จบ -> ให้ติดตาม
              trailingWidget = const Icon(Icons.chevron_right);
            } else {
              // งานที่จบแล้ว (delivered, cancelled)
              trailingWidget = null;
            }

            return ListTile(
              leading: Icon(
                isActive
                    ? Icons.local_shipping
                    : (delivery.status == 'cancelled_by_user'
                        ? Icons.cancel
                        : Icons.check_circle),
                color: isActive
                    ? Colors.blue
                    : (delivery.status == 'cancelled_by_user'
                        ? Colors.red
                        : Colors.green),
              ),
              title: Text('ส่งไป: ${delivery.receiverName}'),
              subtitle: Text(
                'สถานะ: ${delivery.status}',
                // ... (style) ...
              ),
              trailing: trailingWidget,
              onTap: () {
                // กดแล้วเด้งไปหน้าแผนที่
                if (isActive || delivery.status == 'delivered') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserTrackingScreen(
                        deliveryId: delivery.deliveryId,
                      ),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}