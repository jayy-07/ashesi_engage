import 'package:flutter/material.dart';
import '../../../models/entities/discussion_comment.dart';

class SentimentStatsCard extends StatelessWidget {
  final List<DiscussionComment> comments;
  final double? proposalSentimentScore;
  final double? proposalSentimentMagnitude;

  const SentimentStatsCard({
    super.key,
    required this.comments,
    this.proposalSentimentScore,
    this.proposalSentimentMagnitude,
  });

  Widget _buildSentimentDistribution(BuildContext context) {
    final theme = Theme.of(context);
    final commentsWithSentiment = comments.where((c) => c.sentimentScore != null).toList();
    
    if (commentsWithSentiment.isEmpty) {
      return const Center(
        child: Text('No sentiment data available'),
      );
    }

    int veryPositive = 0;
    int positive = 0;
    int neutral = 0;
    int negative = 0;
    int veryNegative = 0;

    for (final comment in commentsWithSentiment) {
      final score = comment.sentimentScore!;
      if (score >= 0.5) {
        veryPositive++;
      } else if (score > 0.1) {
        positive++;
      } else if (score >= -0.1) {
        neutral++;
      } else if (score >= -0.5) {
        negative++;
      } else {
        veryNegative++;
      }
    }

    final total = commentsWithSentiment.length.toDouble();
    final barHeight = 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comment Sentiment Distribution',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 16),
        _buildSentimentBar(
          'Very Positive',
          veryPositive / total,
          Colors.green,
          '$veryPositive',
          barHeight,
          theme,
        ),
        const SizedBox(height: 8),
        _buildSentimentBar(
          'Positive',
          positive / total,
          Colors.lightGreen,
          '$positive',
          barHeight,
          theme,
        ),
        const SizedBox(height: 8),
        _buildSentimentBar(
          'Neutral',
          neutral / total,
          Colors.grey,
          '$neutral',
          barHeight,
          theme,
        ),
        const SizedBox(height: 8),
        _buildSentimentBar(
          'Negative',
          negative / total,
          Colors.orange,
          '$negative',
          barHeight,
          theme,
        ),
        const SizedBox(height: 8),
        _buildSentimentBar(
          'Very Negative',
          veryNegative / total,
          Colors.red,
          '$veryNegative',
          barHeight,
          theme,
        ),
      ],
    );
  }

  Widget _buildSentimentBar(
    String label,
    double percentage,
    Color color,
    String count,
    double height,
    ThemeData theme,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage,
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha:0.2),
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            count,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sentiment Analysis',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (proposalSentimentScore != null && proposalSentimentMagnitude != null) ...[
              const SizedBox(height: 16),
              Text(
                'Discussion Sentiment',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Score',
                      proposalSentimentScore!.toStringAsFixed(2),
                      'Indicates overall emotional leaning (-1 to +1)',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Magnitude',
                      proposalSentimentMagnitude!.toStringAsFixed(2),
                      'Indicates emotional intensity (0+)',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            _buildSentimentDistribution(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    String description,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
} 