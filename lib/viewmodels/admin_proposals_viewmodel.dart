import 'package:flutter/foundation.dart';
import 'package:flutter_quill/quill_delta.dart';
import '../models/entities/student_proposal.dart';
import '../models/services/proposal_service.dart';
import '../models/services/auth_service.dart';

class AdminProposalsViewModel extends ChangeNotifier {
  final ProposalService _proposalService = ProposalService();
  List<StudentProposal> _proposals = [];
  List<StudentProposal> _filteredProposals = [];
  bool _isLoading = false;
  String? _error;
  String? _currentAdminName;
  String? _currentAdminId;
  Set<String> _selectedClasses = {};
  String _searchQuery = '';

  List<StudentProposal> get proposals => _filteredProposals;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Set<String> get selectedClasses => _selectedClasses;
  String get searchQuery => _searchQuery;
  String get currentAdminId => _currentAdminId ?? '';
  String get currentAdminName => _currentAdminName ?? '';

  // Get unique classes from proposals
  Set<String> get availableClasses => _proposals.map((p) => p.authorClass).toSet();

  void setClassFilters(Set<String> classes) {
    _selectedClasses = classes;
    _applyFilters();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _selectedClasses.clear();
    _searchQuery = '';
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filteredProposals = _proposals.where((proposal) {
      // Apply class filter
      if (_selectedClasses.isNotEmpty && !_selectedClasses.contains(proposal.authorClass)) {
        return false;
      }

      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return proposal.title.toLowerCase().contains(query) ||
               proposal.plainContent.toLowerCase().contains(query) ||
               proposal.authorName.toLowerCase().contains(query) ||
               proposal.authorClass.toLowerCase().contains(query);
      }

      return true;
    }).toList();
  }

  Future<void> loadCurrentAdmin() async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user != null) {
        _currentAdminId = user.uid;
        _currentAdminName = '${user.displayName}';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading current admin: $e');
    }
  }

  Future<void> loadProposals() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await loadCurrentAdmin(); // Load admin info first
      _proposals = await _proposalService.getAllProposals();
      _filteredProposals = List.from(_proposals); // Initialize filtered list
      _error = null;
    } catch (e) {
      _error = 'Failed to load proposals: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteProposal(String proposalId) async {
    try {
      await _proposalService.deleteProposal(proposalId);
      _proposals.removeWhere((proposal) => proposal.id == proposalId);
      _applyFilters(); // Update filtered list
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete proposal: $e';
      debugPrint(_error);
      rethrow;
    }
  }

  Future<void> answerProposal(String proposalId, Delta answer, String adminId) async {
    try {
      await _proposalService.answerProposal(
        proposalId: proposalId,
        answer: answer,
        plainAnswer: answer.toList().map((op) => op.value?.toString() ?? '').join(''),
        adminId: adminId,
        adminName: _currentAdminName ?? 'Admin',
      );
      
      // Update local state
      final index = _proposals.indexWhere((p) => p.id == proposalId);
      if (index != -1) {
        _proposals[index] = _proposals[index].copyWith(
          answer: {'ops': answer.toJson()},
          plainAnswer: answer.toList().map((op) => op.value?.toString() ?? '').join(''),
          answeredAt: DateTime.now(),
          answeredBy: adminId,
          answeredByName: _currentAdminName ?? 'Admin',
        );
        _applyFilters();
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to answer proposal: $e';
      debugPrint(_error);
      rethrow;
    }
  }

  // Method to select a specific proposal, potentially with a highlighted comment
  void selectProposal(String proposalId, String? highlightCommentId) {
    // This method could be implemented to store the selected proposal ID
    // and handle any UI updates needed when a proposal is selected from elsewhere
    debugPrint('Selected proposal: $proposalId, highlight comment: $highlightCommentId');
    // Additional implementation could involve fetching the proposal details
    // or updating UI state to show the proposal and highlight the comment
    notifyListeners();
  }
}