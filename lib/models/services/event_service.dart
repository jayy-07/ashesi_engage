import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../entities/event.dart';
import 'dart:typed_data' show Uint8List;

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'events';

  Future<Event> createEvent({
    dynamic imageFile,
    required String title,
    required String shortDescription,
    required String longDescription,
    required String location,
    required DateTime startTime,
    required DateTime endTime,
    required bool isAllDay,
    required String organizer,
    required List<String> classScopes,
    required bool isAllClasses,
    bool isVirtual = false,
    String? meetingLink,
  }) async {
    try {
      String? imageUrl;

      if (imageFile != null) {
        final String fileName = 'events/${DateTime.now().millisecondsSinceEpoch}_event_image';
        final Reference storageRef = _storage.ref().child(fileName);
        late UploadTask uploadTask;

        if (kIsWeb) {
          if (imageFile is Uint8List) {
            uploadTask = storageRef.putData(imageFile);
          } else {
            throw Exception('Invalid file type for web platform');
          }
        } else {
          if (imageFile is File) {
            uploadTask = storageRef.putFile(imageFile);
          } else {
            throw Exception('Invalid file type for mobile platform');
          }
        }

        final snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      // Create doc reference first to get the ID
      final docRef = _firestore.collection(_collection).doc();
      final now = DateTime.now();

      final event = Event(
        id: docRef.id,
        title: title,
        shortDescription: shortDescription,
        longDescription: longDescription,
        location: location,
        startTime: startTime,
        endTime: endTime,
        isAllDay: isAllDay,
        imageUrl: imageUrl ?? '',
        organizer: organizer,
        classScopes: classScopes,
        isAllClasses: isAllClasses,
        createdAt: now,
        createdBy: _firestore.app.options.projectId,
        isVirtual: isVirtual,
        meetingLink: meetingLink,
      );

      await docRef.set({
        'title': title,
        'shortDescription': shortDescription,
        'longDescription': longDescription,
        'location': location,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'isAllDay': isAllDay,
        'imageUrl': imageUrl ?? '',
        'organizer': organizer,
        'classScopes': classScopes,
        'isAllClasses': isAllClasses,
        'createdAt': Timestamp.fromDate(now),
        'createdBy': event.createdBy,
        'isVirtual': isVirtual,
        'meetingLink': meetingLink,
      });

      return event;
    } catch (e) {
      throw Exception('Failed to create event: $e');
    }
  }

  Stream<List<Event>> getEvents() {
    return _firestore
        .collection(_collection)
        .orderBy('startTime', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Event(
          id: doc.id,
          title: data['title'] as String? ?? '',
          shortDescription: data['shortDescription'] as String? ?? '',
          longDescription: data['longDescription'] as String? ?? '',
          location: data['location'] as String? ?? '',
          startTime: (data['startTime'] as Timestamp).toDate(),
          endTime: (data['endTime'] as Timestamp).toDate(),
          isAllDay: data['isAllDay'] as bool? ?? false,
          imageUrl: data['imageUrl'] as String? ?? '',
          organizer: data['organizer'] as String? ?? '',
          classScopes: List<String>.from(data['classScopes'] ?? []),
          isAllClasses: data['isAllClasses'] as bool? ?? false,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          createdBy: data['createdBy'] as String? ?? 'admin',
          isVirtual: data['isVirtual'] as bool? ?? false,
          meetingLink: data['meetingLink'] as String?,
        );
      }).toList();
    });
  }

  Future<void> deleteEvent(Event event) async {
    try {
      if (event.imageUrl.isNotEmpty) {
        final Reference storageRef = _storage.refFromURL(event.imageUrl);
        await storageRef.delete();
      }

      await _firestore.collection(_collection).doc(event.id).delete();
    } catch (e) {
      throw Exception('Failed to delete event: $e');
    }
  }

  Future<Event?> getEventById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      return Event(
        id: doc.id,
        title: data['title'] as String? ?? '',
        shortDescription: data['shortDescription'] as String? ?? '',
        longDescription: data['longDescription'] as String? ?? '',
        location: data['location'] as String? ?? '',
        startTime: (data['startTime'] as Timestamp).toDate(),
        endTime: (data['endTime'] as Timestamp).toDate(),
        isAllDay: data['isAllDay'] as bool? ?? false,
        imageUrl: data['imageUrl'] as String? ?? '',
        organizer: data['organizer'] as String? ?? '',
        classScopes: List<String>.from(data['classScopes'] ?? []),
        isAllClasses: data['isAllClasses'] as bool? ?? false,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        createdBy: data['createdBy'] as String? ?? 'admin',
        isVirtual: data['isVirtual'] as bool? ?? false,
        meetingLink: data['meetingLink'] as String?,
      );
    } catch (e) {
      throw Exception('Failed to get event: $e');
    }
  }

  Future<void> updateEvent(Event event) async {
    try {
      await _firestore.collection(_collection).doc(event.id).update({
        'title': event.title,
        'shortDescription': event.shortDescription,
        'longDescription': event.longDescription,
        'location': event.location,
        'startTime': Timestamp.fromDate(event.startTime),
        'endTime': Timestamp.fromDate(event.endTime),
        'isAllDay': event.isAllDay,
        'imageUrl': event.imageUrl,
        'organizer': event.organizer,
        'classScopes': event.classScopes,
        'isAllClasses': event.isAllClasses,
        'updatedAt': FieldValue.serverTimestamp(),
        'isVirtual': event.isVirtual,
        'meetingLink': event.meetingLink,
      });
    } catch (e) {
      throw Exception('Failed to update event: $e');
    }
  }
}