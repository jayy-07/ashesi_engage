import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String classYear;
  final String? photoURL;
  final int role;
  final DateTime loginDate;
  final DateTime accountCreationDate;
  final bool isBanned;
  final DateTime? bannedUntil;
  final String? banReason;
  final bool isDeleted;
  final DateTime? deletedAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.classYear,
    this.photoURL,
    this.role = 3, // Default to regular user
    DateTime? loginDate,
    DateTime? accountCreationDate,
    this.isBanned = false,
    this.bannedUntil,
    this.banReason,
    this.isDeleted = false,
    this.deletedAt,
  }) : 
    loginDate = loginDate ?? DateTime.now(),
    accountCreationDate = accountCreationDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'classYear': classYear,
      'photoURL': photoURL,
      'role': role,
      'loginDate': loginDate,
      'accountCreationDate': accountCreationDate,
      'isBanned': isBanned,
      'bannedUntil': bannedUntil,
      'banReason': banReason,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      classYear: map['classYear'] ?? '',
      photoURL: map['photoURL'],
      role: map['role'] ?? 3,
      loginDate: (map['loginDate'] as Timestamp?)?.toDate(),
      accountCreationDate: (map['accountCreationDate'] as Timestamp?)?.toDate(),
      isBanned: map['isBanned'] ?? false,
      bannedUntil: map['bannedUntil'] != null 
          ? map['bannedUntil'] is Timestamp 
              ? (map['bannedUntil'] as Timestamp).toDate()
              : DateTime.parse(map['bannedUntil'])
          : null,
      banReason: map['banReason'],
      isDeleted: map['isDeleted'] ?? false,
      deletedAt: map['deletedAt'] != null
          ? map['deletedAt'] is Timestamp
              ? (map['deletedAt'] as Timestamp).toDate()
              : DateTime.parse(map['deletedAt'])
          : null,
    );
  }

  factory AppUser.fromFirebaseUser(User user) {
    // Split display name into first and last name if available
    final nameParts = user.displayName?.split(' ') ?? ['', ''];
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      firstName: nameParts.first,
      lastName: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
      classYear: '',
      photoURL: user.photoURL,
    );
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? firstName,
    String? lastName,
    String? classYear,
    String? photoURL,
    int? role,
    DateTime? loginDate,
    DateTime? accountCreationDate,
    bool? isBanned,
    DateTime? bannedUntil,
    String? banReason,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      classYear: classYear ?? this.classYear,
      photoURL: photoURL ?? this.photoURL,
      role: role ?? this.role,
      loginDate: loginDate ?? this.loginDate,
      accountCreationDate: accountCreationDate ?? this.accountCreationDate,
      isBanned: isBanned ?? this.isBanned,
      bannedUntil: bannedUntil ?? this.bannedUntil,
      banReason: banReason ?? this.banReason,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
