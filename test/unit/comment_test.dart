import 'package:flutter_test/flutter_test.dart';
import 'package:ashesi_engage/models/entities/comment.dart';

void main() {
  group('Comment Tests', () {
    final testDate = DateTime(2024, 4, 28);

    test('should create Comment with required fields', () {
      final comment = Comment(
        id: 'test-id',
        proposalId: 'proposal-id',
        authorId: 'author-id',
        authorName: 'Test Author',
        authorAvatar: 'test-avatar.jpg',
        authorClass: '2024',
        content: 'Test comment',
        datePosted: testDate,
      );

      expect(comment.id, 'test-id');
      expect(comment.proposalId, 'proposal-id');
      expect(comment.authorId, 'author-id');
      expect(comment.authorName, 'Test Author');
      expect(comment.content, 'Test comment');
      expect(comment.upvotes, 0);
      expect(comment.downvotes, 0);
      expect(comment.score, 0);
      expect(comment.hasUserUpvoted, false);
      expect(comment.hasUserDownvoted, false);
      expect(comment.isOptimistic, false);
    });

    test('should calculate score correctly', () {
      final comment = Comment(
        id: 'test-id',
        proposalId: 'proposal-id',
        authorId: 'author-id',
        authorName: 'Test Author',
        authorAvatar: 'test-avatar.jpg',
        authorClass: '2024',
        content: 'Test comment',
        datePosted: testDate,
        upvotes: 10,
        downvotes: 3,
      );

      expect(comment.score, 7);
    });

    test('should interpret sentiment correctly', () {
      final comments = [
        Comment(
          id: 'test-1',
          proposalId: 'proposal-id',
          authorId: 'author-id',
          authorName: 'Test Author',
          authorAvatar: 'test-avatar.jpg',
          authorClass: '2024',
          content: 'Very positive comment',
          datePosted: testDate,
          sentimentScore: 0.8,
          sentimentMagnitude: 2.5,
        ),
        Comment(
          id: 'test-2',
          proposalId: 'proposal-id',
          authorId: 'author-id',
          authorName: 'Test Author',
          authorAvatar: 'test-avatar.jpg',
          authorClass: '2024',
          content: 'Negative comment',
          datePosted: testDate,
          sentimentScore: -0.3,
          sentimentMagnitude: 1.2,
        ),
      ];

      expect(comments[0].sentimentInterpretation, 'Very Positive | Strong');
      expect(comments[1].sentimentInterpretation, 'Negative | Moderate');
    });

    test('should create copy with updated fields', () {
      final original = Comment(
        id: 'test-id',
        proposalId: 'proposal-id',
        authorId: 'author-id',
        authorName: 'Test Author',
        authorAvatar: 'test-avatar.jpg',
        authorClass: '2024',
        content: 'Test comment',
        datePosted: testDate,
        upvotes: 5,
        downvotes: 2,
      );

      final updated = original.copyWith(
        upvotes: 6,
        hasUserUpvoted: true,
        sentimentScore: 0.5,
        sentimentMagnitude: 1.0,
      );

      expect(updated.id, original.id);
      expect(updated.content, original.content);
      expect(updated.upvotes, 6);
      expect(updated.hasUserUpvoted, true);
      expect(updated.sentimentScore, 0.5);
      expect(updated.sentimentMagnitude, 1.0);
    });
  });
}