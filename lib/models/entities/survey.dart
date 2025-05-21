import 'package:cloud_firestore/cloud_firestore.dart';

class Survey {
  final String id;
  final String title;
  final String description;
  final String surveyLink;
  final String imageUrl;
  final String createdBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isAllClasses;
  final List<String> classScopes;
  final bool isCompleted;
  final String category;
  final String organizer;

  Survey({
    required this.id,
    required this.title,
    required this.description,
    required this.surveyLink,
    required this.imageUrl,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    required this.isAllClasses,
    required this.classScopes,
    this.isCompleted = false,
    required this.category,
    required this.organizer,
  });

  factory Survey.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Survey(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      surveyLink: data['surveyLink'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      isAllClasses: data['isAllClasses'] ?? false,
      classScopes: List<String>.from(data['classScopes'] ?? []),
      isCompleted: data['isCompleted'] ?? false,
      category: data['category'] ?? '',
      organizer: data['organizer'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'surveyLink': surveyLink,
      'imageUrl': imageUrl,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isAllClasses': isAllClasses,
      'classScopes': classScopes,
      'isCompleted': isCompleted,
      'category': category,
      'organizer': organizer,
    };
  }

  Survey copyWith({
    String? id,
    String? title,
    String? description,
    String? surveyLink,
    String? imageUrl,
    String? createdBy,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isAllClasses,
    List<String>? classScopes,
    bool? isCompleted,
    String? category,
    String? organizer,
  }) {
    return Survey(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      surveyLink: surveyLink ?? this.surveyLink,
      imageUrl: imageUrl ?? this.imageUrl,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isAllClasses: isAllClasses ?? this.isAllClasses,
      classScopes: classScopes ?? this.classScopes,
      isCompleted: isCompleted ?? this.isCompleted,
      category: category ?? this.category,
      organizer: organizer ?? this.organizer,
    );
  }
}