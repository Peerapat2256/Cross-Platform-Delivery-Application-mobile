import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:test_databse/screens/user/address_list_screen.dart';
import 'package:test_databse/screens/user/create_delivery_screen.dart';
import 'package:test_databse/screens/user/delivery_history_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:test_databse/screens/user/multi_tracking_screen.dart';
class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  String segmentedValue = 'รับงาน';
  int _selectedIndex = 0;

  // เพิ่มตัวแปร
  String _userName = 'กำลังโหลด...';
  String? _profileImageUrl;

  // เพิ่ม initState
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // เพิ่มฟังก์ชันโหลดข้อมูล
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _userName = doc.data()?['name'] ?? 'User';
          _profileImageUrl = doc.data()?['photoUrl'];
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
      if (mounted) setState(() => _userName = 'Error');
    }
  }

  void _onNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DeliveryHistoryScreen()),
      );
     
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
              _userName, 
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
                  ? NetworkImage(_profileImageUrl!)
                  : null,
              child: (_profileImageUrl == null)
                  ? Text(
                      _userName.length > 1
                          ? _userName.substring(0, 2).toUpperCase()
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
          child: ListView(
            
            children: [
              const SizedBox(height: 8),

              // Title
              Text('User', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),

              // Segmented control
              CupertinoSegmentedControl<String>(
                children: const {
                  'รับงาน': Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 10.0,
                      horizontal: 24.0,
                    ),
                    child: Text('ส่งพัสดุ'),
                  ),

                  'รับพัสดุ': Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 10.0,
                      horizontal: 24.0,
                    ),
                    child: Text('รับพัสดุ'),
                  ),
                },
                groupValue: segmentedValue,
                unselectedColor: Colors.grey.shade100,
                borderColor: Colors.grey.shade300,
                pressedColor: Colors.grey.shade200,
                selectedColor: Colors.black,
                onValueChanged: (v) => setState(() => segmentedValue = v),
              ),

              const SizedBox(height: 16),

              // Small action cards
              Row(
                children: [
                  Expanded(
                    child: _SmallActionCard(
                      title: 'ส่งพัสดุ',
                      icon: Icons.inventory_2,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateDeliveryScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SmallActionCard(
                      title: 'จัดการที่อยู่', 
                      icon: Icons.map,     
                      onTap: () {
                        //  5. เพิ่ม onTap ให้นำทางไปหน้า List ที่อยู่
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddressListScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SmallActionCard(
                title: 'ติดตามงานทั้งหมด (แผนที่รวม)',
                icon: Icons.map_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MultiTrackingScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              // // Section Title
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //   children: [
              //     const Text(
              //       'รับงาน',
              //       style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              //     ),
              //     TextButton(onPressed: () {}, child: const Text('View all')),
              //   ],
              // ),

              // const SizedBox(height: 8),

              // // Job list
              // Expanded(
              //   child: ListView.separated(
              //     itemCount: 2,
              //     separatorBuilder: (_, __) => const SizedBox(height: 12),
              //     itemBuilder: (context, index) {
              //       return JobCard(
              //         title: 'Food Items/Groceries',
              //         recipient: 'Paul Pogba',
              //         dropOff: 'Maryland bustop, Anthony Ikeja',
              //         onAccept: () {},
              //         onReject: () {},
              //       );
              //     },
              //   ),
              // ),
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
    );
  }
}

class _SmallActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  const _SmallActionCard({
    Key? key,
    required this.title,
    required this.icon,
    this.onTap, //  7. รับค่า onTap
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // ... (โค้ดเดิม) ...
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class JobCard extends StatelessWidget {
  final String title;
  final String recipient;
  final String dropOff;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const JobCard({
    Key? key,
    required this.title,
    required this.recipient,
    required this.dropOff,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_grocery_store_outlined,
                    size: 22,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 16,
                  color: Colors.black54,
                ),
                const SizedBox(width: 6),
                Text(
                  'Recipient: $recipient',
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: Colors.black54,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    dropOff,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
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
                      'Reject',
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
                      'Accept',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
