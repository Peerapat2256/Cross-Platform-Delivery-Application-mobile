import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:test_databse/controller/rider/rider_controller.dart';

import 'package:test_databse/model/rider.dart';
import 'package:test_databse/screens/rider/delivery_tracking_screen.dart'
    hide RiderHomeController;
import 'package:test_databse/screens/rider/job_preview_screen.dart'; // ตรวจสอบ Path ให้ถูกต้อง

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
        // ดึง 'name' มาแสดงเป็นชื่อ
        _riderName = riderData['name'] ?? 'Rider';
        // ดึง 'plateUrl' มาแสดงเป็นรูปโปรไฟล์ ตามโครงสร้างของ RegisterController
        _profileImageUrl = riderData['photoUrl'];
      });
    }
  }

  void _onNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none, color: Colors.black54),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blueGrey.shade100,
              backgroundImage: _profileImageUrl != null
                  ? NetworkImage(_profileImageUrl!) // <-- แสดงรูปที่ดึงมา
                  : null,
              child: (_profileImageUrl == null)
                  ? Text(
                      _riderName.length > 1
                          ? _riderName.substring(0, 2).toUpperCase()
                          : '..',
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
              Row(
                children: const [
                  Expanded(
                    child: _SmallActionCard(
                      title: 'รับงาน',
                      icon: Icons.assignment_turned_in_outlined,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _SmallActionCard(
                      title: 'ค้นหาผู้รับ',
                      icon: Icons.search,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'งานที่รอไรเดอร์',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  TextButton(onPressed: () {}, child: const Text('ดูทั้งหมด')),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _controller.getAvailableJobs(),
                  builder: (context, snapshot) {
                    print(
                      "🕵️‍ StreamBuilder ทำงานใหม่! สถานะ: ${snapshot.connectionState}",
                    );
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
                      print("ไม่มีข้อมูลงาน หรือข้อมูลว่างเปล่า");
                      return const Center(
                        child: Text(
                          'ยังไม่มีงานในขณะนี้',
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }

                    final jobDocs = snapshot.data!.docs;
                    //print("✅ พบงาน ${jobDocs.length} รายการ! กำลังจะแสดงผล...");
                    return ListView.separated(
                      itemCount: jobDocs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final delivery = Delivery.fromMap(jobDocs[index]);

                        return JobCard(
                          recipient: delivery.receiverName,
                          pickupAddress: delivery.pickupAddress, //  ส่งที่อยู่รับ
                          dropOffAddress: delivery.deliveryAddress, // ส่งที่อยู่ส่ง
                          pickupImageUrl: delivery.pickupImageUrl, // ส่ง URL รูป
                          onAccept: () {
                            // ไม่ต้องเรียก controller.acceptJob() แล้ว
                            // ให้เด้งไปหน้าพรีวิวแทน
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => JobPreviewScreen(
                                  delivery: delivery, 
                                ),
                              ),
                            );
                          },
                          onReject: () {},
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          print('กำลังสร้างงานจำลอง...');
          await _controller.simulateNewJob();

          // แสดงข้อความบอกว่าสร้างสำเร็จแล้ว
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('สร้างงานจำลอง 1 งานสำเร็จ!'),
                backgroundColor: Colors.blue,
              ),
            );
          }
        },
        tooltip: 'สร้างงานจำลอง',
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add_location_alt_outlined),
      ),
    );
  }
}

class _SmallActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SmallActionCard({Key? key, required this.title, required this.icon})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.black54),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

// ‼️ แทนที่ JobCard เดิมด้วยอันนี้ ‼️
class JobCard extends StatelessWidget {
  final String recipient;
  final String pickupAddress; // 1. เพิ่มที่อยู่รับ
  final String dropOffAddress; // 2. เปลี่ยนชื่อ (เดิมคือ dropOff)
  final String? pickupImageUrl; // 3. เพิ่ม URL รูป
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const JobCard({
    Key? key,
    required this.recipient,
    required this.pickupAddress,
    required this.dropOffAddress,
    this.pickupImageUrl,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      clipBehavior: Clip.antiAlias, // 4. เพิ่ม clipBehavior
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 5. แสดงรูป (ถ้ามี)
          if (pickupImageUrl != null)
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(pickupImageUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            // (ถ้าไม่มีรูป)
            Container(
              height: 120,
              width: double.infinity,
              color: Colors.grey.shade200,
              child: Icon(Icons.inventory_2_outlined,
                  size: 40, color: Colors.grey.shade500),
            ),

          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ผู้รับ: $recipient',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 6. เพิ่มส่วนแสดง "ที่อยู่รับ"
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.store_outlined, // ไอคอนจุดรับ
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'รับของ: $pickupAddress',
                        style: TextStyle(color: Colors.blue.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 7. แก้ไขส่วน "ที่อยู่ส่ง"
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.place_outlined, // ไอคอนจุดส่ง
                      size: 16,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ส่งของ: $dropOffAddress',
                        style: TextStyle(color: Colors.green.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 8. ปุ่ม (เหมือนเดิม)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'ปฏิเสธ',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'รับงาน',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
