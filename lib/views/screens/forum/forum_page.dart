import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../../viewmodels/discussions_viewmodel.dart';
import '../../widgets/forum/discussion_post_card.dart';
import 'discussion_detail_page.dart';
import 'search_discussions_page.dart';
import 'write_discussion_page.dart';

class ForumPage extends StatefulWidget {
  const ForumPage({super.key});

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> with SingleTickerProviderStateMixin {
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
    final viewModel = Provider.of<DiscussionsViewModel>(context, listen: false);
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
    return Consumer<DiscussionsViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          body: viewModel.discussions.isEmpty
                ? _buildEmptyState(context)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final minPadding = 16.0;
                      final discussionHeight = 120.0;
                      final headerHeight = 60.0;
                      final totalContentHeight = (viewModel.discussions.length * discussionHeight) + headerHeight;
                      final availableHeight = constraints.maxHeight;
                      final stretch = math.max(0.0, (availableHeight - totalContentHeight) * 0.3);
                      
                      return ListView.builder(
                        physics: const ClampingScrollPhysics(),
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: viewModel.discussions.length + 2,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildSearchBar(context);
                          }
                          if (index == viewModel.discussions.length + 1) {
                            return SizedBox(height: math.max(minPadding, stretch));
                          }
                          final discussion = viewModel.discussions[index - 1];
                          return DiscussionPostCard(
                            discussion: discussion,
                            onVote: (isUpvote) => viewModel.voteDiscussion(discussion.id, isUpvote),
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
                            onDelete: () async {
                              await Future.microtask(() => viewModel.deleteDiscussion(discussion.id));
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
              builder: (context) => const SearchDiscussionsPage(),
            ),
          );
        },
        child: SearchBar(
          enabled: false,
          hintText: 'Search discussions',
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

  Widget _buildFAB(BuildContext context, DiscussionsViewModel viewModel) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SizedBox(
          width: _widthAnimation.value,
          child: FloatingActionButton.extended(
            heroTag: 'forum_fab',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WriteDiscussionPage(),
                ),
              );
            },
            icon: const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(Icons.chat_bubble_outline),
            ),
            label: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: _fadeAnimation.value,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text('Start Discussion',
                   style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                    ),),
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
                  Icons.forum_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No discussions yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to start a discussion!',
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
