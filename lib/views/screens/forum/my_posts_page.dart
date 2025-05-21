import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../widgets/forum/discussion_post_card.dart';
import '../../../viewmodels/discussions_viewmodel.dart';
import 'discussion_search_wrapper.dart';
import 'write_discussion_page.dart';
import 'discussion_detail_page.dart';
import 'dart:math' as math;

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> with SingleTickerProviderStateMixin {
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

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SearchDiscussionsWrapper(),
            ),
          );
        },
        child: SearchBar(
          enabled: false,
          hintText: 'Search my discussions',
          padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 16.0)),
          leading: const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: Icon(Icons.search),
          ),
          elevation: WidgetStateProperty.all(0.0),
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) {
              return Theme.of(context).colorScheme.surfaceContainerHighest;
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DiscussionsViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final userPosts = viewModel.getUserDiscussions();

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Posts'),
          ),
          body: userPosts.isEmpty
              ? _buildEmptyState(context)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final minPadding = 16.0;
                    final discussionHeight = 120.0;
                    final headerHeight = 60.0;
                    final totalContentHeight = (userPosts.length * discussionHeight) + headerHeight;
                    final availableHeight = constraints.maxHeight;
                    final stretch = math.max(0.0, (availableHeight - totalContentHeight) * 0.3);
                    
                    return ListView.separated(
                      key: const PageStorageKey('my_posts_list'),
                      physics: const ClampingScrollPhysics(),
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        bottom: math.max(minPadding, stretch),
                        left: 16.0,
                        right: 16.0,
                      ),
                      itemCount: userPosts.length + 1,
                      separatorBuilder: (context, index) => index == 0 
                          ? const SizedBox.shrink()
                          : const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildSearchBar(context);
                        }
                        final post = userPosts[index - 1];
                        return DiscussionPostCard(
                          key: ValueKey(post.id),
                          discussion: post,
                          onVote: (isUpvote) => viewModel.voteDiscussion(post.id, isUpvote),
                          onReply: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DiscussionDetailPage(
                                  discussion: post,
                                  focusComment: true,
                                ),
                              ),
                            );
                          },
                          onReport: () => viewModel.reportDiscussion(post.id, context),
                          onDelete: () async {
                            await Future.microtask(() => viewModel.deleteDiscussion(post.id));
                          },
                        );
                      },
                    );
                  },
                ),
          floatingActionButton: _buildFAB(context),
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
                  'Start your first discussion!\nShare your thoughts.',
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

  Widget _buildFAB(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SizedBox(
          width: _widthAnimation.value,
          child: FloatingActionButton.extended(
            heroTag: 'my_posts_fab',
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
                  child: const Text(
                    'Start Discussion',
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            isExtended: context.watch<DiscussionsViewModel>().isFabExtended,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}