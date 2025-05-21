import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../models/entities/student_proposal.dart';
import '../../widgets/user_avatar.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import '../screens/admin_proposal_detail_screen.dart';

class AdminProposalCard extends StatelessWidget {
  final StudentProposal proposal;
  final VoidCallback onDelete;
  final Future<void> Function(Delta answer) onAnswer;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;

  const AdminProposalCard({
    super.key,
    required this.proposal,
    required this.onDelete,
    required this.onAnswer,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelected,
  });

  // Generate a sentiment score between 0 and 1 based on proposal data
  // This is just a placeholder implementation
  double _generateSentimentScore() {
    final hash = proposal.id.hashCode + proposal.title.hashCode;
    return (hash.abs() % 100) / 100;
  }

  Color _getSentimentColor(BuildContext context, double score) {
    if (score >= 0.7) {
      return Colors.green;
    } else if (score >= 0.4) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentimentScore = _generateSentimentScore();
    final sentimentColor = _getSentimentColor(context, sentimentScore);

    return Card(
      elevation: 0,
      child: InkWell(
        onTap: isSelectionMode ? () => onSelected?.call(!isSelected) : () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminProposalDetailScreen(proposal: proposal),
            ),
          );
        },
        child: Stack(
          children: [
            if (isSelectionMode)
              Positioned(
                top: 12,
                right: 12,
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserAvatar(
                        imageUrl: proposal.authorAvatar,
                        radius: 20,
                        fallbackInitial: proposal.authorName.substring(0, 1),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    proposal.authorName,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (proposal.answeredAt != null)
                                  Chip(
                                    label: const Text('Answered'),
                                    avatar: const Icon(Icons.check_circle_outline, size: 18),
                                    backgroundColor: theme.colorScheme.secondaryContainer,
                                    labelStyle: TextStyle(
                                      color: theme.colorScheme.onSecondaryContainer,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  proposal.authorClass,
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '•',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  timeago.format(proposal.datePosted),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isSelectionMode)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem<String>(
                              value: proposal.answeredAt != null ? 'edit' : 'answer',
                              child: ListTile(
                                leading: Icon(proposal.answeredAt != null 
                                  ? Icons.edit_outlined
                                  : Icons.question_answer_outlined
                                ),
                                title: Text(proposal.answeredAt != null ? 'Edit Answer' : 'Answer'),
                                dense: true,
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete_outline),
                                title: Text('Delete'),
                                dense: true,
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'delete') {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Proposal'),
                                  content: const Text(
                                    'Are you sure you want to delete this proposal? This action cannot be undone.'
                                  ),
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
                                      onPressed: () {
                                        Navigator.pop(context);
                                        onDelete();
                                      },
                                      child: const Text('DELETE'),
                                    ),
                                  ],
                                ),
                              );
                            } else if (value == 'answer' || value == 'edit') {
                              final controller = QuillController.basic();
                              if (proposal.answeredAt != null && proposal.answer != null) {
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
                                                  value == 'answer' ? 'Answer Proposal' : 'Edit Answer',
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
                                              'Your Answer',
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
                                                        const SnackBar(content: Text('Please write an answer')),
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
                                                      await onAnswer(delta);
                                                      if (context.mounted) {
                                                        Navigator.pop(context);
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              value == 'answer' 
                                                                ? 'Proposal answered successfully'
                                                                : 'Answer updated successfully'
                                                            ),
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
                                                  child: Text(value == 'answer' ? 'SUBMIT' : 'UPDATE'),
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
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    proposal.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    proposal.plainContent,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: proposal.progressPercentage,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${proposal.currentSignatures} signatures of ${proposal.requiredSignatures} required',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 