import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/discussions_viewmodel.dart';
import '../../widgets/forum/discussion_post_card.dart';

class SearchDiscussionsPage extends StatefulWidget {
  const SearchDiscussionsPage({super.key});

  @override
  State<SearchDiscussionsPage> createState() => _SearchDiscussionsPageState();
}

class _SearchDiscussionsPageState extends State<SearchDiscussionsPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Reset search when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscussionsViewModel>().clearSearch();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            hintText: 'Search discussions',
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                context.read<DiscussionsViewModel>().clearSearch();
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
                  // Navigate to discussion detail.
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
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}