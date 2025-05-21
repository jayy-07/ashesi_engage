import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/entities/discussion_post.dart';
import '../../../models/services/discussion_service.dart';
import '../../../viewmodels/admin_discussions_viewmodel.dart';
import '../widgets/admin_discussion_card.dart';
import 'admin_discussion_detail_screen.dart';

class AdminDiscussionsScreen extends StatefulWidget {
  final String? initialDiscussionId;
  final String? highlightCommentId;

  const AdminDiscussionsScreen({
    super.key,
    this.initialDiscussionId,
    this.highlightCommentId,
  });

  @override
  State<AdminDiscussionsScreen> createState() => _AdminDiscussionsScreenState();
}

class _AdminDiscussionsScreenState extends State<AdminDiscussionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _classSearchController = TextEditingController();
  bool _isSelectionMode = false;
  Set<String> _selectedDiscussionIds = {};
  String _searchQuery = '';
  String _classSearchQuery = '';
  Set<String> _selectedClasses = {};
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // If we have an initial discussion ID, directly navigate to the detail screen
    if (widget.initialDiscussionId != null) {
      debugPrint('AdminDiscussionsScreen initialized with discussionId: ${widget.initialDiscussionId}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // First load the discussion data
        DiscussionService().getDiscussion(widget.initialDiscussionId!).then((discussion) {
          if (discussion != null && mounted) {
            debugPrint('Discussion loaded, showing detail screen');
            // Navigate directly to the detail screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminDiscussionDetailScreen(discussion: discussion),
              ),
            );
          }
        });
      });
    }
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
    return Consumer<AdminDiscussionsViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final discussions = viewModel.discussions;
        
        // If a discussion is selected, find it and show the detail screen
        if (viewModel.selectedDiscussionId != null) {
          debugPrint('Building AdminDiscussionsScreen with selectedDiscussionId: ${viewModel.selectedDiscussionId}');
          debugPrint('Available discussion IDs: ${discussions.map((d) => d.id).join(', ')}');
          
          // Find the selected discussion
          final selectedDiscussionList = discussions.where(
            (d) => d.id == viewModel.selectedDiscussionId
          ).toList();
          
          if (selectedDiscussionList.isNotEmpty) {
            debugPrint('Found selected discussion, showing detail screen');
            return AdminDiscussionDetailScreen(discussion: selectedDiscussionList.first);
          } else {
            // If we couldn't find the discussion in the list, it might not be loaded yet
            // Let's fetch it directly
            return FutureBuilder<DiscussionPost?>(
              future: DiscussionService().getDiscussion(viewModel.selectedDiscussionId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasData && snapshot.data != null) {
                  debugPrint('Loaded discussion directly, showing detail screen');
                  return AdminDiscussionDetailScreen(discussion: snapshot.data!);
                }
                
                // If we couldn't find or load the discussion, show the list view anyway
                debugPrint('Could not find discussion with ID: ${viewModel.selectedDiscussionId}');
                return const Center(child: Text('Discussion not found'));
              },
            );
          }
        }

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
                        'Manage Discussions',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (discussions.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isSelectionMode = true;
                            });
                          },
                          icon: const Icon(Icons.checklist),
                          tooltip: 'Select discussions',
                        ),
                    ] else ...[
                      Text(
                        '${_selectedDiscussionIds.length} selected',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            if (_selectedDiscussionIds.length == discussions.length) {
                              _selectedDiscussionIds.clear();
                            } else {
                              _selectedDiscussionIds = discussions.map((e) => e.id).toSet();
                            }
                          });
                        },
                        icon: Icon(_selectedDiscussionIds.length == discussions.length 
                          ? Icons.deselect 
                          : Icons.select_all
                        ),
                        label: Text(_selectedDiscussionIds.length == discussions.length 
                          ? 'Deselect All' 
                          : 'Select All'
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = false;
                            _selectedDiscussionIds.clear();
                          });
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                      if (_selectedDiscussionIds.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                            foregroundColor: Theme.of(context).colorScheme.onError,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Discussions'),
                                content: Text(
                                  'Are you sure you want to delete ${_selectedDiscussionIds.length} discussion${_selectedDiscussionIds.length == 1 ? '' : 's'}? This action cannot be undone.'
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('CANCEL'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.error,
                                      foregroundColor: Theme.of(context).colorScheme.onError,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      for (final id in _selectedDiscussionIds) {
                                        viewModel.deleteDiscussion(id);
                                      }
                                      setState(() {
                                        _isSelectionMode = false;
                                        _selectedDiscussionIds.clear();
                                      });
                                    },
                                    child: const Text('DELETE'),
                                  ),
                                ],
                              ),
                            );
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
                          hintText: 'Search discussions...',
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
                child: discussions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No discussions found',
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
                          mainAxisExtent: 200, // Slightly shorter than proposals since discussions are typically shorter
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: MediaQuery.of(context).size.width > 1400 ? 1.2 : 1,
                        ),
                        itemCount: discussions.length,
                        itemBuilder: (context, index) {
                          final discussion = discussions[index];
                          if (_searchQuery.isNotEmpty) {
                            final query = _searchQuery.toLowerCase();
                            if (!discussion.plainContent.toLowerCase().contains(query) &&
                                !discussion.authorName.toLowerCase().contains(query) &&
                                !discussion.authorClass.toLowerCase().contains(query)) {
                              return const SizedBox.shrink();
                            }
                          }
                          if (_selectedClasses.isNotEmpty && !_selectedClasses.contains(discussion.authorClass)) {
                            return const SizedBox.shrink();
                          }
                          if (_selectedDateRange != null) {
                            if (discussion.datePosted.isBefore(_selectedDateRange!.start) ||
                                discussion.datePosted.isAfter(_selectedDateRange!.end.add(const Duration(days: 1)))) {
                              return const SizedBox.shrink();
                            }
                          }
                          return AdminDiscussionCard(
                            discussion: discussion,
                            onDelete: () => viewModel.deleteDiscussion(discussion.id),
                            isSelectionMode: _isSelectionMode,
                            isSelected: _selectedDiscussionIds.contains(discussion.id),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedDiscussionIds.add(discussion.id);
                                } else {
                                  _selectedDiscussionIds.remove(discussion.id);
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