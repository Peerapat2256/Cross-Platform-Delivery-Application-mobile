import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DbService {
  User? get user => FirebaseAuth.instance.currentUser;

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
}
