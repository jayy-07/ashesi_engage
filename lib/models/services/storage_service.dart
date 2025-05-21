import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadProfileImage(String uid, File imageFile) async {
    try {
      // Validate file size
      final fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) { // 5MB limit
        throw Exception('Image size must be less than 5MB');
      }

      final ref = _storage.ref().child('profile_images/$uid.jpg');
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'userId': uid},
      );

      await ref.putFile(imageFile, metadata);
      final url = await ref.getDownloadURL();
      return url;
    } on FirebaseException catch (e) {
      debugPrint('Storage error: ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied to upload image. Please try again.');
      } else if (e.code == 'canceled') {
        throw Exception('Upload was cancelled. Please try again.');
      }
      throw Exception('Failed to upload image: ${e.message}');
    } catch (e) {
      debugPrint('Upload error: $e');
      throw Exception('Failed to upload image. Please try again.');
    }
  }
}
