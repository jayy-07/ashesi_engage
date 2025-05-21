import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ashesi_engage/models/entities/student_proposal.dart';

void main() {
  group('StudentProposal Tests', () {
    final testDate = DateTime(2024, 4, 28);
    final testContent = {'ops': [{'insert': 'Test content'}]};

    test('should create StudentProposal with required fields', () {
      final proposal = StudentProposal(
        id: 'test-id',
        authorId: 'author-id',
        authorName: 'Test Author',
        authorClass: '2024',
        authorAvatar: 'test-avatar.jpg',
        title: 'Test Proposal',
        content: testContent,
        plainContent: 'Test content',
        datePosted: testDate,
        currentSignatures: 0,
        requiredSignatures: 100,
        isEndorsedByUser: false,
        endorserIds: [],
        tier: ProposalTier.minor,
      );

      expect(proposal.id, 'test-id');
      expect(proposal.authorId, 'author-id');
      expect(proposal.authorName, 'Test Author');
      expect(proposal.title, 'Test Proposal');
      expect(proposal.content, testContent);
      expect(proposal.currentSignatures, 0);
      expect(proposal.requiredSignatures, 100);
      expect(proposal.tier, ProposalTier.minor);
      expect(proposal.isAnswered, false);
      expect(proposal.deleted, null);
      expect(proposal.deletedAt, null);
    });

    test('should calculate remaining signatures correctly', () {
      final proposal = StudentProposal(
        id: 'test-id',
        authorId: 'author-id',
        authorName: 'Test Author',
        authorClass: '2024',
        authorAvatar: 'test-avatar.jpg',
        title: 'Test Proposal',
        content: testContent,
        plainContent: 'Test content',
        datePosted: testDate,
        currentSignatures: 30,
        requiredSignatures: 100,
        isEndorsedByUser: false,
        endorserIds: [],
        tier: ProposalTier.minor,
      );

      expect(proposal.remainingSignatures, 70);
      expect(proposal.progressPercentage, 0.3);
    });

    test('should convert to and from Map correctly', () {
      final original = StudentProposal(
        id: 'test-id',
        authorId: 'author-id',
        authorName: 'Test Author',
        authorClass: '2024',
        authorAvatar: 'test-avatar.jpg',
        title: 'Test Proposal',
        content: testContent,
        plainContent: 'Test content',
        datePosted: testDate,
        currentSignatures: 30,
        requiredSignatures: 100,
        isEndorsedByUser: true,
        endorserIds: ['user1', 'user2'],
        tier: ProposalTier.moderate,
        sentimentScore: 0.8,
        sentimentMagnitude: 1.5,
      );

      final map = original.toMap();
      final fromMap = StudentProposal.fromMap(map);

      expect(fromMap.id, original.id);
      expect(fromMap.authorId, original.authorId);
      expect(fromMap.title, original.title);
      expect(fromMap.currentSignatures, original.currentSignatures);
      expect(fromMap.tier, original.tier);
      expect(fromMap.sentimentScore, original.sentimentScore);
      expect(fromMap.sentimentMagnitude, original.sentimentMagnitude);
    });

    test('should interpret sentiment correctly', () {
      final proposals = [
        StudentProposal(
          id: 'test-1',
          authorId: 'author-id',
          authorName: 'Test Author',
          authorClass: '2024',
          authorAvatar: 'test-avatar.jpg',
          title: 'Very Positive',
          content: testContent,
          plainContent: 'Test content',
          datePosted: testDate,
          currentSignatures: 0,
          requiredSignatures: 100,
          isEndorsedByUser: false,
          endorserIds: [],
          tier: ProposalTier.minor,
          sentimentScore: 0.8,
          sentimentMagnitude: 2.5,
        ),
        StudentProposal(
          id: 'test-2',
          authorId: 'author-id',
          authorName: 'Test Author',
          authorClass: '2024',
          authorAvatar: 'test-avatar.jpg',
          title: 'Neutral',
          content: testContent,
          plainContent: 'Test content',
          datePosted: testDate,
          currentSignatures: 0,
          requiredSignatures: 100,
          isEndorsedByUser: false,
          endorserIds: [],
          tier: ProposalTier.minor,
          sentimentScore: 0.0,
          sentimentMagnitude: 0.5,
        ),
      ];

      expect(proposals[0].sentimentInterpretation, 'Very Positive | Strong');
      expect(proposals[1].sentimentInterpretation, 'Neutral | Mild');
    });

    test('should check user endorsement correctly', () {
      final proposal = StudentProposal(
        id: 'test-id',
        authorId: 'author-id',
        authorName: 'Test Author',
        authorClass: '2024',
        authorAvatar: 'test-avatar.jpg',
        title: 'Test Proposal',
        content: testContent,
        plainContent: 'Test content',
        datePosted: testDate,
        currentSignatures: 2,
        requiredSignatures: 100,
        isEndorsedByUser: false,
        endorserIds: ['user1', 'user2'],
        tier: ProposalTier.minor,
      );

      expect(proposal.hasUserEndorsed('user1'), true);
      expect(proposal.hasUserEndorsed('user3'), false);
    });

    test('should create copy with updated fields', () {
      final original = StudentProposal(
        id: 'test-id',
        authorId: 'author-id',
        authorName: 'Test Author',
        authorClass: '2024',
        authorAvatar: 'test-avatar.jpg',
        title: 'Test Proposal',
        content: testContent,
        plainContent: 'Test content',
        datePosted: testDate,
        currentSignatures: 30,
        requiredSignatures: 100,
        isEndorsedByUser: false,
        endorserIds: [],
        tier: ProposalTier.minor,
      );

      final updated = original.copyWith(
        currentSignatures: 40,
        isEndorsedByUser: true,
        sentimentScore: 0.5,
      );

      expect(updated.id, original.id);
      expect(updated.currentSignatures, 40);
      expect(updated.isEndorsedByUser, true);
      expect(updated.sentimentScore, 0.5);
      expect(updated.title, original.title);
    });
  });
}