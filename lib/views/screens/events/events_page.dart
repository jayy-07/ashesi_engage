import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../models/entities/event.dart';
import '../../../viewmodels/events_viewmodel.dart';
import '../../widgets/events/event_card.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final _filters = [
    (label: 'All Events', value: EventFilter.all),
    (label: 'Today', value: EventFilter.today),
    (label: 'This Week', value: EventFilter.thisWeek),
    (label: 'This Month', value: EventFilter.thisMonth),
  ];

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final _firstDay = DateTime.now().subtract(const Duration(days: 30)); // Allow viewing current month
  final _lastDay = DateTime.now().add(const Duration(days: 365));
  bool _isCalendarVisible = false;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  Map<DateTime, List<Event>> _getEventsForDay(EventsViewModel viewModel) {
    Map<DateTime, List<Event>> events = {};
    
    for (var monthEvents in viewModel.eventsByMonth.values) {
      for (var event in monthEvents) {
        final day = DateTime(event.startTime.year, event.startTime.month, event.startTime.day);
        events[day] = [...(events[day] ?? []), event];
      }
    }

    //log('Normalized Events for days: ${events.keys}');
    return events;
  }

  List<Event> _getEventsForSelectedDay(EventsViewModel viewModel) {
    if (_selectedDay == null) return [];
    
    final events = _getEventsForDay(viewModel);
    return events[DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay, EventsViewModel viewModel) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        // When selecting a day, automatically set filter to show only that day's events
        viewModel.setFilter(EventFilter.all); // Reset to all first to ensure view updates properly
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EventsViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = _getEventsForDay(viewModel);
        final selectedDayEvents = _getEventsForSelectedDay(viewModel);
        final colorScheme = Theme.of(context).colorScheme;

        return RefreshIndicator(
          onRefresh: viewModel.loadUserClassAndEvents,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // Calendar toggle button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isCalendarVisible = !_isCalendarVisible;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Calendar',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                _isCalendarVisible ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Animated calendar with sliding animation
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return SizeTransition(
                          sizeFactor: CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOut,
                          ),
                          axisAlignment: -1,
                          child: child,
                        );
                      },
                      child: _isCalendarVisible ? Container(
                        key: const ValueKey('calendar'),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: TableCalendar<Event>(
                          firstDay: _firstDay,
                          lastDay: _lastDay,
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                          eventLoader: (day) {
                            final normalizedDay = DateTime(day.year, day.month, day.day);
                            return events[normalizedDay] ?? [];
                          },
                          calendarFormat: _calendarFormat,
                          startingDayOfWeek: StartingDayOfWeek.monday,
                          headerStyle: HeaderStyle(
                            formatButtonVisible: true,
                            formatButtonShowsNext: false,
                            formatButtonDecoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            formatButtonTextStyle: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                            titleTextStyle: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          availableCalendarFormats: const {
                            CalendarFormat.month: 'Month',
                            CalendarFormat.twoWeeks: '2 Weeks',
                            CalendarFormat.week: 'Week',
                          },
                          onFormatChanged: (format) {
                            setState(() {
                              _calendarFormat = format;
                            });
                          },
                          calendarStyle: CalendarStyle(
                            outsideDaysVisible: false,
                            todayDecoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha:0.4),
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            todayTextStyle: TextStyle(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            selectedTextStyle: TextStyle(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          calendarBuilders: CalendarBuilders(
                            singleMarkerBuilder: (context, date, event) {
                              if (isSameDay(_selectedDay, date)) {
                                return const SizedBox();
                              }
                              return Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(horizontal: 1.0),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              );
                            },
                            markerBuilder: (context, date, events) {
                              if (events.isEmpty || isSameDay(_selectedDay, date)) {
                                return const SizedBox();
                              }
                              return Positioned(
                                bottom: 5,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              );
                            },
                          ),
                          onDaySelected: (selectedDay, focusedDay) => 
                              _onDaySelected(selectedDay, focusedDay, viewModel),
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                          },
                        ),
                      ) : Container(
                        key: const ValueKey('empty'),
                        height: 0,
                      ),
                    ),
                    
                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: _filters.map((filter) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(filter.label),
                              selected: viewModel.currentFilter == filter.value,
                              onSelected: (bool selected) {
                                if (selected) {
                                  setState(() {
                                    // Clear day selection when selecting a filter
                                    if (_selectedDay != null) {
                                      _selectedDay = null;
                                    }
                                    viewModel.setFilter(filter.value);
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Selected day events (if a day is selected)
              if (_selectedDay != null && selectedDayEvents.isEmpty)
                SliverFillRemaining(
                  child: Center(
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
                          'No events on ${DateFormat.yMMMMd().format(_selectedDay!)}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check another day or create a new event',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_selectedDay != null)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final event = selectedDayEvents[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: EventCard(
                            event: event,
                            onAddToCalendar: viewModel.addToCalendar,
                          ),
                        );
                      },
                      childCount: selectedDayEvents.length,
                    ),
                  ),
                )
              
              // Empty state when no events (and no day selected)
              else if (viewModel.eventsByMonth.isEmpty)
                SliverFillRemaining(
                  child: Center(
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
                          'No upcoming events',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check back later for new events',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                
              // Events grouped by month (when no specific day is selected)  
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final month = viewModel.eventsByMonth.keys.elementAt(index);
                        final events = viewModel.eventsByMonth[month]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                DateFormat.yMMMM().format(
                                  DateTime.parse('${month.split("-")[0]}-${month.split("-")[1]}-01'),
                                ),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ...events.map((event) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: EventCard(
                                event: event,
                                onAddToCalendar: viewModel.addToCalendar,
                              ),
                            )),
                          ],
                        );
                      },
                      childCount: viewModel.eventsByMonth.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
