import 'package:flutter/material.dart';
import '../../models/entities/report.dart';
import '../../models/services/report_service.dart';
import '../../models/services/auth_service.dart';
import 'package:provider/provider.dart';

class ReportDialog extends StatefulWidget {
  final String contentType; // 'discussion', 'discussion_comment', 'proposal', 'proposal_comment'
  final String contentId;

  const ReportDialog({
    super.key,
    required this.contentType,
    required this.contentId,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final _reportService = ReportService();
  String _selectedReason = ReportReason.values.first;
  final _additionalInfoController = TextEditingController();
  bool _isSubmitting = false;

  String get _contentTypeDisplay {
    switch (widget.contentType) {
      case 'discussion':
        return 'Discussion';
      case 'discussion_comment':
        return 'Discussion Comment';
      case 'proposal':
        return 'Proposal';
      case 'proposal_comment':
        return 'Proposal Comment';
      default:
        return 'Content';
    }
  }

  @override
  void dispose() {
    _additionalInfoController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) return;

    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to report content')),
        );
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _reportService.submitReport(
        contentType: widget.contentType,
        contentId: widget.contentId,
        reporterId: user.uid,
        reason: _selectedReason,
        additionalInfo: _additionalInfoController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_contentTypeDisplay reported successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('Report $_contentTypeDisplay'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Why are you reporting this ${_contentTypeDisplay.toLowerCase()}?'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedReason,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: ReportReason.values.map((reason) {
                return DropdownMenuItem(
                  value: reason,
                  child: Text(reason),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedReason = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _additionalInfoController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Additional Information (Optional)',
                hintText: 'Provide any additional context...',
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submitReport,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }
} 