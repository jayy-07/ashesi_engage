import 'dart:async';

import 'package:flutter/material.dart';
import '../models/entities/process.dart';
import '../models/entities/student_proposal.dart';
import '../models/services/proposal_service.dart';
import '../models/services/auth_service.dart';
import '../views/widgets/report_dialog.dart';
import '../widgets/snackbar_helper.dart';

class HomeViewModel extends ChangeNotifier {
  List<Process> _processes = [];
  bool _isLoading = true;
  final String _userName = "Joel"; // This would come from user service later

  // Getters
  List<Process> get processes => _processes;
  bool get isLoading => _isLoading;
  String get userName => _userName;

  HomeViewModel() {
    loadProcesses();
  }

  Future<void> loadProcesses() async {
    _isLoading = true;
    notifyListeners();

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    
    _processes = [
      const Process(
        title: 'Improving Campus Transportation',
        description: 'Help shape the future of campus transportation! '
            'We\'re gathering ideas to enhance shuttle services and '
            'introduce new options.',
        status: 'Active',
        imageUrl: 'https://picsum.photos/800/200',
        proposalProgress: 1.0,
        votingProgress: 0.6,
        implementationProgress: 0.0,
        daysLeft: 5,
        phase: 'Voting Phase',
      ),
      const Process(
        title: 'Campus Sustainability Initiative',
        description: 'Join us in making our campus more environmentally friendly '
            'through innovative recycling programs and renewable energy solutions.',
        status: 'Active',
        imageUrl: 'https://picsum.photos/800/201',
        proposalProgress: 0.8,
        votingProgress: 0.0,
        implementationProgress: 0.0,
        daysLeft: 12,
        phase: 'Proposal Phase',
      ),
    ];

    _isLoading = false;
    notifyListeners();
  }

  void onParticipate(Process process) {
    // Handle participate action
    // This would be implemented later with actual functionality
    //print('Participating in process: ${process.title}');
  }
}

class ProposalsViewModel extends ChangeNotifier {
  final ProposalService _proposalService;
  final AuthService _authService;
  List<StudentProposal> _proposals = [];
  bool _isLoading = true;
  final bool _isRefreshing = false;
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isFabExtended = true;
  StreamSubscription<List<StudentProposal>>? _proposalsSubscription;
  Timer? _searchDebouncer;

  // Getters
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isSearching => _isSearching;
  List<StudentProposal> get proposals => _proposals;
  String get searchQuery => _searchQuery;
  bool get isFabExtended => _isFabExtended;

  List<StudentProposal> get filteredProposals {
    if (_searchQuery.isEmpty) return [];
    
    final query = _searchQuery.toLowerCase();
    return _proposals.where((proposal) {
      return proposal.title.toLowerCase().contains(query) ||
             proposal.plainContent.toLowerCase().contains(query) ||
             proposal.authorName.toLowerCase().contains(query) ||
             proposal.authorClass.toLowerCase().contains(query); // Add class search
    }).toList();
  }

  List<StudentProposal> getUserProposals() {
    final user = _authService.currentUser;
    if (user == null) return [];
    
    return _proposals.where((proposal) => 
      proposal.authorId == user.uid
    ).toList();
  }

  ProposalsViewModel(this._authService) : _proposalService = ProposalService() {
    _initProposalsStream();
  }

  void _initProposalsStream() {
    _isLoading = true;
    notifyListeners();

    _proposalsSubscription = _proposalService.getProposals().listen(
      (proposals) {
        _proposals = proposals.map((proposal) {
          final user = _authService.currentUser;
          return proposal.copyWith(
            isEndorsedByUser: user != null && proposal.hasUserEndorsed(user.uid)
          );
        }).toList();
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error loading proposals: $error');
        _isLoading = false;
        notifyListeners();
      }
    );
  }

  @override
  void dispose() {
    _searchDebouncer?.cancel();
    _proposalsSubscription?.cancel();
    _searchQuery = '';
    super.dispose();
  }

  void setFabExtended(bool extended) {
    _isFabExtended = extended;
    notifyListeners();
  }

  Future<void> updateSearchQuery(String query) async {
    _searchQuery = query;
    _isSearching = true;
    notifyListeners();

    // Cancel previous debouncer if any
    _searchDebouncer?.cancel();
    
    // Debounce search to avoid excessive updates
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () {
      _isSearching = false;
      notifyListeners();
    });
  }

  void clearSearch() {
    _searchQuery = '';
    _isSearching = false;
    notifyListeners();
  }

  Future<void> endorseProposal(String proposalId) async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final proposal = _proposals.firstWhere((p) => p.id == proposalId);
      
      if (proposal.isEndorsedByUser) {
        await _proposalService.removeEndorsement(proposalId, user.uid);
      } else {
        await _proposalService.endorseProposal(proposalId, user.uid);
      }
      // The stream will automatically update the UI
    } catch (e) {
      debugPrint('Error toggling endorsement: $e');
      rethrow;
    }
  }

  Future<void> removeEndorsement(String proposalId) async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      await _proposalService.removeEndorsement(proposalId, user.uid);
      // The stream will automatically update the UI
    } catch (e) {
      debugPrint('Error removing endorsement: $e');
      rethrow;
    }
  }

  Future<void> replyToProposal(String proposalId) async {
    // TODO: Implement reply logic
    notifyListeners();
  }

  Future<void> reportProposal(String proposalId, BuildContext context) async {
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => ReportDialog(
          contentType: 'proposal',
          contentId: proposalId,
        ),
      );

      if (result == true) {
        debugPrint('Proposal reported: $proposalId');
      }
    } catch (e) {
      debugPrint('Error reporting proposal: $e');
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Failed to report proposal. Please try again.');
      }
    }
  }

  Future<void> deleteProposal(String proposalId) async {
    try {
      await _proposalService.deleteProposal(proposalId);
      // Stream will automatically update the UI
    } catch (e) {
      debugPrint('Error deleting proposal: $e');
      rethrow;
    }
  }
}