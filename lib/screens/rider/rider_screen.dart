import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:test_databse/controller/rider/rider_controller.dart';

import 'package:test_databse/model/rider.dart';
import 'package:test_databse/screens/login_screen.dart';

import 'package:test_databse/screens/rider/delivery_tracking_screen.dart';


import 'package:test_databse/screens/rider/job_preview_screen.dart';

class RiderHomePage extends StatefulWidget {
  const RiderHomePage({Key? key}) : super(key: key);

  @override
  State<RiderHomePage> createState() => _RiderHomePageState();
}

class _RiderHomePageState extends State<RiderHomePage> {
  final RiderHomeController _controller = RiderHomeController();
  int _selectedIndex = 0;

  String _riderName = 'กำลังโหลด...';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadRiderData();
    _checkForActiveJob(); // เรียกฟังก์ชันเช็คงานค้าง
  }

Future<void> _checkForActiveJob() async {
    final activeJobId = await _controller.checkActiveJob();
    if (activeJobId != null) {
      // ถ้ามีงานค้าง
      print("พบงานค้าง: $activeJobId, กำลังนำทาง...");
      if (mounted) {
        // ใช้ pushReplacement เพื่อไม่ให้ย้อนกลับมาหน้านี้ได้
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DeliveryTrackingPage(
              deliveryId: activeJobId,
            ),
          ),
        );
      }
    } else {
      // ไม่มีงานค้าง ก็ไม่ต้องทำอะไร
      print("ไม่พบงานค้าง, แสดงหน้าหางานใหม่ตามปกติ");
    }
  }
  Future<void> _loadRiderData() async {
    final riderData = await _controller.getCurrentRiderData();
    if (riderData != null && mounted) {
      setState(() {
        _riderName = riderData['name'] ?? 'Rider';
        // แก้ไข: ดึง 'photoUrl' สำหรับรูปโปรไฟล์
        _profileImageUrl = riderData['photoUrl'];
      });
    }
  }

  void _onNavTapped(int index) {
     if (index == 2) { // Index 2 = Profile
        // TODO: Implement navigation to Rider Profile Screen if needed
        print("Profile tab tapped");
     } else if (index == 1) { // Index 1 = History
        // TODO: Implement navigation to Rider History Screen if needed
        print("History tab tapped");
     }
     // Only update index if not navigating away immediately
     if (index != 1 && index != 2) { // Keep Home selected if navigating away
       setState(() {
         _selectedIndex = index;
       });
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            const Text(
              'สวัสดีคุณ',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Text(
              _riderName,
              style: const TextStyle(fontSize: 16, color: Colors.black),
            ),
          ],
        ),
        actions: [
          // --- ปุ่ม Logout (ย้ายมาไว้ตรงนี้ดีกว่า) ---
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'ออกจากระบบ',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                 context: context,
                 builder: (context) => AlertDialog(
                   title: Text('ออกจากระบบ'),
                   content: Text('คุณต้องการออกจากระบบหรือไม่?'),
                   actions: [
                     TextButton(onPressed: () => Navigator.pop(context, false), child: Text('ยกเลิก')),
                     TextButton(onPressed: () => Navigator.pop(context, true), child: Text('ยืนยัน', style: TextStyle(color: Colors.red))),
                   ],
                 ),
               );
               if (confirm == true) {
                  await FirebaseAuth.instance.signOut();
                  // ใช้ pushAndRemoveUntil เพื่อเคลียร์หน้าทั้งหมดก่อนหน้า Login
                  if (mounted) { // Check mount status
                      Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (Route<dynamic> route) => false, // Remove all routes
                      );
                  }
               }
            },
          ),
          // IconButton( // ปุ่ม Notification เดิม
          //   onPressed: () {},
          //   icon: const Icon(Icons.notifications_none, color: Colors.black54),
          // ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blueGrey.shade100,
              backgroundImage: _profileImageUrl != null
                  ? NetworkImage(_profileImageUrl!)
                  : null,
              child: (_profileImageUrl == null)
                  ? Text(
                      _riderName.isNotEmpty ? _riderName.substring(0, math.min(_riderName.length, 2)).toUpperCase() : '..', // Handle short names
                      style: const TextStyle(color: Colors.black87),
                    )
                  : null,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Rider',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 28),
              // --- Action Cards (อาจจะไม่จำเป็นแล้ว ถ้ามีแค่ List งาน) ---
              // Row(
              //   children: const [
              //     Expanded( child: _SmallActionCard( /*...*/ ), ),
              //     SizedBox(width: 12),
              //     Expanded( child: _SmallActionCard( /*...*/ ), ),
              //   ],
              // ),
              // const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'งานที่รอไรเดอร์',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  // TextButton(onPressed: () {}, child: const Text('ดูทั้งหมด')), // อาจจะไม่จำเป็น
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _controller.getAvailableJobs(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      print("🔥 เกิดข้อผิดพลาดใน Stream: ${snapshot.error}");
                      return const Center(
                        child: Text('เกิดข้อผิดพลาดในการโหลดงาน'),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'ยังไม่มีงานในขณะนี้',
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }

                    final jobDocs = snapshot.data!.docs;
                    return ListView.separated(
                      itemCount: jobDocs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final delivery = Delivery.fromMap(jobDocs[index]);

                        return JobCard(
                          recipient: delivery.receiverName,
                          pickupAddress: delivery.pickupAddress,
                          dropOffAddress: delivery.deliveryAddress,
                          pickupImageUrl: delivery.pickupImageUrl,
                          senderName: delivery.senderName,
                          senderPhone: delivery.senderPhone,
                          itemName: delivery.itemName ?? 'สินค้าไม่ระบุชื่อ',
                          itemDetails: delivery.itemDetails,
                          onAccept: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => JobPreviewScreen(
                                  delivery: delivery,
                                ),
                              ),
                            );
                          },
                          // ทำให้ปุ่มปฏิเสธกดไม่ได้ (หรือจะซ่อนไปเลยก็ได้)
                          onReject: () {
                             print("Reject button pressed for ${delivery.deliveryId}");
                             // Add functionality here if needed, e.g., temporary hide
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTapped,
        backgroundColor: Colors.white,
        elevation: 8,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black45,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton( // เอาปุ่ม Simulate ออก
      //   onPressed: () async { /* ... */ },
      // ),
    );
  }
}

// (_SmallActionCard เดิม - อาจจะไม่ต้องใช้แล้ว ลบได้)
class _SmallActionCard extends StatelessWidget {
// ... โค้ดเดิม ...
   final String title;
  final IconData icon;
  const _SmallActionCard({Key? key, required this.title, required this.icon})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container( /* ... */ );
  }
}

// (JobCard เดิม ที่แก้ไขแล้ว)
class JobCard extends StatelessWidget {
// ... โค้ดเดิม ...
  final String recipient;
  final String pickupAddress;
  final String dropOffAddress;
  final String? pickupImageUrl;
  final String senderName;
  final String senderPhone;
  final String itemName;
  final String? itemDetails;
  final VoidCallback onAccept;
  final VoidCallback onReject;

   const JobCard({
    Key? key,
    required this.recipient,
    required this.pickupAddress,
    required this.dropOffAddress,
    this.pickupImageUrl,
    required this.senderName,
    required this.senderPhone,
    required this.itemName,
    this.itemDetails,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // (ส่วนแสดงรูปภาพ pickupImageUrl เหมือนเดิม)
           if (pickupImageUrl != null) Container( height: 120, width: double.infinity, decoration: BoxDecoration( image: DecorationImage(image: NetworkImage(pickupImageUrl!), fit: BoxFit.cover,),),)
           else Container( height: 120, width: double.infinity, color: Colors.grey.shade200, child: Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade500), ),


          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- ข้อมูลสินค้า ---
                 Text( itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis,),
                if (itemDetails != null && itemDetails!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text( itemDetails!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis,),
                ],
                const Divider(height: 16),

                // --- ข้อมูลผู้ส่ง ---
                 _buildInfoRow( icon: Icons.person_pin_circle_outlined, value: '$senderName ($senderPhone)', color: Colors.purple.shade700,),
                 const SizedBox(height: 8),

                // --- ข้อมูลผู้รับ ---
                _buildInfoRow( icon: Icons.person_outline, value: recipient, color: Colors.black54,),
                const SizedBox(height: 12),

                // --- ที่อยู่รับ ---
                _buildInfoRow( icon: Icons.store_outlined, value: pickupAddress, color: Colors.blue.shade700,),
                const SizedBox(height: 8),

                // --- ที่อยู่ส่ง ---
                 _buildInfoRow( icon: Icons.place_outlined, value: dropOffAddress, color: Colors.green.shade700,),
                const SizedBox(height: 16),

                // --- ปุ่ม ---
                Row(
                   children: [
                     Expanded( child: OutlinedButton( onPressed: onReject, style: OutlinedButton.styleFrom( side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8),), padding: const EdgeInsets.symmetric(vertical: 12),), child: const Text( 'ปฏิเสธ', style: TextStyle(color: Colors.redAccent),),),),
                     const SizedBox(width: 12),
                     Expanded( child: ElevatedButton( onPressed: onAccept, style: ElevatedButton.styleFrom( backgroundColor: Colors.black, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8),), padding: const EdgeInsets.symmetric(vertical: 12),), child: const Text( 'รับงาน', style: TextStyle(color: Colors.white),),),),
                   ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widget แสดงข้อมูล ---
   Widget _buildInfoRow({
    required IconData icon,
    String? label, // Make label optional
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        // if (label != null) Text('$label ', style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
          ),
        ),
      ],
    );
  }
}