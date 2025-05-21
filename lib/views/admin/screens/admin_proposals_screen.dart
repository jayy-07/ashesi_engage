import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/admin_proposals_viewmodel.dart';
import '../widgets/admin_proposal_card.dart';

class AdminProposalsScreen extends StatefulWidget {
  final String? initialProposalId;
  final String? highlightCommentId;

  const AdminProposalsScreen({
    super.key,
    this.initialProposalId,
    this.highlightCommentId,
  });

  @override
  State<AdminProposalsScreen> createState() => _AdminProposalsScreenState();
}

class _AdminProposalsScreenState extends State<AdminProposalsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _classSearchController = TextEditingController();
  String _searchQuery = '';
  String _classSearchQuery = '';
  Set<String> _selectedClasses = {};
  bool _isSelectionMode = false;
  Set<String> _selectedProposalIds = {};
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // Load proposals when the screen is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProposalsViewModel>(context, listen: false).loadProposals();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _classSearchController.dispose();
    super.dispose();
  }

  void _showMultiSelectFilterDialog({
    required BuildContext context,
    required String title,
    required Set<String> selectedValues,
    required Set<String> options,
    required ValueChanged<Set<String>> onChanged,
    required TextEditingController searchController,
    required String searchQuery,
    required ValueChanged<String> onSearchChanged,
  }) {
    // Reset search query when dialog opens
    searchController.clear();
    String localSearchQuery = '';
    Set<String> tempSelected = Set.from(selectedValues);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400,
              maxHeight: 500,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
        children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchController,
              decoration: InputDecoration(
                      hintText: 'Search ${title.toLowerCase()}...',
                prefixIcon: const Icon(Icons.search),
                      suffixIcon: localSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                                searchController.clear();
                          setState(() {
                                  localSearchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
              onChanged: (value) {
                setState(() {
                        localSearchQuery = value;
                });
              },
            ),
                  const SizedBox(height: 16),
          Expanded(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ListView(
                        padding: EdgeInsets.zero,
                children: [
                          ListTile(
                            leading: Icon(
                              tempSelected.isEmpty ? Icons.check_circle : Icons.check_box_outline_blank,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: const Text('All'),
                            onTap: () {
                              setState(() {
                                tempSelected.clear();
                              });
                            },
                          ),
                          const Divider(height: 1),
                          ...options
                              .where((option) => localSearchQuery.isEmpty ||
                                  option.toLowerCase().contains(localSearchQuery.toLowerCase()))
                              .map(
                                (option) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    ListTile(
                                      leading: Icon(
                                        tempSelected.contains(option) ? Icons.check_box : Icons.check_box_outline_blank,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      title: Text(option),
                                      onTap: () {
                                        setState(() {
                                          if (tempSelected.contains(option)) {
                                            tempSelected.remove(option);
                                          } else {
                                            tempSelected.add(option);
                                          }
                                        });
                                      },
                                    ),
                                    if (option != options.last) const Divider(height: 1),
                                  ],
                                ),
                              ),
                            ],
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('CANCEL'),
                              ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          onChanged(tempSelected);
                          Navigator.pop(context);
                        },
                        child: const Text('APPLY'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProposalsViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final proposals = viewModel.proposals;

        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  children: [
                    if (!_isSelectionMode) ...[
                      Text(
                        'Manage Proposals',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (proposals.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isSelectionMode = true;
                            });
                          },
                          icon: const Icon(Icons.checklist),
                          tooltip: 'Select proposals',
                        ),
                    ] else ...[
                      Text(
                        '${_selectedProposalIds.length} selected',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            if (_selectedProposalIds.length == proposals.length) {
                              _selectedProposalIds.clear();
                            } else {
                              _selectedProposalIds = proposals.map((e) => e.id).toSet();
                            }
                          });
                        },
                        icon: Icon(_selectedProposalIds.length == proposals.length 
                          ? Icons.deselect 
                          : Icons.select_all
                        ),
                        label: Text(_selectedProposalIds.length == proposals.length 
                          ? 'Deselect All' 
                          : 'Select All'
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = false;
                            _selectedProposalIds.clear();
                          });
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                      if (_selectedProposalIds.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                            foregroundColor: Theme.of(context).colorScheme.onError,
                          ),
                          onPressed: () {
                            // TODO: Implement bulk delete
                          },
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete Selected'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    // Search field
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search proposals...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _searchController.clear();
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 48),
                    
                    // Filters
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Class filter
                            FilterChip(
                              label: Text(_selectedClasses.isEmpty 
                                  ? 'Select Classes' 
                                  : _selectedClasses.length == 1 
                                      ? _selectedClasses.first 
                                      : '${_selectedClasses.length} Classes'),
                              selected: _selectedClasses.isNotEmpty,
                              onSelected: (bool selected) {
                                _showMultiSelectFilterDialog(
                                  context: context,
                                  title: 'Classes',
                                  selectedValues: _selectedClasses,
                                  options: viewModel.availableClasses,
                                  onChanged: (value) => setState(() => _selectedClasses = value),
                                  searchController: _classSearchController,
                                  searchQuery: _classSearchQuery,
                                  onSearchChanged: (value) => setState(() => _classSearchQuery = value),
                                );
                              },
                              showCheckmark: false,
                              avatar: Icon(
                                Icons.school,
                                color: _selectedClasses.isNotEmpty
                                    ? Theme.of(context).colorScheme.onSecondaryContainer
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Date filter
                            FilterChip(
                              label: Text(_selectedDateRange == null
                                  ? 'Select Date Range'
                                  : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}'),
                              selected: _selectedDateRange != null,
                              onSelected: (bool selected) async {
                                if (selected) {
                                  final DateTimeRange? result = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                    currentDate: DateTime.now(),
                                    saveText: 'APPLY',
                                  );
                                  if (result != null) {
                                    setState(() {
                                      _selectedDateRange = result;
                                    });
                                  }
                                } else {
                                  setState(() {
                                    _selectedDateRange = null;
                                  });
                                }
                              },
                              showCheckmark: false,
                              avatar: Icon(
                                Icons.calendar_today,
                                color: _selectedDateRange != null
                                    ? Theme.of(context).colorScheme.onSecondaryContainer
                                    : null,
                              ),
                            ),

                            // Clear filters button
                            if (_searchQuery.isNotEmpty ||
                                _selectedClasses.isNotEmpty ||
                                _selectedDateRange != null) ...[
                              const SizedBox(width: 16),
                              FilledButton.tonalIcon(
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _searchController.clear();
                                    _selectedClasses.clear();
                                    _selectedDateRange = null;
                                  });
                                },
                                icon: const Icon(Icons.clear_all),
                                label: const Text('Clear Filters'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Divider(),
              ),
              Expanded(
                child: proposals.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No proposals found',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your filters',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 600,
                          mainAxisExtent: 280,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: MediaQuery.of(context).size.width > 1400 ? 1.2 : 1,
                        ),
                        itemCount: proposals.length,
                        itemBuilder: (context, index) {
                          final proposal = proposals[index];
                          if (_searchQuery.isNotEmpty) {
                            final query = _searchQuery.toLowerCase();
                            if (!proposal.title.toLowerCase().contains(query) &&
                                !proposal.plainContent.toLowerCase().contains(query) &&
                                !proposal.authorName.toLowerCase().contains(query) &&
                                !proposal.authorClass.toLowerCase().contains(query)) {
                              return const SizedBox.shrink();
                            }
                          }
                          if (_selectedClasses.isNotEmpty && !_selectedClasses.contains(proposal.authorClass)) {
                            return const SizedBox.shrink();
                          }
                          if (_selectedDateRange != null) {
                            if (proposal.datePosted.isBefore(_selectedDateRange!.start) ||
                                proposal.datePosted.isAfter(_selectedDateRange!.end.add(const Duration(days: 1)))) {
                              return const SizedBox.shrink();
                            }
                          }
                          return AdminProposalCard(
                            proposal: proposal,
                            onDelete: () async {
                              try {
                                await viewModel.deleteProposal(proposal.id);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Proposal deleted successfully')),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to delete proposal: $e')),
                                  );
                                }
                              }
                            },
                            onAnswer: (answer) async {
                              try {
                                await viewModel.answerProposal(
                                  proposal.id,
                                  answer,
                                  viewModel.currentAdminId,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Answer submitted successfully')),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to submit answer: $e')),
                                  );
                                }
                              }
                            },
                            isSelectionMode: _isSelectionMode,
                            isSelected: _selectedProposalIds.contains(proposal.id),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedProposalIds.add(proposal.id);
                                } else {
                                  _selectedProposalIds.remove(proposal.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
          );
        },
    );
  }
}