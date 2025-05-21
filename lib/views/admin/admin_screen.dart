import 'package:ashesi_engage/views/admin/screens/admin_discussions_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'admin_layout.dart';
import 'screens/admin_events_screen.dart';
import '../../viewmodels/event_viewmodel.dart';
import '../../viewmodels/admin_proposals_viewmodel.dart';
import '../../viewmodels/admin_discussions_viewmodel.dart';
import '../../viewmodels/article_viewmodel.dart';
import '../../views/screens/user_management_screen.dart';
import '../../views/screens/notification_test_screen.dart';
import 'polls/polls_admin_screen.dart';
import 'screens/admin_reports_screen.dart';
import 'screens/admin_discussion_detail_screen.dart';
import 'surveys/surveys_admin_screen.dart';
import 'screens/admin_proposals_screen.dart';
import 'article/articles_admin_screen.dart';
import 'article/write_article_page.dart';
import 'dashboard_screen.dart';
import '../../models/services/discussion_service.dart';
import '../../models/entities/discussion_post.dart';
import '../../models/services/article_service.dart';

// Import the notification class directly for better type safety
class AdminTabChangeNotification extends Notification {
  final int tabIndex;
  AdminTabChangeNotification(this.tabIndex);
}

class AdminScreen extends StatefulWidget {
  final String? initialProposalId;
  final String? initialDiscussionId;
  final String? highlightCommentId;

  const AdminScreen({
    super.key, 
    this.initialProposalId,
    this.initialDiscussionId,
    this.highlightCommentId,
  });

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    
    // Set initial tab based on which ID was passed
    if (widget.initialProposalId != null) {
      _selectedIndex = 2; // Proposals tab
      
      // Use a short delay to allow the screen to build before passing data to viewmodel
      Future.delayed(Duration.zero, () {
        if (mounted) {
          final viewModel = Provider.of<AdminProposalsViewModel>(context, listen: false);
          viewModel.selectProposal(widget.initialProposalId!, widget.highlightCommentId);
        }
      });
    } else if (widget.initialDiscussionId != null) {
      _selectedIndex = 3; // Discussions tab
      
      // Use a short delay to allow the screen to build before passing data to viewmodel
      Future.delayed(Duration.zero, () {
        if (mounted) {
          final viewModel = Provider.of<AdminDiscussionsViewModel>(context, listen: false);
          viewModel.selectDiscussion(widget.initialDiscussionId!, widget.highlightCommentId);
        }
      });
    }
  }

  Widget _getScreen() {
    // If initialDiscussionId is provided and we're on the discussions tab,
    // directly load the discussion detail screen
    if (_selectedIndex == 3 && widget.initialDiscussionId != null) {
      debugPrint('AdminScreen: Loading discussion detail directly for ID ${widget.initialDiscussionId}');
      return FutureBuilder<DiscussionPost?>(
        future: DiscussionService().getDiscussion(widget.initialDiscussionId!),
        builder: (context, AsyncSnapshot<DiscussionPost?> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasData && snapshot.data != null) {
            debugPrint('AdminScreen: Discussion loaded successfully');
            return AdminDiscussionDetailScreen(discussion: snapshot.data!);
          }
          
          // If discussion not found, fall back to discussion list
          debugPrint('AdminScreen: Discussion not found, showing list');
          return AdminDiscussionsScreen(
            initialDiscussionId: widget.initialDiscussionId,
            highlightCommentId: widget.highlightCommentId,
          );
        }
      );
    }
    
    // Regular tab handling
    switch (_selectedIndex) {
      case 0:
        return const DashboardScreen();
      case 1:
        return ChangeNotifierProvider(
          create: (_) => ArticleViewModel(),
          child: const ArticlesAdminScreen(),
        );
      case 2:
        return AdminProposalsScreen(
          initialProposalId: widget.initialProposalId,
          highlightCommentId: widget.highlightCommentId,
        );
      case 3:
        return AdminDiscussionsScreen(
          initialDiscussionId: widget.initialDiscussionId,
          highlightCommentId: widget.highlightCommentId,
        );
      case 4:
        return const EventsScreen();
      case 5:
        return const SurveysAdminScreen();
      case 6:
        return const AdminReportsScreen();
      case 7:
        return const PollsAdminScreen();
      case 8:
        return const UserManagementScreen();
      case 9:
        return NotificationTestScreen();
      case 10:
        return NotificationTestScreen();
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EventViewModel()),
        ChangeNotifierProvider(create: (_) => AdminProposalsViewModel()),
        ChangeNotifierProvider(create: (_) => AdminDiscussionsViewModel()),
      ],
      child: NotificationListener<AdminTabChangeNotification>(
        onNotification: (notification) {
          setState(() {
            _selectedIndex = notification.tabIndex;
          });
          return true;
        },
        child: AdminLayout(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          child: _getScreen(),
        ),
      ),
    );
  }
}
