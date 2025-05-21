import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../entities/survey.dart';
import 'package:rxdart/rxdart.dart';

class SurveyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'surveys';

  // Get all surveys
  Stream<List<Survey>> getAllSurveys({List<String>? classScopes, bool fetchAllForAdmin = false}) {
    try {
      Query query = _firestore.collection(_collection);
          // .orderBy('expiresAt', descending: true); // Order will be applied specifically

      if (fetchAllForAdmin) {
        // Admin: fetch all surveys
        return query.orderBy('expiresAt', descending: true).snapshots().map((snapshot) {
          try {
            return snapshot.docs.map((doc) {
              try {
                return Survey.fromFirestore(doc);
              } catch (e) {
                debugPrint('Error converting survey doc ${doc.id} in fetchAllForAdmin: $e');
                return null;
              }
            }).whereType<Survey>().toList();
          } catch (e) {
            debugPrint('Error processing survey snapshot in fetchAllForAdmin: $e');
            return <Survey>[];
          }
        });
      }

      // User-specific fetching:
      final allClassesQuery = query
          .where('isAllClasses', isEqualTo: true)
          .orderBy('expiresAt', descending: true);
      
      if (classScopes != null && classScopes.isNotEmpty) {
        final classSpecificQuery = query
            .where('isAllClasses', isEqualTo: false)
            .where('classScopes', arrayContainsAny: classScopes)
            .orderBy('expiresAt', descending: true);
        
        return Rx.combineLatest2<QuerySnapshot, QuerySnapshot, List<Survey>>(
          allClassesQuery.snapshots(),
          classSpecificQuery.snapshots(),
          (QuerySnapshot allClassesSnapshot, QuerySnapshot classSpecificSnapshot) {
            try {
              final allClassesSurveys = allClassesSnapshot.docs
                  .map((doc) {
                    try {
                      return Survey.fromFirestore(doc);
                    } catch (e) {
                      debugPrint('Error converting all classes survey doc ${doc.id}: $e');
                      return null;
                    }
                  })
                  .whereType<Survey>()
                  .toList();
              
              final classSpecificSurveys = classSpecificSnapshot.docs
                  .map((doc) {
                    try {
                      return Survey.fromFirestore(doc);
                    } catch (e) {
                      debugPrint('Error converting class specific survey doc ${doc.id}: $e');
                      return null;
                    }
                  })
                  .whereType<Survey>()
                  .toList();
              
              // Combine and sort. No duplicates expected due to mutually exclusive isAllClasses conditions.
              final combinedList = [...allClassesSurveys, ...classSpecificSurveys];
              combinedList.sort((a, b) => b.expiresAt.compareTo(a.expiresAt));
              return combinedList;

            } catch (e) {
              debugPrint('Error merging survey streams: $e');
              return <Survey>[];
            }
          },
        );
      }
      
      // If no specific classScopes and not fetchAllForAdmin (e.g. unauthenticated, user with no class): 
      // return only 'all classes' surveys
      return allClassesQuery.snapshots().map((snapshot) {
        try {
          return snapshot.docs
              .map((doc) {
                try {
                  return Survey.fromFirestore(doc);
                } catch (e) {
                  debugPrint('Error converting survey doc ${doc.id}: $e');
                  return null;
                }
              })
              .whereType<Survey>()
              .toList();
        } catch (e) {
          debugPrint('Error processing survey snapshot: $e');
          return <Survey>[];
        }
      });
    } catch (e) {
      debugPrint('Error in getAllSurveys: $e');
      return Stream.value([]);
    }
  }

  // Get active surveys
  Stream<List<Survey>> getActiveSurveys({List<String>? classScopes}) {
    Query query = _firestore.collection(_collection)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('expiresAt');

    // First get all surveys that are available to all classes
    final allClassesQuery = query.where('isAllClasses', isEqualTo: true);
    
    // If user has classes, also get surveys specific to those classes
    if (classScopes != null && classScopes.isNotEmpty) {
      final classSpecificQuery = query
          .where('isAllClasses', isEqualTo: false)
          .where('classScopes', arrayContainsAny: classScopes);
      
      // Get both snapshots
      return _firestore.collection(_collection).snapshots().map((snapshot) {
        try {
          return snapshot.docs
              .map((doc) {
                try {
                  return Survey.fromFirestore(doc);
                } catch (e) {
                  if (kDebugMode) {
                    print('Error converting survey doc ${doc.id}: $e');
                  }
                  return null;
                }
              })
              .whereType<Survey>()
              .toList();
        } catch (e) {
          if (kDebugMode) {
            print('Error processing survey snapshot: $e');
          }
          return <Survey>[];
        }
      });
    }
    
    // If no classes, just return surveys available to all
    return allClassesQuery.snapshots().map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) {
              try {
                return Survey.fromFirestore(doc);
              } catch (e) {
                if (kDebugMode) {
                  print('Error converting survey doc ${doc.id}: $e');
                }
                return null;
              }
            })
            .whereType<Survey>()
            .toList();
      } catch (e) {
        if (kDebugMode) {
          print('Error processing survey snapshot: $e');
        }
        return <Survey>[];
      }
    });
  }

  // Get a specific survey
  Stream<Survey?> getSurvey(String surveyId) {
    return _firestore.collection(_collection)
        .doc(surveyId)
        .snapshots()
        .map((doc) => doc.exists ? Survey.fromFirestore(doc) : null);
  }

  // Create a new survey
  Future<String> createSurvey(Survey survey) async {
    final docRef = await _firestore.collection(_collection).add(survey.toFirestore());
    return docRef.id;
  }

  // Update a survey
  Future<void> updateSurvey(Survey survey) async {
    await _firestore.collection(_collection)
        .doc(survey.id)
        .update(survey.toFirestore());
  }

  // Delete a survey
  Future<void> deleteSurvey(String surveyId) async {
    await _firestore.collection(_collection).doc(surveyId).delete();
  }

  // Mark survey as completed or uncompleted
  Future<void> markSurveyAsCompleted(String surveyId, bool isCompleted) async {
    await _firestore.collection(_collection).doc(surveyId).update({
      'isCompleted': isCompleted,
    });
  }
}