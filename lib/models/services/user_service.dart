import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/models/app_user.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _databaseService = DatabaseService();

  Future<AdminUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    return AdminUser(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: (data['role'] ?? 3).toInt(),
      classYear: data['classYear'] ?? '',
    );
  }

  Future<List<String>> getAvailableClasses() async {
    return _databaseService.getAvailableClasses();
  }
}

class AdminUser {
  final String id;
  final String name;
  final String email;
  final int role;
  final String classYear;

  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.classYear,
  });
}

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createOrUpdateUser(AppUser user) async {
    try {
      await _db.collection('users').doc(user.uid).set(
        user.toMap(),
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        // Handle offline case - the data will be synced when back online
        debugPrint('Offline: Changes will be synced when back online');
      } else {
        throw Exception('Failed to create/update user: $e');
      }
    } catch (e) {
      throw Exception('Failed to create/update user: $e');
    }
  }

  Future<AppUser?> getUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final user = AppUser.fromMap(doc.data()!);
        
        // Check if user is banned
        if (user.isBanned) {
          final now = DateTime.now();
          if (user.bannedUntil == null || user.bannedUntil!.isAfter(now)) {
            throw BannedUserException(user);
          } else {
            // Ban has expired, update user status
            await unbanUser(user.uid);
            // Return the unbanned user
            return user.copyWith(isBanned: false, bannedUntil: null, banReason: null);
          }
        }
        
        return user;
      }
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        // Try to get from cache
        final doc = await _db.collection('users').doc(uid).get(
          const GetOptions(source: Source.cache),
        );
        if (doc.exists) {
          final user = AppUser.fromMap(doc.data()!);
          
          // Check if user is banned (even in offline mode)
          if (user.isBanned) {
            final now = DateTime.now();
            if (user.bannedUntil == null || user.bannedUntil!.isAfter(now)) {
              throw BannedUserException(user);
            }
          }
          
          return user;
        }
      }
      throw Exception('Failed to get user: $e');
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  Future<Map<String, dynamic>> getUserData(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() ?? {};
      }
      return {};
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        // Try to get from cache
        final doc = await _db.collection('users').doc(uid).get(
          const GetOptions(source: Source.cache),
        );
        if (doc.exists) {
          return doc.data() ?? {};
        }
      }
      throw Exception('Failed to get user data: $e');
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  Future<void> updateUserLoginDate(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'loginDate': Timestamp.now(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        // Handle offline case - the data will be synced when back online
        debugPrint('Offline: Login date will be updated when back online');
      } else {
        throw Exception('Failed to update login date: $e');
      }
    } catch (e) {
      throw Exception('Failed to update login date: $e');
    }
  }

  Future<List<String>> getAvailableClasses() async {
    try {
      final doc = await _db.collection('settings').doc('classes').get();
      if (doc.exists) {
        return List<String>.from(doc.data()?['available_classes'] ?? []);
      }
      // Return default classes if none set
      return [
        'Class of 2024',
        'Class of 2025',
        'Class of 2026',
        'Class of 2027',
        'Class of 2028',
      ];
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        // Try to get from cache
        final doc = await _db.collection('settings').doc('classes').get(
          const GetOptions(source: Source.cache),
        );
        if (doc.exists) {
          return List<String>.from(doc.data()?['available_classes'] ?? []);
        }
        // Return default classes if offline and no cache
        return [
          'Class of 2024',
          'Class of 2025',
          'Class of 2026',
          'Class of 2027',
          'Class of 2028',
        ];
      }
      throw Exception('Failed to fetch available classes: $e');
    } catch (e) {
      throw Exception('Failed to fetch available classes: $e');
    }
  }

  Future<List<AppUser>> getAllUsers() async {
    try {
      final snapshot = await _db.collection('users').get();
      return snapshot.docs.map((doc) => AppUser.fromMap(doc.data())).toList();
    } catch (e) {
      throw Exception('Failed to get users: $e');
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      // Soft delete by setting deleted flag
      await _db.collection('users').doc(uid).update({
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  Future<void> permanentlyDeleteUser(String uid) async {
    try {
      // Add to banned emails collection to prevent future registration
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        await _db.collection('banned_emails').doc(userData['email']).set({
          'bannedAt': FieldValue.serverTimestamp(),
          'bannedBy': _auth.currentUser?.uid,
          'reason': 'Permanent deletion',
        });
      }
      
      // Delete the user document
      await _db.collection('users').doc(uid).delete();
    } catch (e) {
      throw Exception('Failed to permanently delete user: $e');
    }
  }

  Future<void> banUser(String uid, {DateTime? until, String? reason}) async {
    try {
      await _db.collection('users').doc(uid).update({
        'banned': true,
        'bannedAt': FieldValue.serverTimestamp(),
        'bannedUntil': until != null ? Timestamp.fromDate(until) : null,
        'banReason': reason,
        'bannedBy': _auth.currentUser?.uid,
      });
    } catch (e) {
      throw Exception('Failed to ban user: $e');
    }
  }

  Future<void> unbanUser(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'banned': false,
        'bannedAt': FieldValue.delete(),
        'bannedUntil': FieldValue.delete(),
        'bannedBy': FieldValue.delete(),
      });
    } catch (e) {
      throw Exception('Failed to unban user: $e');
    }
  }

  Future<bool> isUserBanned(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      if (!(data['banned'] ?? false)) return false;
      
      final bannedUntil = data['bannedUntil'] as Timestamp?;
      if (bannedUntil == null) return true; // Permanent ban
      
      return DateTime.now().isBefore(bannedUntil.toDate());
    } catch (e) {
      throw Exception('Failed to check user ban status: $e');
    }
  }

  Future<bool> isEmailBanned(String email) async {
    try {
      final doc = await _db.collection('banned_emails').doc(email).get();
      return doc.exists;
    } catch (e) {
      throw Exception('Failed to check email ban status: $e');
    }
  }
}
