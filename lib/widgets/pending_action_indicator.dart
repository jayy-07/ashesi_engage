import 'package:flutter/material.dart';
import '../viewmodels/mixins/offline_action_mixin.dart';

class PendingActionIndicator extends StatelessWidget {
  final bool hasPendingActions;
  final VoidCallback? onTap;

  const PendingActionIndicator({
    super.key,
    required this.hasPendingActions,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasPendingActions) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha:0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sync_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              'Pending sync',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PendingActionsList extends StatelessWidget {
  final List<PendingAction> actions;
  final bool isSyncing;
  final VoidCallback? onRetry;

  const PendingActionsList({
    super.key,
    required this.actions,
    required this.isSyncing,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const Center(
        child: Text('No pending actions'),
      );
    }

    return Column(
      children: [
        if (isSyncing)
          const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return ListTile(
                leading: const Icon(Icons.sync_rounded),
                title: Text(_getActionTitle(action.type)),
                subtitle: Text(
                  'Created ${_formatDate(action.createdAt)}',
                ),
                trailing: isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              );
            },
          ),
        ),
        if (!isSyncing && onRetry != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry Sync'),
            ),
          ),
      ],
    );
  }

  String _getActionTitle(String type) {
    switch (type) {
      case 'endorse':
        return 'Pending endorsement';
      case 'upvote':
        return 'Pending upvote';
      case 'bookmark':
        return 'Pending bookmark';
      case 'post':
        return 'Pending post';
      case 'survey':
        return 'Pending survey completion';
      default:
        return 'Pending action';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
} 