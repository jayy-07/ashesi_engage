import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ashesi_engage/models/entities/poll.dart';

void main() {
  group('Poll Tests', () {
    late DateTime testDate;
    late DateTime expiryDate;

    setUp(() {
      testDate = DateTime(2024, 4, 28);
      expiryDate = DateTime(2024, 5, 28);
    });

    test('should create PollVote correctly', () {
      final vote = PollVote(
        optionId: 'option-1',
        timestamp: testDate,
      );

      expect(vote.optionId, 'option-1');
      expect(vote.timestamp, testDate);
    });

    test('should convert PollVote to/from Map', () {
      final vote = PollVote(
        optionId: 'option-1',
        timestamp: testDate,
      );

      final map = vote.toMap();
      expect(map['optionId'], 'option-1');
      expect(map['timestamp'], isA<Timestamp>());

      final reconstructedVote = PollVote.fromMap(map);
      expect(reconstructedVote.optionId, vote.optionId);
      expect(reconstructedVote.timestamp, vote.timestamp);
    });

    test('should create PollOption correctly', () {
      final option = PollOption(
        id: 'option-1',
        text: 'Option 1',
      );

      expect(option.id, 'option-1');
      expect(option.text, 'Option 1');
    });

    test('should convert PollOption to/from Map', () {
      final option = PollOption(
        id: 'option-1',
        text: 'Option 1',
      );

      final map = option.toMap();
      expect(map['id'], 'option-1');
      expect(map['text'], 'Option 1');

      final reconstructedOption = PollOption.fromMap(map);
      expect(reconstructedOption.id, option.id);
      expect(reconstructedOption.text, option.text);
    });

    test('should create Poll with all fields', () {
      final options = [
        PollOption(id: 'option-1', text: 'Option 1'),
        PollOption(id: 'option-2', text: 'Option 2'),
      ];

      final votes = {
        'user1': PollVote(optionId: 'option-1', timestamp: testDate),
        'user2': PollVote(optionId: 'option-2', timestamp: testDate),
      };

      final poll = Poll(
        id: 'test-poll',
        title: 'Test Poll',
        description: 'Test Description',
        createdBy: 'user1',
        createdAt: testDate,
        expiresAt: expiryDate,
        options: options,
        votes: votes,
        showRealTimeResults: true,
        showResultsAfterEnd: true,
        finalResultsDuration: 7,
        isAllClasses: true,
        classScopes: ['2024', '2025'],
        isActive: true,
        isReversible: true,
      );

      expect(poll.id, 'test-poll');
      expect(poll.title, 'Test Poll');
      expect(poll.description, 'Test Description');
      expect(poll.createdBy, 'user1');
      expect(poll.createdAt, testDate);
      expect(poll.expiresAt, expiryDate);
      expect(poll.options.length, 2);
      expect(poll.votes.length, 2);
      expect(poll.showRealTimeResults, true);
      expect(poll.showResultsAfterEnd, true);
      expect(poll.finalResultsDuration, 7);
      expect(poll.isAllClasses, true);
      expect(poll.classScopes, ['2024', '2025']);
      expect(poll.isActive, true);
      expect(poll.isReversible, true);
    });

    test('should convert Poll to/from Map', () {
      final options = [
        PollOption(id: 'option-1', text: 'Option 1'),
        PollOption(id: 'option-2', text: 'Option 2'),
      ];

      final votes = {
        'user1': PollVote(optionId: 'option-1', timestamp: testDate),
        'user2': PollVote(optionId: 'option-2', timestamp: testDate),
      };

      final poll = Poll(
        id: 'test-poll',
        title: 'Test Poll',
        description: 'Test Description',
        createdBy: 'user1',
        createdAt: testDate,
        expiresAt: expiryDate,
        options: options,
        votes: votes,
        showRealTimeResults: true,
        showResultsAfterEnd: true,
        finalResultsDuration: 7,
        isAllClasses: true,
        classScopes: ['2024', '2025'],
        isActive: true,
        isReversible: true,
      );

      final map = poll.toMap();
      final reconstructedPoll = Poll.fromMap(map..['id'] = 'test-poll');

      expect(reconstructedPoll.id, poll.id);
      expect(reconstructedPoll.title, poll.title);
      expect(reconstructedPoll.description, poll.description);
      expect(reconstructedPoll.createdBy, poll.createdBy);
      expect(reconstructedPoll.createdAt, poll.createdAt);
      expect(reconstructedPoll.expiresAt, poll.expiresAt);
      expect(reconstructedPoll.options.length, poll.options.length);
      expect(reconstructedPoll.votes.length, poll.votes.length);
      expect(reconstructedPoll.showRealTimeResults, poll.showRealTimeResults);
      expect(reconstructedPoll.showResultsAfterEnd, poll.showResultsAfterEnd);
      expect(reconstructedPoll.finalResultsDuration, poll.finalResultsDuration);
      expect(reconstructedPoll.isAllClasses, poll.isAllClasses);
      expect(reconstructedPoll.classScopes, poll.classScopes);
      expect(reconstructedPoll.isActive, poll.isActive);
      expect(reconstructedPoll.isReversible, poll.isReversible);
    });

    test('should check if user has voted', () {
      final poll = Poll(
        id: 'test-poll',
        title: 'Test Poll',
        description: 'Test Description',
        createdBy: 'user1',
        createdAt: testDate,
        expiresAt: expiryDate,
        options: [PollOption(id: 'option-1', text: 'Option 1')],
        votes: {
          'user1': PollVote(optionId: 'option-1', timestamp: testDate),
        },
        showRealTimeResults: true,
        showResultsAfterEnd: true,
        finalResultsDuration: 7,
        isAllClasses: true,
        classScopes: ['2024'],
        isActive: true,
        isReversible: true,
      );

      expect(poll.hasUserVoted('user1'), true);
      expect(poll.hasUserVoted('user2'), false);
    });

    test('should get votes for option', () {
      final poll = Poll(
        id: 'test-poll',
        title: 'Test Poll',
        description: 'Test Description',
        createdBy: 'user1',
        createdAt: testDate,
        expiresAt: expiryDate,
        options: [
          PollOption(id: 'option-1', text: 'Option 1'),
          PollOption(id: 'option-2', text: 'Option 2'),
        ],
        votes: {
          'user1': PollVote(optionId: 'option-1', timestamp: testDate),
          'user2': PollVote(optionId: 'option-1', timestamp: testDate),
          'user3': PollVote(optionId: 'option-2', timestamp: testDate),
        },
        showRealTimeResults: true,
        showResultsAfterEnd: true,
        finalResultsDuration: 7,
        isAllClasses: true,
        classScopes: ['2024'],
        isActive: true,
        isReversible: true,
      );

      expect(poll.getVotesForOption('option-1'), 2);
      expect(poll.getVotesForOption('option-2'), 1);
      expect(poll.getVotesForOption('option-3'), 0);
    });

    test('should check if results can be shown', () {
      final activePoll = Poll(
        id: 'test-poll',
        title: 'Test Poll',
        description: 'Test Description',
        createdBy: 'user1',
        createdAt: testDate,
        expiresAt: expiryDate,
        options: [PollOption(id: 'option-1', text: 'Option 1')],
        votes: {},
        showRealTimeResults: true,
        showResultsAfterEnd: true,
        finalResultsDuration: 7,
        isAllClasses: true,
        classScopes: ['2024'],
        isActive: true,
        isReversible: true,
      );

      final hiddenPoll = Poll(
        id: 'test-poll',
        title: 'Test Poll',
        description: 'Test Description',
        createdBy: 'user1',
        createdAt: testDate,
        expiresAt: expiryDate,
        options: [PollOption(id: 'option-1', text: 'Option 1')],
        votes: {},
        showRealTimeResults: false,
        showResultsAfterEnd: false,
        finalResultsDuration: 7,
        isAllClasses: true,
        classScopes: ['2024'],
        isActive: true,
        isReversible: true,
      );

      expect(activePoll.canShowResults, true);
      expect(hiddenPoll.canShowResults, false);
    });
  });
} 