import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String title;
  final String imageUrl;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final String location;
  final bool isVirtual;
  final String? meetingLink;
  final String organizer;
  final String shortDescription;
  final String longDescription;
  final List<String> classScopes;
  final bool isAllClasses;
  final DateTime createdAt;
  final String createdBy;

  const Event({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    required this.location,
    this.isVirtual = false,
    this.meetingLink,
    required this.organizer,
    required this.shortDescription,
    required this.longDescription,
    required this.classScopes,
    required this.isAllClasses,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'imageUrl': imageUrl,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'isAllDay': isAllDay,
      'location': location,
      'isVirtual': isVirtual,
      'meetingLink': meetingLink,
      'organizer': organizer,
      'shortDescription': shortDescription,
      'longDescription': longDescription,
      'classScopes': classScopes,
      'isAllClasses': isAllClasses,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    final startTime = (map['startTime'] as Timestamp).toDate();
    
    return Event(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      startTime: startTime,
      endTime: map['endTime'] != null 
          ? (map['endTime'] as Timestamp).toDate()
          : startTime.add(const Duration(hours: 1)),
      isAllDay: map['isAllDay'] as bool? ?? false,
      location: map['location'] as String? ?? '',
      isVirtual: map['isVirtual'] as bool? ?? false,
      meetingLink: map['meetingLink'] as String?,
      organizer: map['organizer'] as String? ?? '',
      shortDescription: map['shortDescription'] as String? ?? '',
      longDescription: map['longDescription'] as String? ?? '',
      classScopes: List<String>.from(map['classScopes'] ?? []),
      isAllClasses: map['isAllClasses'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] as String? ?? '',
    );
  }

  Event copyWith({
    String? id,
    String? title,
    String? imageUrl,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    String? location,
    bool? isVirtual,
    String? meetingLink,
    String? organizer,
    String? shortDescription,
    String? longDescription,
    List<String>? classScopes,
    bool? isAllClasses,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      location: location ?? this.location,
      isVirtual: isVirtual ?? this.isVirtual,
      meetingLink: meetingLink ?? this.meetingLink,
      organizer: organizer ?? this.organizer,
      shortDescription: shortDescription ?? this.shortDescription,
      longDescription: longDescription ?? this.longDescription,
      classScopes: classScopes ?? this.classScopes,
      isAllClasses: isAllClasses ?? this.isAllClasses,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
