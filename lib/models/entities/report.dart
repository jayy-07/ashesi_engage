import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String id;
  final String contentType; // 'discussion', 'comment', 'proposal'
  final String contentId;
  final String reporterId;
  final String reason;
  final String? additionalInfo;
  final DateTime timestamp;
  final String status; // 'pending', 'reviewed', 'resolved', 'dismissed'

  const Report({
    required this.id,
    required this.contentType,
    required this.contentId,
    required this.reporterId,
    required this.reason,
    this.additionalInfo,
    required this.timestamp,
    required this.status,
  });

  factory Report.fromMap(String id, Map<String, dynamic> map) {
    return Report(
      id: id,
      contentType: map['contentType'] as String,
      contentId: map['contentId'] as String,
      reporterId: map['reporterId'] as String,
      reason: map['reason'] as String,
      additionalInfo: map['additionalInfo'] as String?,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      status: map['status'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contentType': contentType,
      'contentId': contentId,
      'reporterId': reporterId,
      'reason': reason,
      'additionalInfo': additionalInfo,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
    };
  }
}

// Predefined report reasons
class ReportReason {
  static const String inappropriate = 'Inappropriate content';
  static const String spam = 'Spam';
  static const String harassment = 'Harassment';
  static const String misinformation = 'Misinformation';
  static const String offensive = 'Offensive content';
  static const String other = 'Other';

  static List<String> get values => [
    inappropriate,
    spam,
    harassment,
    misinformation,
    offensive,
    other,
  ];
} 