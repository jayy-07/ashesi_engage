import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/entities/article.dart';
import '../models/services/article_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ArticleViewModel extends ChangeNotifier {
  final ArticleService _service = ArticleService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  SharedPreferences? _prefs;
  
  List<Article> _articles = [];
  bool _isLoading = false;
  String? _error;

  ArticleViewModel() {
    _initializePrefs();
  }

  Future<void> _initializePrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Getters
  List<Article> get articles => _articles;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Article> get featuredArticles => 
    _articles.where((n) => n.isFeatured && n.isPublished).toList();
  List<Article> get publishedArticles =>
    _articles.where((n) => n.isPublished).toList();
  List<Article> get draftArticles =>
    _articles.where((n) => !n.isPublished).toList();

  // Load all articles
  Future<void> loadArticles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _articles = await _service.getAllArticles();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create a new article
  Future<String?> createArticle(Article article) async {
    try {
      final id = await _service.createArticle(article);
      await loadArticles(); // Refresh the list
      return id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Update an existing article
  Future<void> updateArticle(Article article) async {
    try {
      await _service.updateArticle(article);
      await loadArticles(); // Refresh the list
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Delete a article
  Future<void> deleteArticle(String id) async {
    try {
      await _service.deleteArticle(id);
      await loadArticles(); // Refresh the list
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Upload an image
  Future<String?> uploadImage(File file, String articleId) async {
    try {
      return await _service.uploadImage(file, articleId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Upload a web image (for Flutter Web)
  Future<String?> uploadWebImage(Uint8List bytes, String articleId) async {
    try {
      return await _service.uploadWebImage(bytes, articleId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Toggle featured status
  Future<void> toggleFeatured(String id, bool isFeatured) async {
    try {
      // Get the current article state
      final doc = await _firestore.collection('articles').doc(id).get();
      final isPublished = doc.data()?['isPublished'] ?? false;

      // Prevent featuring if article is not published
      if (isFeatured && !isPublished) {
        throw 'Article must be published before it can be featured';
      }

      await _service.toggleFeatured(id, isFeatured);
      await loadArticles(); // Refresh the list
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Toggle published status
  Future<void> togglePublished(String id, bool isPublished) async {
    try {
      final updateData = {
        'isPublished': isPublished,
        if (isPublished) 'datePublished': FieldValue.serverTimestamp(),
        // Automatically unfeature when unpublishing
        if (!isPublished) 'isFeatured': false,
      };

      await _firestore.collection('articles').doc(id).update(updateData);

      if (isPublished) {
        // Get the article data to include in the notification
        final articleDoc = await _firestore.collection('articles').doc(id).get();
        final article = Article.fromFirestore(articleDoc);

        // Check notification settings before sending
        final shouldNotify = _prefs?.getBool('notifyArticle') ?? true;
        if (shouldNotify) {
          // Call the Cloud Function to send the notification
          await _functions.httpsCallable('sendArticleNotification').call({
            'articleId': id,
            'title': 'New Article Available',
            'body': 'Check out the latest article: ${article.title}',
            'type': 'article',
          });
        }
      }

      await loadArticles();
    } catch (e) {
      debugPrint('Error toggling article published state: $e');
      rethrow;
    }
  }

  // Listen to article updates
  void startListening() {
    _service.streamArticles().listen(
      (articles) {
        _articles = articles;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      }
    );
  }
}