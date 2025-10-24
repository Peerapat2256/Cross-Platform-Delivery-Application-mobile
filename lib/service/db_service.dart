import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:test_databse/model/address.dart';
import 'package:test_databse/model/profile.dart'; 
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:test_databse/model/rider.dart';
class DbService {
  User? get user => FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveUploadedFilesData(Map<String, String> data) async {
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .collection("uploads")
        .doc()
        .set(data);
  }

  Stream<QuerySnapshot> readUploadedFiles() {
    if (user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .collection("uploads")
        .snapshots();
  }
  ///  ดึงรายการที่เรา "เป็นผู้ส่ง"
  Stream<List<Delivery>> getMySentDeliveries() {
    if (user == null) return Stream.value([]);
    return _db
        .collection('deliveries')
        .where('sender_id', isEqualTo: user!.uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Delivery.fromMap(doc)).toList());
  }
  ///  ดึงรายการที่เรา "เป็นผู้รับ"
  Stream<List<Delivery>> getMyReceivedDeliveries() {
    if (user == null) return Stream.value([]);
    return _db
        .collection('deliveries')
        .where('receiver_id', isEqualTo: user!.uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Delivery.fromMap(doc)).toList());
  }

  /// ดึงข้อมูลงาน 1 ชิ้นแบบ Real-time (เหมือนของ Rider)
  Stream<DocumentSnapshot> getDeliveryStream(String deliveryId) {
    return _db.collection('deliveries').doc(deliveryId).snapshots();
  }

  ///  ดึงข้อมูลตำแหน่ง + โปรไฟล์ของ Rider 1 คนแบบ Real-time
  Stream<DocumentSnapshot> getRiderStream(String riderId) {
    return _db.collection('users').doc(riderId).snapshots();
  }


  /// ดึง Stream รายการที่อยู่ทั้งหมดของ User
  Stream<List<UserAddress>> streamUserAddresses() {
    if (user == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(user!.uid)
        .collection('addresses')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => UserAddress.fromSnap(doc)).toList();
    });
  }

  /// เพิ่มที่อยู่ใหม่
  Future<void> addAddress(String name, String details, GeoPoint location) async {
    if (user == null) return;
    final newAddress = {
      'name': name,
      'details': details,
      'location': location,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _db
        .collection('users')
        .doc(user!.uid)
        .collection('addresses')
        .add(newAddress);
  }

  /// ลบที่อยู่
  Future<void> deleteAddress(String addressId) async {
    if (user == null) return;
    await _db
        .collection('users')
        .doc(user!.uid)
        .collection('addresses')
        .doc(addressId)
        .delete();
  }
/// ค้นหาผู้รับจากเบอร์โทร
  Future<Profile?> findReceiverByPhone(String phone) async {
    if (user == null) return null;

    final query = await _db
        .collection('users')
        .where('phone', isEqualTo: phone)
        .where('userType', isEqualTo: 'user') // ต้องเป็น User เท่านั้น
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null; // ไม่พบ
    }

    // กันตัวเอง (ห้ามส่งหาตัวเอง)
    if (query.docs.first.id == user!.uid) {
      return null;
    }

    return Profile.fromMap(query.docs.first.data());
  }

  /// ดึงรายการที่อยู่ "ของผู้รับ" (ที่ไม่ใช่เรา)
  Future<List<UserAddress>> getReceiverAddresses(String receiverId) async {
    final snapshot = await _db
        .collection('users')
        .doc(receiverId)
        .collection('addresses')
        .get();

    return snapshot.docs.map((doc) => UserAddress.fromSnap(doc)).toList();
  }

  /// สร้างออเดอร์ส่งของ
  Future<void> createDeliveryOrder({
    required UserAddress senderAddress,
    required Profile receiverProfile,
    required UserAddress receiverAddress,
    required String pickupPhotoUrl,
  }) async {
    if (user == null) throw Exception('User not logged in');

    final senderId = user!.uid;

    await _db.collection('deliveries').add({
      'status': 'waiting_for_rider', // ‼️ สถานะ [1] ตามโจทย์
      'created_at': FieldValue.serverTimestamp(),
      'pickup_image_url': pickupPhotoUrl, // ‼️ รูปถ่ายสถานะ [1]
      'delivery_image_url': null,

      // ข้อมูลผู้ส่ง (Denormalized)
      'sender_id': senderId,
      'pickup_address_full':
          '${senderAddress.name} (${senderAddress.details})',
      'pickup_location': senderAddress.location,

      // ข้อมูลผู้รับ (Denormalized)
      'receiver_id': receiverProfile.uid,
      'receiver_name': receiverProfile.name,
      'receiver_phone': receiverProfile.phone,
      'delivery_address_full':
          '${receiverAddress.name} (${receiverAddress.details})',
      'delivery_location': receiverAddress.location,

      // ข้อมูลไรเดอร์ (ยังไม่มี)
      'rider_id': null,
    });
  }

Future<String> cancelDelivery(String deliveryId) async {
    if (user == null) return "คุณยังไม่ได้เข้าสู่ระบบ";
    try {
      final docRef = _db.collection('deliveries').doc(deliveryId);
      final doc = await docRef.get();

      if (!doc.exists) return "ไม่พบงานนี้";

      final status = doc.data()?['status'];

      if (status == 'waiting_for_rider') {
        // ถ้ายังไม่มีใครรับ -> ยกเลิกได้
        await docRef.update({
          'status': 'cancelled_by_user', // เปลี่ยนสถานะ
        });
        return "ยกเลิกงานสำเร็จ";
      } else {
        // ถ้ามีคนรับไปแล้ว หรือส่งเสร็จแล้ว
        return "ไม่สามารถยกเลิกงานได้ (Rider รับงานไปแล้ว)";
      }
    } catch (e) {
      return "เกิดข้อผิดพลาด: $e";
    }
  }


}
