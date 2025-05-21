import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ashesi_engage/models/event.dart';

void main() {
  group('Event Model Tests', () {
    late DateTime testDate;
    late DateTime testStartTime;
    late DateTime testEndTime;
    late DateTime testCreatedAt;

    setUp(() {
      testDate = DateTime(2024, 4, 28);
      testStartTime = DateTime(2024, 4, 28, 14, 30); // 2:30 PM
      testEndTime = DateTime(2024, 4, 28, 16, 30);   // 4:30 PM
      testCreatedAt = DateTime(2024, 4, 27, 10, 0); // 10:00 AM
    });

    test('should create an Event instance with all required fields', () {
      final event = Event(
        id: 'test-id',
        title: 'Test Event',
        imageUrl: 'https://example.com/image.jpg',
        date: testDate,
        isAllDay: false,
        startTime: testStartTime,
        endTime: testEndTime,
        location: 'Test Location',
        organizers: 'Test Organizers',
        shortDescription: 'Short description',
        longDescription: 'Long description',
        createdAt: testCreatedAt,
        createdBy: 'test-user',
      );

      expect(event.id, 'test-id');
      expect(event.title, 'Test Event');
      expect(event.imageUrl, 'https://example.com/image.jpg');
      expect(event.date, testDate);
      expect(event.isAllDay, false);
      expect(event.startTime, testStartTime);
      expect(event.endTime, testEndTime);
      expect(event.location, 'Test Location');
      expect(event.organizers, 'Test Organizers');
      expect(event.shortDescription, 'Short description');
      expect(event.longDescription, 'Long description');
      expect(event.createdAt, testCreatedAt);
      expect(event.createdBy, 'test-user');
    });

    test('should create an Event instance with all-day event', () {
      final event = Event(
        id: 'test-id',
        title: 'All Day Event',
        imageUrl: 'https://example.com/image.jpg',
        date: testDate,
        isAllDay: true,
        location: 'Test Location',
        organizers: 'Test Organizers',
        shortDescription: 'Short description',
        longDescription: 'Long description',
        createdAt: testCreatedAt,
        createdBy: 'test-user',
      );

      expect(event.isAllDay, true);
      expect(event.startTime, null);
      expect(event.endTime, null);
    });

    test('should convert Event to Map correctly', () {
      final event = Event(
        id: 'test-id',
        title: 'Test Event',
        imageUrl: 'https://example.com/image.jpg',
        date: testDate,
        isAllDay: false,
        startTime: testStartTime,
        endTime: testEndTime,
        location: 'Test Location',
        organizers: 'Test Organizers',
        shortDescription: 'Short description',
        longDescription: 'Long description',
        createdAt: testCreatedAt,
        createdBy: 'test-user',
      );

      final map = event.toMap();

      expect(map['id'], 'test-id');
      expect(map['title'], 'Test Event');
      expect(map['imageUrl'], 'https://example.com/image.jpg');
      expect(map['date'], isA<Timestamp>());
      expect(map['isAllDay'], false);
      expect(map['startTime'], isA<Timestamp>());
      expect(map['endTime'], isA<Timestamp>());
      expect(map['location'], 'Test Location');
      expect(map['organizers'], 'Test Organizers');
      expect(map['shortDescription'], 'Short description');
      expect(map['longDescription'], 'Long description');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['createdBy'], 'test-user');
    });

    test('should create Event from Map correctly', () {
      final map = {
        'id': 'test-id',
        'title': 'Test Event',
        'imageUrl': 'https://example.com/image.jpg',
        'date': Timestamp.fromDate(testDate),
        'isAllDay': false,
        'startTime': Timestamp.fromDate(testStartTime),
        'endTime': Timestamp.fromDate(testEndTime),
        'location': 'Test Location',
        'organizers': 'Test Organizers',
        'shortDescription': 'Short description',
        'longDescription': 'Long description',
        'createdAt': Timestamp.fromDate(testCreatedAt),
        'createdBy': 'test-user',
      };

      final event = Event.fromMap(map);

      expect(event.id, 'test-id');
      expect(event.title, 'Test Event');
      expect(event.imageUrl, 'https://example.com/image.jpg');
      expect(event.date, testDate);
      expect(event.isAllDay, false);
      expect(event.startTime, testStartTime);
      expect(event.endTime, testEndTime);
      expect(event.location, 'Test Location');
      expect(event.organizers, 'Test Organizers');
      expect(event.shortDescription, 'Short description');
      expect(event.longDescription, 'Long description');
      expect(event.createdAt, testCreatedAt);
      expect(event.createdBy, 'test-user');
    });
  });
} 