import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/progressive_image.dart';
import '../../../models/entities/event.dart';
import '../../../viewmodels/events_viewmodel.dart';
import '../../../widgets/snackbar_helper.dart';

class EventDetailPage extends StatelessWidget {
  final Event event;

  const EventDetailPage({
    super.key,
    required this.event,
  });

  String _formatEventTime() {
    if (event.isAllDay) return 'All day';
    return '${DateFormat.jm().format(event.startTime)} - ${DateFormat.jm().format(event.endTime)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = Provider.of<EventsViewModel>(context);
    final padding = MediaQuery.of(context).padding;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  ProgressiveImage(url: event.imageUrl),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.black87,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 1,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, padding.bottom + 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat.yMMMMd().format(event.startTime),
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  Text(
                                    _formatEventTime(),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          Row(
                            children: [
                              Icon(
                                event.isVirtual ? Icons.video_call : Icons.location_on,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  event.location,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          if (event.isVirtual && event.meetingLink != null) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final uri = Uri.parse(event.meetingLink!);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                } else {
                                  if (context.mounted) {
                                    SnackbarHelper.showError(context, 'Could not open meeting link');
                                  }
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 40), // Align with text above
                                    Icon(
                                      Icons.link,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        event.meetingLink!,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.primary,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const Divider(height: 32),
                          Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Organized by',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Text(
                                      event.organizer,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'About',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.longDescription,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () {
                          final modifiedEvent = event.isVirtual && event.meetingLink != null
                              ? event.copyWith(location: event.meetingLink!)
                              : event;
                          viewModel.addToCalendar(modifiedEvent);
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('Add to Calendar'),
                      ),
                      if (event.isVirtual && event.meetingLink != null) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(event.meetingLink!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            } else {
                              if (context.mounted) {
                                SnackbarHelper.showError(context, 'Could not open meeting link');
                              }
                            }
                          },
                          icon: const Icon(Icons.video_call),
                          label: const Text('Join Meeting'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
