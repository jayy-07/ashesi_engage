import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/entities/poll.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:provider/provider.dart';
import '../../../viewmodels/polls_viewmodel.dart';

class PollCard extends StatelessWidget {
  final Poll poll;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PollCard({
    super.key,
    required this.poll,
    this.onEdit,
    this.onDelete,
  });

  Future<void> _selectNewExpiryDate(BuildContext context) async {
    HapticFeedback.selectionClick();

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

    HapticFeedback.lightImpact();
    context.read<PollsViewModel>().updatePollExpiryDate(poll.id, newExpiryDate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isExpired = now.isAfter(poll.expiresAt);
    final totalVotes = poll.votes.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: isExpired 
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  isExpired ? Icons.timer_off : Icons.timer,
                  size: 16,
                  color: isExpired 
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _selectNewExpiryDate(context),
                  child: Text(
                    isExpired
                      ? 'Ended ${timeago.format(poll.expiresAt)}'
                      : 'Ends ${timeago.format(poll.expiresAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isExpired 
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: isExpired 
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'change_expiry',
                      child: ListTile(
                        leading: const Icon(Icons.schedule),
                        title: const Text('Change Expiry Date'),
                      ),
                    ),
                    if (onEdit != null)
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: const Icon(Icons.edit),
                          title: const Text('Edit Poll'),
                        ),
                      ),
                    if (onDelete != null)
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
                  onSelected: (value) {
                    switch (value) {
                      case 'change_expiry':
                        _selectNewExpiryDate(context);
                        break;
                      case 'edit':
                        HapticFeedback.selectionClick();
                        onEdit?.call();
                        break;
                      case 'delete':
                        HapticFeedback.heavyImpact();
                        onDelete?.call();
                        break;
                    }
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  poll.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  poll.description,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildInfoChip(
                        context,
                        icon: Icons.how_to_vote,
                        label: '$totalVotes votes',
                      ),
                      const SizedBox(width: 8),
                      if (poll.isAllClasses)
                        _buildInfoChip(
                          context,
                          icon: Icons.school,
                          label: 'All Classes',
                        )
                      else
                        _buildInfoChip(
                          context,
                          icon: Icons.school,
                          label: '${poll.classScopes.length} Classes',
                        ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        context,
                        icon: Icons.visibility,
                        label: poll.showRealTimeResults ? 'Live Results' : 'Hidden Results',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Options:',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: poll.options.map((option) {
                        final votesForOption = poll.getVotesForOption(option.id);
                        final percentage = totalVotes > 0
                            ? (votesForOption / totalVotes * 100)
                            : 0.0;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percentage / 100,
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                  minHeight: 8,
                                ),
                              ),
                              Text(
                                '$votesForOption votes (${percentage.toStringAsFixed(1)}%)',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}