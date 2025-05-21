import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/user_viewmodel.dart';
import '../../models/services/auth_service.dart';
import '../../auth/screens/sign_in_page.dart';
import '../../auth/screens/profile_edit_page.dart';
import '../screens/proposals/my_proposals_page.dart';
import '../screens/forum/my_posts_page.dart';
import '../../viewmodels/proposals_viewmodel.dart';
import '../../viewmodels/discussions_viewmodel.dart';
import 'user_avatar.dart';
import '../../models/services/bookmark_service.dart';
import '../screens/bookmarks/bookmarks_page.dart';
import 'package:go_router/go_router.dart';
import '../../services/reply_service.dart';
import '../screens/articles/articles_page.dart';
import '../../viewmodels/article_viewmodel.dart';

class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final userVM = Provider.of<UserViewModel>(context);
    final authService = Provider.of<AuthService>(context);
    final proposalsVM = Provider.of<ProposalsViewModel>(context);
    final bookmarkService = BookmarkService();
    
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              '${userVM.firstName ?? ''} ${userVM.lastName ?? ''}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            accountEmail: null,
            currentAccountPicture: UserAvatar(
              imageUrl: userVM.profileImageUrl,
              radius: 32,
              fallbackInitial: userVM.firstName?.substring(0, 1),
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('My Profile'),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileEditPage(),
                ),
              );
            },
          ),
          const Divider(), // Divider after Profile
          ListTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: const Text('My Proposals'),
            trailing: Text(
              proposalsVM.getUserProposals().length.toString(),
              style: const TextStyle(color: Colors.grey),
            ),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyProposalsPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.forum_outlined),
            title: const Text('My Posts'),
            trailing: Text(
              context.watch<DiscussionsViewModel>().getUserDiscussions().length.toString(),
              style: const TextStyle(color: Colors.grey)
            ),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyPostsPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.comment_outlined),
            title: const Text('My Replies'),
            trailing: FutureBuilder<int>(
              future: _countUserReplies(authService.currentUser?.uid ?? ''),
              builder: (context, snapshot) {
                return Text(
                  (snapshot.connectionState == ConnectionState.waiting)
                      ? '...'
                      : snapshot.data?.toString() ?? '0',
                  style: const TextStyle(color: Colors.grey),
                );
              },
            ),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              context.pushNamed('replies');
            },
          ),
          const Divider(), // Divider after My Activity section
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: authService.currentUser != null 
              ? bookmarkService.getUserBookmarks(authService.currentUser!.uid)
              : Stream.value([]),
            builder: (context, snapshot) {
              final bookmarkCount = snapshot.data?.length ?? 0;
              return ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: const Text('Bookmarks'),
                trailing: Text(
                  bookmarkCount.toString(),
                  style: const TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(context); // Close drawer first
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BookmarksPage(),
                    ),
                  );
                },
              );
            }
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('Articles'),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChangeNotifierProvider(
                    create: (_) => ArticleViewModel(),
                    child: const ArticlesPage(),
                  ),
                ),
              );
            },
          ),
          const Spacer(), // Keep spacer to push Sign Out to bottom
          const Divider(), // Divider before Sign Out
          ListTile(
            leading: Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              // Close the drawer first
              Navigator.pop(context);
              
              // Show confirmation dialog
              final bool? shouldSignOut = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('CANCEL'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('SIGN OUT'),
                      ),
                    ],
                  );
                },
              );
              
              // If user cancels or dismisses the dialog
              if (shouldSignOut != true) return;
              
              // User confirmed sign out, show loading indicator
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                );
              }

              try {
                // Explicitly clear the user view model data first
                userVM.clearUserData();
                
                // Sign out
                await authService.signOut();
                
                // Remove the loading indicator
                if (context.mounted) {
                  Navigator.pop(context);
                }
                
                // Navigate to sign-in page to force a complete reset of the app state
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const SignInPage()),
                    (route) => false, // Remove all previous routes
                  );
                }
              } catch (e) {
                // Remove the loading indicator
                if (context.mounted) {
                  Navigator.pop(context);
                }
                
                // Show error message
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to sign out: ${e.toString()}'),
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<int> _countUserReplies(String userId) async {
    if (userId.isEmpty) return 0;
    
    final replyService = ReplyService();
    final (proposalComments, _) = await replyService.getUserProposalComments(userId);
    final (discussionComments, _) = await replyService.getUserDiscussionComments(userId);
    
    return proposalComments.length + discussionComments.length;
  }
}
