import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class DiscussionPost {
  final String id;
  final String authorId;
  final String authorName;
  final String authorClass;
  final String authorAvatar;
  final dynamic content; // Store Quill Delta
  final String plainContent; // Store plain text version
  final DateTime datePosted;
  final int upvotes;
  final int downvotes;
  final int replyCount;
  final bool hasUserUpvoted;
  final bool hasUserDownvoted;
  final List<String> upvoterIds;
  final List<String> downvoterIds;
  final double? sentimentScore;
  final double? sentimentMagnitude;

  const DiscussionPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorClass,
    required this.authorAvatar,
    required this.content,
    required this.plainContent,
    required this.datePosted,
    this.upvotes = 0,
    this.downvotes = 0,
    this.replyCount = 0,
    this.hasUserUpvoted = false,
    this.hasUserDownvoted = false,
    this.upvoterIds = const [],
    this.downvoterIds = const [],
    this.sentimentScore,
    this.sentimentMagnitude,
  });

  String? get sentimentInterpretation {
    if (sentimentScore == null || sentimentMagnitude == null) return null;

    String sentiment;
    if (sentimentScore! >= 0.5) {
      sentiment = 'Very Positive';
    } else if (sentimentScore! > 0.1) {
      sentiment = 'Positive';
    } else if (sentimentScore! >= -0.1) {
      sentiment = 'Neutral';
    } else if (sentimentScore! >= -0.5) {
      sentiment = 'Negative';
    } else {
      sentiment = 'Very Negative';
    }

    String intensity;
    if (sentimentMagnitude! >= 2.0) {
      intensity = 'Strong';
    } else if (sentimentMagnitude! >= 1.0) {
      intensity = 'Moderate';
    } else {
      intensity = 'Mild';
    }

    return '$sentiment | $intensity';
  }

  // Helper method for voting functionality
  DiscussionPost copyWith({
    int? upvotes,
    int? downvotes,
    int? replyCount,
    bool? hasUserUpvoted,
    bool? hasUserDownvoted,
    List<String>? upvoterIds,
    List<String>? downvoterIds,
    double? sentimentScore,
    double? sentimentMagnitude,
  }) {
    return DiscussionPost(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorClass: authorClass,
      authorAvatar: authorAvatar,
      content: content,
      plainContent: plainContent,
      datePosted: datePosted,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      replyCount: replyCount ?? this.replyCount,
      hasUserUpvoted: hasUserUpvoted ?? this.hasUserUpvoted,
      hasUserDownvoted: hasUserDownvoted ?? this.hasUserDownvoted,
      upvoterIds: upvoterIds ?? this.upvoterIds,
      downvoterIds: downvoterIds ?? this.downvoterIds,
      sentimentScore: sentimentScore ?? this.sentimentScore,
      sentimentMagnitude: sentimentMagnitude ?? this.sentimentMagnitude,
    );
  }

  factory DiscussionPost.fromMap(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['datePosted'];
    
    return DiscussionPost(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorClass: data['authorClass'] ?? '',
      authorAvatar: data['authorAvatar'] ?? 'https://ui-avatars.com/api/?name=User',
      content: data['content'] ?? '', // This will store the Quill Delta
      plainContent: data['plainContent'] ?? '',
      datePosted: timestamp != null 
          ? (timestamp as Timestamp).toDate() 
          : DateTime.now(),
      upvotes: List<String>.from(data['upvoterIds'] ?? []).length,
      downvotes: List<String>.from(data['downvoterIds'] ?? []).length,
      replyCount: data['replyCount'] ?? 0,
      upvoterIds: List<String>.from(data['upvoterIds'] ?? []),
      downvoterIds: List<String>.from(data['downvoterIds'] ?? []),
      sentimentScore: data['sentimentScore']?.toDouble(),
      sentimentMagnitude: data['sentimentMagnitude']?.toDouble(),
    );
  }
}
