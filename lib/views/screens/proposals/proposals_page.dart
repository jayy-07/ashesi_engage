import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../widgets/proposals/proposal_post.dart';
import '../../../viewmodels/proposals_viewmodel.dart';
import 'search_proposals_wrapper.dart';
import 'write_proposal_page.dart';
import 'dart:math' as math;


class ProposalsPage extends StatefulWidget {
  const ProposalsPage({super.key});

  @override
  State<ProposalsPage> createState() => _ProposalsPageState();
}

class _ProposalsPageState extends State<ProposalsPage> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_animationController);
    _widthAnimation = Tween<double>(begin: 160.0, end: 56.0).animate(_animationController);
  }

  void _onScroll() {
    final viewModel = Provider.of<ProposalsViewModel>(context, listen: false);
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (viewModel.isFabExtended) {
        viewModel.setFabExtended(false);
        _animationController.forward();
      }
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!viewModel.isFabExtended) {
        viewModel.setFabExtended(true);
        _animationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProposalsViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          body: viewModel.proposals.isEmpty
              ? _buildEmptyState(context)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate available height for stretching
                    final minPadding = 16.0;
                    final proposalHeight = 120.0;
                    final headerHeight = 60.0;
                    final totalContentHeight = (viewModel.proposals.length * proposalHeight) + headerHeight;
                    final availableHeight = constraints.maxHeight;
                    final stretch = math.max(0.0, (availableHeight - totalContentHeight) * 0.3);
                    
                    return ListView.separated(
                      key: const PageStorageKey('proposals_list'),
                      physics: const ClampingScrollPhysics(),
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        bottom: math.max(minPadding, stretch),
                        left: 16.0,
                        right: 16.0,
                      ),
                      itemCount: viewModel.proposals.length + 1,
                      separatorBuilder: (context, index) => index == 0 
                          ? const SizedBox.shrink()
                          : const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildSearchBar(context);
                        }
                        final proposal = viewModel.proposals[index - 1];
                        return ProposalPost(
                          key: ValueKey(proposal.id),
                          proposal: proposal,
                          onEndorse: () => viewModel.endorseProposal(proposal.id),
                          onReply: () => viewModel.replyToProposal(proposal.id),
                          onReport: () => viewModel.reportProposal(proposal.id, context),
                          onDelete: () async {
                            // Add a microtask delay to avoid the frame scheduling issue
                            await Future.microtask(() => viewModel.deleteProposal(proposal.id));
                          },
                        );
                      },
                    );
                  },
                ),
          floatingActionButton: _buildFAB(context, viewModel),
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SearchProposalsWrapper(),
            ),
          );
        },
        child: SearchBar(
          enabled: false,
          hintText: 'Search proposals',
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

  Widget _buildFAB(BuildContext context, ProposalsViewModel viewModel) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SizedBox(
          width: _widthAnimation.value,
          child: FloatingActionButton.extended(
            heroTag: 'proposals_fab',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WriteProposalPage(),
                ),
              );
            },
            icon: const Padding(
              padding: EdgeInsets.only(left: 8.0), // Adjust the value as needed
              child: Icon(Icons.edit_outlined),
            ),
            label: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: _fadeAnimation.value,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text(
                    'Write Proposal',
                    style: TextStyle(
                      fontSize: 13.0, // Match Material Design standards
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            isExtended: viewModel.isFabExtended,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
                  Icons.how_to_vote_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No proposals yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to submit a proposal!\nYour voice matters.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
