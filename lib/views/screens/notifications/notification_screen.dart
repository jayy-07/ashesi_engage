import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../models/notification.dart';
import '../../../services/notification_service.dart';
import '../../../widgets/notification_card.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationService = Provider.of<NotificationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () => notificationService.markAllAsRead(),
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: StreamBuilder<List<UserNotification>>(
        stream: notificationService.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const Center(
              child: Text('No notifications'),
            );
          }

          // Group notifications by date
          final groupedNotifications = _groupNotificationsByDate(notifications);

          return ListView.builder(
            itemCount: groupedNotifications.length,
            itemBuilder: (context, index) {
              final date = groupedNotifications.keys.elementAt(index);
              final notificationsForDate = groupedNotifications[date]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _formatDate(date),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  ...notificationsForDate.map((notification) => NotificationCard(
                        notification: notification,
                        onTap: () {
                          notificationService.markAsRead(notification.id);
                          // Handle notification tap based on type
                          _handleNotificationTap(context, notification);
                        },
                        onDismiss: () =>
                            notificationService.deleteNotification(notification.id),
                      )),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Map<DateTime, List<UserNotification>> _groupNotificationsByDate(
      List<UserNotification> notifications) {
    final groups = <DateTime, List<UserNotification>>{};
    
    for (final notification in notifications) {
      final date = DateTime(
        notification.timestamp.year,
        notification.timestamp.month,
        notification.timestamp.day,
      );

      if (!groups.containsKey(date)) {
        groups[date] = [];
      }
      groups[date]!.add(notification);
    }

    return Map.fromEntries(
      groups.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == DateTime(now.year, now.month, now.day)) {
      return 'Today';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else if (now.difference(dateToCheck).inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }

  void _handleNotificationTap(BuildContext context, UserNotification notification) {
    switch (notification.type) {
      case NotificationType.newPoll:
      case NotificationType.pollDeadline:
      case NotificationType.pollResults:
      case NotificationType.pollExpired:
        // Navigate to poll details
        if (notification.data?['pollId'] != null) {
          context.push('/polls/${notification.data!['pollId']}');
        }
        break;
      case NotificationType.proposalEndorsement:
      case NotificationType.proposalEndorsementComplete:
      case NotificationType.proposalReply:
        // Navigate to proposal details
        if (notification.data?['proposalId'] != null) {
          context.push('/proposals/${notification.data!['proposalId']}');
        }
        break;
      case NotificationType.article:
      case NotificationType.system:
        // Handle both article and system notifications that might contain article data
        final data = notification.data;
        if (data != null) {
          final dynamic articleId = data['articleId'];
          if (articleId is String && articleId.isNotEmpty) {
            context.push('/articles/$articleId');
          }
        }
        break;
    }
  }
}