import 'package:cloud_firestore/cloud_firestore.dart';

class Article {
  final String id;
  final String title;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final Map<String, dynamic> content; // Store as Quill Delta
  final String plainContent; // For search and preview
  final String? thumbnailUrl; // Optional thumbnail image
  final DateTime datePublished;
  final bool isFeatured;
  final bool isPublished;
  final DateTime? lastModified;

  const Article({
    required this.id,
    required this.title,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.plainContent,
    this.thumbnailUrl,
    required this.datePublished,
    this.isFeatured = false,
    this.isPublished = false,
    this.lastModified,
  });

  // Create from Firebase document
  factory Article.fromMap(Map<String, dynamic> map) {
    final content = map['content'];
    final timestamp = map['datePublished'];
    final modifiedTimestamp = map['lastModified'];
    
    return Article(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorAvatar: map['authorAvatar'] ?? '',
      content: {
        'ops': content is List ? content : []
      },
      plainContent: map['plainContent'] ?? '',
      thumbnailUrl: map['thumbnailUrl'],
      datePublished: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      isFeatured: map['isFeatured'] ?? false,
      isPublished: map['isPublished'] ?? false,
      lastModified: modifiedTimestamp is Timestamp ? modifiedTimestamp.toDate() : null,
    );
  }

  // Create from Firestore document
  factory Article.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Article.fromMap({
      'id': doc.id,
      ...data,
    });
  }

  // Convert to Firebase document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'content': content['ops'],
      'plainContent': plainContent,
      'thumbnailUrl': thumbnailUrl,
      'datePublished': Timestamp.fromDate(datePublished),
      'isFeatured': isFeatured,
      'isPublished': isPublished,
      'lastModified': lastModified != null ? Timestamp.fromDate(lastModified!) : null,
    };
  }

  Article copyWith({
    String? id,
    String? title,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    Map<String, dynamic>? content,
    String? plainContent,
    String? thumbnailUrl,
    DateTime? datePublished,
    bool? isFeatured,
    bool? isPublished,
    DateTime? lastModified,
  }) {
    return Article(
      id: id ?? this.id,
      title: title ?? this.title,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      plainContent: plainContent ?? this.plainContent,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      datePublished: datePublished ?? this.datePublished,
      isFeatured: isFeatured ?? this.isFeatured,
      isPublished: isPublished ?? this.isPublished,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}