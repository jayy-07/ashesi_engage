import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/entities/comment.dart';
import '../../../models/entities/discussion_comment.dart';
import '../../../models/services/auth_service.dart';
import '../../../services/reply_service.dart';
import '../../widgets/proposals/comment_tile.dart';
import '../../widgets/forum/discussion_comment_tile.dart';
import '../../../widgets/snackbar_helper.dart';

class MyRepliesPage extends StatefulWidget {
  const MyRepliesPage({super.key});

  @override
  State<MyRepliesPage> createState() => _MyRepliesPageState();
}

class _MyRepliesPageState extends State<MyRepliesPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String? _selectedType;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<dynamic> _allReplies = [];
  DocumentSnapshot? _lastProposalDoc;
  DocumentSnapshot? _lastDiscussionDoc;
  final ReplyService _replyService = ReplyService();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialReplies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreReplies();
    }
  }

  Future<void> _loadInitialReplies() async {
    if (!mounted) return;
    
    debugPrint('Starting initial replies load');
    setState(() {
      _isLoading = true;
      _allReplies = [];
      _lastProposalDoc = null;
      _lastDiscussionDoc = null;
      _hasMore = true;
    });

    await _loadMoreReplies();
    
    if (mounted) {
      setState(() {
        debugPrint('Finished initial load. Total replies: ${_allReplies.length}');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreReplies() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;
      debugPrint('Loading more replies for user: $userId');
      
      if (userId == null) {
        debugPrint('No user ID found - user not logged in');
        setState(() {
          _isLoadingMore = false;
          _hasMore = false;
        });
        return;
      }

      List<dynamic> newReplies = [];

      // Load proposal comments if no type filter or filter is 'proposal'
      if (_selectedType == null || _selectedType == 'proposal') {
        debugPrint('Fetching proposal comments...');
        final (proposalComments, lastDoc) = await _replyService.getUserProposalComments(
          userId,
          lastDocument: _lastProposalDoc,
        );
        debugPrint('Found ${proposalComments.length} proposal comments');
        if (proposalComments.isNotEmpty) {
          _lastProposalDoc = lastDoc;
          newReplies.addAll(proposalComments.map((comment) => {
            'type': 'proposal',
            'item': comment,
          }));
        }
      }

      // Load discussion comments if no type filter or filter is 'discussion'
      if (_selectedType == null || _selectedType == 'discussion') {
        debugPrint('Fetching discussion comments...');
        final (discussionComments, lastDoc) = await _replyService.getUserDiscussionComments(
          userId,
          lastDocument: _lastDiscussionDoc,
        );
        debugPrint('Found ${discussionComments.length} discussion comments');
        if (discussionComments.isNotEmpty) {
          _lastDiscussionDoc = lastDoc;
          newReplies.addAll(discussionComments.map((comment) => {
            'type': 'discussion',
            'item': comment,
          }));
        }
      }

      debugPrint('Total new replies found: ${newReplies.length}');

      // Sort all replies by date
      newReplies.sort((a, b) {
        final DateTime dateA = a['type'] == 'proposal'
            ? (a['item'] as Comment).datePosted
            : (a['item'] as DiscussionComment).datePosted;
        final DateTime dateB = b['type'] == 'proposal'
            ? (b['item'] as Comment).datePosted
            : (b['item'] as DiscussionComment).datePosted;
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _allReplies.addAll(newReplies);
          debugPrint('Updated total replies: ${_allReplies.length}');
          _isLoadingMore = false;
          _hasMore = newReplies.length >= ReplyService.pageSize;
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading replies: $e');
      debugPrint('Stack trace: $stack');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _hasMore = false;
        });
        SnackbarHelper.showError(context, 'Error loading replies: $e');
      }
    }
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: SearchBar(
        controller: _searchController,
        hintText: 'Search replies',
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16.0),
        ),
        leading: const Icon(Icons.search),
        trailing: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                });
                _loadInitialReplies();
              },
            ),
        ],
        elevation: const WidgetStatePropertyAll(0.0),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Proposal Comments'),
            selected: _selectedType == 'proposal',
            onSelected: (selected) {
              setState(() {
                _selectedType = selected ? 'proposal' : null;
              });
              _loadInitialReplies();
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Discussion Comments'),
            selected: _selectedType == 'discussion',
            onSelected: (selected) {
              setState(() {
                _selectedType = selected ? 'discussion' : null;
              });
              _loadInitialReplies();
            },
          ),
        ],
      ),
    );
  }

  List<dynamic> _filterReplies(List<dynamic> replies) {
    return replies.where((reply) {
      if (_searchQuery.isEmpty) return true;

      final query = _searchQuery.toLowerCase();
      if (reply['type'] == 'discussion') {
        final comment = reply['item'] as DiscussionComment;
        return comment.content.toLowerCase().contains(query);
      } else if (reply['type'] == 'proposal') {
        final comment = reply['item'] as Comment;
        return comment.content.toLowerCase().contains(query);
      }
      return false;
    }).toList();
  }

  void _navigateToComment(dynamic reply) {
    if (reply['type'] == 'proposal') {
      final comment = reply['item'] as Comment;
      context.push('/proposals/${comment.proposalId}?commentId=${comment.id}');
    } else if (reply['type'] == 'discussion') {
      final comment = reply['item'] as DiscussionComment;
      context.push('/discussions/${comment.discussionId}?commentId=${comment.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Replies'),
      ),
      body: Column(
        children: [
          _buildSearchBar(context),
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildRepliesList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildRepliesList(ThemeData theme) {
    final filteredReplies = _filterReplies(_allReplies);
    debugPrint('Building replies list. Total: ${_allReplies.length}, Filtered: ${filteredReplies.length}');

    if (_allReplies.isEmpty && !_isLoading && !_isLoadingMore) {
      debugPrint('No replies to display - showing empty state');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.comment_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No replies yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your replies to discussions and proposals\nwill appear here.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (filteredReplies.isEmpty && !_isLoading && !_isLoadingMore) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No replies found',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: filteredReplies.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == filteredReplies.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final reply = filteredReplies[index];
        return GestureDetector(
          onTap: () => _navigateToComment(reply),
          child: _buildReplyTile(reply),
        );
      },
    );
  }

  Widget _buildReplyTile(dynamic reply) {
    final theme = Theme.of(context);
    
    if (reply['type'] == 'proposal') {
      final comment = reply['item'] as Comment;
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(alpha:0.5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Proposal Comment',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(comment.datePosted),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            CommentTile(
              comment: comment,
              onVote: (_) {}, // Read-only view
              onDelete: () {}, // Read-only view
              onReport: () {}, // Read-only view
              isAuthor: true,
            ),
          ],
        ),
      );
    } else {
      final comment = reply['item'] as DiscussionComment;
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha:0.5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Discussion Comment',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(comment.datePosted),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            DiscussionCommentTile(
              key: ValueKey('reply-${comment.id}'),
              comment: comment,
              onVote: (_) {}, // Read-only view
              onReply: () {}, // Read-only view
              onToggleExpand: (_, __) {}, // Read-only view
              indentWidth: 0, // No indentation in list view
              isLastSibling: true,
            ),
          ],
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      // Format as MMM dd, yyyy for dates more than a week old
      return '${_getMonthAbbreviation(date.month)} ${date.day}, ${date.year}';
    } else if (difference.inDays > 0) {
      // Show days ago for dates within a week
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      // Show hours ago
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      // Show minutes ago
      return '${difference.inMinutes}m ago';
    } else {
      // Show just now for very recent comments
      return 'Just now';
    }
  }

  String _getMonthAbbreviation(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
} 