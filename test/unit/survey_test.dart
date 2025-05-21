import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ashesi_engage/models/entities/survey.dart';

void main() {
  group('Survey Tests', () {
    final testDate = DateTime(2024, 4, 28);
    final testDoc = FakeDocumentSnapshot({
      'title': 'Test Survey',
      'description': 'Test Description',
      'surveyLink': 'https://example.com/survey',
      'imageUrl': 'https://example.com/image.jpg',
      'createdBy': 'creator-id',
      'createdAt': Timestamp.fromDate(testDate),
      'expiresAt': Timestamp.fromDate(testDate.add(Duration(days: 7))),
      'isAllClasses': false,
      'classScopes': ['2024', '2025'],
      'isCompleted': false,
      'category': 'Academic',
      'organizer': 'Department of CS',
    });

    test('should create Survey with required fields', () {
      final survey = Survey(
        id: 'test-id',
        title: 'Test Survey',
        description: 'Test Description',
        surveyLink: 'https://example.com/survey',
        imageUrl: 'https://example.com/image.jpg',
        createdBy: 'creator-id',
        createdAt: testDate,
        expiresAt: testDate.add(Duration(days: 7)),
        isAllClasses: false,
        classScopes: ['2024', '2025'],
        category: 'Academic',
        organizer: 'Department of CS',
      );

      expect(survey.id, 'test-id');
      expect(survey.title, 'Test Survey');
      expect(survey.description, 'Test Description');
      expect(survey.surveyLink, 'https://example.com/survey');
      expect(survey.imageUrl, 'https://example.com/image.jpg');
      expect(survey.createdBy, 'creator-id');
      expect(survey.createdAt, testDate);
      expect(survey.expiresAt, testDate.add(Duration(days: 7)));
      expect(survey.isAllClasses, false);
      expect(survey.classScopes, ['2024', '2025']);
      expect(survey.isCompleted, false);
      expect(survey.category, 'Academic');
      expect(survey.organizer, 'Department of CS');
    });

    test('should create Survey from Firestore document', () {
      final survey = Survey.fromFirestore(testDoc);

      expect(survey.title, 'Test Survey');
      expect(survey.description, 'Test Description');
      expect(survey.surveyLink, 'https://example.com/survey');
      expect(survey.imageUrl, 'https://example.com/image.jpg');
      expect(survey.createdBy, 'creator-id');
      expect(survey.createdAt, testDate);
      expect(survey.expiresAt, testDate.add(Duration(days: 7)));
      expect(survey.isAllClasses, false);
      expect(survey.classScopes, ['2024', '2025']);
      expect(survey.isCompleted, false);
      expect(survey.category, 'Academic');
      expect(survey.organizer, 'Department of CS');
    });

    test('should convert Survey to Firestore document', () {
      final survey = Survey(
        id: 'test-id',
        title: 'Test Survey',
        description: 'Test Description',
        surveyLink: 'https://example.com/survey',
        imageUrl: 'https://example.com/image.jpg',
        createdBy: 'creator-id',
        createdAt: testDate,
        expiresAt: testDate.add(Duration(days: 7)),
        isAllClasses: false,
        classScopes: ['2024', '2025'],
        category: 'Academic',
        organizer: 'Department of CS',
      );

      final map = survey.toFirestore();

      expect(map['title'], 'Test Survey');
      expect(map['description'], 'Test Description');
      expect(map['surveyLink'], 'https://example.com/survey');
      expect(map['imageUrl'], 'https://example.com/image.jpg');
      expect(map['createdBy'], 'creator-id');
      expect(map['createdAt'], Timestamp.fromDate(testDate));
      expect(map['expiresAt'], Timestamp.fromDate(testDate.add(Duration(days: 7))));
      expect(map['isAllClasses'], false);
      expect(map['classScopes'], ['2024', '2025']);
      expect(map['isCompleted'], false);
      expect(map['category'], 'Academic');
      expect(map['organizer'], 'Department of CS');
    });

    test('should create copy with updated fields', () {
      final original = Survey(
        id: 'test-id',
        title: 'Test Survey',
        description: 'Test Description',
        surveyLink: 'https://example.com/survey',
        imageUrl: 'https://example.com/image.jpg',
        createdBy: 'creator-id',
        createdAt: testDate,
        expiresAt: testDate.add(Duration(days: 7)),
        isAllClasses: false,
        classScopes: ['2024', '2025'],
        category: 'Academic',
        organizer: 'Department of CS',
      );

      final updated = original.copyWith(
        title: 'Updated Survey',
        isCompleted: true,
        classScopes: ['2024', '2025', '2026'],
      );

      expect(updated.id, original.id);
      expect(updated.title, 'Updated Survey');
      expect(updated.isCompleted, true);
      expect(updated.classScopes, ['2024', '2025', '2026']);
      expect(updated.createdAt, original.createdAt);
      expect(updated.expiresAt, original.expiresAt);
    });
  });
}

// Helper class to mock Firestore DocumentSnapshot
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