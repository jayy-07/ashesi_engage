import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String title;
  final String imageUrl;
  final DateTime date;
  final bool isAllDay;
  final DateTime? startTime;
  final DateTime? endTime;
  final String location;
  final String organizers;
  final String shortDescription;
  final String longDescription;
  final DateTime createdAt;
  final String createdBy;

  Event({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.date,
    required this.isAllDay,
    this.startTime,
    this.endTime,
    required this.location,
    required this.organizers,
    required this.shortDescription,
    required this.longDescription,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'imageUrl': imageUrl,
      'date': Timestamp.fromDate(date),
      'isAllDay': isAllDay,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'location': location,
      'organizers': organizers,
      'shortDescription': shortDescription,
      'longDescription': longDescription,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] as String,
      title: map['title'] as String,
      imageUrl: map['imageUrl'] as String,
      date: (map['date'] as Timestamp).toDate(),
      isAllDay: map['isAllDay'] as bool,
      startTime: map['startTime'] != null ? (map['startTime'] as Timestamp).toDate() : null,
      endTime: map['endTime'] != null ? (map['endTime'] as Timestamp).toDate() : null,
      location: map['location'] as String,
      organizers: map['organizers'] as String,
      shortDescription: map['shortDescription'] as String,
      longDescription: map['longDescription'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      createdBy: map['createdBy'] as String,
    );
  }
} 