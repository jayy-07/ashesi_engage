import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'sentiment_analysis_service.dart';

class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _sentimentService = SentimentAnalysisService();

  Future<String> createComment({
    required String proposalId,
    required String authorId,
    required String authorName,
    required String authorClass,
    required String authorAvatar,
    required String content,
  }) async {
    try {
      // Analyze sentiment
      Map<String, dynamic>? sentimentData;
      try {
        final response = await _sentimentService.analyzeSentiment(content);
        final documentSentiment = response['documentSentiment'];
        sentimentData = {
          'sentimentScore': documentSentiment['score'],
          'sentimentMagnitude': documentSentiment['magnitude'],
        };
      } catch (e) {
        if (kDebugMode) {
          print('Failed to analyze sentiment: $e');
        }
        // Continue without sentiment data
      }

      final commentId = _firestore.collection('proposals').doc(proposalId).collection('comments').doc().id;
      final comment = {
        'id': commentId,
        'proposalId': proposalId,
        'authorId': authorId,
        'authorName': authorName,
        'authorClass': authorClass,
        'authorAvatar': authorAvatar,
        'content': content,
        'datePosted': FieldValue.serverTimestamp(),
        'upvotes': 0,
        'downvotes': 0,
        'upvoterIds': [],
        'downvoterIds': [],
        if (sentimentData != null) ...sentimentData,
      };

      await _firestore
        .collection('proposals')
        .doc(proposalId)
        .collection('comments')
        .doc(commentId)
        .set(comment);

      // Update comment count in proposal
      await _firestore.collection('proposals').doc(proposalId).update({
        'commentCount': FieldValue.increment(1),
      });

      return commentId;
    } catch (e) {
      throw Exception('Failed to create comment: $e');
    }
  }

  // ... rest of the service methods ...
} 