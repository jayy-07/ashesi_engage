import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ashesi_engage/models/entities/discussion_post.dart';

void main() {
  group('DiscussionPost Tests', () {
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

    test('should create DiscussionPost with required fields', () {
      final post = DiscussionPost(
        id: 'test-id',
        authorId: 'author-1',
        authorName: 'Test Author',
        authorClass: '2024',
        authorAvatar: 'https://example.com/avatar.jpg',
        content: testContent,
        plainContent: 'Test content',
        datePosted: testDate,
      );

      expect(post.id, 'test-id');
      expect(post.authorId, 'author-1');
      expect(post.authorName, 'Test Author');
      expect(post.authorClass, '2024');
      expect(post.authorAvatar, 'https://example.com/avatar.jpg');
      expect(post.content, testContent);
      expect(post.plainContent, 'Test content');
      expect(post.datePosted, testDate);
      expect(post.upvotes, 0);
      expect(post.downvotes, 0);
      expect(post.replyCount, 0);
      expect(post.hasUserUpvoted, false);
      expect(post.hasUserDownvoted, false);
      expect(post.upvoterIds, isEmpty);
      expect(post.downvoterIds, isEmpty);
    });

    test('should create DiscussionPost with all fields', () {
      final post = DiscussionPost(
        id: 'test-id',
        authorId: 'author-1',
        authorName: 'Test Author',
        authorClass: '2024',
        authorAvatar: 'https://example.com/avatar.jpg',
        content: testContent,
        plainContent: 'Test content',
        datePosted: testDate,
        upvotes: 5,
        downvotes: 2,
        replyCount: 3,
        hasUserUpvoted: true,
        hasUserDownvoted: false,
        upvoterIds: ['user1', 'user2', 'user3', 'user4', 'user5'],
        downvoterIds: ['user6', 'user7'],
        sentimentScore: 0.8,
        sentimentMagnitude: 1.5,
      );

      expect(post.id, 'test-id');
      expect(post.authorId, 'author-1');
      expect(post.authorName, 'Test Author');
      expect(post.authorClass, '2024');
      expect(post.authorAvatar, 'https://example.com/avatar.jpg');
      expect(post.content, testContent);
      expect(post.plainContent, 'Test content');
      expect(post.datePosted, testDate);
      expect(post.upvotes, 5);
      expect(post.downvotes, 2);
      expect(post.replyCount, 3);
      expect(post.hasUserUpvoted, true);
      expect(post.hasUserDownvoted, false);
      expect(post.upvoterIds, ['user1', 'user2', 'user3', 'user4', 'user5']);
      expect(post.downvoterIds, ['user6', 'user7']);
      expect(post.sentimentScore, 0.8);
      expect(post.sentimentMagnitude, 1.5);
    });

    test('should interpret sentiment correctly', () {
      final posts = [
        DiscussionPost(
          id: 'test-id-1',
          authorId: 'author-1',
          authorName: 'Test Author',
          authorClass: '2024',
          authorAvatar: 'https://example.com/avatar.jpg',
          content: testContent,
          plainContent: 'Test content',
          datePosted: testDate,
          sentimentScore: 0.8,
          sentimentMagnitude: 2.5,
        ),
        DiscussionPost(
          id: 'test-id-2',
          authorId: 'author-1',
          authorName: 'Test Author',
          authorClass: '2024',
          authorAvatar: 'https://example.com/avatar.jpg',
          content: testContent,
          plainContent: 'Test content',
          datePosted: testDate,
          sentimentScore: -0.3,
          sentimentMagnitude: 1.2,
        ),
        DiscussionPost(
          id: 'test-id-3',
          authorId: 'author-1',
          authorName: 'Test Author',
          authorClass: '2024',
          authorAvatar: 'https://example.com/avatar.jpg',
          content: testContent,
          plainContent: 'Test content',
          datePosted: testDate,
          sentimentScore: 0.0,
          sentimentMagnitude: 0.5,
        ),
      ];

      expect(posts[0].sentimentInterpretation, 'Very Positive | Strong');
      expect(posts[1].sentimentInterpretation, 'Negative | Moderate');
      expect(posts[2].sentimentInterpretation, 'Neutral | Mild');
    });

    test('should create DiscussionPost from Map', () {
      final map = {
        'id': 'test-id',
        'authorId': 'author-1',
        'authorName': 'Test Author',
        'authorClass': '2024',
        'authorAvatar': 'https://example.com/avatar.jpg',
        'content': testContent,
        'plainContent': 'Test content',
        'datePosted': Timestamp.fromDate(testDate),
        'upvoterIds': ['user1', 'user2'],
        'downvoterIds': ['user3'],
        'replyCount': 3,
        'sentimentScore': 0.8,
        'sentimentMagnitude': 1.5,
      };

      final doc = FakeDocumentSnapshot(map);
      final post = DiscussionPost.fromMap(doc);

      expect(post.id, 'test-id');
      expect(post.authorId, 'author-1');
      expect(post.authorName, 'Test Author');
      expect(post.authorClass, '2024');
      expect(post.authorAvatar, 'https://example.com/avatar.jpg');
      expect(post.content, testContent);
      expect(post.plainContent, 'Test content');
      expect(post.datePosted, testDate);
      expect(post.upvoterIds, ['user1', 'user2']);
      expect(post.downvoterIds, ['user3']);
      expect(post.replyCount, 3);
      expect(post.sentimentScore, 0.8);
      expect(post.sentimentMagnitude, 1.5);
    });
  });
}

class FakeDocumentSnapshot implements DocumentSnapshot {
  final Map<String, dynamic> _data;
  final String _id;

  FakeDocumentSnapshot(this._data) : _id = _data['id'] as String;

  @override
  Map<String, dynamic> data() => _data;

  @override
  String get id => _id;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
} 