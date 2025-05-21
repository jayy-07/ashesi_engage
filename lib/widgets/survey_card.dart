import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../models/entities/survey.dart';
import '../viewmodels/survey_viewmodel.dart';

class SurveyCard extends StatelessWidget {
  final Survey survey;

  const SurveyCard({
    super.key,
    required this.survey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isExpired = survey.expiresAt.isBefore(now);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (survey.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  survey.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
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
                          Text(
                            survey.title,
                            style: theme.textTheme.titleLarge,
                          ),
                          if (survey.organizer.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'By ${survey.organizer}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  survey.description,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (survey.category.isNotEmpty) Row(
                  children: [
                    Icon(
                      Icons.category,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      survey.category,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () {
                        final viewModel = context.read<SurveyViewModel>();
                        viewModel.markSurveyAsCompleted(survey.id);
                      },
                      icon: Icon(
                        survey.isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                      ),
                      label: Text(survey.isCompleted ? 'Completed' : 'Mark Complete'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _launchSurvey(context),
                      icon: const Icon(Icons.launch),
                      label: const Text('Take Survey'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchSurvey(BuildContext context) async {
    final uri = Uri.parse(survey.surveyLink);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open survey link'),
          ),
        );
      }
    }
  }
} 