import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../entities/article.dart';
import '../../services/notification_service.dart';

class ArticleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final NotificationService _notificationService = NotificationService();
  final String _collection = 'articles';

  // Create a new article
  Future<String> createArticle(Article article) async {
    final docRef = _firestore.collection(_collection).doc();
    await docRef.set(article.copyWith(id: docRef.id).toMap());
    return docRef.id;
  }

  // Get a single article by ID
  Future<Article?> getArticle(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) return null;
    return Article.fromMap(doc.data()!..['id'] = doc.id);
  }

  // Get all articles
  Future<List<Article>> getAllArticles() async {
    final snapshot = await _firestore.collection(_collection)
      .orderBy('datePublished', descending: true)
      .get();
    
    return snapshot.docs.map((doc) => 
      Article.fromMap(doc.data()..['id'] = doc.id)
    ).toList();
  }

  // Get featured articles
  Future<List<Article>> getFeaturedArticles() async {
    final snapshot = await _firestore.collection(_collection)
      .where('isFeatured', isEqualTo: true)
      .where('isPublished', isEqualTo: true)
      .orderBy('datePublished', descending: true)
      .get();
    
    return snapshot.docs.map((doc) => 
      Article.fromMap(doc.data()..['id'] = doc.id)
    ).toList();
  }

  // Update a article
  Future<void> updateArticle(Article article) async {
    await _firestore.collection(_collection)
      .doc(article.id)
      .update(article.copyWith(
        lastModified: DateTime.now()
      ).toMap());
  }

  // Delete a article
  Future<void> deleteArticle(String id) async {
    final article = await getArticle(id);
    if (article?.thumbnailUrl != null) {
      try {
        await _storage.refFromURL(article!.thumbnailUrl!).delete();
      } catch (e) {
        // Ignore errors if image doesn't exist
      }
    }
    await _firestore.collection(_collection).doc(id).delete();
  }

  // Upload an image and get its URL
  Future<String> uploadImage(File file, String articleId) async {
    final ref = _storage.ref('articles/$articleId/${DateTime.now().millisecondsSinceEpoch}');
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  // Upload a web image (Uint8List) and get its URL - for web platform
  Future<String> uploadWebImage(Uint8List bytes, String articleId) async {
    final ref = _storage.ref('articles/$articleId/${DateTime.now().millisecondsSinceEpoch}');
    final uploadTask = await ref.putData(bytes);
    return await uploadTask.ref.getDownloadURL();
  }

  // Toggle featured status
  Future<void> toggleFeatured(String id, bool isFeatured) async {
    await _firestore.collection(_collection)
      .doc(id)
      .update({
        'isFeatured': isFeatured,
        'lastModified': FieldValue.serverTimestamp(),
      });
  }

  // Toggle published status
  Future<void> togglePublished(String id, bool isPublished) async {
    await _firestore.collection(_collection)
      .doc(id)
      .update({
        'isPublished': isPublished,
        'lastModified': FieldValue.serverTimestamp(),
        'datePublished': isPublished ? FieldValue.serverTimestamp() : null,
      });
    
    // If article is being published, send notifications
    if (isPublished) {
      await _sendArticleNotifications(id);
    }
  }
  
  // Send notifications for a published article
  Future<void> _sendArticleNotifications(String id) async {
    try {
      // Get the article details
      final article = await getArticle(id);
      if (article == null) return;
      
      // Check notification settings
      final shouldSendNotification = true; // This can be obtained from preferences if needed
      
      if (shouldSendNotification) {
        // Call the Cloud Function to send the notification
        await _functions.httpsCallable('sendArticleNotification').call({
          'articleId': id,
          'title': 'New Article Available',
          'body': '"${article.title}" has been published. Check it out!',
          'type': 'article',
        });
        
        debugPrint('Article notification sent for ${article.title}');
      }
    } catch (e) {
      debugPrint('Error sending article notification: $e');
    }
  }

  // Stream of articles for real-time updates
  Stream<List<Article>> streamArticles() {
    return _firestore.collection(_collection)
      .orderBy('datePublished', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => Article.fromMap(doc.data()..['id'] = doc.id))
        .toList());
  }
}