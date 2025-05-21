import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/discussions_viewmodel.dart';
import '../../widgets/forum/discussion_post_card.dart';
import 'discussion_detail_page.dart';

class SearchDiscussionsWrapper extends StatelessWidget {
  const SearchDiscussionsWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search discussions',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                context.read<DiscussionsViewModel>().clearSearch();
                Navigator.pop(context);
              },
            ),
          ),
          style: theme.textTheme.bodyLarge,
          onChanged: (value) {
            context.read<DiscussionsViewModel>().updateSearchQuery(value);
          },
        ),
      ),
      body: Consumer<DiscussionsViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isSearching) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.searchQuery.isEmpty) {
            return _buildEmptyPrompt(
              theme,
              icon: Icons.search,
              message: 'Type to search discussions',
            );
          }

          final results = viewModel.filteredDiscussions;
          if (results.isEmpty) {
            return _buildEmptyPrompt(
              theme,
              icon: Icons.search_off,
              message: 'No discussions found for "${viewModel.searchQuery}"',
            );
          }

          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final discussion = results[index];
              return DiscussionPostCard(
                key: ValueKey(discussion.id),
                discussion: discussion,
                onVote: (isUpvote) =>
                    viewModel.voteDiscussion(discussion.id, isUpvote),
                onReply: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DiscussionDetailPage(
                        discussion: discussion,
                        focusComment: true,
                      ),
                    ),
                  );
                },
                onReport: () => viewModel.reportDiscussion(discussion.id, context),
                onDelete: () => viewModel.deleteDiscussion(discussion.id),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyPrompt(ThemeData theme,
      {required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}