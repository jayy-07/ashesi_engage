import 'package:flutter/material.dart';
import '../../../models/services/bookmark_service.dart';
import '../../../models/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../../models/entities/discussion_post.dart';
import '../../../models/entities/student_proposal.dart';
import '../../widgets/proposals/proposal_post.dart';
import '../../widgets/forum/discussion_post_card.dart';
import 'dart:math' as math;

class SearchBookmarksWrapper extends StatefulWidget {
  const SearchBookmarksWrapper({super.key});

  @override
  State<SearchBookmarksWrapper> createState() => _SearchBookmarksWrapperState();
}

class _SearchBookmarksWrapperState extends State<SearchBookmarksWrapper> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedType;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Proposals'),
            selected: _selectedType == 'proposal',
            onSelected: (selected) {
              setState(() {
                _selectedType = selected ? 'proposal' : null;
              });
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Discussions'),
            selected: _selectedType == 'discussion',
            onSelected: (selected) {
              setState(() {
                _selectedType = selected ? 'discussion' : null;
              });
            },
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterBookmarks(List<Map<String, dynamic>> bookmarks) {
    return bookmarks.where((bookmark) {
      // Apply type filter
      if (_selectedType != null && bookmark['type'] != _selectedType) {
        return false;
      }

      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (bookmark['type'] == 'discussion') {
          final discussion = bookmark['item'] as DiscussionPost;
          return discussion.plainContent.toLowerCase().contains(query);
        } else if (bookmark['type'] == 'proposal') {
          final proposal = bookmark['item'] as StudentProposal;
          return proposal.title.toLowerCase().contains(query) ||
                 proposal.plainContent.toLowerCase().contains(query);
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkService = BookmarkService();
    final authService = Provider.of<AuthService>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search bookmarks',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
            ),
          ),
          style: theme.textTheme.bodyLarge,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildFilterChips(),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: authService.currentUser != null 
          ? bookmarkService.getUserBookmarks(authService.currentUser!.uid)
          : Stream.value([]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading bookmarks: ${snapshot.error}'),
            );
          }

          final bookmarks = snapshot.data ?? [];
          final filteredBookmarks = _filterBookmarks(bookmarks);

          if (filteredBookmarks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 64.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _searchQuery.isNotEmpty ? Icons.search_off : Icons.bookmark_outline,
                      size: 64,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty ? 'No bookmarks found' : 'No bookmarks yet',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Try adjusting your search or filters'
                          : 'Bookmark discussions and proposals\nto read them later.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final minPadding = 16.0;
              final itemHeight = 120.0;
              final totalContentHeight = filteredBookmarks.length * itemHeight;
              final availableHeight = constraints.maxHeight;
              final stretch = math.max(0.0, (availableHeight - totalContentHeight) * 0.3);

              return ListView.separated(
                key: const PageStorageKey('search_bookmarks_list'),
                physics: const ClampingScrollPhysics(),
                controller: _scrollController,
                padding: EdgeInsets.only(
                  bottom: math.max(minPadding, stretch),
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                ),
                itemCount: filteredBookmarks.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final bookmark = filteredBookmarks[index];
                  final type = bookmark['type'] as String;

                  if (type == 'discussion') {
                    final discussion = bookmark['item'] as DiscussionPost;
                    return DiscussionPostCard(
                      discussion: discussion,
                      onVote: (isUpvote) {},
                      onReply: () {},
                      onReport: () {},
                      onDelete: () {},
                    );
                  } else if (type == 'proposal') {
                    final proposal = bookmark['item'] as StudentProposal;
                    return ProposalPost(
                      proposal: proposal,
                      onEndorse: () {},
                      onReply: () {},
                      onReport: () {},
                      onDelete: () {},
                    );
                  }

                  return const SizedBox.shrink();
                },
              );
            },
          );
        },
      ),
    );
  }
} 