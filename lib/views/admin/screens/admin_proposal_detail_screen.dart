import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import '../../../models/entities/student_proposal.dart';
import '../../../models/entities/comment.dart';
import '../../../viewmodels/admin_proposal_details_viewmodel.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/ai_summary_card.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../models/services/proposal_service.dart';
import '../widgets/admin_comment_tile.dart';
import '../widgets/proposal_sentiment_stats_card.dart';

class AdminProposalDetailScreen extends StatefulWidget {
  final StudentProposal proposal;
  final String? highlightCommentId;  // Add this parameter

  const AdminProposalDetailScreen({
    super.key,
    required this.proposal,
    this.highlightCommentId,  // Add this parameter
  });

  @override
  State<AdminProposalDetailScreen> createState() => _AdminProposalDetailScreenState();
}

class _AdminProposalDetailScreenState extends State<AdminProposalDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ChangeNotifierProvider(
      create: (context) => AdminProposalDetailsViewModel(widget.proposal, context, ProposalService()),
      child: Consumer<AdminProposalDetailsViewModel>(
        builder: (context, viewModel, child) => Scaffold(
          appBar: AppBar(
            title: const Text('Proposal'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete Proposal',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Proposal'),
                      content: const Text('Are you sure you want to delete this proposal? This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CANCEL'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                          ),
                          onPressed: () async {
                            try {
                              Navigator.pop(context); // Close dialog
                              await viewModel.deleteProposal();
                              if (context.mounted) {
                                Navigator.pop(context); // Go back to proposals list
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Proposal deleted successfully'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to delete proposal: $e'),
                                    backgroundColor: theme.colorScheme.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('DELETE'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          body: Row(
            children: [
              // Left side - Proposal content
              Expanded(
                flex: 3,
                child: _ProposalContent(proposal: widget.proposal),
              ),
              // Vertical divider
              const VerticalDivider(width: 1),
              // Right side - Comments
              Expanded(
                flex: 2,
                child: _CommentsSection(
                  highlightCommentId: widget.highlightCommentId,  // Pass the parameter
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProposalContent extends StatelessWidget {
  final StudentProposal proposal;

  const _ProposalContent({required this.proposal});

  Widget _buildSentimentChip(BuildContext context) {
    if (proposal.sentimentScore == null || proposal.sentimentMagnitude == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final interpretation = proposal.sentimentInterpretation;
    if (interpretation == null) return const SizedBox.shrink();

    final parts = interpretation.split(' | ');
    if (parts.length != 2) return const SizedBox.shrink();

    final sentiment = parts[0];
    final intensity = parts[1];

    Color getChipColor() {
      if (proposal.sentimentScore! >= 0.5) {
        return Colors.green.withValues(alpha:0.2);
      } else if (proposal.sentimentScore! > 0.1) {
        return Colors.lightGreen.withValues(alpha:0.2);
      } else if (proposal.sentimentScore! >= -0.1) {
        return Colors.grey.withValues(alpha:0.2);
      } else if (proposal.sentimentScore! >= -0.5) {
        return Colors.orange.withValues(alpha:0.2);
      } else {
        return Colors.red.withValues(alpha:0.2);
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: getChipColor(),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sentiment,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '|',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha:0.5),
                  ),
                ),
              ),
              Text(
                intensity,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline, size: 16),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          tooltip: '''
Score (${proposal.sentimentScore?.toStringAsFixed(2)}): Indicates the overall emotional leaning
• -1.0 to -0.5: Very Negative
• -0.5 to -0.1: Negative
• -0.1 to 0.1: Neutral
• 0.1 to 0.5: Positive
• 0.5 to 1.0: Very Positive

Magnitude (${proposal.sentimentMagnitude?.toStringAsFixed(2)}): Measures emotional intensity
• 0.0 to 1.0: Mild emotion
• 1.0 to 2.0: Moderate emotion
• 2.0+: Strong emotion''',
          onPressed: () {},
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<AdminProposalDetailsViewModel>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                imageUrl: proposal.authorAvatar,
                radius: 24,
                fallbackInitial: proposal.authorName.substring(0, 1),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proposal.authorName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      proposal.authorClass,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              if (proposal.answeredAt != null)
                Chip(
                  label: const Text('Answered'),
                  avatar: const Icon(Icons.check_circle_outline, size: 18),
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  labelStyle: TextStyle(color: theme.colorScheme.onSecondaryContainer),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  proposal.title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildSentimentChip(context),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: QuillEditor(
              controller: QuillController.basic()..document = Document.fromJson(proposal.content['ops'] as List),
              scrollController: ScrollController(),
              focusNode: FocusNode(),
              configurations: QuillEditorConfigurations(
                enableInteractiveSelection: false,
                showCursor: false,
                padding: EdgeInsets.zero,
                autoFocus: false,
                expands: false,
                scrollable: false,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            timeago.format(proposal.datePosted),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          if (proposal.answeredAt != null) ...[
            const Divider(),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(
                  Icons.question_answer_outlined,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Official Response',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    final controller = QuillController.basic();
                    if (proposal.answer != null) {
                      controller.document = Document.fromJson(proposal.answer!['ops'] as List);
                    }
                    final focusNode = FocusNode();
                    final scrollController = ScrollController();
                    bool isSending = false;

                    showDialog(
                      context: context,
                      builder: (context) => StatefulBuilder(
                        builder: (context, setState) => Dialog(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 800,
                              maxHeight: 800,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Edit Response',
                                        style: theme.textTheme.titleLarge,
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          proposal.title,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          proposal.plainContent,
                                          style: theme.textTheme.bodyMedium,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Your Response',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  QuillToolbar.simple(
                                    controller: controller,
                                    configurations: QuillSimpleToolbarConfigurations(
                                      showFontFamily: false,
                                      showFontSize: false,
                                      showBackgroundColorButton: false,
                                      showClearFormat: false,
                                      showColorButton: false,
                                      showCodeBlock: false,
                                      showQuote: false,
                                      showSubscript: false,
                                      showSuperscript: false,
                                      showSearchButton: false,
                                      showAlignmentButtons: false,
                                      showHeaderStyle: false,
                                      showIndent: false,
                                      showLink: false,
                                      showInlineCode: false,
                                      showDirection: false,
                                      showDividers: false,
                                      showStrikeThrough: false,
                                      showListCheck: false,
                                      showClipboardCopy: false,
                                      showClipboardCut: false,
                                      showClipboardPaste: false,
                                      multiRowsDisplay: false,
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: theme.colorScheme.outline,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: QuillEditor(
                                        controller: controller,
                                        scrollController: scrollController,
                                        focusNode: focusNode,
                                        configurations: QuillEditorConfigurations(
                                          padding: const EdgeInsets.all(16),
                                          autoFocus: true,
                                          expands: false,
                                          scrollable: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('CANCEL'),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton(
                                        onPressed: isSending ? null : () async {
                                          final plainAnswer = controller.document.toPlainText().trim();
                                          if (plainAnswer.isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Please write a response')),
                                            );
                                            return;
                                          }

                                          // Get the Delta for formatted text
                                          final delta = controller.document.toDelta();
                                          // Ensure it ends with newline
                                          if (!plainAnswer.endsWith('\n')) {
                                            delta.insert('\n');
                                          }

                                          setState(() => isSending = true);
                                          try {
                                            await viewModel.answerProposal(
                                              proposal.id,
                                              delta,
                                              viewModel.currentAdminId,
                                            );
                                            if (context.mounted) {
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Response updated successfully'),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor: theme.colorScheme.error,
                                                ),
                                              );
                                            }
                                          } finally {
                                            if (context.mounted) {
                                              setState(() => isSending = false);
                                            }
                                          }
                                        },
                                        child: const Text('UPDATE'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Response'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(alpha:0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: QuillEditor(
                controller: QuillController.basic()..document = Document.fromJson(proposal.answer?['ops'] as List? ?? []),
                scrollController: ScrollController(),
                focusNode: FocusNode(),
                configurations: QuillEditorConfigurations(
                  enableInteractiveSelection: false,
                  showCursor: false,
                  padding: EdgeInsets.zero,
                  autoFocus: false,
                  expands: false,
                  scrollable: false,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Answered ${timeago.format(proposal.answeredAt!)}',
              style: theme.textTheme.bodySmall,
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: () {
                final controller = QuillController.basic();
                final focusNode = FocusNode();
                final scrollController = ScrollController();
                bool isSending = false;

                showDialog(
                  context: context,
                  builder: (context) => StatefulBuilder(
                    builder: (context, setState) => Dialog(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 800,
                          maxHeight: 800,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Answer Proposal',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      proposal.title,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      proposal.plainContent,
                                      style: theme.textTheme.bodyMedium,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Your Response',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              QuillToolbar.simple(
                                controller: controller,
                                configurations: QuillSimpleToolbarConfigurations(
                                  showFontFamily: false,
                                  showFontSize: false,
                                  showBackgroundColorButton: false,
                                  showClearFormat: false,
                                  showColorButton: false,
                                  showCodeBlock: false,
                                  showQuote: false,
                                  showSubscript: false,
                                  showSuperscript: false,
                                  showSearchButton: false,
                                  showAlignmentButtons: false,
                                  showHeaderStyle: false,
                                  showIndent: false,
                                  showLink: false,
                                  showInlineCode: false,
                                  showDirection: false,
                                  showDividers: false,
                                  showStrikeThrough: false,
                                  showListCheck: false,
                                  showClipboardCopy: false,
                                  showClipboardCut: false,
                                  showClipboardPaste: false,
                                  multiRowsDisplay: false,
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: theme.colorScheme.outline,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: QuillEditor(
                                    controller: controller,
                                    scrollController: scrollController,
                                    focusNode: focusNode,
                                    configurations: QuillEditorConfigurations(
                                      padding: const EdgeInsets.all(16),
                                      autoFocus: true,
                                      expands: false,
                                      scrollable: true,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('CANCEL'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: isSending ? null : () async {
                                      final plainAnswer = controller.document.toPlainText().trim();
                                      if (plainAnswer.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please write a response')),
                                        );
                                        return;
                                      }

                                      // Get the Delta for formatted text
                                      final delta = controller.document.toDelta();
                                      // Ensure it ends with newline
                                      if (!plainAnswer.endsWith('\n')) {
                                        delta.insert('\n');
                                      }

                                      setState(() => isSending = true);
                                      try {
                                        await viewModel.answerProposal(
                                          proposal.id,
                                          delta,
                                          viewModel.currentAdminId,
                                        );
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Response submitted successfully'),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: theme.colorScheme.error,
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (context.mounted) {
                                          setState(() => isSending = false);
                                        }
                                      }
                                    },
                                    child: const Text('SUBMIT'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.question_answer_outlined),
              label: const Text('Answer Proposal'),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(height: 32),
          AISummaryCard(
            isLoading: viewModel.isLoadingAISummary,
            summary: viewModel.aiSummary,
            commentCount: viewModel.comments.length,
            onGenerateSummary: viewModel.generateSummary,
            hasGeneratedSummary: viewModel.hasGeneratedSummary,
          ),
          if (!viewModel.hasGeneratedSummary && 
            !viewModel.isLoadingAISummary && 
            viewModel.comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: viewModel.generateSummary,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate Summary'),
                ),
              ),
            ),
          const SizedBox(height: 24),
          ProposalSentimentStatsCard(
            comments: viewModel.comments,
            proposalSentimentScore: proposal.sentimentScore,
            proposalSentimentMagnitude: proposal.sentimentMagnitude,
          ),
        ],
      ),
    );
  }
}

class _CommentsSection extends StatefulWidget {
  final String? highlightCommentId;  // Add this parameter

  const _CommentsSection({
    this.highlightCommentId,
  });

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Set<String> selectedClasses = {};
  Set<String> selectedSentiments = {};
  Set<String> selectedMagnitudes = {};

  final sentimentRanges = {
    'Very Positive': (0.5, 1.0),
    'Positive': (0.1, 0.5),
    'Neutral': (-0.1, 0.1),
    'Negative': (-0.5, -0.1),
    'Very Negative': (-1.0, -0.5),
  };

  final magnitudeRanges = {
    'Mild': (0.0, 1.0),
    'Moderate': (1.0, 2.0),
    'Strong': (2.0, double.infinity),
  };

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    
    // Handle highlighting when comments are loaded
    if (widget.highlightCommentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final viewModel = context.read<AdminProposalDetailsViewModel>();
        if (!viewModel.isLoadingComments && viewModel.comments.isNotEmpty) {
          _scrollToHighlightedComment();
        }
      });
    }
  }

  void _scrollToHighlightedComment() {
    if (widget.highlightCommentId == null) return;

    final viewModel = context.read<AdminProposalDetailsViewModel>();
    final highlightedComment = viewModel.comments.firstWhere(
      (c) => c.id == widget.highlightCommentId,
      orElse: () => viewModel.comments.first,
    );

    // Use a short delay to ensure the ListView is built
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      final index = viewModel.comments.indexOf(highlightedComment);
      if (index != -1) {
        _scrollController.animateTo(
          index * 120.0, // Approximate height of each comment tile
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // Filter comments based on search text and selected filters
  List<Comment> _getFilteredComments(List<Comment> comments) {
    return comments.where((comment) {
      // Search by text content
      final matchesSearch = _searchController.text.isEmpty ||
          comment.content.toLowerCase().contains(_searchController.text.toLowerCase());

      // Filter by class
      final matchesClass = selectedClasses.isEmpty ||
          selectedClasses.contains(comment.authorClass);

      // Filter by sentiment score
      final matchesSentiment = selectedSentiments.isEmpty ||
          selectedSentiments.any((sentiment) {
            final range = sentimentRanges[sentiment]!;
            return comment.sentimentScore != null &&
                comment.sentimentScore! >= range.$1 &&
                comment.sentimentScore! <= range.$2;
          });

      // Filter by sentiment magnitude
      final matchesMagnitude = selectedMagnitudes.isEmpty ||
          selectedMagnitudes.any((magnitude) {
            final range = magnitudeRanges[magnitude]!;
            return comment.sentimentMagnitude != null &&
                comment.sentimentMagnitude! >= range.$1 &&
                comment.sentimentMagnitude! < range.$2;
          });

      return matchesSearch && matchesClass && matchesSentiment && matchesMagnitude;
    }).toList();
  }

  // Build filter chips for a given set of options
  Widget _buildFilterChips({
    required String title,
    required List<String> options,
    required Set<String> selectedValues,
    required Function(String) onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: options.map((option) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text(option),
                  selected: selectedValues.contains(option),
                  onSelected: (selected) => onSelected(option),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<AdminProposalDetailsViewModel>();
    
    // Get unique classes from comments
    final classes = viewModel.comments
        .map((c) => c.authorClass)
        .toSet()
        .toList()
      ..sort();

    final filteredComments = _getFilteredComments(viewModel.comments);
    final hasComments = viewModel.comments.isNotEmpty;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Comments',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${filteredComments.length}/${viewModel.comments.length}',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: viewModel.isLoadingComments
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: _scrollController,  // Add scroll controller
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (hasComments) ...[
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search comments...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      // Filters
                      _buildFilterChips(
                        title: 'Class',
                        options: classes,
                        selectedValues: selectedClasses,
                        onSelected: (value) => setState(() {
                          if (selectedClasses.contains(value)) {
                            selectedClasses.remove(value);
                          } else {
                            selectedClasses.add(value);
                          }
                        }),
                      ),
                      _buildFilterChips(
                        title: 'Sentiment',
                        options: sentimentRanges.keys.toList(),
                        selectedValues: selectedSentiments,
                        onSelected: (value) => setState(() {
                          if (selectedSentiments.contains(value)) {
                            selectedSentiments.remove(value);
                          } else {
                            selectedSentiments.add(value);
                          }
                        }),
                      ),
                      _buildFilterChips(
                        title: 'Magnitude',
                        options: magnitudeRanges.keys.toList(),
                        selectedValues: selectedMagnitudes,
                        onSelected: (value) => setState(() {
                          if (selectedMagnitudes.contains(value)) {
                            selectedMagnitudes.remove(value);
                          } else {
                            selectedMagnitudes.add(value);
                          }
                        }),
                      ),
                    ],
                    if (!hasComments && !viewModel.isLoadingComments)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'No comments yet',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    // Comments list
                    ...filteredComments.map((comment) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AdminCommentTile(
                        key: ValueKey(comment.id),
                        comment: comment,
                        onDelete: () => viewModel.deleteComment(comment.id),
                        isHighlighted: widget.highlightCommentId == comment.id,  // Add highlighting
                      ),
                    )),
                  ],
                ),
        ),
      ],
    );
  }
}