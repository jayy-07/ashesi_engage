import 'package:cloud_firestore/cloud_firestore.dart';

enum ProposalTier {
  minor(100, 'Minor Change'),
  moderate(200, 'Moderate Change'),
  major(500, 'Major Change');

  final int requiredSignatures;
  final String label;
  const ProposalTier(this.requiredSignatures, this.label);
}

class StudentProposal {
  final String id;
  final String authorId;
  final String authorName;
  final String authorClass;
  final String authorAvatar;
  final String title;
  final Map<String, dynamic> content; // Store as Quill Delta
  final String plainContent; // For search and preview
  final DateTime datePosted;
  final int currentSignatures;
  final int requiredSignatures;
  final bool isEndorsedByUser;
  final List<String> endorserIds;
  final ProposalTier tier;
  final bool? deleted; // Add deleted flag
  final DateTime? deletedAt; // Add deletion timestamp
  final Map<String, dynamic>? answer; // Store as Quill Delta
  final String? plainAnswer; // For search and preview
  final DateTime? answeredAt;
  final String? answeredBy;
  final String? answeredByName;
  final double? sentimentScore;
  final double? sentimentMagnitude;

  const StudentProposal({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorClass,
    required this.authorAvatar,
    required this.title,
    required this.content,
    required this.plainContent,
    required this.datePosted,
    required this.currentSignatures,
    required this.requiredSignatures,
    required this.isEndorsedByUser,
    required this.endorserIds,
    required this.tier,
    this.deleted,
    this.deletedAt,
    this.answer,
    this.plainAnswer,
    this.answeredAt,
    this.answeredBy,
    this.answeredByName,
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

  // Create from Firebase document
  factory StudentProposal.fromMap(Map<String, dynamic> map) {
    final content = map['content'];
    final answer = map['answer'];
    final timestamp = map['datePosted'];
    final deletedTimestamp = map['deletedAt'];
    final answeredTimestamp = map['answeredAt'];
    
    return StudentProposal(
      id: map['id'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorClass: map['authorClass'] ?? '',
      authorAvatar: map['authorAvatar'] ?? 'https://ui-avatars.com/api/?name=User',
      title: map['title'] ?? '',
      content: {
        'ops': content is List ? content : []
      },
      plainContent: map['plainContent'] ?? '',
      datePosted: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      currentSignatures: map['currentSignatures'] ?? 0,
      requiredSignatures: map['requiredSignatures'] ?? 100,
      isEndorsedByUser: map['isEndorsedByUser'] ?? false,
      endorserIds: List<String>.from(map['endorserIds'] ?? []),
      tier: ProposalTier.values.firstWhere(
        (t) => t.name == map['tier'],
        orElse: () => ProposalTier.minor
      ),
      deleted: map['deleted'],
      deletedAt: deletedTimestamp is Timestamp ? deletedTimestamp.toDate() : null,
      answer: answer is Map ? Map<String, dynamic>.from(answer) : null,
      plainAnswer: map['plainAnswer'],
      answeredAt: answeredTimestamp is Timestamp ? answeredTimestamp.toDate() : null,
      answeredBy: map['answeredBy'],
      answeredByName: map['answeredByName'],
      sentimentScore: map['sentimentScore']?.toDouble(),
      sentimentMagnitude: map['sentimentMagnitude']?.toDouble(),
    );
  }

  // Convert to Firebase document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorClass': authorClass,
      'authorAvatar': authorAvatar,
      'title': title,
      'content': content,
      'plainContent': plainContent,
      'datePosted': Timestamp.fromDate(datePosted),
      'currentSignatures': currentSignatures,
      'requiredSignatures': requiredSignatures,
      'isEndorsedByUser': isEndorsedByUser,
      'endorserIds': endorserIds,
      'tier': tier.name,
      'answer': answer,
      'plainAnswer': plainAnswer,
      'answeredAt': answeredAt != null ? Timestamp.fromDate(answeredAt!) : null,
      'answeredBy': answeredBy,
      'answeredByName': answeredByName,
      'sentimentScore': sentimentScore,
      'sentimentMagnitude': sentimentMagnitude,
    };
  }

  bool hasUserEndorsed(String userId) => endorserIds.contains(userId);
  int get remainingSignatures => requiredSignatures - currentSignatures;
  double get progressPercentage => currentSignatures / requiredSignatures;
  bool get isAnswered => answeredAt != null;

  StudentProposal copyWith({
    bool? isEndorsedByUser,
    int? currentSignatures,
    Map<String, dynamic>? answer,
    String? plainAnswer,
    DateTime? answeredAt,
    String? answeredBy,
    String? answeredByName,
    double? sentimentScore,
    double? sentimentMagnitude,
  }) {
    return StudentProposal(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorClass: authorClass,
      authorAvatar: authorAvatar,
      title: title,
      content: content,
      plainContent: plainContent,
      datePosted: datePosted,
      currentSignatures: currentSignatures ?? this.currentSignatures,
      requiredSignatures: requiredSignatures,
      isEndorsedByUser: isEndorsedByUser ?? this.isEndorsedByUser,
      endorserIds: endorserIds,
      tier: tier,
      deleted: deleted,
      deletedAt: deletedAt,
      answer: answer ?? this.answer,
      plainAnswer: plainAnswer ?? this.plainAnswer,
      answeredAt: answeredAt ?? this.answeredAt,
      answeredBy: answeredBy ?? this.answeredBy,
      answeredByName: answeredByName ?? this.answeredByName,
      sentimentScore: sentimentScore ?? this.sentimentScore,
      sentimentMagnitude: sentimentMagnitude ?? this.sentimentMagnitude,
    );
  }
}
