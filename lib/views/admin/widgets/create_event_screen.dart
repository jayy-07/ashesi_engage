import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/event_viewmodel.dart';
import '../../../models/entities/event.dart';  // Add this import
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:io';
import 'package:universal_html/html.dart' as html;
import '../../../models/services/user_service.dart';
import 'package:intl/intl.dart';

class CreateEventScreen extends StatefulWidget {
  final Event? event;  // Add this field to support editing
  
  const CreateEventScreen({
    super.key,
    this.event,
  });

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final UserService _userService = UserService();
  dynamic _eventImage; // Change to dynamic to handle both platforms
  String? _webImageUrl;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isAllDay = false;
  bool _isVirtual = false;  // Add this line
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isAllClasses = false;
  List<String> _selectedClasses = [];
  String? _timeError;
  
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _organizersController = TextEditingController();
  final _shortDescController = TextEditingController();
  final _longDescController = TextEditingController();
  final _meetingLinkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      // Initialize form with existing event data
      _titleController.text = widget.event!.title;
      _locationController.text = widget.event!.location;
      _organizersController.text = widget.event!.organizer;
      _shortDescController.text = widget.event!.shortDescription;
      _longDescController.text = widget.event!.longDescription;
      _selectedDate = widget.event!.startTime;
      _isAllDay = widget.event!.isAllDay;
      _isAllClasses = widget.event!.isAllClasses;
      _selectedClasses = List.from(widget.event!.classScopes);
      _isVirtual = widget.event!.isVirtual;  // Add this line
      if (_isVirtual && widget.event!.meetingLink != null) {
        _meetingLinkController.text = widget.event!.meetingLink!;
      }
      if (!_isAllDay) {
        _startTime = TimeOfDay.fromDateTime(widget.event!.startTime);
        _endTime = TimeOfDay.fromDateTime(widget.event!.endTime);
      }
      if (widget.event!.imageUrl.isNotEmpty) {
        _webImageUrl = widget.event!.imageUrl;
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    
    if (image != null) {
      if (kIsWeb) {
        // For web platform
        final bytes = await image.readAsBytes();
        setState(() {
          _eventImage = bytes;
          final blob = html.Blob([bytes]);
          _webImageUrl = html.Url.createObjectUrl(blob);
        });
      } else {
        // For mobile platforms
        setState(() {
          _eventImage = File(image.path);
        });
      }
    }
  }

  Future<void> _selectDate() async {
    try {
      final DateTime today = DateTime.now();
      final DateTime initialDate = _selectedDate ?? today;
      final DateTime firstDate = initialDate.isBefore(today)
          ? initialDate
          : today;
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: today.add(const Duration(days: 365)),
      );
      if (picked != null) {
        // Check if selected date is today and time is in past
        if (picked.year == DateTime.now().year &&
            picked.month == DateTime.now().month &&
            picked.day == DateTime.now().day) {
          // If times are already selected, validate them
          if (_startTime != null) {
            final startDateTime = DateTime(
              picked.year,
              picked.month,
              picked.day,
              _startTime!.hour,
              _startTime!.minute,
            );
            if (startDateTime.isBefore(DateTime.now())) {
              setState(() {
                _startTime = null;
                _endTime = null;
                _timeError = 'Cannot set event time in the past';
              });
            }
          }
        }
        setState(() {
          _selectedDate = picked;
          _timeError = null;
        });
      }
    } catch (e, stack) {
      debugPrint('Error in showDatePicker: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening date picker: $e')),
        );
      }
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final now = DateTime.now();
    final isToday = _selectedDate?.year == now.year &&
        _selectedDate?.month == now.month &&
        _selectedDate?.day == now.day;

    TimeOfDay initialTime;
    if (isStart) {
      initialTime = _startTime ?? TimeOfDay.now();
      // If today, ensure initial time is not in the past
      if (isToday) {
        final currentTime = TimeOfDay.now();
        if (initialTime.hour < currentTime.hour ||
            (initialTime.hour == currentTime.hour && initialTime.minute < currentTime.minute)) {
          initialTime = currentTime;
        }
      }
    } else {
      initialTime = _endTime ?? (_startTime?.replacing(hour: _startTime!.hour + 1) ?? TimeOfDay.now());
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      if (isToday) {
        // For today's events, validate against current time
        final currentTime = TimeOfDay.now();
        if (isStart && (picked.hour < currentTime.hour ||
            (picked.hour == currentTime.hour && picked.minute < currentTime.minute))) {
          setState(() {
            _timeError = 'Cannot set start time in the past';
          });
          return;
        }
      }

      // When setting end time, validate it's after start time
      if (!isStart && _startTime != null) {
        final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
        final endMinutes = picked.hour * 60 + picked.minute;
        if (endMinutes <= startMinutes) {
          setState(() {
            _timeError = 'End time must be after start time';
          });
          return;
        }
      }

      // When setting start time, validate existing end time
      if (isStart && _endTime != null) {
        final startMinutes = picked.hour * 60 + picked.minute;
        final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
        if (endMinutes <= startMinutes) {
          setState(() {
            _endTime = null;
            _timeError = 'Please select a new end time';
          });
        }
      }

      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        // Clear error if valid time selected
        _timeError = null;
      });
    }
  }

  bool _isFormValid() {
    if (_formKey.currentState == null) return false;
    if (!_formKey.currentState!.validate()) return false;
    if (_selectedDate == null) return false;
    if (!_isAllDay && (_startTime == null || _endTime == null)) return false;
    
    // Check all required fields
    if (_titleController.text.trim().isEmpty) return false;
    if (_locationController.text.trim().isEmpty) return false;
    if (_organizersController.text.trim().isEmpty) return false;
    if (_shortDescController.text.trim().isEmpty) return false;
    if (_longDescController.text.trim().isEmpty) return false;
    
    // Check class scope
    if (!_isAllClasses && _selectedClasses.isEmpty) return false;
    
    return true;
  }

  Future<void> _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date')),
        );
        return;
      }

      if (!_isAllDay && (_startTime == null || _endTime == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select both start and end times')),
        );
        return;
      }

      if (!_isAllClasses && _selectedClasses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one class or enable "All Classes"')),
        );
        return;
      }

      try {
        setState(() {
          _isSaving = true;
        });

        final eventViewModel = Provider.of<EventViewModel>(context, listen: false);
        final user = await _userService.getCurrentUser();
        
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not authorized to create/edit events')),
          );
          return;
        }

        final DateTime startDateTime = _isAllDay 
            ? DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day)
            : DateTime(
                _selectedDate!.year,
                _selectedDate!.month,
                _selectedDate!.day,
                _startTime!.hour,
                _startTime!.minute,
              );

        final DateTime endDateTime = _isAllDay 
            ? DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59)
            : DateTime(
                _selectedDate!.year,
                _selectedDate!.month,
                _selectedDate!.day,
                _endTime!.hour,
                _endTime!.minute,
              );

        final meetingLink = _isVirtual ? _meetingLinkController.text.trim() : null;

        if (widget.event != null) {
          // Update existing event
          await eventViewModel.updateEvent(
            Event(
              id: widget.event!.id,
              title: _titleController.text.trim(),
              shortDescription: _shortDescController.text.trim(),
              longDescription: _longDescController.text.trim(),
              location: _locationController.text.trim(),
              startTime: startDateTime,
              endTime: endDateTime,
              isAllDay: _isAllDay,
              imageUrl: widget.event!.imageUrl,
              organizer: _organizersController.text.trim(),
              classScopes: _selectedClasses,
              isAllClasses: _isAllClasses,
              createdAt: widget.event!.createdAt,
              createdBy: widget.event!.createdBy,
              isVirtual: _isVirtual,
              meetingLink: meetingLink,
            ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event updated successfully')),
          );
        } else {
          // Create new event
          await eventViewModel.createEvent(
            imageFile: _eventImage,
            title: _titleController.text.trim(),
            shortDescription: _shortDescController.text.trim(),
            longDescription: _longDescController.text.trim(),
            location: _locationController.text.trim(),
            startTime: startDateTime,
            endTime: endDateTime,
            isAllDay: _isAllDay,
            organizer: _organizersController.text.trim(),
            classScopes: _selectedClasses,
            isAllClasses: _isAllClasses,
            isVirtual: _isVirtual,
            meetingLink: meetingLink,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event created successfully')),
          );
        }

        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${widget.event != null ? 'update' : 'create'} event: $e')),
        );
      } finally {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _organizersController.dispose();
    _shortDescController.dispose();
    _longDescController.dispose();
    _meetingLinkController.dispose();
    super.dispose();
  }

  Widget _buildDateTimeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date & Time',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(
                _selectedDate != null
                    ? DateFormat.yMMMMd().format(_selectedDate!)
                    : 'Select date',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDate,
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('All Day'),
              value: _isAllDay,
              onChanged: (bool value) {
                setState(() {
                  _isAllDay = value;
                  if (value) {
                    _timeError = null;
                  }
                });
              },
            ),
            if (!_isAllDay) ...[
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Time'),
                subtitle: Text(_startTime?.format(context) ?? 'Select start time'),
                trailing: const Icon(Icons.access_time),
                onTap: () => _selectTime(true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End Time'),
                subtitle: Text(_endTime?.format(context) ?? 'Select end time'),
                trailing: const Icon(Icons.access_time),
                onTap: () => _selectTime(false),
              ),
              if (_timeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _timeError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClassScopeSection() {
    final theme = Theme.of(context);
    final eventViewModel = Provider.of<EventViewModel>(context);
    final availableClasses = eventViewModel.availableClasses;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Class Scope',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available to All Classes'),
              subtitle: Text(
                'When enabled, this event will be visible to all classes',
                style: theme.textTheme.bodySmall,
              ),
              value: _isAllClasses,
              onChanged: (value) {
                setState(() {
                  _isAllClasses = value;
                  if (value) {
                    _selectedClasses.clear();
                  }
                });
              },
            ),
            if (!_isAllClasses) ...[
              const Divider(height: 32),
              Text(
                'Select Classes',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableClasses.map((className) {
                  return FilterChip(
                    label: Text(className),
                    selected: _selectedClasses.contains(className),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedClasses.add(className);
                        } else {
                          _selectedClasses.remove(className);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              if (_selectedClasses.isEmpty && !_isAllClasses) ...[
                const SizedBox(height: 8),
                Text(
                  'Please select at least one class or enable "All Classes"',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location & Organizers',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Virtual Meeting'),
              subtitle: Text(
                'Enable if this is an online event',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: _isVirtual,
              onChanged: (bool value) {
                setState(() {
                  _isVirtual = value;
                  if (value) {
                    _locationController.text = 'Virtual Meeting';
                  } else {
                    if (_locationController.text == 'Virtual Meeting') {
                      _locationController.text = '';
                    }
                    _meetingLinkController.clear();
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            if (_isVirtual) ...[
              TextFormField(
                controller: _meetingLinkController,
                decoration: const InputDecoration(
                  labelText: 'Meeting Link',
                  hintText: 'Enter meeting link (must start with https://)',
                  helperText: 'The meeting link must start with https://',
                  prefixIcon: Icon(Icons.link),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a meeting link';
                  }
                  // URL validation
                  final uri = Uri.tryParse(value);
                  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                    return 'Please enter a valid URL starting with https://';
                  }
                  if (uri.scheme != 'https') {
                    return 'The meeting link must use HTTPS';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {}); // Update form validity
                },
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _locationController,
              enabled: !_isVirtual,
              decoration: InputDecoration(
                labelText: _isVirtual ? 'Virtual Meeting' : 'Location',
                hintText: _isVirtual ? 'Virtual Meeting' : 'Enter event location',
                prefixIcon: Icon(
                  _isVirtual ? Icons.video_call : Icons.location_on_outlined
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a location';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {}); // Update form validity
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _organizersController,
              decoration: const InputDecoration(
                labelText: 'Organizers',
                hintText: 'Enter event organizers',
                prefixIcon: Icon(Icons.people_outline),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter organizers';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {}); // Update form validity
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event != null ? 'Edit Event' : 'Create Event'),
        actions: [
          TextButton.icon(
            onPressed: _isFormValid() && !_isSaving ? _saveEvent : null,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(widget.event != null ? 'Save Changes' : 'Save Event'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline),
                          const SizedBox(width: 8),
                          Text(
                            'Required fields: Title, Location, Organizers, Date, ${_isAllDay ? '' : 'Start/End Time, '}Short Description, Long Description',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column - Image, Date/Time, and Class Scope
                      Expanded(
                        flex: 2,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Event Image
                            Card(
                              clipBehavior: Clip.antiAlias,
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      image: (_eventImage != null || _webImageUrl != null)
                                          ? DecorationImage(
                                              image: kIsWeb
                                                  ? NetworkImage(_webImageUrl!)
                                                  : FileImage(_eventImage!) as ImageProvider,
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: (_eventImage == null && _webImageUrl == null)
                                        ? Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.add_photo_alternate_outlined,
                                                size: 48,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Add Event Image',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                              Text(
                                                '(16:9 aspect ratio)',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildDateTimeSection(),
                            const SizedBox(height: 16),
                            _buildClassScopeSection(),
                            const SizedBox(height: 16),
                            _buildLocationSection(),
                          ],
                        ),
                      ),
                      // Right Column - Event Details
                      Expanded(
                        flex: 3,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Event Details',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _titleController,
                                      decoration: const InputDecoration(
                                        labelText: 'Event Title',
                                        hintText: 'Enter event title',
                                        prefixIcon: Icon(Icons.title),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter an event title';
                                        }
                                        return null;
                                      },
                                      onChanged: (value) {
                                        setState(() {}); // This will trigger rebuild and update Save button state
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _shortDescController,
                                      decoration: const InputDecoration(
                                        labelText: 'Short Description',
                                        hintText: 'Enter a brief description',
                                        prefixIcon: Icon(Icons.short_text),
                                      ),
                                      maxLength: 150,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a short description';
                                        }
                                        return null;
                                      },
                                      onChanged: (value) {
                                        setState(() {}); // This will trigger rebuild and update Save button state
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _longDescController,
                                      decoration: const InputDecoration(
                                        labelText: 'Long Description',
                                        hintText: 'Enter detailed description',
                                        alignLabelWithHint: true,
                                        prefixIcon: Icon(Icons.description_outlined),
                                      ),
                                      maxLines: 12,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a detailed description';
                                        }
                                        return null;
                                      },
                                      onChanged: (value) {
                                        setState(() {}); // This will trigger rebuild and update Save button state
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}