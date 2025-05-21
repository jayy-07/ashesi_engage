import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../viewmodels/event_viewmodel.dart';
import '../widgets/admin_event_card.dart';
import '../widgets/create_event_screen.dart';
import '../../../models/entities/event.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  Set<String> _selectedLocations = {};
  Set<String> _selectedOrganizers = {};
  Set<String> _selectedClassScopes = {};
  final TextEditingController _searchController = TextEditingController();
  String _locationSearchQuery = '';
  String _organizerSearchQuery = '';
  String _classSearchQuery = '';
  final TextEditingController _locationSearchController = TextEditingController();
  final TextEditingController _organizerSearchController = TextEditingController();
  final TextEditingController _classSearchController = TextEditingController();
  bool _isSelectionMode = false;
  Set<String> _selectedEventIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    _locationSearchController.dispose();
    _organizerSearchController.dispose();
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

  List<Event> _filterEvents(List<Event> events) {
    return events.where((event) {
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!event.title.toLowerCase().contains(query) &&
            !event.shortDescription.toLowerCase().contains(query) &&
            !event.location.toLowerCase().contains(query) &&
            !event.organizer.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Date range filter
      if (_selectedDateRange != null) {
        final eventDate = DateTime(
          event.startTime.year,
          event.startTime.month,
          event.startTime.day,
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
        if (eventDate.isBefore(startDate) || eventDate.isAfter(endDate)) {
          return false;
        }
      }

      // Location filter
      if (_selectedLocations.isNotEmpty && !_selectedLocations.contains(event.location)) {
        return false;
      }

      // Organizer filter
      if (_selectedOrganizers.isNotEmpty && !_selectedOrganizers.contains(event.organizer)) {
        return false;
      }

      // Class scope filter
      if (_selectedClassScopes.isNotEmpty) {
        if (event.isAllClasses) return true;
        return event.classScopes.any((scope) => _selectedClassScopes.contains(scope));
      }

      return true;
    }).toList();
  }

  Set<String> _getUniqueLocations(List<Event> events) {
    return events.map((e) => e.location).toSet();
  }

  Set<String> _getUniqueOrganizers(List<Event> events) {
    return events.map((e) => e.organizer).toSet();
  }

  Future<void> _deleteSelectedEvents(BuildContext context, List<Event> selectedEvents) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Events'),
        content: Text(
          'Are you sure you want to delete ${selectedEvents.length} selected event${selectedEvents.length > 1 ? 's' : ''}?'
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
        final viewModel = Provider.of<EventViewModel>(context, listen: false);
        for (final event in selectedEvents) {
          await viewModel.deleteEvent(event);
        }
        setState(() {
          _isSelectionMode = false;
          _selectedEventIds.clear();
        });
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedEvents.length} event${selectedEvents.length > 1 ? 's' : ''} deleted successfully'),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete events: $e')),
        );
      }
    }
  }

  Widget _buildSearchAndFilters(List<Event> events) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          // Search field
          Expanded(
            flex: 2,  // Increased back to 2
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search events...',
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
          const SizedBox(width: 48),  // Increased spacing between search and filters
          
          // Filters
          Expanded(
            flex: 5,  // Increased to 5 to push filters more to the right
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
                  
                  // Location filter
                  FilterChip(
                    label: Text(_selectedLocations.isEmpty 
                        ? 'Select Locations' 
                        : _selectedLocations.length == 1 
                            ? _selectedLocations.first 
                            : '${_selectedLocations.length} Locations'),
                    selected: _selectedLocations.isNotEmpty,
                    onSelected: (bool selected) {
                      _showMultiSelectFilterDialog(
                        context: context,
                        title: 'Locations',
                        selectedValues: _selectedLocations,
                        options: _getUniqueLocations(events),
                        onChanged: (value) => setState(() => _selectedLocations = value),
                        searchController: _locationSearchController,
                        searchQuery: _locationSearchQuery,
                        onSearchChanged: (value) => setState(() => _locationSearchQuery = value),
                      );
                    },
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.location_on,
                      color: _selectedLocations.isNotEmpty
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Organizer filter
                  FilterChip(
                    label: Text(_selectedOrganizers.isEmpty 
                        ? 'Select Organizers' 
                        : _selectedOrganizers.length == 1 
                            ? _selectedOrganizers.first 
                            : '${_selectedOrganizers.length} Organizers'),
                    selected: _selectedOrganizers.isNotEmpty,
                    onSelected: (bool selected) {
                      _showMultiSelectFilterDialog(
                        context: context,
                        title: 'Organizers',
                        selectedValues: _selectedOrganizers,
                        options: _getUniqueOrganizers(events),
                        onChanged: (value) => setState(() => _selectedOrganizers = value),
                        searchController: _organizerSearchController,
                        searchQuery: _organizerSearchQuery,
                        onSearchChanged: (value) => setState(() => _organizerSearchQuery = value),
                      );
                    },
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.person,
                      color: _selectedOrganizers.isNotEmpty
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Class scope filter
                  Consumer<EventViewModel>(
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
                            options: viewModel.availableClasses.toSet(),
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

                  // Clear filters button
                  if (_searchQuery.isNotEmpty ||
                      _selectedDateRange != null ||
                      _selectedLocations.isNotEmpty ||
                      _selectedOrganizers.isNotEmpty ||
                      _selectedClassScopes.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                          _selectedDateRange = null;
                          _selectedLocations.clear();
                          _selectedOrganizers.clear();
                          _selectedClassScopes.clear();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<EventViewModel>(
        builder: (context, eventViewModel, child) {
          if (eventViewModel.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final events = _filterEvents(eventViewModel.events);
          final selectedEvents = events.where((e) => _selectedEventIds.contains(e.id)).toList();
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  children: [
                    if (!_isSelectionMode) ...[
                      Text(
                        'Manage Events',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (events.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isSelectionMode = true;
                            });
                          },
                          icon: const Icon(Icons.checklist),
                          tooltip: 'Select events',
                        ),
                    ] else ...[
                      Text(
                        '${_selectedEventIds.length} selected',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            if (_selectedEventIds.length == events.length) {
                              _selectedEventIds.clear();
                            } else {
                              _selectedEventIds = events.map((e) => e.id).toSet();
                            }
                          });
                        },
                        icon: Icon(_selectedEventIds.length == events.length 
                          ? Icons.deselect 
                          : Icons.select_all
                        ),
                        label: Text(_selectedEventIds.length == events.length 
                          ? 'Deselect All' 
                          : 'Select All'
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = false;
                            _selectedEventIds.clear();
                          });
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                      if (_selectedEventIds.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                            foregroundColor: Theme.of(context).colorScheme.onError,
                          ),
                          onPressed: () => _deleteSelectedEvents(context, selectedEvents),
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete Selected'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              _buildSearchAndFilters(eventViewModel.events),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Divider(),
              ),
              Expanded(
                child: events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No events found',
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
                          mainAxisExtent: 380,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: MediaQuery.of(context).size.width > 1400 ? 1.2 : 1,
                        ),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return AdminEventCard(
                            event: event,
                            isSelectionMode: _isSelectionMode,
                            isSelected: _selectedEventIds.contains(event.id),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedEventIds.add(event.id);
                                } else {
                                  _selectedEventIds.remove(event.id);
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
                    builder: (context) => const CreateEventScreen(),
                    fullscreenDialog: true,
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Event'),
            ),
    );
  }
}