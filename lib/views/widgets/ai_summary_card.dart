import 'package:flutter/material.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';

class AISummaryCard extends StatelessWidget {
  final bool isLoading;
  final String? summary;
  final int commentCount;
  final VoidCallback onGenerateSummary;
  final bool hasGeneratedSummary;

  const AISummaryCard({
    super.key,
    required this.isLoading,
    required this.summary,
    required this.commentCount,
    required this.onGenerateSummary,
    required this.hasGeneratedSummary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI-Powered Summary',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (hasGeneratedSummary && summary != null && summary!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: summary!));
                    },
                    tooltip: 'Copy summary',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (commentCount == 0)
              const Text('No comments yet to summarize.')
            else if (isLoading && (summary == null || summary!.isEmpty))
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer(
                    duration: const Duration(milliseconds: 1500),
                    interval: const Duration(milliseconds: 500),
                    color: theme.colorScheme.onSurface,
                    colorOpacity: 0.1,
                    child: Container(
                      height: 12,
                      width: MediaQuery.of(context).size.width * 0.9,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Shimmer(
                    duration: const Duration(milliseconds: 1500),
                    interval: const Duration(milliseconds: 500),
                    color: theme.colorScheme.onSurface,
                    colorOpacity: 0.1,
                    child: Container(
                      height: 12,
                      width: MediaQuery.of(context).size.width * 0.7,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Shimmer(
                    duration: const Duration(milliseconds: 1500),
                    interval: const Duration(milliseconds: 500),
                    color: theme.colorScheme.onSurface,
                    colorOpacity: 0.1,
                    child: Container(
                      height: 12,
                      width: MediaQuery.of(context).size.width * 0.4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              )
            else if (!hasGeneratedSummary && !isLoading)
              Text(
                'Tap "Generate Summary" below to get an AI-powered overview of the discussion.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else if (summary != null && summary!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: summary!,
                    selectable: false,
                    styleSheet: MarkdownStyleSheet(
                      p: theme.textTheme.bodyMedium,
                      listBullet: theme.textTheme.bodyMedium,
                      h5: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textScaler: const TextScaler.linear(1.0),
                      blockSpacing: 8.0,
                      listIndent: 16.0,
                    ),
                  ),
                  // Show cursor indicator if still loading
                  if (isLoading)
                    Row(
                      children: [
                        Text(
                          '_',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        BlinkingCursor(),
                      ],
                    ),
                ],
              )
            else
              Text(
                'Unable to generate summary at this time.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Blinking cursor animation for text generation effect
class BlinkingCursor extends StatefulWidget {
  const BlinkingCursor({super.key});

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Text(
        '|',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
