
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:test_databse/screens/login_screen.dart';
import 'package:test_databse/screens/select_register_screen.dart';
import 'package:test_databse/screens/user/address_list_screen.dart';
import 'package:test_databse/screens/user/create_delivery_screen.dart';
import 'package:test_databse/screens/user/delivery_history_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:test_databse/screens/user/multi_tracking_widget.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  int _selectedIndex = 0;
  String _userName = 'กำลังโหลด...';
  String? _profileImageUrl;
  String _selectedToggle = 'send'; // ‼️ 1. State สำหรับปุ่ม Toggle

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // (โค้ด _loadUserData ของคุณ ถูกต้องแล้วครับ)
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

  // (โค้ด _onNavTapped ของคุณ ถูกต้องแล้วครับ)
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
      backgroundColor: Colors.white, // ‼️ 2. เพิ่มพื้นหลังสีขาว
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
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'ออกจากระบบ',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                 Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 3. ส่วนบน (ปุ่ม) ---
            _buildSendPackageView(), // (เรียก Widget ที่รวมปุ่ม)

            const SizedBox(height: 24),
            const Text(
              'Map Tracking', // (ข้อความตามรูป)
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            // --- 4. ส่วนล่าง (แผนที่) ---
            const Expanded(
              child: MultiTrackingWidget(), // (เรียก Widget แผนที่รวม)
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      // bottomNavigationBar: BottomNavigationBar(
      //   // ... (โค้ด BottomNavigationBar ของคุณ ถูกต้องแล้วครับ) ...
      //   currentIndex: _selectedIndex,
      //   onTap: _onNavTapped,
      //   backgroundColor: Colors.white,
      //   elevation: 8,
      //   selectedItemColor: Colors.black,
      //   unselectedItemColor: Colors.black45,
      //   items: const [
      //     BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
      //     BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.person_outline),
      //       label: 'Profile',
      //     ),
      //   ],
      // ),
    );
  }

  // ‼️ 5. Widget ที่แสดง "ส่วนบน" (อัปเดต UI ใหม่)
  Widget _buildSendPackageView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        // --- 6. ปุ่ม Toggle แบบใหม่ ---
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildToggleChip(
              text: 'send',
              isSelected: _selectedToggle == 'send',
              onTap: () => setState(() => _selectedToggle = 'send'),
            ),
            _buildToggleChip(
              text: 'รับพัสดุ',
              isSelected: _selectedToggle == 'receive',
              onTap: () => setState(() => _selectedToggle = 'receive'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // --- 7. Title "send a package" + Icon ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'send a package',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.tune_outlined,
                  color: Colors.black), // ไอคอน Filter
            ),
          ],
        ),
        const SizedBox(height: 16),

        // --- 8. Layout Card แบบใหม่ (ตามที่คุณบอก) ---
        Row(
          children: [
            Expanded(
              child: _FeatureCard(
                title: 'ส่งพัสดุ', // (เดิม "เพิ่มสินค้า")
                iconWidget: _buildIcon(Icons.inventory_2_outlined,
                    Colors.orange), // ไอคอนตามรูป
                iconAlignment: Alignment.topLeft,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateDeliveryScreen(), // (ถูกต้อง)
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FeatureCard(
                title: 'จัดการที่อยู่', // (เดิม "ค้นหาผู้รับ")
                iconWidget:
                    _buildIcon(Icons.map_outlined, Colors.blue), // (เปลี่ยนไอคอน)
                iconAlignment: Alignment.topRight,
                onTap: () {
                  // (เปลี่ยนปลายทาง)
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
        Row(
          children: [
            Expanded(
              flex: 1, // 1 ส่วน
              child: _FeatureCard(
                title: 'รายการส่งสินค้า', // (ตามที่คุณบอก)
                iconWidget: _buildIcon(
                    Icons.receipt_long_outlined, Colors.purple),
                iconAlignment: Alignment.topLeft,
                onTap: () {
                  _onNavTapped(1); // (ถูกต้อง: ไปหน้า History)
                },
              ),
            ),
            Expanded(flex: 1, child: Container()), // 1 ส่วน (เว้นว่าง)
          ],
        ),
      ],
    );
  }

  // ‼️ 9. Widget ใหม่สำหรับปุ่ม Toggle "Pill"
  Widget _buildToggleChip({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        width: 120, // กำหนดความกว้าง
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ‼️ 10. Widget ใหม่สำหรับ Icon (เพื่อให้เหมือนในรูป)
  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
} // <--- สิ้นสุด _UserHomePageState

// ‼️ 11. Widget ใหม่สำหรับ Card (แทนที่ _SmallActionCard เดิม)
class _FeatureCard extends StatelessWidget {
  final String title;
  final Widget iconWidget;
  final Alignment iconAlignment;
  final VoidCallback onTap;

  const _FeatureCard({
    Key? key,
    required this.title,
    required this.iconWidget,
    required this.iconAlignment,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20), // ทำให้โค้งมนมากขึ้น
        ),
        child: Stack(
          children: [
            Align(
              alignment: iconAlignment,
              child: iconWidget,
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}