import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/polls_viewmodel.dart';

class CreatePollScreen extends StatefulWidget {
  const CreatePollScreen({super.key});

  @override
  CreatePollScreenState createState() => CreatePollScreenState();
}

class CreatePollScreenState extends State<CreatePollScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  DateTime _expiresAt = DateTime.now().add(const Duration(days: 1));
  bool _showRealTimeResults = true;
  bool _showResultsAfterEnd = true;
  int _finalResultsDuration = 24;
  bool _isAllClasses = false;
  final List<String> _selectedClasses = [];
  bool _isReversible = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiresAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    if (date == null) return;

    // ignore: use_build_context_synchronously
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expiresAt),
    );
    if (time == null) return;

    setState(() {
      _expiresAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isAllClasses && _selectedClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one class or enable "All Classes"')),
      );
      return;
    }

    final options = _optionControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 options are required')),
      );
      return;
    }

    try {
      await context.read<PollsViewModel>().createPoll(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        options: options,
        expiresAt: _expiresAt,
        showRealTimeResults: _showRealTimeResults,
        showResultsAfterEnd: _showResultsAfterEnd,
        finalResultsDuration: _finalResultsDuration,
        isAllClasses: _isAllClasses,
        classScopes: _selectedClasses,
        isReversible: _isReversible,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating poll: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.of(context).size.width;
    final maxColumns = (availableWidth / 600).floor();
    final useGrid = maxColumns > 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Poll'),
        actions: [
          TextButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check),
            label: const Text('Create'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (useGrid)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPollDetails(context),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPollOptions(context),
                          const SizedBox(height: 32),
                          _buildPollSettings(context),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPollDetails(context),
                    const SizedBox(height: 32),
                    _buildPollOptions(context),
                    const SizedBox(height: 32),
                    _buildPollSettings(context),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPollDetails(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = Provider.of<PollsViewModel>(context);
    final availableClasses = viewModel.availableClasses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Poll Details',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
            helperText: 'Enter a clear and concise title',
          ),
          validator: (value) {
            if (value?.trim().isEmpty ?? true) {
              return 'Title is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
            helperText: 'Provide more context about the poll (optional)',
            alignLabelWithHint: true,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        InkWell(
          onTap: () => _selectDateTime(context),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Expiry Date & Time',
              border: OutlineInputBorder(),
              helperText: 'When should the poll close?',
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_expiresAt.year}/${_expiresAt.month}/${_expiresAt.day} '
                  '${_expiresAt.hour}:${_expiresAt.minute.toString().padLeft(2, '0')}',
                ),
                const Icon(Icons.calendar_today),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
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
                    'When enabled, this poll will be visible to all classes',
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
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
                  ),
                  if (_selectedClasses.isEmpty) ...[
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
        ),
      ],
    );
  }

  Widget _buildPollOptions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Poll Options',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...List.generate(_optionControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _optionControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Option ${index + 1}',
                      border: const OutlineInputBorder(),
                      helperText: index == 0 ? 'Add at least 2 options' : null,
                    ),
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Option is required';
                      }
                      return null;
                    },
                  ),
                ),
                if (_optionControllers.length > 2)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _removeOption(index),
                    tooltip: 'Remove option',
                  ),
              ],
            ),
          );
        }),
        Center(
          child: TextButton.icon(
            onPressed: _addOption,
            icon: const Icon(Icons.add),
            label: const Text('Add Option'),
          ),
        ),
      ],
    );
  }

  Widget _buildPollSettings(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Poll Settings',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Results Visibility',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show Real-time Results'),
                  subtitle: Text(
                    'Allow voters to see results while the poll is active',
                    style: theme.textTheme.bodySmall,
                  ),
                  value: _showRealTimeResults,
                  onChanged: (value) {
                    setState(() {
                      _showRealTimeResults = value;
                    });
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show Results After End'),
                  subtitle: Text(
                    'Show final results after the poll expires',
                    style: theme.textTheme.bodySmall,
                  ),
                  value: _showResultsAfterEnd,
                  onChanged: (value) {
                    setState(() {
                      _showResultsAfterEnd = value;
                    });
                  },
                ),
                if (_showResultsAfterEnd) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Show Results Duration',
                      border: OutlineInputBorder(),
                      helperText: 'How long to show results after poll ends',
                    ),
                    value: _finalResultsDuration,
                    items: [
                      DropdownMenuItem(
                        value: 24,
                        child: Text('24 hours'),
                      ),
                      DropdownMenuItem(
                        value: 48,
                        child: Text('48 hours'),
                      ),
                      DropdownMenuItem(
                        value: 72,
                        child: Text('72 hours'),
                      ),
                      DropdownMenuItem(
                        value: 168,
                        child: Text('1 week'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _finalResultsDuration = value;
                        });
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vote Settings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow Vote Changes'),
                  subtitle: Text(
                    'Let voters change or remove their votes',
                    style: theme.textTheme.bodySmall,
                  ),
                  value: _isReversible,
                  onChanged: (value) {
                    setState(() {
                      _isReversible = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}