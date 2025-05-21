import 'package:flutter/material.dart';
import '../../../models/entities/survey.dart';
import '../../../viewmodels/survey_viewmodel.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'create_survey_screen.dart';

class SurveyCard extends StatelessWidget {
  final Survey survey;
  final bool isSelectionMode;
  final bool isSelected;
  final Function(bool)? onSelected;

  const SurveyCard({
    super.key,
    required this.survey,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelected,
  });

  void _handleMenuAction(BuildContext context, String value) async {
    final viewModel = context.read<SurveyViewModel>();

    switch (value) {
      case 'delete':
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Survey'),
            content: const Text(
              'Are you sure you want to delete this survey? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCEL'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('DELETE'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          try {
            await viewModel.deleteSurvey(survey.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Survey deleted successfully')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to delete survey: $e')),
              );
            }
          }
        }
        break;

      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateSurveyScreen(survey: survey),
            fullscreenDialog: true,
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isExpired = survey.expiresAt.isBefore(now);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Survey Image - Reducing height to accommodate content
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  image: survey.imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(survey.imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: survey.imageUrl.isEmpty
                    ? Center(
                        child: Icon(
                          Icons.analytics,
                          size: 48,
                          color: theme.colorScheme.outline,
                        ),
                      )
                    : null,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), // Reduced padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          // Category badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2, // Reduced vertical padding
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              survey.category,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // More menu or selection indicator
                          if (!isSelectionMode)
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero, // Remove padding
                              icon: Icon(
                                Icons.more_vert,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 20, // Slightly smaller icon
                              ),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Edit'),
                                    dense: true,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.delete_outline,
                                      color: theme.colorScheme.error,
                                    ),
                                    title: Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                    dense: true,
                                  ),
                                ),
                              ],
                              onSelected: (value) => _handleMenuAction(context, value),
                            )
                          else
                            IconButton(
                              padding: EdgeInsets.zero, // Remove padding
                              icon: Icon(
                                isSelected ? Icons.check_circle : Icons.circle_outlined,
                                color: isSelected ? theme.colorScheme.primary : null,
                                size: 20, // Slightly smaller icon
                              ),
                              onPressed: () => onSelected?.call(!isSelected),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4), // Reduced spacing
                      Text(
                        survey.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2), // Reduced spacing
                      Flexible(
                        child: Text(
                          survey.description,
                          style: theme.textTheme.bodySmall,
                          maxLines: 3, // Increased maxLines to accommodate more text
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4), // Reduced spacing
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Created ${timeago.format(survey.createdAt)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11, // Slightly smaller text
                                  ),
                                ),
                                if (isExpired)
                                  Text(
                                    'Expired ${timeago.format(survey.expiresAt)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.error,
                                      fontSize: 11, // Slightly smaller text
                                    ),
                                  )
                                else
                                  Text(
                                    'Expires ${timeago.format(survey.expiresAt, allowFromNow: true)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontSize: 11, // Slightly smaller text
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (survey.isAllClasses)
                            Text(
                              'All Classes',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontSize: 11, // Slightly smaller text
                              ),
                            )
                          else
                            Text(
                              '${survey.classScopes.length} Classes',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11, // Slightly smaller text
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (survey.isCompleted)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Completed',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}