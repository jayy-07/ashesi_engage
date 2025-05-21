import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/entities/survey.dart';
import '../../viewmodels/survey_viewmodel.dart';
import 'package:timeago/timeago.dart' as timeago;

class SurveyCard extends StatelessWidget {
  final Survey survey;

  const SurveyCard({
    super.key,
    required this.survey,
  });

  Future<void> _openSurvey(BuildContext context) async {
    if (!survey.isCompleted) {
      final uri = Uri.parse(survey.surveyLink);
      
      if (Theme.of(context).platform == TargetPlatform.android) {
        // Show in WebView for Android
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(survey.title),
              ),
              body: WebViewWidget(
                controller: WebViewController()
                  ..setJavaScriptMode(JavaScriptMode.unrestricted)
                  ..loadRequest(uri),
              ),
            ),
          ),
        );
      } else {
        // Launch in browser for other platforms
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
      
      // Mark as completed after opening
      if (!context.mounted) return;
      try {
        await context.read<SurveyViewModel>().markSurveyAsCompleted(survey.id);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark survey as completed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isExpired = survey.expiresAt.isBefore(now);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isExpired ? null : () => _openSurvey(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            if (survey.imageUrl.isNotEmpty)
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  image: DecorationImage(
                    image: NetworkImage(survey.imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                height: 160,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Center(
                  child: Icon(
                    Icons.analytics,
                    size: 48,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),

            // Content Section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Category badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            survey.category, // Changed from survey.category.name to survey.category
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (survey.isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
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
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      survey.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      survey.description,
                      style: theme.textTheme.bodySmall,
                      maxLines: 4, // Increased maxLines to accommodate more text
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Organized by ${survey.organizer}',
                                style: theme.textTheme.bodySmall,
                              ),
                              if (isExpired)
                                Text(
                                  'Expired ${timeago.format(survey.expiresAt)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                )
                              else
                                Text(
                                  'Expires ${timeago.format(survey.expiresAt, allowFromNow: true)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!isExpired && !survey.isCompleted)
                          FilledButton.icon(
                            onPressed: () => _openSurvey(context),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Take Survey'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}