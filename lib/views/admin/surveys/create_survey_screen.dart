import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../viewmodels/survey_viewmodel.dart';
import '../../../models/entities/survey.dart';
import 'dart:io';
import 'package:universal_html/html.dart' as html;
import 'package:intl/intl.dart';

class CreateSurveyScreen extends StatefulWidget {
  final Survey? survey; // For editing existing surveys

  const CreateSurveyScreen({
    super.key,
    this.survey,
  });

  @override
  State<CreateSurveyScreen> createState() => _CreateSurveyScreenState();
}

class _CreateSurveyScreenState extends State<CreateSurveyScreen> {
  final _formKey = GlobalKey<FormState>();
  dynamic _surveyImage;
  String? _webImageUrl;
  DateTime? _expiresAt;
  bool _isAllClasses = false;
  List<String> _selectedClasses = [];
  String _selectedCategory = ''; // Changed from enum to String
  bool _isSaving = false;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _surveyLinkController = TextEditingController();
  final _organizerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.survey != null) {
      _titleController.text = widget.survey!.title;
      _descriptionController.text = widget.survey!.description;
      _surveyLinkController.text = widget.survey!.surveyLink;
      _organizerController.text = widget.survey!.organizer;
      _expiresAt = widget.survey!.expiresAt;
      _isAllClasses = widget.survey!.isAllClasses;
      _selectedClasses = List.from(widget.survey!.classScopes);
      _selectedCategory = widget.survey!.category;
      if (widget.survey!.imageUrl.isNotEmpty) {
        _webImageUrl = widget.survey!.imageUrl;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _surveyLinkController.dispose();
    _organizerController.dispose();
    super.dispose();
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
        final bytes = await image.readAsBytes();
        setState(() {
          _surveyImage = bytes;
          final blob = html.Blob([bytes]);
          _webImageUrl = html.Url.createObjectUrl(blob);
        });
      } else {
        setState(() {
          _surveyImage = File(image.path);
        });
      }
    }
  }

  Future<void> _selectExpiryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      // Show time picker
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_expiresAt ?? DateTime.now().add(const Duration(days: 7))),
      );
      if (time != null) {
        setState(() {
          _expiresAt = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Widget _buildCategorySection() {
    final theme = Theme.of(context);
    final viewModel = Provider.of<SurveyViewModel>(context);
    final availableCategories = viewModel.availableCategories;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...availableCategories.map(
              (category) => RadioListTile<String>(
                title: Text(category),
                value: category,
                groupValue: _selectedCategory,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
              ),
            ),
            if (_selectedCategory.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Please select a category',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 12,
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
    final viewModel = Provider.of<SurveyViewModel>(context);
    final availableClasses = viewModel.availableClasses;

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
                'When enabled, this survey will be visible to all classes',
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

  bool _isFormValid() {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return false;
    if (_expiresAt == null) return false;
    if (!_isAllClasses && _selectedClasses.isEmpty) return false;
    if (_selectedCategory.isEmpty) return false;

    return true;
  }

  Future<void> _saveSurvey() async {
    if (!_isFormValid()) {
      if (_expiresAt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an expiry date')),
        );
        return;
      }

      if (!_isAllClasses && _selectedClasses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one class or enable "All Classes"')),
        );
        return;
      }

      if (_selectedCategory.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category')),
        );
        return;
      }

      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      final viewModel = Provider.of<SurveyViewModel>(context, listen: false);

      if (widget.survey != null) {
        // Update existing survey
        await viewModel.updateSurvey(
          widget.survey!.copyWith(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            surveyLink: _surveyLinkController.text.trim(),
            expiresAt: _expiresAt!,
            isAllClasses: _isAllClasses,
            classScopes: _selectedClasses,
            category: _selectedCategory,
            organizer: _organizerController.text.trim(),
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Survey updated successfully')),
          );
          Navigator.pop(context);
        }
      } else {
        // Create new survey
        await viewModel.createSurvey(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          surveyLink: _surveyLinkController.text.trim(),
          imageFile: _surveyImage,
          expiresAt: _expiresAt!,
          isAllClasses: _isAllClasses,
          classScopes: _selectedClasses,
          category: _selectedCategory,
          organizer: _organizerController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Survey created successfully')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${widget.survey != null ? 'update' : 'create'} survey: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.survey != null ? 'Edit Survey' : 'Create Survey'),
        actions: [
          TextButton.icon(
            onPressed: _isFormValid() && !_isSaving ? _saveSurvey : null,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(widget.survey != null ? 'Save Changes' : 'Create Survey'),
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
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column
                      Expanded(
                        flex: 2,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Survey Image
                            Card(
                              clipBehavior: Clip.antiAlias,
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      image: (_surveyImage != null || _webImageUrl != null)
                                          ? DecorationImage(
                                              image: kIsWeb
                                                  ? NetworkImage(_webImageUrl!)
                                                  : FileImage(_surveyImage!) as ImageProvider,
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: (_surveyImage == null && _webImageUrl == null)
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
                                                'Add Survey Image',
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

                            // Category Selection (Updated)
                            _buildCategorySection(),
                            const SizedBox(height: 16),

                            // Class Scope
                            _buildClassScopeSection(),
                          ],
                        ),
                      ),

                      // Right Column
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
                                      'Survey Details',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _titleController,
                                      decoration: const InputDecoration(
                                        labelText: 'Survey Title',
                                        hintText: 'Enter survey title',
                                        prefixIcon: Icon(Icons.title),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a survey title';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _descriptionController,
                                      decoration: const InputDecoration(
                                        labelText: 'Description',
                                        hintText: 'Enter survey description (max 400 characters)',
                                        prefixIcon: Icon(Icons.description_outlined),
                                        alignLabelWithHint: true,
                                      ),
                                      maxLength: 400,
                                      maxLines: 5, // Increased maxLines to accommodate more text
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a description';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _surveyLinkController,
                                      decoration: const InputDecoration(
                                        labelText: 'Survey Link',
                                        hintText: 'Enter survey link (must start with https://)',
                                        prefixIcon: Icon(Icons.link),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a survey link';
                                        }
                                        // URL validation
                                        final uri = Uri.tryParse(value);
                                        if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                                          return 'Please enter a valid URL starting with https://';
                                        }
                                        if (uri.scheme != 'https') {
                                          return 'The survey link must use HTTPS';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _organizerController,
                                      decoration: const InputDecoration(
                                        labelText: 'Organizer',
                                        hintText: 'Enter organizer name',
                                        prefixIcon: Icon(Icons.people_outline),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter an organizer';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Expiry Date & Time'),
                                      subtitle: Text(
                                        _expiresAt != null
                                            ? DateFormat('MMM d, y HH:mm').format(_expiresAt!)
                                            : 'Select expiry date and time',
                                      ),
                                      trailing: const Icon(Icons.calendar_today),
                                      onTap: _selectExpiryDate,
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