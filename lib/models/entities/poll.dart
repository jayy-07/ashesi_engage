import 'package:cloud_firestore/cloud_firestore.dart';

class PollVote {
  final String optionId;
  final DateTime timestamp;

  const PollVote({
    required this.optionId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'optionId': optionId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory PollVote.fromMap(Map<String, dynamic> map) {
    final timestamp = map['timestamp'];
    return PollVote(
      optionId: map['optionId'] as String,
      timestamp: timestamp != null 
          ? (timestamp as Timestamp).toDate()
          : DateTime.now(), // Fallback to current time if timestamp is missing
    );
  }
}

class Poll {
  final String id;
  final String title;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<PollOption> options;
  final Map<String, PollVote> votes;
  final bool showRealTimeResults;
  final bool showResultsAfterEnd;
  final int finalResultsDuration;
  final bool isAllClasses;
  final List<String> classScopes;
  final bool isActive;
  final bool isReversible;

  const Poll({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    required this.options,
    required this.votes,
    required this.showRealTimeResults,
    required this.showResultsAfterEnd,
    required this.finalResultsDuration,
    required this.isAllClasses,
    required this.classScopes,
    required this.isActive,
    required this.isReversible,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'options': options.map((option) => option.toMap()).toList(),
      'votes': votes.map((key, value) => MapEntry(key, value.toMap())),
      'showRealTimeResults': showRealTimeResults,
      'showResultsAfterEnd': showResultsAfterEnd,
      'finalResultsDuration': finalResultsDuration,
      'isAllClasses': isAllClasses,
      'classScopes': classScopes,
      'isActive': isActive,
      'isReversible': isReversible,
    };
  }

  factory Poll.fromMap(Map<String, dynamic> map) {
    return Poll(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      createdBy: map['createdBy'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      expiresAt: (map['expiresAt'] as Timestamp).toDate(),
      options: (map['options'] as List<dynamic>)
          .map((option) => PollOption.fromMap(option as Map<String, dynamic>))
          .toList(),
      votes: (map['votes'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          PollVote.fromMap(value as Map<String, dynamic>),
        ),
      ),
      showRealTimeResults: map['showRealTimeResults'] as bool,
      showResultsAfterEnd: map['showResultsAfterEnd'] as bool,
      finalResultsDuration: map['finalResultsDuration'] as int,
      isAllClasses: map['isAllClasses'] as bool,
      classScopes: (map['classScopes'] as List<dynamic>).cast<String>(),
      isActive: map['isActive'] as bool,
      isReversible: map['isReversible'] as bool,
    );
  }

  factory Poll.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Poll.fromMap(data..['id'] = doc.id);
  }

  bool hasUserVoted(String userId) => votes.containsKey(userId);

  int getVotesForOption(String optionId) {
    return votes.values.where((vote) => vote.optionId == optionId).length;
  }

  bool get canShowResults {
    if (showRealTimeResults) return true;
    if (!showResultsAfterEnd) return false;
    return expiresAt.isBefore(DateTime.now());
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  int get totalVotes => votes.length;

  Poll copyWith({
    String? id,
    String? title,
    String? description,
    String? createdBy,
    DateTime? createdAt,
    DateTime? expiresAt,
    List<PollOption>? options,
    Map<String, PollVote>? votes,
    bool? showRealTimeResults,
    bool? showResultsAfterEnd,
    int? finalResultsDuration,
    bool? isAllClasses,
    List<String>? classScopes,
    bool? isActive,
    bool? isReversible,
  }) {
    return Poll(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      options: options ?? this.options,
      votes: votes ?? this.votes,
      showRealTimeResults: showRealTimeResults ?? this.showRealTimeResults,
      showResultsAfterEnd: showResultsAfterEnd ?? this.showResultsAfterEnd,
      finalResultsDuration: finalResultsDuration ?? this.finalResultsDuration,
      isAllClasses: isAllClasses ?? this.isAllClasses,
      classScopes: classScopes ?? this.classScopes,
      isActive: isActive ?? this.isActive,
      isReversible: isReversible ?? this.isReversible,
    );
  }
}

class PollOption {
  final String id;
  final String text;

  const PollOption({
    required this.id,
    required this.text,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
    };
  }

  factory PollOption.fromMap(Map<String, dynamic> map) {
    return PollOption(
      id: map['id'] as String,
      text: map['text'] as String,
    );
  }
}