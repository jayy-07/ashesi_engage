import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/proposals_viewmodel.dart';
import '../../widgets/proposals/proposal_post.dart';

class SearchProposalsPage extends StatefulWidget {
  const SearchProposalsPage({super.key});

  @override
  State<SearchProposalsPage> createState() => _SearchProposalsPageState();
}

class _SearchProposalsPageState extends State<SearchProposalsPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Reset search when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProposalsViewModel>().clearSearch();
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
            hintText: 'Search proposals',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                context.read<ProposalsViewModel>().clearSearch();
              },
            ),
          ),
          style: theme.textTheme.bodyLarge,
          onChanged: (value) {
            context.read<ProposalsViewModel>().updateSearchQuery(value);
          },
        ),
      ),
      body: Consumer<ProposalsViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isSearching) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.searchQuery.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Type to search proposals',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          final results = viewModel.filteredProposals;
          
          if (results.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No proposals found for "${viewModel.searchQuery}"',
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
            itemCount: results.length,
            itemBuilder: (context, index) {
              final proposal = results[index];
              return ProposalPost(
                key: ValueKey(proposal.id),
                proposal: proposal,
                onEndorse: () => viewModel.endorseProposal(proposal.id),
                onReply: () => viewModel.replyToProposal(proposal.id),
                onReport: () => viewModel.reportProposal(proposal.id, context),
                onDelete: () => viewModel.deleteProposal(proposal.id),
              );
            },
          );
        },
      ),
    );
  }
}