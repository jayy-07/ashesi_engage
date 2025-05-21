import 'package:ashesi_engage/viewmodels/user_viewmodel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:provider/provider.dart';
import '../../../models/entities/student_proposal.dart';
import '../../../models/services/auth_service.dart';
import '../../../viewmodels/proposal_details_viewmodel.dart';
import '../../widgets/proposals/comment_tile.dart';
import '../../widgets/ai_summary_card.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../widgets/user_avatar.dart'; 
import '../../../models/services/proposal_service.dart';
import 'package:flutter/services.dart';
import '../../../providers/bookmark_provider.dart';
import '../../../widgets/snackbar_helper.dart';

class ProposalDetailPage extends StatefulWidget {
  final String proposalId;
  final bool focusComment;
  final String? highlightCommentId;

  const ProposalDetailPage({
    super.key,
    required this.proposalId,
    this.focusComment = false,
    this.highlightCommentId,
  });

  @override
  State<ProposalDetailPage> createState() => _ProposalDetailPageState();
}

class _ProposalDetailPageState extends State<ProposalDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final bool _isSendingComment = false;
  final bool _isEndorsing = false;
  late final ProposalDetailsViewModel _viewModel;
  bool _isLoading = true;
  String? _error;
  String? _highlightedCommentId;

  @override
  void initState() {
    super.initState();
    _loadProposal();
    _highlightedCommentId = widget.highlightCommentId;
  }

  Future<void> _loadProposal() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final proposalService = ProposalService();
      final proposal = await proposalService.getProposal(widget.proposalId);
      
      if (proposal == null) {
        setState(() {
          _error = 'Proposal not found';
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;

      _viewModel = ProposalDetailsViewModel(proposal, context, proposalService);
      
      if (widget.focusComment) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _commentFocus.requestFocus();
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error loading proposal: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    if (!_isLoading) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proposal')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proposal')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loadProposal,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ChangeNotifierProvider<ProposalDetailsViewModel>.value(
      value: _viewModel,
      child: Consumer<ProposalDetailsViewModel>(
        builder: (context, viewModel, child) => Scaffold(
          appBar: AppBar(
            title: const Text('Proposal'),
            actions: [
              IconButton(
                icon: Icon(
                  viewModel.isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                  color: viewModel.isBookmarked ? Theme.of(context).colorScheme.primary : null,
                ),
                onPressed: () {
                  context.read<BookmarkProvider>().toggleBookmark(
                    itemId: widget.proposalId,
                    itemType: 'proposal',
                  );
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (BuildContext context) {
                  final user = Provider.of<AuthService>(context, listen: false).currentUser;
                  final isCurrentUserAuthor = user != null && user.uid == viewModel.proposal.authorId;
                  return [
                    if (isCurrentUserAuthor)
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Delete'),
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
                onSelected: (String value) async {
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
                            onPressed: () async {
                              final nav = Navigator.of(context);
                              Navigator.pop(context); // close the dialog
                              try {
                                await viewModel.deleteProposal();
                                nav.pop(); // pop the detail page
                                if (mounted) {
                                  SnackbarHelper.showSuccess(context, 'Proposal deleted');
                                }
                              } catch (e) {
                                if (mounted) {
                                  SnackbarHelper.showError(context, 'Failed to delete proposal: ${e.toString()}');
                                }
                              }
                            },
                            child: Text(
                              'Delete',
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (value == 'report') {
                    await viewModel.reportProposal();
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: _ProposalDetailContent(
                  viewModel: viewModel,
                  focusComment: widget.focusComment,
                  highlightCommentId: _highlightedCommentId,
                ),
              ),
              _CommentInput(focusComment: widget.focusComment),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProposalDetailContent extends StatefulWidget {
  final ProposalDetailsViewModel viewModel;
  final bool focusComment;
  final String? highlightCommentId;

  const _ProposalDetailContent({
    required this.viewModel,
    this.focusComment = false,
    this.highlightCommentId,
  });

  @override
  State<_ProposalDetailContent> createState() => _ProposalDetailContentState();
}

class _ProposalDetailContentState extends State<_ProposalDetailContent> with SingleTickerProviderStateMixin {
  final FocusNode _commentFocus = FocusNode();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _highlightedCommentId;
  bool _canSubmitComment = false;
  bool _isLoadingAISummary = true;
  bool _isEndorsing = false;
  late AnimationController _highlightController;
  late Animation<double> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    _highlightedCommentId = widget.highlightCommentId;
    
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _highlightAnimation = CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeInOut,
    );
    
    if (_highlightedCommentId != null) {
      // Wait for the comments to load and then scroll to the highlighted comment
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToComment(_highlightedCommentId!);
        _highlightController.forward();
        // Auto-dismiss highlight after 2 seconds
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) {
            _highlightController.reverse();
            setState(() {
              _highlightedCommentId = null;
            });
          }
        });
      });
    }
    
    _commentController.addListener(() {
      setState(() {
        _canSubmitComment = _commentController.text.trim().isNotEmpty;
      });
    });
  }

  void _scrollToComment(String commentId) {
    // Give time for the list to build
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      final commentKey = GlobalKey();
      final index = widget.viewModel.comments.indexWhere((c) => c.id == commentId);
      
      if (index != -1) {
        _scrollController.animateTo(
          index * 120.0, // Approximate height of each comment tile
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentFocus.dispose();
    _commentController.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  Widget _buildEndorseButton(
      BuildContext context, ProposalDetailsViewModel viewModel) {
    final theme = Theme.of(context);

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

    return viewModel.proposal.isEndorsedByUser
        ? FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Endorsed'),
            onPressed: () => _handleEndorse(viewModel),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
            ),
          )
        : OutlinedButton.icon(
            icon: const Icon(Icons.how_to_vote),
            label: const Text('Endorse'),
            onPressed: () => _handleEndorse(viewModel),
          );
  }

  Future<void> _handleEndorse(ProposalDetailsViewModel viewModel) async {
    if (_isEndorsing) return;

    setState(() => _isEndorsing = true);
    try {
      HapticFeedback.mediumImpact();
      await viewModel.endorseProposal();
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) {
        setState(() => _isEndorsing = false);
      }
    }
  }

  Widget _buildCommentsList() {
    final viewModel = context.watch<ProposalDetailsViewModel>();
    final authService = Provider.of<AuthService>(context, listen: false);

    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: viewModel.comments.length,
      itemBuilder: (context, index) {
        final comment = viewModel.comments[index];
        final isAuthor = comment.authorId == authService.currentUser?.uid;
        final isHighlighted = comment.id == _highlightedCommentId;

        return CommentTile(
          key: ValueKey('comment-${comment.id}'),
          comment: comment,
          onVote: (isUpvote) => viewModel.voteComment(comment.id, isUpvote),
          onDelete: () => viewModel.deleteComment(comment.id),
          onReport: () => viewModel.reportComment(comment.id),
          isAuthor: isAuthor,
          isOptimistic: comment.isOptimistic,
          isHighlighted: isHighlighted,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<ProposalDetailsViewModel>();

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UserAvatar(
                      imageUrl: viewModel.proposal.authorAvatar,
                      radius: 20,
                      fallbackInitial: viewModel.proposal.authorName.substring(0, 1),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            viewModel.proposal.authorName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            viewModel.proposal.authorClass,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SelectableText(
                  viewModel.proposal.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QuillEditor(
                    controller: QuillController(
                      document: viewModel.proposalContentController.document,
                      selection: const TextSelection.collapsed(offset: 0),
                      readOnly: true, // Set readOnly to true here
                    ),
                    scrollController: ScrollController(),
                    focusNode: FocusNode(),
                    configurations: QuillEditorConfigurations(
                      showCursor: false,
                      padding: EdgeInsets.zero,
                      autoFocus: false,
                      expands: false,
                      enableInteractiveSelection: true,
                      scrollable: false,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  timeago.format(viewModel.proposal.datePosted),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (viewModel.proposal.answeredAt != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: theme.colorScheme.secondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Answered',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Builder(
                            builder: (context) {
                              if (kDebugMode) {
                                print('Debug - Raw answer data: ${viewModel.proposal.answer}');
                              }
                              
                              // Create document from the Delta ops
                              List<dynamic> deltaOps;
                              if (viewModel.proposal.answer?['ops'] != null) {
                                deltaOps = List<dynamic>.from(viewModel.proposal.answer!['ops']);
                                // Check if last operation ends with newline
                                final lastOp = deltaOps.last;
                                if (lastOp is Map<String, dynamic> && 
                                    lastOp['insert'] is String && 
                                    !(lastOp['insert'] as String).endsWith('\n')) {
                                  deltaOps.add({'insert': '\n'});
                                }
                              } else {
                                deltaOps = [
                                  {'insert': viewModel.proposal.plainAnswer ?? ''},
                                  {'insert': '\n'}
                                ];
                              }
                              
                              if (kDebugMode) {
                                print('Debug - Delta ops: $deltaOps');
                              }
                              final document = Document.fromJson(deltaOps);
                              if (kDebugMode) {
                                print('Debug - Created document length: ${document.length}');
                              }
                              
                              return QuillEditor(
                                controller: QuillController(
                                  document: document,
                                  selection: const TextSelection.collapsed(offset: 0),
                                  readOnly: true,
                                ),
                                scrollController: ScrollController(),
                                focusNode: FocusNode(),
                                configurations: QuillEditorConfigurations(
                                  showCursor: false,
                                  padding: EdgeInsets.zero,
                                  autoFocus: false,
                                  expands: false,
                                  enableInteractiveSelection: true,
                                  scrollable: false,
                                ),
                              );
                            }
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Answered ${timeago.format(viewModel.proposal.answeredAt!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        'Endorsements Progress',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: viewModel.proposal.progressPercentage,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      '${viewModel.proposal.currentSignatures} signatures',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                TextSpan(
                                  text:
                                      ', ${viewModel.proposal.remainingSignatures} to go',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (viewModel.proposal.answeredAt == null)
                            _buildEndorseButton(context, viewModel),
                        ],
                      ),
                    ],
                  ),
                ),
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
                const SizedBox(height: 18),
                Text(
                  '${viewModel.comments.length} ${viewModel.comments.length == 1 ? 'comment' : 'comments'}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                if (viewModel.isLoadingComments)
                  const Center(child: CircularProgressIndicator())
                else
                  _buildCommentsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentInput extends StatefulWidget {
  final bool focusComment;

  const _CommentInput({required this.focusComment});

  @override
  State<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<_CommentInput> {
  @override
  void initState() {
    super.initState();
    if (widget.focusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final viewModel = context.read<ProposalDetailsViewModel>();
        viewModel.commentFocus.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<ProposalDetailsViewModel>(); // For TextField and comment logic

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start, // Align to top
            children: [
              Consumer<UserViewModel>(
                builder: (context, userViewModel, child) {
                  final appUser = userViewModel.currentUser;

                  String? imageUrl;
                  String fallbackInitial = '?';
                  String constructedDisplayName = '';

                  if (appUser != null) {
                    imageUrl = appUser.photoURL; // Corrected: Use photoURL
                    constructedDisplayName = "${appUser.firstName} ${appUser.lastName}".trim();

                    if (constructedDisplayName.isNotEmpty) {
                      fallbackInitial = constructedDisplayName[0].toUpperCase();
                    } else if (appUser.email.isNotEmpty) { // Corrected: AppUser.email is non-nullable
                      fallbackInitial = appUser.email[0].toUpperCase(); // Corrected: No ! needed
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0), // Match text field padding
                    child: UserAvatar(
                      imageUrl: imageUrl,
                      radius: 20,
                      fallbackInitial: fallbackInitial,
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: viewModel.commentController,
                  focusNode: viewModel.commentFocus,
                  maxLength: viewModel.characterLimit,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    counterText:
                        '${viewModel.characterCount}/${viewModel.characterLimit}',
                    counterStyle: theme.textTheme.bodySmall?.copyWith(
                      color: viewModel.isOverCharacterLimit
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    suffixIcon: viewModel.canSubmitComment
                        ? IconButton(
                            icon: viewModel.isSendingComment
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.send,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            onPressed: viewModel.isSendingComment
                                ? null
                                : () async {
                                    await viewModel.submitComment();
                                    if (mounted) {
                                      // The snackbar is now handled by the view model
                                    }
                                  },
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
