import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/user_viewmodel.dart';
import '../../auth/screens/sign_in_page.dart';
import '../../models/services/auth_service.dart';
import '../../views/widgets/user_avatar.dart';

class AdminLayout extends StatefulWidget {
  final Widget child;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AdminLayout({
    super.key, 
    required this.child,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          LayoutBuilder(
            builder: (context, constraint) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraint.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      selectedIndex: widget.selectedIndex,
                      onDestinationSelected: widget.onDestinationSelected,
                      labelType: NavigationRailLabelType.all,
                      groupAlignment: -1.0, // Align to the top
                      leading: Column(
                        children: [
                          const SizedBox(height: 8),
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 20),
                            child: InkWell(
                              onTap: () => widget.onDestinationSelected(0),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Image.asset(
                                  'assets/images/Ashesi_University_Logo_hut.png',
                                  width: 32,
                                  height: 32,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      destinations: [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: Text('Dashboard'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.newspaper_outlined),
                          selectedIcon: Icon(Icons.newspaper),
                          label: Text('Articles'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.lightbulb_outlined),
                          selectedIcon: Icon(Icons.lightbulb),
                          label: Text('Proposals'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.forum_outlined),
                          selectedIcon: Icon(Icons.forum),
                          label: Text('Discussions'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.event_outlined),
                          selectedIcon: Icon(Icons.event),
                          label: Text('Events'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.analytics_outlined),
                          selectedIcon: Icon(Icons.analytics),
                          label: Text('Surveys'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.security_outlined),
                          selectedIcon: Icon(Icons.security),
                          label: Text('Moderation'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.poll_outlined),
                          selectedIcon: Icon(Icons.poll),
                          label: Text('Polls'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.people_outlined),
                          selectedIcon: Icon(Icons.people),
                          label: Text('Users'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.history_outlined),
                          selectedIcon: Icon(Icons.history),
                          label: Text('Logs'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha:0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24),
          Text(
            'Admin Console',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const Spacer(),
          Consumer<UserViewModel>(
            builder: (context, userVM, _) {
              return PopupMenuButton<String>(
                offset: const Offset(0, 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: UserAvatar(
                    imageUrl: userVM.profileImageUrl,
                    radius: 16,
                    fallbackInitial: userVM.firstName?.substring(0, 1),
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text('My Profile'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'signout',
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'signout') {
                    try {
                      await Provider.of<AuthService>(context, listen: false).signOut();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const SignInPage()),
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to sign out: $e')),
                        );
                      }
                    }
                  } else if (value == 'profile') {
                    // TODO: Navigate to profile page
                    debugPrint('Navigate to profile');
                  }
                },
              );
            },
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}