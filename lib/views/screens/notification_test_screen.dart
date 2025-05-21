import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../services/poll_service.dart';
import '../../models/entities/poll.dart';

class NotificationTestScreen extends StatelessWidget {
  final NotificationService _notificationService = NotificationService();
  final PollService _pollService = PollService();

  NotificationTestScreen({super.key});

  Future<void> _testLocalNotification(BuildContext context) async {
    await _notificationService.showPollNotification(
      title: 'Test Local Notification',
      body: 'This is a test notification',
      payload: {
        'type': 'test',
        'pollId': 'test-id',
      },
    );
    _showSnackBar(context, 'Local notification sent');
  }

  Future<void> _testDeadlineNotification(BuildContext context) async {
    await _notificationService.showPollDeadlineNotification(
      title: 'Test Deadline Notification',
      body: 'This poll is closing in 1 hour',
      payload: {
        'type': 'poll_deadline',
        'pollId': 'test-id',
      },
    );
    _showSnackBar(context, 'Deadline notification sent');
  }

  Future<void> _testFCMWithNewPoll(BuildContext context) async {
    try {
      // Create a test poll that expires in 2 hours
      final poll = Poll(
        id: 'test-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Test FCM Poll',
        description: 'This is a test poll created to verify FCM notifications',
        createdBy: 'test-user',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
        options: [
          PollOption(id: '1', text: 'Option 1'),
          PollOption(id: '2', text: 'Option 2'),
        ],
        votes: {},
        showRealTimeResults: true,
        showResultsAfterEnd: true,
        finalResultsDuration: 24,
        isAllClasses: true,
        classScopes: [],
        isActive: true,
        isReversible: true,
      );

      await _pollService.createPoll(poll);
      _showSnackBar(context, 'Test poll created, FCM notification should arrive shortly');
    } catch (e) {
      _showSnackBar(context, 'Error creating test poll: $e');
    }
  }

  Future<void> _testPendingNotifications(BuildContext context) async {
    await _pollService.checkForPendingNotifications();
    _showSnackBar(context, 'Checked for pending notifications');
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Notifications'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Notification Test Panel',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => _testLocalNotification(context),
                icon: const Icon(Icons.notifications),
                label: const Text('Test Local Notification'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _testDeadlineNotification(context),
                icon: const Icon(Icons.alarm),
                label: const Text('Test Deadline Notification'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _testFCMWithNewPoll(context),
                icon: const Icon(Icons.cloud),
                label: const Text('Test FCM with New Poll'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _testPendingNotifications(context),
                icon: const Icon(Icons.refresh),
                label: const Text('Check Pending Notifications'),
              ),
              const SizedBox(height: 32),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Testing Instructions:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Local Notification - Tests basic local notification\n'
                        '2. Deadline Notification - Tests deadline alert format\n'
                        '3. FCM Test - Creates a poll to trigger FCM\n'
                        '4. Check Pending - Manually checks for notifications\n\n'
                        'Note: FCM notifications may take a few moments to arrive',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}