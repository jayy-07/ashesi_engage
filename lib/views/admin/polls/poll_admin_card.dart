import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/entities/poll.dart';
import '../../../viewmodels/admin_polls_viewmodel.dart';
import 'poll_analytics_screen.dart';

class PollAdminCard extends StatelessWidget {
  final Poll poll;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;

  const PollAdminCard({
    super.key,
    required this.poll,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isExpired = poll.expiresAt.isBefore(now);
    final totalVotes = poll.votes.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isSelectionMode 
            ? () => onSelected?.call(!isSelected)
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChangeNotifierProvider.value(
                    value: context.read<AdminPollsViewModel>(),
                    child: PollAnalyticsScreen(poll: poll),
                  ),
                ),
              ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    poll.title,
                                    style: theme.textTheme.titleLarge,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isExpired)
                                  Chip(
                                    label: const Text('Expired'),
                                    backgroundColor: theme.colorScheme.errorContainer,
                                    labelStyle: TextStyle(
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              poll.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (!isSelectionMode)
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'analytics',
                              child: ListTile(
                                leading: const Icon(Icons.analytics),
                                title: const Text('View Analytics'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'change_expiry',
                              child: ListTile(
                                leading: const Icon(Icons.schedule),
                                title: const Text('Change Expiry Date'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'toggle_realtime',
                              child: ListTile(
                                leading: Icon(
                                  poll.showRealTimeResults 
                                      ? Icons.visibility 
                                      : Icons.visibility_off,
                                ),
                                title: Text(
                                  '${poll.showRealTimeResults ? 'Hide' : 'Show'} Real-time Results',
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'toggle_final',
                              child: ListTile(
                                leading: Icon(
                                  poll.showResultsAfterEnd 
                                      ? Icons.visibility 
                                      : Icons.visibility_off,
                                ),
                                title: Text(
                                  '${poll.showResultsAfterEnd ? 'Hide' : 'Show'} Final Results',
                                ),
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: theme.colorScheme.error,
                                ),
                                title: Text(
                                  'Delete Poll',
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          onSelected: (value) => _handleMenuAction(context, value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (poll.options.isNotEmpty) ...[
                    Text(
                      'Results:',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ...poll.options.map((option) {
                      final votes = poll.getVotesForOption(option.id);
                      final percentage = totalVotes > 0 ? votes / totalVotes * 100 : 0;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option.text,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                Text(
                                  '$votes votes',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                minHeight: 6,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, y HH:mm').format(poll.expiresAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.how_to_vote,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$totalVotes votes',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (!poll.isAllClasses) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.school,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${poll.classScopes.length} classes',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isSelectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? theme.colorScheme.primary : null,
                  ),
                  onPressed: () => onSelected?.call(!isSelected),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String value) async {
    switch (value) {
      case 'analytics':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChangeNotifierProvider.value(
              value: context.read<AdminPollsViewModel>(),
              child: PollAnalyticsScreen(poll: poll),
            ),
          ),
        );
        break;
      case 'change_expiry':
        _selectNewExpiryDate(context);
        break;
      case 'toggle_realtime':
        context.read<AdminPollsViewModel>().toggleRealTimeResults(
          poll.id,
          !poll.showRealTimeResults,
        );
        break;
      case 'toggle_final':
        context.read<AdminPollsViewModel>().toggleResultsAfterEnd(
          poll.id,
          !poll.showResultsAfterEnd,
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Poll'),
            content: const Text('Are you sure you want to delete this poll?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () {
                  context.read<AdminPollsViewModel>().deletePoll(poll.id);
                  Navigator.pop(context);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        break;
    }
  }

  Future<void> _selectNewExpiryDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: poll.expiresAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;

    // ignore: use_build_context_synchronously
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(poll.expiresAt),
    );
    if (time == null) return;

    final newExpiryDate = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    // ignore: use_build_context_synchronously
    context.read<AdminPollsViewModel>().updatePollExpiryDate(poll.id, newExpiryDate);
  }
}