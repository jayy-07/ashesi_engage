import 'package:cloud_firestore/cloud_firestore.dart';

class Bookmark {
  final String id;
  final String userId;
  final String itemId;
  final String itemType; // 'proposal' or 'discussion'
  final DateTime dateBookmarked;

  const Bookmark({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.itemType,
    required this.dateBookmarked,
  });

  factory Bookmark.fromMap(String id, Map<String, dynamic> map) {
    return Bookmark(
      id: id,
      userId: map['userId'] ?? '',
      itemId: map['itemId'] ?? '',
      itemType: map['itemType'] ?? '',
      dateBookmarked: (map['dateBookmarked'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'itemId': itemId,
      'itemType': itemType,
      'dateBookmarked': Timestamp.fromDate(dateBookmarked),
    };
  }
}