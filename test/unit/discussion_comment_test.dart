import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ashesi_engage/models/entities/discussion_comment.dart';

void main() {
  group('DiscussionComment Tests', () {
    late DateTime testDate;

    setUp(() {
      testDate = DateTime(2024, 4, 28);
    });

    test('should create DiscussionComment with required fields', () {
      final comment = DiscussionComment(
        id: 'test-id',
        discussionId: 'discussion-1',
        authorId: 'author-1',
        authorName: 'Test Author',
        authorAvatar: 'https://example.com/avatar.jpg',
        authorClass: '2024',
        content: 'Test comment',
        datePosted: testDate,
        replies: [],
      );

      expect(comment.id, 'test-id');
      expect(comment.discussionId, 'discussion-1');
      expect(comment.authorId, 'author-1');
      expect(comment.authorName, 'Test Author');
      expect(comment.authorAvatar, 'https://example.com/avatar.jpg');
      expect(comment.authorClass, '2024');
      expect(comment.content, 'Test comment');
      expect(comment.datePosted, testDate);
      expect(comment.upvoterIds, isEmpty);
      expect(comment.downvoterIds, isEmpty);
      expect(comment.replyCount, 0);
      expect(comment.isExpanded, true);
      expect(comment.level, 0);
      expect(comment.replies, isEmpty);
      expect(comment.isOptimistic, false);
    });

    test('should create DiscussionComment with all fields', () {
      final comment = DiscussionComment(
        id: 'test-id',
        parentId: 'parent-1',
        threadParentId: 'thread-1',
        discussionId: 'discussion-1',
        authorId: 'author-1',
        authorName: 'Test Author',
        authorAvatar: 'https://example.com/avatar.jpg',
        authorClass: '2024',
        content: 'Test comment',
        datePosted: testDate,
        upvoterIds: ['user1', 'user2'],
        downvoterIds: ['user3'],
        replyCount: 2,
        isExpanded: false,
        level: 1,
        replies: [],
        sentimentScore: 0.8,
        sentimentMagnitude: 1.5,
        isOptimistic: true,
      );

      expect(comment.id, 'test-id');
      expect(comment.parentId, 'parent-1');
      expect(comment.threadParentId, 'thread-1');
      expect(comment.discussionId, 'discussion-1');
      expect(comment.authorId, 'author-1');
      expect(comment.authorName, 'Test Author');
      expect(comment.authorAvatar, 'https://example.com/avatar.jpg');
      expect(comment.authorClass, '2024');
      expect(comment.content, 'Test comment');
      expect(comment.datePosted, testDate);
      expect(comment.upvoterIds, ['user1', 'user2']);
      expect(comment.downvoterIds, ['user3']);
      expect(comment.replyCount, 2);
      expect(comment.isExpanded, false);
      expect(comment.level, 1);
      expect(comment.replies, isEmpty);
      expect(comment.sentimentScore, 0.8);
      expect(comment.sentimentMagnitude, 1.5);
      expect(comment.isOptimistic, true);
    });

    test('should calculate derived properties correctly', () {
      final comment = DiscussionComment(
        id: 'test-id',
        discussionId: 'discussion-1',
        authorId: 'author-1',
        authorName: 'Test Author',
        authorAvatar: 'https://example.com/avatar.jpg',
        authorClass: '2024',
        content: 'Test comment',
        datePosted: testDate,
        upvoterIds: ['user1', 'user2'],
        downvoterIds: ['user3'],
        replyCount: 2,
        replies: [],
      );

      expect(comment.upvotes, 2);
      expect(comment.downvotes, 1);
      expect(comment.score, 1);
      expect(comment.hasReplies, true);
    });

    test('should check user votes correctly', () {
      final comment = DiscussionComment(
        id: 'test-id',
        discussionId: 'discussion-1',
        authorId: 'author-1',
        authorName: 'Test Author',
        authorAvatar: 'https://example.com/avatar.jpg',
        authorClass: '2024',
        content: 'Test comment',
        datePosted: testDate,
        upvoterIds: ['user1', 'user2'],
        downvoterIds: ['user3'],
        replyCount: 0,
        replies: [],
      );

      expect(comment.hasUserUpvoted('user1'), true);
      expect(comment.hasUserUpvoted('user3'), false);
      expect(comment.hasUserDownvoted('user3'), true);
      expect(comment.hasUserDownvoted('user1'), false);
    });

    test('should interpret sentiment correctly', () {
      final comments = [
        DiscussionComment(
          id: 'test-id-1',
          discussionId: 'discussion-1',
          authorId: 'author-1',
          authorName: 'Test Author',
          authorAvatar: 'https://example.com/avatar.jpg',
          authorClass: '2024',
          content: 'Test comment',
          datePosted: testDate,
          replies: [],
          sentimentScore: 0.8,
          sentimentMagnitude: 2.5,
        ),
        DiscussionComment(
          id: 'test-id-2',
          discussionId: 'discussion-1',
          authorId: 'author-1',
          authorName: 'Test Author',
          authorAvatar: 'https://example.com/avatar.jpg',
          authorClass: '2024',
          content: 'Test comment',
          datePosted: testDate,
          replies: [],
          sentimentScore: -0.3,
          sentimentMagnitude: 1.2,
        ),
      ];

      expect(comments[0].sentimentInterpretation, 'Very Positive | Strong');
      expect(comments[1].sentimentInterpretation, 'Negative | Moderate');
    });

    test('should create DiscussionComment from Firestore', () {
      final data = {
        'parentId': 'parent-1',
        'threadParentId': 'thread-1',
        'discussionId': 'discussion-1',
        'authorId': 'author-1',
        'authorName': 'Test Author',
        'authorAvatar': 'https://example.com/avatar.jpg',
        'authorClass': '2024',
        'content': 'Test comment',
        'datePosted': Timestamp.fromDate(testDate),
        'upvoterIds': ['user1', 'user2'],
        'downvoterIds': ['user3'],
        'replyCount': 2,
        'sentimentScore': 0.8,
        'sentimentMagnitude': 1.5,
      };

      final doc = FakeDocumentSnapshot(data);
      final comment = DiscussionComment.fromFirestore(doc);

      expect(comment.id, 'test-id');
      expect(comment.parentId, 'parent-1');
      expect(comment.threadParentId, 'thread-1');
      expect(comment.discussionId, 'discussion-1');
      expect(comment.authorId, 'author-1');
      expect(comment.authorName, 'Test Author');
      expect(comment.authorAvatar, 'https://example.com/avatar.jpg');
      expect(comment.authorClass, '2024');
      expect(comment.content, 'Test comment');
      expect(comment.datePosted, testDate);
      expect(comment.upvoterIds, ['user1', 'user2']);
      expect(comment.downvoterIds, ['user3']);
      expect(comment.replyCount, 2);
      expect(comment.sentimentScore, 0.8);
      expect(comment.sentimentMagnitude, 1.5);
    });

    test('should convert DiscussionComment to Map', () {
      final comment = DiscussionComment(
        id: 'test-id',
        parentId: 'parent-1',
        threadParentId: 'thread-1',
        discussionId: 'discussion-1',
        authorId: 'author-1',
        authorName: 'Test Author',
        authorAvatar: 'https://example.com/avatar.jpg',
        authorClass: '2024',
        content: 'Test comment',
        datePosted: testDate,
        upvoterIds: ['user1', 'user2'],
        downvoterIds: ['user3'],
        replyCount: 2,
        replies: [],
        sentimentScore: 0.8,
        sentimentMagnitude: 1.5,
      );

      final map = comment.toMap();

      expect(map['parentId'], 'parent-1');
      expect(map['threadParentId'], 'thread-1');
      expect(map['discussionId'], 'discussion-1');
      expect(map['authorId'], 'author-1');
      expect(map['authorName'], 'Test Author');
      expect(map['authorAvatar'], 'https://example.com/avatar.jpg');
      expect(map['authorClass'], '2024');
      expect(map['content'], 'Test comment');
      expect(map['datePosted'], isA<Timestamp>());
      expect(map['upvotes'], 2);
      expect(map['downvotes'], 1);
      expect(map['upvoterIds'], ['user1', 'user2']);
      expect(map['downvoterIds'], ['user3']);
      expect(map['sentimentScore'], 0.8);
      expect(map['sentimentMagnitude'], 1.5);
    });

    test('should simulate vote changes correctly', () {
      final comment = DiscussionComment(
        id: 'test-id',
        discussionId: 'discussion-1',
        authorId: 'author-1',
        authorName: 'Test Author',
        authorAvatar: 'https://example.com/avatar.jpg',
        authorClass: '2024',
        content: 'Test comment',
        datePosted: testDate,
        upvoterIds: ['user1'],
        downvoterIds: ['user2'],
        replyCount: 0,
        replies: [],
      );

      final upvotedComment = comment.simulateVote('user3', true);
      expect(upvotedComment.upvoterIds, ['user1', 'user3']);
      expect(upvotedComment.downvoterIds, ['user2']);

      final changedVoteComment = comment.simulateVote('user1', false);
      expect(changedVoteComment.upvoterIds, isEmpty);
      expect(changedVoteComment.downvoterIds, ['user2', 'user1']);
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