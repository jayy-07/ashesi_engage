import 'package:flutter/material.dart';
import '../../../models/services/bookmark_service.dart';
import '../../../models/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../../models/entities/discussion_post.dart';
import '../../../models/entities/student_proposal.dart';
import '../../widgets/proposals/proposal_post.dart';
import '../../widgets/forum/discussion_post_card.dart';
import 'dart:math' as math;
import 'search_bookmarks_wrapper.dart';

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SearchBookmarksWrapper(),
            ),
          );
        },
        child: SearchBar(
          enabled: false,
          hintText: 'Search bookmarks',
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16.0),
          ),
          leading: const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: Icon(Icons.search),
          ),
          elevation: const WidgetStatePropertyAll(0.0),
          backgroundColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkService = BookmarkService();
    final authService = Provider.of<AuthService>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
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

          if (bookmarks.isEmpty) {
            return ListView(
              physics: const ClampingScrollPhysics(),
              children: [
                _buildSearchBar(context),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 64.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_outline,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No bookmarks yet',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bookmark discussions and proposals\nto read them later.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final minPadding = 16.0;
              final itemHeight = 120.0;
              final headerHeight = 60.0;
              final totalContentHeight = (bookmarks.length * itemHeight) + headerHeight;
              final availableHeight = constraints.maxHeight;
              final stretch = math.max(0.0, (availableHeight - totalContentHeight) * 0.3);

              return ListView.separated(
                key: const PageStorageKey('bookmarks_list'),
                physics: const ClampingScrollPhysics(),
                controller: _scrollController,
                padding: EdgeInsets.only(
                  bottom: math.max(minPadding, stretch),
                  left: 16.0,
                  right: 16.0,
                ),
                itemCount: bookmarks.length + 1,
                separatorBuilder: (context, index) => index == 0
                    ? const SizedBox.shrink()
                    : const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildSearchBar(context);
                  }

                  final bookmark = bookmarks[index - 1];
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