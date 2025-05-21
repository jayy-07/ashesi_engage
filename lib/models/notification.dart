import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  newPoll,
  pollDeadline,
  pollResults,
  pollExpired,
  proposalEndorsement,
  proposalEndorsementComplete,
  proposalReply,
  article,
  system,
}

class UserNotification {
  final String id;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? data;

  const UserNotification({
    required this.id,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.data,
  });

  UserNotification copyWith({
    String? id,
    String? message,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return UserNotification(
      id: id ?? this.id,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    return UserNotification(
      id: json['id'] as String,
      message: json['message'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${json['type']}',
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'type': type.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      if (data != null) 'data': data,
    };
  }

  factory UserNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserNotification(
      id: doc.id,
      message: data['message'] as String,
      type: NotificationType.values.firstWhere(
        (t) => t.toString() == 'NotificationType.${data['type']}',
        orElse: () => NotificationType.system,
      ),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] as bool? ?? false,
      data: data['data'] as Map<String, dynamic>?,
    );
  }
}