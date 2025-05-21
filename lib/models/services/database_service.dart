import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/models/app_user.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<AppUser>> getAllUsers() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs.map((doc) => AppUser.fromMap({
      'uid': doc.id,
      ...doc.data(),
    })).toList();
  }

  Future<void> banUser(String uid, {DateTime? until, String? reason}) async {
    await _db.collection('users').doc(uid).update({
      'isBanned': true,
      'bannedUntil': until?.toIso8601String(),
      'banReason': reason,
    });
  }

  Future<void> unbanUser(String uid) async {
    await _db.collection('users').doc(uid).update({
      'isBanned': false,
      'bannedUntil': null,
      'banReason': null,
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  Future<void> deleteUser(String uid) async {
    await _db.collection('users').doc(uid).update({
      'isDeleted': true,
      'deletedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> permanentlyDeleteUser(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }
} 