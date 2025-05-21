import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../models/entities/student_proposal.dart';
import '../../../models/services/proposal_service.dart';
import '../../../models/services/auth_service.dart';
import '../../../providers/bookmark_provider.dart';
import '../../screens/proposals/proposal_detail_page.dart';
import '../user_avatar.dart';
import 'package:flutter/services.dart';
import '../../../widgets/snackbar_helper.dart';

class ProposalPost extends StatefulWidget {
  final StudentProposal proposal;
  final VoidCallback onEndorse;
  final VoidCallback onReply;
  final VoidCallback onReport;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const ProposalPost({
    super.key,
    required this.proposal,
    required this.onEndorse,
    required this.onReply,
    required this.onReport,
    required this.onDelete,
    this.onTap,
  });

  @override
  State<ProposalPost> createState() => _ProposalPostState();
}

class _ProposalPostState extends State<ProposalPost> {
  bool _isEndorsing = false;
  late Stream<int> _commentCountStream;
  
  @override
  void initState() {
    super.initState();
    _commentCountStream = ProposalService().getCommentCount(widget.proposal.id);
    // Check bookmark status when widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookmarkProvider>().checkBookmarkStatus(widget.proposal.id);
    });
  }

  Future<void> _handleEndorse() async {
    if (_isEndorsing) return;  // Prevent double-clicks
    
    setState(() => _isEndorsing = true);
    try {
      HapticFeedback.mediumImpact();
      await Future.microtask(widget.onEndorse);
      // Add small delay to ensure Firestore update is complete
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) {
        setState(() => _isEndorsing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookmarkProvider = context.watch<BookmarkProvider>();
    final isBookmarked = bookmarkProvider.isBookmarked(widget.proposal.id);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: widget.onTap ?? () => _navigateToProposal(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatar(
                    imageUrl: widget.proposal.authorAvatar,
                    radius: 20,
                    fallbackInitial: widget.proposal.authorName.substring(0, 1),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.proposal.authorName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              widget.proposal.authorClass,
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeago.format(widget.proposal.datePosted),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        if (widget.proposal.answeredAt != null)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Answered',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'More options',
                    itemBuilder: (BuildContext context) {
                      final authService = Provider.of<AuthService>(context, listen: false);
                      final isAuthor = widget.proposal.authorId == authService.currentUser?.uid;
                      
                      return [
                        if (isAuthor)
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline),
                              title: Text('Delete'),
                              dense: true,
                            ),
                          ),
                        PopupMenuItem<String>(
                          value: 'bookmark',
                          child: ListTile(
                            leading: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_outline),
                            title: Text(isBookmarked ? 'Remove bookmark' : 'Bookmark'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'report',
                          child: ListTile(
                            leading: Icon(Icons.flag_outlined),
                            title: Text('Report'),
                            dense: true,
                          ),
                        ),
                      ];
                    },
                    onSelected: (String value) {
                      if (value == 'delete') {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Proposal'),
                            content: const Text('Are you sure you want to delete this proposal? This action cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.onDelete();
                                  SnackbarHelper.showSuccess(context, 'Proposal deleted');
                                },
                                child: Text(
                                  'Delete',
                                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else if (value == 'bookmark') {
                        bookmarkProvider.toggleBookmark(
                          itemId: widget.proposal.id,
                          itemType: 'proposal',
                        );
                        SnackbarHelper.showSuccess(context, isBookmarked ? 'Bookmark removed' : 'Bookmark added');
                      } else if (value == 'report') {
                        widget.onReport();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.proposal.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.proposal.plainContent,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.proposal.plainContent.length > 200)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Read more',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                    tween: Tween<double>(
                      begin: 0,
                      end: widget.proposal.progressPercentage,
                    ),
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.proposal.currentSignatures} signatures, ${widget.proposal.remainingSignatures} more to go',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StreamBuilder<int>(
                    stream: _commentCountStream,
                    builder: (context, snapshot) {
                      final commentCount = snapshot.data ?? 0;
                      return TextButton.icon(
                        icon: const Icon(Icons.comment_outlined),
                        label: Text('$commentCount'),
                        onPressed: () => _navigateToProposal(context),
                      );
                    },
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.reply),
                        label: const Text('Reply'),
                        onPressed: () => _navigateToProposal(context, focusComment: true),
                      ),
                      if (widget.proposal.answeredAt == null) ...[
                        const SizedBox(width: 8),
                        _buildEndorseButton(context),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndorseButton(BuildContext context) {
    if (_isEndorsing) {
      return FilledButton.icon(
        icon: SizedBox(
          width: 20,
          height: 20,
            child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
        ),
        label: const Text('Processing...'),
        onPressed: null,
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
        ),
      );
    }

    return widget.proposal.isEndorsedByUser
      ? FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Endorsed'),
          onPressed: _handleEndorse,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        )
      : OutlinedButton.icon(
          icon: const Icon(Icons.how_to_vote),
          label: const Text('Endorse'),
          onPressed: _handleEndorse,
        );
  }

  void _navigateToProposal(BuildContext context, {bool focusComment = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProposalDetailPage(
          proposalId: widget.proposal.id,
          focusComment: focusComment,
        ),
      ),
    );
  }
}
