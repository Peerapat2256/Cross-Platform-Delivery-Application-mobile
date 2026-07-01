
import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:test_databse/service/clouddinary_service.dart';

class RiderHomeController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  StreamSubscription<Position>? _positionStreamSubscription;
Future<String> cancelDeliveryByRider(String deliveryId) async {
    final riderId = _auth.currentUser!.uid;
    final jobRef = _db.collection('deliveries').doc(deliveryId);

    try {
      // ใช้ Transaction เพื่อความปลอดภัย
      await _db.runTransaction((transaction) async {
        final jobSnapshot = await transaction.get(jobRef);

        if (!jobSnapshot.exists) {
          throw Exception("ไม่พบงานนี้ในระบบ");
        }

        final jobData = jobSnapshot.data() as Map<String, dynamic>;

        // ตรวจสอบว่าเป็นงานของ Rider คนนี้จริง และสถานะยังไม่จบ
        if (jobData['rider_id'] != riderId) {
          throw Exception("คุณไม่ใช่ผู้รับผิดชอบงานนี้");
        }
        if (jobData['status'] != 'rider_accepted' && jobData['status'] != 'picked_up') {
          throw Exception("ไม่สามารถยกเลิกงานในสถานะนี้ได้");
        }

        // อัปเดต: คืนสถานะงาน + ลบข้อมูล Rider ออก
        transaction.update(jobRef, {
          'status': 'waiting_for_rider', // คืนสถานะให้คนอื่นรับได้
          'rider_id': null,
          'accepted_at': null,
        
        });
      });
      // (Optional: อาจจะต้องอัปเดตสถานะ is_available ของ Rider กลับเป็น true ด้วย)
      // await _db.collection('users').doc(riderId).update({'is_available': true});

      return "ยกเลิกงานสำเร็จ";
    } catch (e) {
      print('🔥 เกิดข้อผิดพลาดในการยกเลิกงาน: $e');
      return "เกิดข้อผิดพลาด: ${e.toString()}";
    }
  }

  Future<Map<String, dynamic>?> getCurrentRiderData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _db.collection('users').doc(user.uid).get();
        return doc.data();
      }
      return null;
    } catch (e) {
      print("Error fetching rider data: $e");
      return null;
    }
  }

  /// ตรวจสอบว่ามีงานที่กำลังทำค้างอยู่หรือไม่ (สถานะ 'rider_accepted' หรือ 'picked_up')
  Future<String?> checkActiveJob() async {
    final riderId = _auth.currentUser!.uid;

    final query = await _db
        .collection('deliveries')
        .where('rider_id', isEqualTo: riderId)
        .where('status', whereIn: ['rider_accepted', 'picked_up'])
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      // ถ้ำพบงานค้าง
      return query.docs.first.id; // คืนค่า ID ของงานนั้น
    }
    return null; // ไม่พบงานค้าง
  }

  Stream<QuerySnapshot> getAvailableJobs() {
    return _db
        .collection('deliveries')
        .where('status', isEqualTo: 'waiting_for_rider')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Future<String> acceptJob(String deliveryId) async {
    final riderId = _auth.currentUser!.uid;

    //--- ตรวจสอบเงื่อนไข: ไรเดอร์ 1 คน รับงานได้ทีละงาน ---
    final riderJobs = await _db
        .collection('deliveries')
        .where('rider_id', isEqualTo: riderId)
        .where('status', whereIn: ['rider_accepted', 'picked_up'])
        .limit(1)
        .get();

    if (riderJobs.docs.isNotEmpty) {
      return "คุณมีงานที่ยังดำเนินการอยู่แล้ว ไม่สามารถรับงานซ้อนได้";
    }

    final jobRef = _db.collection('deliveries').doc(deliveryId);

    try {
      await _db.runTransaction((transaction) async {
        final jobSnapshot = await transaction.get(jobRef);

        if (!jobSnapshot.exists) {
          throw Exception("งานนี้ไม่มีอยู่ในระบบแล้ว");
        }
        final jobData = jobSnapshot.data() as Map<String, dynamic>;
        if (jobData['status'] != 'waiting_for_rider') {
          throw Exception("มีไรเดอร์ท่านอื่นรับงานนี้ไปแล้ว");
        }
        transaction.update(jobRef, {
          'status': 'rider_accepted',
          'rider_id': riderId,
          'accepted_at': FieldValue.serverTimestamp(),
        });
      });
      return "รับงานสำเร็จ";
    } catch (e) {
      return e.toString().contains('มีไรเดอร์ท่านอื่นรับงานนี้ไปแล้ว')
          ? "มีไรเดอร์ท่านอื่นรับงานนี้ไปแล้ว"
          : "เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง";
    }
  }

  Future<void> simulateNewJob() async {
    try {
      final newJobData = {
        'status': 'waiting_for_rider', // <-- สถานะเริ่มต้นที่ไรเดอร์จะมองเห็น
        'created_at': FieldValue.serverTimestamp(),
        'pickup_image_url':
            'https://via.placeholder.com/150', // URL รูปตัวอย่าง
        // ข้อมูลผู้ส่ง (จำลองตาม ER Diagram)
        'sender_info': {
          'user_id': 'sender_test_01',
          'name': 'สมหญิง ยืนยง',
          'phone_number': '0812345678',
        },

        // ข้อมูลผู้รับ (จำลองตาม ER Diagram)
        'receiver_name': 'สมศักดิ์ รักเรียน',
        'receiver_phone': '0898765432',

        // ที่อยู่ต้นทาง-ปลายทาง (ข้อมูล Denormalized)
        'pickup_address_full':
            'คณะวิทยาการสารสนเทศ มหาวิทยาลัยมหาสารคาม ต.ขามเรียง อ.กันทรวิชัย จ.มหาสารคาม 44150',
        'delivery_address_full':
            'คณะวิทยาศาสตร์ มหาวิทยาลัยมหาสารคาม ต.ขามเรียง อ.กันทรวิชัย จ.มหาสารคาม 44150',
        // (Optional) พิกัด GPS
        'pickup_location': const GeoPoint(16.2480, 103.2497),
        'delivery_location': const GeoPoint(16.2467, 103.2508),
        // Field อื่นๆ ที่อาจจำเป็น (ปล่อยว่างไว้ก่อนได้)
        'rider_id': null,
        'delivery_image_url': null,
      };

      // เพิ่มข้อมูลลงใน collection 'deliveries'
      await _db.collection('deliveries').add(newJobData);
      print('สร้างงานจำลองสำเร็จ!');
    } catch (e) {
      print('🔥 เกิดข้อผิดพลาดในการสร้างงานจำลอง: $e');
    }
  }

  Stream<DocumentSnapshot> getDeliveryStream(String deliveryId) {
    return _db.collection('deliveries').doc(deliveryId).snapshots();
  }

  Future<String?> uploadImageToCloudinary(File imageFile) async {
    try {
      final tempResult = FilePickerResult([
        PlatformFile(
          name: imageFile.path.split('/').last,
          path: imageFile.path,
          size: await imageFile.length(),
        ),
      ]);
      return await uploadTocloud(tempResult);
    } catch (e) {
      print('🔥 เกิดข้อผิดพลาดในการอัปโหลดไป Cloudinary: $e');
      return null;
    }
  }

  

  Future<String> confirmPickupOrDelivery({
    required String deliveryId,
    required String expectedStatus,
    required String newStatus,
    required GeoPoint targetLocation,
    required File imageFile,
    required String imageFieldName,
  }) async {
    try {
      final doc = await _db.collection('deliveries').doc(deliveryId).get();
      if (!doc.exists || doc.data()?['status'] != expectedStatus) {
        return "สถานะของงานไม่ถูกต้อง อาจมีบางอย่างผิดพลาด";
      }
      // 3.2 ตรวจสอบระยะทาง (ตามโจทย์: ไม่เกิน 20 เมตร)
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        targetLocation.latitude,
        targetLocation.longitude,
      );

      print('ระยะห่างจากเป้าหมาย: ${distance.toStringAsFixed(2)} เมตร');

      if (distance > 50) {
        return "คุณอยู่ห่างจากเป้าหมายเกิน 20 เมตร (ระยะห่างปัจจุบัน: ${distance.toStringAsFixed(2)} เมตร)";
      }

      final imageUrl = await uploadImageToCloudinary(imageFile);
      if (imageUrl == null) {
        return "ไม่สามารถอัปโหลดรูปภาพได้ กรุณาลองใหม่อีกครั้ง";
      }

      await _db.collection('deliveries').doc(deliveryId).update({
        'status': newStatus,
        imageFieldName: imageUrl,
      });

      return "อัปเดตสถานะสำเร็จ!";
    } catch (e) {
      print('🔥 เกิดข้อผิดพลาดในการยืนยัน: $e');
      return "เกิดข้อผิดพลาด: $e";
    }
  }

  void startLocationUpdates() {
    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) {
          final riderId = _auth.currentUser!.uid;
          _db.collection('users').doc(riderId).update({
            'current_latitude': position.latitude,
            'current_longitude': position.longitude,
            'last_seen': FieldValue.serverTimestamp(),
          });
        });
  }

  void stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
    print('หยุดการติดตามตำแหน่ง');
  }
}
