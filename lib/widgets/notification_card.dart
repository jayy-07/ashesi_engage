import 'package:flutter/material.dart';
import '../models/notification.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationCard extends StatelessWidget {
  final UserNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const NotificationCard({
    Key? key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16.0),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: Material(
        color: notification.isRead
            ? null
            : Theme.of(context).colorScheme.primary.withValues(alpha:0.1),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIcon(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getNotificationTitle(),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight:
                                  notification.isRead ? null : FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeago.format(notification.timestamp),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color? color;

    switch (notification.type) {
      case NotificationType.newPoll:
        icon = Icons.poll;
        color = Colors.blue;
        break;
      case NotificationType.pollDeadline:
        icon = Icons.timer;
        color = Colors.orange;
        break;
      case NotificationType.pollResults:
        icon = Icons.bar_chart;
        color = Colors.green;
        break;
      case NotificationType.pollExpired:
        icon = Icons.timer_off;
        color = Colors.red;
        break;
      case NotificationType.proposalEndorsement:
        icon = Icons.thumb_up;
        color = Colors.purple;
        break;
      case NotificationType.proposalEndorsementComplete:
        icon = Icons.verified;
        color = Colors.green;
        break;
      case NotificationType.proposalReply:
        icon = Icons.reply;
        color = Colors.blue;
        break;
      case NotificationType.article:
        icon = Icons.newspaper;
        color = Colors.green;
        break;
      case NotificationType.system:
        icon = Icons.info;
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color?.withValues(alpha:0.1),
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }

  String _getNotificationTitle() {
    switch (notification.type) {
      case NotificationType.newPoll:
        return 'New Poll Available';
      case NotificationType.pollDeadline:
        return 'Poll Closing Soon';
      case NotificationType.pollResults:
        return 'Poll Results';
      case NotificationType.pollExpired:
        return 'Poll Expired';
      case NotificationType.proposalEndorsement:
        return 'Proposal Milestone';
      case NotificationType.proposalEndorsementComplete:
        return 'Endorsement Complete';
      case NotificationType.proposalReply:
        return 'New Reply';
      case NotificationType.article:
        return 'New Article';
      case NotificationType.system:
        return 'System Notification';
    }
  }
}