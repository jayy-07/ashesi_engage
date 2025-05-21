import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@immutable
class DiscussionComment {
  // Core Data Properties (all final)
  final String id;
  final String? parentId;
  final String? threadParentId;  
  final String discussionId;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String authorClass;
  final String content;
  final DateTime datePosted;
  final List<String> upvoterIds;
  final List<String> downvoterIds;
  final int replyCount;
  final bool isExpanded;
  final int _level; // Private level storage
  final List<DiscussionComment> replies;
  final double? sentimentScore;
  final double? sentimentMagnitude;
  final bool isOptimistic; 
  
  // Derived properties
  int get upvotes => upvoterIds.length;
  int get downvotes => downvoterIds.length;
  int get score => upvotes - downvotes;
  bool get hasReplies => replyCount > 0;
  int get level => _level;

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

  bool hasUserUpvoted(String userId) => upvoterIds.contains(userId);
  bool hasUserDownvoted(String userId) => downvoterIds.contains(userId);

  const DiscussionComment({
    required this.id,
    this.parentId,
    this.threadParentId,  // Added this parameter
    required this.discussionId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.authorClass,
    required this.content,
    required this.datePosted,
    this.upvoterIds = const [],
    this.downvoterIds = const [],
    this.replyCount = 0,
    this.isExpanded = true,
    int level = 0,
    required this.replies,
    this.sentimentScore,
    this.sentimentMagnitude,
    this.isOptimistic = false, // Default to false
  }) : _level = level;

  factory DiscussionComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DiscussionComment(
      id: doc.id,
      parentId: data['parentId'],
      threadParentId: data['threadParentId'],  // Added this field
      discussionId: data['discussionId'],
      authorId: data['authorId'],
      authorName: data['authorName'],
      authorAvatar: data['authorAvatar'],
      authorClass: data['authorClass'],
      content: data['content'],
      datePosted: (data['datePosted'] as Timestamp).toDate(),
      upvoterIds: List<String>.from(data['upvoterIds'] ?? []),
      downvoterIds: List<String>.from(data['downvoterIds'] ?? []),
      replyCount: data['replyCount'] ?? 0,
      replies: [], // Assuming replies are not provided in the snapshot
      sentimentScore: data['sentimentScore']?.toDouble(),
      sentimentMagnitude: data['sentimentMagnitude']?.toDouble(),
      isOptimistic: false, // Firestore comments are never optimistic
    );
  }

  DiscussionComment copyWith({
    String? id,
    String? parentId,
    String? threadParentId,  // Added this parameter
    String? discussionId,
    String? authorId,
    String? authorName,
    String? authorClass,
    String? authorAvatar,
    String? content,
    DateTime? datePosted,
    List<String>? upvoterIds,
    List<String>? downvoterIds,
    int? replyCount,
    bool? isExpanded,
    int? level,
    List<DiscussionComment>? replies,
    double? sentimentScore,
    double? sentimentMagnitude,
    bool? isOptimistic,
  }) {
    return DiscussionComment(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      threadParentId: threadParentId ?? this.threadParentId,  // Added this field
      discussionId: discussionId ?? this.discussionId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorClass: authorClass ?? this.authorClass,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      datePosted: datePosted ?? this.datePosted,
      upvoterIds: upvoterIds ?? this.upvoterIds,
      downvoterIds: downvoterIds ?? this.downvoterIds,
      replyCount: replyCount ?? this.replyCount,
      isExpanded: isExpanded ?? this.isExpanded,
      level: level ?? _level,
      replies: replies ?? this.replies,
      sentimentScore: sentimentScore ?? this.sentimentScore,
      sentimentMagnitude: sentimentMagnitude ?? this.sentimentMagnitude,
      isOptimistic: isOptimistic ?? this.isOptimistic,
    );
  }

  // Helper to get total reply count (for UI)
  int getTotalReplyCount() {
    int count = replyCount;
    return count;
  }

  // Level calculation (never stored)
  DiscussionComment calculateLevel(int newLevel) {
    return copyWith(level: newLevel);
  }

  // Copy with for UI state changes
  DiscussionComment copyWithUIState({
    bool? isExpanded,
    int? level,
  }) {
    return DiscussionComment(
      id: id,
      parentId: parentId,
      discussionId: discussionId,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      authorClass: authorClass,
      content: content,
      datePosted: datePosted,
      upvoterIds: upvoterIds,
      downvoterIds: downvoterIds,
      isExpanded: isExpanded ?? this.isExpanded,
      level: level ?? _level,
      replyCount: replyCount,
      replies: replies,
      sentimentScore: sentimentScore,
      sentimentMagnitude: sentimentMagnitude,
      isOptimistic: isOptimistic,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'parentId': parentId,
      'threadParentId': threadParentId,  // Added this field
      'discussionId': discussionId,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'authorClass': authorClass,
      'content': content,
      'datePosted': Timestamp.fromDate(datePosted),
      'upvotes': upvotes,
      'downvotes': downvotes,
      'upvoterIds': upvoterIds,
      'downvoterIds': downvoterIds,
      'sentimentScore': sentimentScore,
      'sentimentMagnitude': sentimentMagnitude,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscussionComment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  // Add this method to convert Firestore data to DiscussionComment
  factory DiscussionComment.fromMap(String id, Map<String, dynamic> map) {
    return DiscussionComment(
      id: id,
      parentId: map['parentId'],
      threadParentId: map['threadParentId'],  // Added this field
      discussionId: map['discussionId'],
      authorId: map['authorId'],
      authorName: map['authorName'],
      authorClass: map['authorClass'],
      authorAvatar: map['authorAvatar'],
      content: map['content'],
      datePosted: (map['datePosted'] as Timestamp).toDate(),
      upvoterIds: List<String>.from(map['upvoterIds'] ?? []),
      downvoterIds: List<String>.from(map['downvoterIds'] ?? []),
      replyCount: map['replyCount'] ?? 0,
      isExpanded: false, // Changed from true to false for initial state
      level: 0, // Calculated later
      replies: [], // Assuming replies are not provided in the map
      sentimentScore: map['sentimentScore']?.toDouble(),
      sentimentMagnitude: map['sentimentMagnitude']?.toDouble(),
      isOptimistic: false, // Changed from true to false for initial state
    );
  }

  // Add optimistic vote update methods
  DiscussionComment updateVotes({
    required List<String> newUpvoterIds,
    required List<String> newDownvoterIds,
  }) {
    return copyWith(
      upvoterIds: newUpvoterIds,
      downvoterIds: newDownvoterIds,
    );
  }

  // Helper method to simulate a vote change
  DiscussionComment simulateVote(String userId, bool isUpvote) {
    final newUpvoterIds = List<String>.from(upvoterIds);
    final newDownvoterIds = List<String>.from(downvoterIds);

    // Remove existing votes
    newUpvoterIds.remove(userId);
    newDownvoterIds.remove(userId);

    // Add new vote
    if (isUpvote) {
      newUpvoterIds.add(userId);
    } else {
      newDownvoterIds.add(userId);
    }

    return updateVotes(
      newUpvoterIds: newUpvoterIds,
      newDownvoterIds: newDownvoterIds,
    );
  }
}
