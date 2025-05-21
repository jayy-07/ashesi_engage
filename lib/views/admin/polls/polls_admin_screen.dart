import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../viewmodels/admin_polls_viewmodel.dart';
import '../../../models/entities/poll.dart';
import 'create_poll_screen.dart';
import 'poll_admin_card.dart'; // Import the standalone PollAdminCard

class PollsAdminScreen extends StatefulWidget {
  const PollsAdminScreen({super.key});

  @override
  State<PollsAdminScreen> createState() => _PollsAdminScreenState();
}

class _PollsAdminScreenState extends State<PollsAdminScreen> {
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  Set<String> _selectedClassScopes = {};
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _classSearchController = TextEditingController();
  String _classSearchQuery = '';
  bool _isSelectionMode = false;
  Set<String> _selectedPollIds = {};

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

  List<Poll> _filterPolls(List<Poll> polls) {
    return polls.where((poll) {
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!poll.title.toLowerCase().contains(query) &&
            !poll.description.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Date range filter
      if (_selectedDateRange != null) {
        final pollDate = DateTime(
          poll.createdAt.year,
          poll.createdAt.month,
          poll.createdAt.day,
        );
        final startDate = DateTime(
          _selectedDateRange!.start.year,
          _selectedDateRange!.start.month,
          _selectedDateRange!.start.day,
        );
        final endDate = DateTime(
          _selectedDateRange!.end.year,
          _selectedDateRange!.end.month,
          _selectedDateRange!.end.day,
        );
        if (pollDate.isBefore(startDate) || pollDate.isAfter(endDate)) {
          return false;
        }
      }

      // Class scope filter
      if (_selectedClassScopes.isNotEmpty) {
        if (poll.isAllClasses) return true;
        return poll.classScopes.any((scope) => _selectedClassScopes.contains(scope));
      }

      return true;
    }).toList();
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          // Search field
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search polls...',
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
                  // Date range filter
                  FilterChip(
                    label: Text(_selectedDateRange == null
                        ? 'Select Dates'
                        : '${DateFormat.MMMd().format(_selectedDateRange!.start)} - ${DateFormat.MMMd().format(_selectedDateRange!.end)}'),
                    selected: _selectedDateRange != null,
                    onSelected: (bool selected) async {
                      if (selected) {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                          initialDateRange: _selectedDateRange ?? DateTimeRange(
                            start: DateTime.now(),
                            end: DateTime.now().add(const Duration(days: 7)),
                          ),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                datePickerTheme: DatePickerThemeData(
                                  headerBackgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDateRange = picked;
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
                  const SizedBox(width: 8),

                  // Class scope filter
                  Consumer<AdminPollsViewModel>(
                    builder: (context, viewModel, child) {
                      return FilterChip(
                        label: Text(_selectedClassScopes.isEmpty 
                            ? 'Select Classes' 
                            : _selectedClassScopes.length == 1 
                                ? _selectedClassScopes.first 
                                : '${_selectedClassScopes.length} Classes'),
                        selected: _selectedClassScopes.isNotEmpty,
                        onSelected: (bool selected) {
                          _showMultiSelectFilterDialog(
                            context: context,
                            title: 'Classes',
                            selectedValues: _selectedClassScopes,
                            options: viewModel.availableClasses,
                            onChanged: (value) => setState(() => _selectedClassScopes = value),
                            searchController: _classSearchController,
                            searchQuery: _classSearchQuery,
                            onSearchChanged: (value) => setState(() => _classSearchQuery = value),
                          );
                        },
                        showCheckmark: false,
                        avatar: Icon(
                          Icons.school,
                          color: _selectedClassScopes.isNotEmpty
                              ? Theme.of(context).colorScheme.onSecondaryContainer
                              : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // Show expired polls toggle
                  FilterChip(
                    label: const Text('Show Expired'),
                    selected: context.watch<AdminPollsViewModel>().showExpiredPolls,
                    onSelected: (bool selected) {
                      context.read<AdminPollsViewModel>().toggleExpiredPolls();
                    },
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.history,
                      color: context.watch<AdminPollsViewModel>().showExpiredPolls
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : null,
                    ),
                  ),

                  // Clear filters button
                  if (_searchQuery.isNotEmpty ||
                      _selectedDateRange != null ||
                      _selectedClassScopes.isNotEmpty ||
                      context.watch<AdminPollsViewModel>().showExpiredPolls) ...[
                    const SizedBox(width: 16),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                          _selectedDateRange = null;
                          _selectedClassScopes.clear();
                        });
                        if (context.read<AdminPollsViewModel>().showExpiredPolls) {
                          context.read<AdminPollsViewModel>().toggleExpiredPolls();
                        }
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
    );
  }

  Future<void> _deleteSelectedPolls(BuildContext context, List<Poll> selectedPolls) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Polls'),
        content: Text(
          'Are you sure you want to delete ${selectedPolls.length} selected poll${selectedPolls.length > 1 ? 's' : ''}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!context.mounted) return;
      
      try {
        final viewModel = Provider.of<AdminPollsViewModel>(context, listen: false);
        for (final poll in selectedPolls) {
          await viewModel.deletePoll(poll.id);
        }
        setState(() {
          _isSelectionMode = false;
          _selectedPollIds.clear();
        });
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedPolls.length} poll${selectedPolls.length > 1 ? 's' : ''} deleted successfully'),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete polls: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AdminPollsViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final polls = _filterPolls(viewModel.polls);
          final selectedPolls = polls.where((p) => _selectedPollIds.contains(p.id)).toList();
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  children: [
                    if (!_isSelectionMode) ...[
                      Text(
                        'Manage Polls',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (polls.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isSelectionMode = true;
                            });
                          },
                          icon: const Icon(Icons.checklist),
                          tooltip: 'Select polls',
                        ),
                    ] else ...[
                      Text(
                        '${_selectedPollIds.length} selected',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            if (_selectedPollIds.length == polls.length) {
                              _selectedPollIds.clear();
                            } else {
                              _selectedPollIds = polls.map((e) => e.id).toSet();
                            }
                          });
                        },
                        icon: Icon(_selectedPollIds.length == polls.length 
                          ? Icons.deselect 
                          : Icons.select_all
                        ),
                        label: Text(_selectedPollIds.length == polls.length 
                          ? 'Deselect All' 
                          : 'Select All'
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = false;
                            _selectedPollIds.clear();
                          });
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                      if (_selectedPollIds.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                            foregroundColor: Theme.of(context).colorScheme.onError,
                          ),
                          onPressed: () => _deleteSelectedPolls(context, selectedPolls),
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete Selected'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              _buildSearchAndFilters(),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Divider(),
              ),
              Expanded(
                child: polls.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.poll_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No polls found',
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
                        itemCount: polls.length,
                        itemBuilder: (context, index) {
                          final poll = polls[index];
                          return PollAdminCard(
                            poll: poll,
                            isSelectionMode: _isSelectionMode,
                            isSelected: _selectedPollIds.contains(poll.id),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedPollIds.add(poll.id);
                                } else {
                                  _selectedPollIds.remove(poll.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CreatePollScreen(),
                    fullscreenDialog: true,
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Poll'),
            ),
    );
  }
}