import 'package:flutter/material.dart';
import '../../models/entities/student_proposal.dart';
import '../../models/services/proposal_service.dart';
import '../../models/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ProposalSort {
  newest,
  oldest,
}

class AdminProposalsViewModel extends ChangeNotifier {
  final ProposalService _proposalService;
  final UserService _userService = UserService();
  List<StudentProposal> _proposals = [];
  List<StudentProposal> _filteredProposals = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String? _selectedClass;
  ProposalSort _sortOrder = ProposalSort.newest;
  List<String> _availableClasses = [];
  String? _currentAdminId;
  String? _currentAdminName;
  bool _isDisposed = false;
  bool _showDeleted = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Getters
  List<StudentProposal> get proposals => _filteredProposals;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get selectedClass => _selectedClass;
  ProposalSort get sortOrder => _sortOrder;
  List<String> get availableClasses => _availableClasses;
  String get currentAdminId => _currentAdminId ?? '';
  String get currentAdminName => _currentAdminName ?? '';
  bool get showDeleted => _showDeleted;

  // Add this setter
  set showDeleted(bool value) {
    if (_showDeleted != value) {
      _showDeleted = value;
      _applyFilters();
      _safeNotifyListeners();
    }
  }

  AdminProposalsViewModel(this._proposalService) {
    _loadProposals();
    _loadAvailableClasses();
    _loadCurrentAdmin();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> _loadCurrentAdmin() async {
    try {
      final currentUser = await _userService.getCurrentUser();
      if (currentUser != null && !_isDisposed) {
        _currentAdminId = currentUser.id;
        _currentAdminName = currentUser.name;
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading current admin: $e');
    }
  }

  Future<void> _loadAvailableClasses() async {
    try {
      _availableClasses = await _userService.getAvailableClasses();
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('Error loading classes: $e');
    }
  }

  Future<void> _loadProposals() async {
    try {
      _isLoading = true;
      _safeNotifyListeners();

      // For admin view, we need to get all proposals including deleted ones
      final QuerySnapshot snapshot = await _firestore
          .collection('proposals')
          .orderBy('datePosted', descending: true)
          .get();

      _proposals = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StudentProposal.fromMap({
          'id': doc.id,
          ...data,
        });
      }).toList();

      _applyFilters();
      _isLoading = false;
      _safeNotifyListeners();
    } catch (e) {
      _error = 'Error loading proposals: $e';
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> refreshProposals() => _loadProposals();

  void _applyFilters() {
    List<StudentProposal> filtered = List.from(_proposals);

    // Filter by deleted status if needed
    if (!_showDeleted) {
      filtered = filtered.where((proposal) => proposal.deleted != true).toList();
    }

    // Apply class filter if selected
    if (_selectedClass != null && _selectedClass!.isNotEmpty) {
      filtered = filtered.where((p) => p.authorClass == _selectedClass).toList();
    }

    // Apply search query if any
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) => 
        p.title.toLowerCase().contains(query) || 
        p.plainContent.toLowerCase().contains(query) ||
        p.authorName.toLowerCase().contains(query)
      ).toList();
    }

    // Apply sorting
    if (_sortOrder == ProposalSort.newest) {
      filtered.sort((a, b) => b.datePosted.compareTo(a.datePosted));
    } else {
      filtered.sort((a, b) => a.datePosted.compareTo(b.datePosted));
    }

    _filteredProposals = filtered;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    _safeNotifyListeners();
  }

  void setSelectedClass(String? className) {
    _selectedClass = className;
    _applyFilters();
    _safeNotifyListeners();
  }

  void setSortOrder(ProposalSort order) {
    _sortOrder = order;
    _applyFilters();
    _safeNotifyListeners();
  }


  Color getSentimentColor(double score) {
    if (score >= 0.7) return Colors.green;
    if (score >= 0.4) return Colors.orange;
    return Colors.red;
  }

  Future<void> deleteProposal(StudentProposal proposal) async {
    try {
      await _firestore.collection('proposals').doc(proposal.id).update({
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
      await refreshProposals();
    } catch (e) {
      throw Exception('Failed to delete proposal: $e');
    }
  }
} 