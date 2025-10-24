// lib/model/address.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
@immutable
class UserAddress {
  final String id;
  final String name; // เช่น "บ้าน", "ที่ทำงาน"
  final String details; // เช่น "ตึก A, ห้อง 101"
  final GeoPoint location; // พิกัด GPS

  
  UserAddress({
    required this.id,
    required this.name,
    required this.details,
    required this.location,
  });

  // แปลงจาก Firestore (DocumentSnapshot) มาเป็น Object
  factory UserAddress.fromSnap(DocumentSnapshot snap) {
    var data = snap.data() as Map<String, dynamic>;
    return UserAddress(
      id: snap.id,
      name: data['name'] ?? '',
      details: data['details'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
    );
  }

  // แปลงจาก Object ไปเป็น Map เพื่อบันทึกลง Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'details': details,
      'location': location,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserAddress && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
  
}



