import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ashesi_engage/models/entities/article.dart';

void main() {
  group('Article Tests', () {
    late DateTime testDate;
    late Map<String, dynamic> testContent;

    setUp(() {
      testDate = DateTime(2024, 4, 28);
      testContent = {
        'ops': [
          {'insert': 'Test content'}
        ]
      };
    });

    test('should create Article with required fields', () {
      final article = Article(
        id: 'test-id',
        title: 'Test Article',
        authorId: 'author-1',
        authorName: 'Test Author',
        authorAvatar: 'https://example.com/avatar.jpg',
        content: testContent,
        plainContent: 'Test content',
        datePublished: testDate,
      );

      expect(article.id, 'test-id');
      expect(article.title, 'Test Article');
      expect(article.authorId, 'author-1');
      expect(article.authorName, 'Test Author');
      expect(article.authorAvatar, 'https://example.com/avatar.jpg');
      expect(article.content, testContent);
      expect(article.plainContent, 'Test content');
      expect(article.datePublished, testDate);
      expect(article.thumbnailUrl, isNull);
      expect(article.isFeatured, false);
      expect(article.isPublished, false);
      expect(article.lastModified, isNull);
    });

    test('should create Article with all fields', () {
      final article = Article(
        id: 'test-id',
        title: 'Test Article',
        authorId: 'author-1',
        authorName: 'Test Author',
        authorAvatar: 'https://example.com/avatar.jpg',
        content: testContent,
        plainContent: 'Test content',
        thumbnailUrl: 'https://example.com/thumbnail.jpg',
        datePublished: testDate,
        isFeatured: true,
        isPublished: true,
        lastModified: testDate,
      );

      expect(article.id, 'test-id');
      expect(article.title, 'Test Article');
      expect(article.authorId, 'author-1');
      expect(article.authorName, 'Test Author');
      expect(article.authorAvatar, 'https://example.com/avatar.jpg');
      expect(article.content, testContent);
      expect(article.plainContent, 'Test content');
      expect(article.thumbnailUrl, 'https://example.com/thumbnail.jpg');
      expect(article.datePublished, testDate);
      expect(article.isFeatured, true);
      expect(article.isPublished, true);
      expect(article.lastModified, testDate);
    });

    test('should convert Article to Map correctly', () {
      final article = Article(
        id: 'test-id',
        title: 'Test Article',
        authorId: 'author-1',
        authorName: 'Test Author',
        authorAvatar: 'https://example.com/avatar.jpg',
        content: testContent,
        plainContent: 'Test content',
        thumbnailUrl: 'https://example.com/thumbnail.jpg',
        datePublished: testDate,
        isFeatured: true,
        isPublished: true,
        lastModified: testDate,
      );

      final map = article.toMap();

      expect(map['id'], 'test-id');
      expect(map['title'], 'Test Article');
      expect(map['authorId'], 'author-1');
      expect(map['authorName'], 'Test Author');
      expect(map['authorAvatar'], 'https://example.com/avatar.jpg');
      expect(map['content'], testContent['ops']);
      expect(map['plainContent'], 'Test content');
      expect(map['thumbnailUrl'], 'https://example.com/thumbnail.jpg');
      expect(map['datePublished'], isA<Timestamp>());
      expect(map['isFeatured'], true);
      expect(map['isPublished'], true);
      expect(map['lastModified'], isA<Timestamp>());
    });

    test('should create Article from Map correctly', () {
      final map = {
        'id': 'test-id',
        'title': 'Test Article',
        'authorId': 'author-1',
        'authorName': 'Test Author',
        'authorAvatar': 'https://example.com/avatar.jpg',
        'content': testContent['ops'],
        'plainContent': 'Test content',
        'thumbnailUrl': 'https://example.com/thumbnail.jpg',
        'datePublished': Timestamp.fromDate(testDate),
        'isFeatured': true,
        'isPublished': true,
        'lastModified': Timestamp.fromDate(testDate),
      };

      final article = Article.fromMap(map);

      expect(article.id, 'test-id');
      expect(article.title, 'Test Article');
      expect(article.authorId, 'author-1');
      expect(article.authorName, 'Test Author');
      expect(article.authorAvatar, 'https://example.com/avatar.jpg');
      expect(article.content['ops'], testContent['ops']);
      expect(article.plainContent, 'Test content');
      expect(article.thumbnailUrl, 'https://example.com/thumbnail.jpg');
      expect(article.datePublished, testDate);
      expect(article.isFeatured, true);
      expect(article.isPublished, true);
      expect(article.lastModified, testDate);
    });

    test('should create Article from Firestore document', () {
      final data = {
        'title': 'Test Article',
        'authorId': 'author-1',
        'authorName': 'Test Author',
        'authorAvatar': 'https://example.com/avatar.jpg',
        'content': testContent['ops'],
        'plainContent': 'Test content',
        'thumbnailUrl': 'https://example.com/thumbnail.jpg',
        'datePublished': Timestamp.fromDate(testDate),
        'isFeatured': true,
        'isPublished': true,
        'lastModified': Timestamp.fromDate(testDate),
      };

      final doc = FakeDocumentSnapshot(data);
      final article = Article.fromFirestore(doc);

      expect(article.id, 'test-id');
      expect(article.title, 'Test Article');
      expect(article.authorId, 'author-1');
      expect(article.authorName, 'Test Author');
      expect(article.authorAvatar, 'https://example.com/avatar.jpg');
      expect(article.content['ops'], testContent['ops']);
      expect(article.plainContent, 'Test content');
      expect(article.thumbnailUrl, 'https://example.com/thumbnail.jpg');
      expect(article.datePublished, testDate);
      expect(article.isFeatured, true);
      expect(article.isPublished, true);
      expect(article.lastModified, testDate);
    });

    test('should create copy with updated fields', () {
      final article = Article(
        id: 'test-id',
        title: 'Test Article',
        authorId: 'author-1',
        authorName: 'Test Author',
        authorAvatar: 'https://example.com/avatar.jpg',
        content: testContent,
        plainContent: 'Test content',
        datePublished: testDate,
      );

      final updatedArticle = article.copyWith(
        title: 'Updated Title',
        isPublished: true,
        isFeatured: true,
      );

      expect(updatedArticle.id, article.id);
      expect(updatedArticle.title, 'Updated Title');
      expect(updatedArticle.authorId, article.authorId);
      expect(updatedArticle.content, article.content);
      expect(updatedArticle.isPublished, true);
      expect(updatedArticle.isFeatured, true);
    });
  });
}

class FakeDocumentSnapshot implements DocumentSnapshot {
  final Map<String, dynamic> _data;

  FakeDocumentSnapshot(this._data);

  @override
  Map<String, dynamic> data() => _data;

  @override
  String get id => 'test-id';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
} 