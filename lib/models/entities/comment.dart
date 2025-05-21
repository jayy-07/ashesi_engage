import 'package:flutter/foundation.dart';

@immutable
class Comment {
  final String id;
  final String proposalId;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String authorClass;
  final String content;
  final DateTime datePosted;
  final int upvotes;
  final int downvotes;
  final bool hasUserUpvoted;
  final bool hasUserDownvoted;
  final double? sentimentScore;
  final double? sentimentMagnitude;
  final bool isOptimistic;

  const Comment({
    required this.id,
    required this.proposalId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.authorClass,
    required this.content,
    required this.datePosted,
    this.upvotes = 0,
    this.downvotes = 0,
    this.hasUserUpvoted = false,
    this.hasUserDownvoted = false,
    this.sentimentScore,
    this.sentimentMagnitude,
    this.isOptimistic = false,
  });

  int get score => upvotes - downvotes;

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

  Comment copyWith({
    String? id,
    String? proposalId,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? authorClass,
    String? content,
    DateTime? datePosted,
    int? upvotes,
    int? downvotes,
    bool? hasUserUpvoted,
    bool? hasUserDownvoted,
    double? sentimentScore,
    double? sentimentMagnitude,
    bool? isOptimistic,
  }) {
    return Comment(
      id: id ?? this.id,
      proposalId: proposalId ?? this.proposalId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      authorClass: authorClass ?? this.authorClass,
      content: content ?? this.content,
      datePosted: datePosted ?? this.datePosted,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      hasUserUpvoted: hasUserUpvoted ?? this.hasUserUpvoted,
      hasUserDownvoted: hasUserDownvoted ?? this.hasUserDownvoted,
      sentimentScore: sentimentScore ?? this.sentimentScore,
      sentimentMagnitude: sentimentMagnitude ?? this.sentimentMagnitude,
      isOptimistic: isOptimistic ?? this.isOptimistic,
    );
  }
}
