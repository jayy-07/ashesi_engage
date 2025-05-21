import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/entities/survey.dart';
import '../../../viewmodels/survey_viewmodel.dart';
import 'survey_card.dart';
import 'create_survey_screen.dart';

class SurveysAdminScreen extends StatefulWidget {
  const SurveysAdminScreen({super.key});

  @override
  State<SurveysAdminScreen> createState() => _SurveysAdminScreenState();
}

class _SurveysAdminScreenState extends State<SurveysAdminScreen> {
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  Set<String> _selectedClassScopes = {};
  Set<String> _selectedCategories = {};
  bool _showExpired = false;
  bool _isSelectionMode = false;
  Set<String> _selectedSurveyIds = {};
  
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _classSearchController = TextEditingController();
  final TextEditingController _categorySearchController = TextEditingController();
  String _classSearchQuery = '';
  String _categorySearchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _classSearchController.dispose();
    _categorySearchController.dispose();
    super.dispose();
  }

  Future<void> _showMultiSelectFilterDialog({
    required BuildContext context,
    required String title,
    required Set<String> selectedValues,
    required Set<String> options,
    required Function(Set<String>) onChanged,
    required TextEditingController searchController,
    required String searchQuery,
    required Function(String) onSearchChanged,
  }) async {
    Set<String> tempSelected = Set.from(selectedValues);
    String localSearchQuery = searchQuery;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(title),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.4,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search $title...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: localSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                onChanged: onSearchChanged,
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
                          .where((option) => searchQuery.isEmpty ||
                              option.toLowerCase().contains(searchQuery.toLowerCase()))
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
    );
  }

  List<Survey> _filterSurveys(SurveyViewModel viewModel) {
    // Get admin surveys without class filtering
    final surveys = viewModel.adminSurveys;
    
    return surveys.where((survey) {
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!survey.title.toLowerCase().contains(query) &&
            !survey.description.toLowerCase().contains(query) &&
            !survey.organizer.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Date range filter
      if (_selectedDateRange != null) {
        if (survey.createdAt.isBefore(_selectedDateRange!.start) ||
            survey.createdAt.isAfter(_selectedDateRange!.end)) {
          return false;
        }
      }

      // Category filter
      if (_selectedCategories.isNotEmpty && !_selectedCategories.contains(survey.category)) {
        return false;
      }

      // Expired filter
      if (!_showExpired && survey.expiresAt.isBefore(DateTime.now())) {
        return false;
      }

      return true;
    }).toList();
  }

  Widget _buildSearchAndFilters(List<Survey> surveys) {
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
                hintText: 'Search surveys...',
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

                  // Category filter
                  Consumer<SurveyViewModel>(
                    builder: (context, viewModel, child) {
                      return FilterChip(
                        label: Text(_selectedCategories.isEmpty
                            ? 'Select Categories'
                            : _selectedCategories.length == 1
                                ? _selectedCategories.first
                                : '${_selectedCategories.length} Categories'),
                        selected: _selectedCategories.isNotEmpty,
                        onSelected: (_) {
                          _showMultiSelectFilterDialog(
                            context: context,
                            title: 'Categories',
                            selectedValues: _selectedCategories,
                            options: viewModel.availableCategories,
                            onChanged: (value) => setState(() => _selectedCategories = value),
                            searchController: _categorySearchController,
                            searchQuery: _categorySearchQuery,
                            onSearchChanged: (value) => setState(() => _categorySearchQuery = value),
                          );
                        },
                        showCheckmark: false,
                        avatar: Icon(
                          Icons.category,
                          color: _selectedCategories.isNotEmpty
                              ? Theme.of(context).colorScheme.onSecondaryContainer
                              : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // Show expired surveys toggle
                  FilterChip(
                    label: const Text('Show Expired'),
                    selected: _showExpired,
                    onSelected: (bool selected) {
                      setState(() {
                        _showExpired = selected;
                      });
                    },
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.history,
                      color: _showExpired
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : null,
                    ),
                  ),

                  // Clear filters button
                  if (_searchQuery.isNotEmpty ||
                      _selectedDateRange != null ||
                      _selectedCategories.isNotEmpty ||
                      _showExpired) ...[
                    const SizedBox(width: 16),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                          _selectedDateRange = null;
                          _selectedCategories.clear();
                          _showExpired = false;
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
    );
  }

  Future<void> _deleteSelectedSurveys(BuildContext context, List<Survey> selectedSurveys) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Surveys'),
        content: Text(
          'Are you sure you want to delete ${selectedSurveys.length} selected survey${selectedSurveys.length > 1 ? 's' : ''}?'
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
        final viewModel = Provider.of<SurveyViewModel>(context, listen: false);
        for (final survey in selectedSurveys) {
          await viewModel.deleteSurvey(survey.id);
        }
        setState(() {
          _isSelectionMode = false;
          _selectedSurveyIds.clear();
        });
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedSurveys.length} survey${selectedSurveys.length > 1 ? 's' : ''} deleted successfully'),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete surveys: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<SurveyViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final surveys = _filterSurveys(viewModel);
          final selectedSurveys = surveys.where((s) => _selectedSurveyIds.contains(s.id)).toList();
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  children: [
                    if (!_isSelectionMode) ...[
                      Text(
                        'Manage Surveys',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (surveys.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isSelectionMode = true;
                            });
                          },
                          icon: const Icon(Icons.checklist),
                          tooltip: 'Select surveys',
                        ),
                    ] else ...[
                      Text(
                        '${_selectedSurveyIds.length} selected',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            if (_selectedSurveyIds.length == surveys.length) {
                              _selectedSurveyIds.clear();
                            } else {
                              _selectedSurveyIds = surveys.map((e) => e.id).toSet();
                            }
                          });
                        },
                        icon: Icon(_selectedSurveyIds.length == surveys.length 
                          ? Icons.deselect 
                          : Icons.select_all
                        ),
                        label: Text(_selectedSurveyIds.length == surveys.length 
                          ? 'Deselect All' 
                          : 'Select All'
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = false;
                            _selectedSurveyIds.clear();
                          });
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                      if (_selectedSurveyIds.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                            foregroundColor: Theme.of(context).colorScheme.onError,
                          ),
                          onPressed: () => _deleteSelectedSurveys(context, selectedSurveys),
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete Selected'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              _buildSearchAndFilters(surveys),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Divider(),
              ),
              Expanded(
                child: surveys.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.analytics_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No surveys found',
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
                          mainAxisExtent: 320,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: MediaQuery.of(context).size.width > 1400 ? 1.2 : 1,
                        ),
                        itemCount: surveys.length,
                        itemBuilder: (context, index) {
                          final survey = surveys[index];
                          return SurveyCard(
                            survey: survey,
                            isSelectionMode: _isSelectionMode,
                            isSelected: _selectedSurveyIds.contains(survey.id),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedSurveyIds.add(survey.id);
                                } else {
                                  _selectedSurveyIds.remove(survey.id);
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
                    builder: (context) => const CreateSurveyScreen(),
                    fullscreenDialog: true,
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Survey'),
            ),
    );
  }
}