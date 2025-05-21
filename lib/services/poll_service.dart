import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/entities/poll.dart';
import 'notification_service.dart';

class PollService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  Stream<List<Poll>> getPolls() {
    return _firestore
        .collection('polls')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Poll.fromFirestore(doc)).toList());
  }

  Future<void> createPoll(Poll poll) async {
    // Create the poll in Firestore
    final docRef = await _firestore.collection('polls').add(poll.toMap());
    
    // Send notification about new poll
    await _notificationService.showPollNotification(
      title: 'New Poll Available',
      body: poll.title,
      payload: {
        'type': 'new_poll',
        'pollId': docRef.id,
      },
    );

    // Schedule deadline notifications if the poll hasn't expired
    final now = DateTime.now();
    if (poll.expiresAt.isAfter(now)) {
      // Schedule 1-hour notification
      final oneHourNotificationTime = poll.expiresAt.subtract(const Duration(hours: 1));
      if (oneHourNotificationTime.isAfter(now)) {
        await _firestore.collection('scheduled_notifications').add({
          'type': 'poll_deadline_1hour',
          'pollId': docRef.id,
          'pollTitle': poll.title,
          'scheduledFor': Timestamp.fromDate(oneHourNotificationTime),
          'sent': false,
        });
      }

      // Schedule 30-minute notification
      final thirtyMinNotificationTime = poll.expiresAt.subtract(const Duration(minutes: 30));
      if (thirtyMinNotificationTime.isAfter(now)) {
        await _firestore.collection('scheduled_notifications').add({
          'type': 'poll_deadline_30min',
          'pollId': docRef.id,
          'pollTitle': poll.title,
          'scheduledFor': Timestamp.fromDate(thirtyMinNotificationTime),
          'sent': false,
        });
      }
    }
  }

  Future<void> updatePoll(Poll poll) async {
    await _firestore.collection('polls').doc(poll.id).update(poll.toMap());
  }

  Future<void> deletePoll(String pollId) async {
    await _firestore.collection('polls').doc(pollId).delete();
    
    // Delete any scheduled notifications for this poll
    final notifications = await _firestore
        .collection('scheduled_notifications')
        .where('pollId', isEqualTo: pollId)
        .get();
    
    for (var doc in notifications.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> checkForPendingNotifications() async {
    final now = DateTime.now();
    final oneHourFromNow = now.add(const Duration(hours: 1));
    final thirtyMinFromNow = now.add(const Duration(minutes: 30));

    // Get scheduled notifications that are due
    final querySnapshot = await _firestore
        .collection('scheduled_notifications')
        .where('sent', isEqualTo: false)
        .where('scheduledFor', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final pollId = data['pollId'] as String;
      final pollTitle = data['pollTitle'] as String;
      final type = data['type'] as String;

      // Get the poll to make sure it still exists and is active
      final pollDoc = await _firestore.collection('polls').doc(pollId).get();
      if (!pollDoc.exists) {
        // Poll was deleted, clean up the notification
        await doc.reference.delete();
        continue;
      }

      final poll = Poll.fromFirestore(pollDoc);
      if (!poll.isActive || poll.expiresAt.isBefore(now)) {
        // Poll is no longer active or has expired, clean up the notification
        await doc.reference.delete();
        continue;
      }

      // Send the appropriate notification based on type
      switch (type) {
        case 'poll_deadline_1hour':
          await _notificationService.showPollDeadlineNotification(
            title: 'Poll Closing Soon',
            body: 'The poll "$pollTitle" is closing in 1 hour',
            payload: {
              'type': 'poll_deadline',
              'pollId': pollId,
            },
          );
          break;
        case 'poll_deadline_30min':
          await _notificationService.showPollDeadlineNotification(
            title: 'Poll Closing Very Soon',
            body: 'The poll "$pollTitle" is closing in 30 minutes',
            payload: {
              'type': 'poll_deadline',
              'pollId': pollId,
            },
          );
          break;
      }

      // Mark notification as sent
      await doc.reference.update({'sent': true});
    }
  }

  Future<void> vote(String pollId, String userId, String optionId) async {
    await _firestore.collection('polls').doc(pollId).update({
      'votes.$userId': {
        'optionId': optionId,
        'timestamp': FieldValue.serverTimestamp(),
      },
    });
  }

  Future<void> removeVote(String pollId, String userId) async {
    await _firestore.collection('polls').doc(pollId).update({
      'votes.$userId': FieldValue.delete(),
    });
  }
}