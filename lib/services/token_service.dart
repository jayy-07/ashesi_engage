import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class TokenService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveToken(String userId) async {
    // Skip token handling for web platform
    if (kIsWeb) {
      debugPrint('Skipping FCM token handling for web platform');
      return;
    }

    try {
      // Request permission first
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get the token
        final token = await _messaging.getToken();
        
        if (token != null) {
          // Save it to Firestore
          await _firestore
            .collection('user_tokens')
            .doc(userId)
            .set({
              'token': token,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        }
      }
    } catch (e) {
      debugPrint('Error saving token: $e');
    }
  }

  Future<void> deleteToken(String userId) async {
    // Skip token handling for web platform
    if (kIsWeb) {
      debugPrint('Skipping FCM token deletion for web platform');
      return;
    }

    try {
      await _firestore
        .collection('user_tokens')
        .doc(userId)
        .delete();
    } catch (e) {
      debugPrint('Error deleting token: $e');
    }
  }
}