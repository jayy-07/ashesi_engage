import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ashesi_engage/auth/models/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';

// Create a mock class for Firebase User
class MockUser extends Mock implements User {
  @override
  String get uid => 'test-uid';
  @override
  String? get email => 'test@example.com';
  @override
  String? get displayName => 'Test User';
  @override
  String? get photoURL => 'https://example.com/photo.jpg';
}

void main() {
  group('AppUser Tests', () {
    late DateTime testDate;

    setUp(() {
      testDate = DateTime(2024, 4, 28);
    });

    test('should create AppUser with required fields', () {
      final user = AppUser(
        uid: 'test-uid',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        classYear: '2024',
      );

      expect(user.uid, 'test-uid');
      expect(user.email, 'test@example.com');
      expect(user.firstName, 'Test');
      expect(user.lastName, 'User');
      expect(user.classYear, '2024');
      expect(user.role, 3); // Default role
      expect(user.isBanned, false);
      expect(user.isDeleted, false);
    });

    test('should create AppUser with all fields', () {
      final user = AppUser(
        uid: 'test-uid',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        classYear: '2024',
        photoURL: 'https://example.com/photo.jpg',
        role: 2,
        loginDate: testDate,
        accountCreationDate: testDate,
        isBanned: true,
        bannedUntil: testDate,
        banReason: 'Test ban reason',
        isDeleted: true,
        deletedAt: testDate,
      );

      expect(user.uid, 'test-uid');
      expect(user.email, 'test@example.com');
      expect(user.firstName, 'Test');
      expect(user.lastName, 'User');
      expect(user.classYear, '2024');
      expect(user.photoURL, 'https://example.com/photo.jpg');
      expect(user.role, 2);
      expect(user.loginDate, testDate);
      expect(user.accountCreationDate, testDate);
      expect(user.isBanned, true);
      expect(user.bannedUntil, testDate);
      expect(user.banReason, 'Test ban reason');
      expect(user.isDeleted, true);
      expect(user.deletedAt, testDate);
    });

    test('should convert AppUser to Map correctly', () {
      final user = AppUser(
        uid: 'test-uid',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        classYear: '2024',
        photoURL: 'https://example.com/photo.jpg',
        role: 2,
        loginDate: testDate,
        accountCreationDate: testDate,
        isBanned: true,
        bannedUntil: testDate,
        banReason: 'Test ban reason',
        isDeleted: true,
        deletedAt: testDate,
      );

      final map = user.toMap();

      expect(map['uid'], 'test-uid');
      expect(map['email'], 'test@example.com');
      expect(map['firstName'], 'Test');
      expect(map['lastName'], 'User');
      expect(map['classYear'], '2024');
      expect(map['photoURL'], 'https://example.com/photo.jpg');
      expect(map['role'], 2);
      expect(map['loginDate'], testDate);
      expect(map['accountCreationDate'], testDate);
      expect(map['isBanned'], true);
      expect(map['bannedUntil'], testDate);
      expect(map['banReason'], 'Test ban reason');
      expect(map['isDeleted'], true);
      expect(map['deletedAt'], testDate);
    });

    test('should create AppUser from Map correctly', () {
      final map = {
        'uid': 'test-uid',
        'email': 'test@example.com',
        'firstName': 'Test',
        'lastName': 'User',
        'classYear': '2024',
        'photoURL': 'https://example.com/photo.jpg',
        'role': 2,
        'loginDate': Timestamp.fromDate(testDate),
        'accountCreationDate': Timestamp.fromDate(testDate),
        'isBanned': true,
        'bannedUntil': Timestamp.fromDate(testDate),
        'banReason': 'Test ban reason',
        'isDeleted': true,
        'deletedAt': Timestamp.fromDate(testDate),
      };

      final user = AppUser.fromMap(map);

      expect(user.uid, 'test-uid');
      expect(user.email, 'test@example.com');
      expect(user.firstName, 'Test');
      expect(user.lastName, 'User');
      expect(user.classYear, '2024');
      expect(user.photoURL, 'https://example.com/photo.jpg');
      expect(user.role, 2);
      expect(user.loginDate, testDate);
      expect(user.accountCreationDate, testDate);
      expect(user.isBanned, true);
      expect(user.bannedUntil, testDate);
      expect(user.banReason, 'Test ban reason');
      expect(user.isDeleted, true);
      expect(user.deletedAt, testDate);
    });

    test('should create AppUser from Firebase User', () {
      final firebaseUser = MockUser();
      final user = AppUser.fromFirebaseUser(firebaseUser);

      expect(user.uid, 'test-uid');
      expect(user.email, 'test@example.com');
      expect(user.firstName, 'Test');
      expect(user.lastName, 'User');
      expect(user.photoURL, 'https://example.com/photo.jpg');
      expect(user.role, 3); // Default role
    });

    test('should create copy with updated fields', () {
      final user = AppUser(
        uid: 'test-uid',
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        classYear: '2024',
      );

      final updatedUser = user.copyWith(
        firstName: 'Updated',
        lastName: 'Name',
        role: 1,
      );

      expect(updatedUser.uid, user.uid);
      expect(updatedUser.email, user.email);
      expect(updatedUser.firstName, 'Updated');
      expect(updatedUser.lastName, 'Name');
      expect(updatedUser.role, 1);
      expect(updatedUser.classYear, user.classYear);
    });
  });
} 