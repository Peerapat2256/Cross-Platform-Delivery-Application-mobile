import 'package:cloud_firestore/cloud_firestore.dart';

class Delivery {
  final String deliveryId;
  final String senderId;
  final String receiverName;
  final String receiverPhone;
  final String pickupAddress;
  final String deliveryAddress;
  String status;
  String? riderId;
  final Timestamp createdAt;
  final String? pickupImageUrl;
  final GeoPoint pickupLocation; 
  final GeoPoint deliveryLocation;

  final String senderName;
  final String senderPhone;
  final String? itemName;
  final String? itemDetails;

  Delivery({
    required this.deliveryId,
    required this.senderId,
    required this.receiverName,
    required this.receiverPhone,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.status,
    this.riderId,
    required this.createdAt,
    this.pickupImageUrl,
    required this.pickupLocation,
    required this.deliveryLocation,
    required this.senderName,
    required this.senderPhone,
    this.itemName,
    this.itemDetails,
  });

  factory Delivery.fromMap(DocumentSnapshot doc) {
    Map<String, dynamic> map = doc.data() as Map<String, dynamic>;
    return Delivery(
      deliveryId: doc.id,
      senderId: map['sender_id'] ?? '',
      receiverName: map['receiver_name'] ?? 'N/A',
      receiverPhone: map['receiver_phone'] ?? 'N/A',
      // หมายเหตุ: Firestore ของคุณควรมี field ที่เก็บที่อยู่เต็มๆ
      pickupAddress: map['pickup_address_full'] ?? 'ที่อยู่ต้นทางไม่ระบุ',
      deliveryAddress: map['delivery_address_full'] ?? 'ที่อยู่ปลายทางไม่ระบุ',
      status: map['status'] ?? 'unknown',
      riderId: map['rider_id'],
      createdAt: map['created_at'] ?? Timestamp.now(),
      pickupImageUrl: map['pickup_image_url'],
      pickupLocation:
          map['pickup_location'] ?? const GeoPoint(0, 0),
      deliveryLocation:
          map['delivery_location'] ?? const GeoPoint(0, 0),
          senderName: map['sender_name'] ?? 'ผู้ส่งไม่ระบุ',
      senderPhone: map['sender_phone'] ?? 'ไม่มีเบอร์',
      itemName: map['item_name'], // อาจเป็น null ได้
      itemDetails: map['item_details'], // อาจเป็น null ได้
    );
  }
}
