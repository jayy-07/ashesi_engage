import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/entities/report.dart';
import '../../../models/services/report_service.dart';
import '../../../models/services/content_moderation_service.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({Key? key}) : super(key: key);

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final ReportService _reportService = ReportService();
  final ContentModerationService _contentModerationService = ContentModerationService();
  
  // Map to store content previews to avoid redundant fetches
  final Map<String, ReportedContentPreview?> _contentPreviews = {};
  
  // Filter and search state
  String _selectedStatusFilter = 'all';
  String _selectedTypeFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? _selectedDateRange;

  // Selection mode for bulk actions
  bool _isSelectionMode = false;
  Set<String> _selectedReportIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // Fetch content preview for a report
  Future<void> _fetchContentPreview(Report report) async {
    if (_contentPreviews.containsKey(report.contentId)) return;
    
    final preview = await _contentModerationService.getReportedContentPreview(
      report.contentId,
      report.contentType,
    );
    
    if (mounted) {
      setState(() {
        _contentPreviews[report.contentId] = preview;
      });
    }
  }

  // Method to handle report actions (resolve, dismiss, delete)
  Future<void> _handleReportAction(String reportId, String action, [bool showSnackbar = true]) async {
    try {
      if (action == 'delete') {
        // TODO: Implement delete functionality in ReportService
        // await _reportService.deleteReport(reportId);
      } else {
        await _reportService.updateReportStatus(reportId, action);
      }
      
      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'delete' 
              ? 'Report deleted' 
              : 'Report marked as $action'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process report: $e')),
        );
      }
    }
  }

  // Show moderation actions dialog for a content item
  Future<void> _showModerationActionsDialog(Report report) async {
    // First, ensure we have the content preview
    await _fetchContentPreview(report);
    final preview = _contentPreviews[report.contentId];
    
    // Only handle comments for now, as content like proposals/discussions require different handling
    if (!report.contentType.contains('comment')) {
      // For non-comment content, just navigate to it
      _viewReportedContent(report);
      return;
    }

    final isCommentType = report.contentType.endsWith('_comment');
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Moderate ${_getContentTypeDisplay(report.contentType)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reported reason: ${report.reason}'),
            if (report.additionalInfo != null && report.additionalInfo!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Additional info: ${report.additionalInfo}'),
            ],
            const SizedBox(height: 16),
            if (preview != null) ...[
              const Divider(),
              const SizedBox(height: 8),
              Text('Content preview:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(preview.preview, maxLines: 3, overflow: TextOverflow.ellipsis),
              if (preview.authorName != null) ...[
                const SizedBox(height: 4),
                Text('By: ${preview.authorName}', style: TextStyle(fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 8),
              const Divider(),
            ],
            const SizedBox(height: 16),
            Text('What action would you like to take?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _viewReportedContent(report);
            },
            child: const Text('View Content'),
          ),
          if (isCommentType) 
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _deleteReportedComment(report);
              },
              child: const Text('Delete Comment'),
            ),
        ],
      ),
    );
  }

  // Helper method to get a more readable content type display
  String _getContentTypeDisplay(String contentType) {
    switch (contentType) {
      case 'discussion':
        return 'Discussion';
      case 'discussion_comment':
        return 'Discussion Comment';
      case 'proposal':
        return 'Proposal';
      case 'proposal_comment':
        return 'Proposal Comment';
      default:
        return contentType.replaceAll('_', ' ').capitalize();
    }
  }

  // Method to navigate to the parent content
  Future<void> _viewReportedContent(Report report) async {
    try {
      String? parentId;

      // For comments, we need to find the parent content first
      if (report.contentType.endsWith('_comment')) {
        parentId = await _contentModerationService.findParentContentId(
          report.contentId, 
          report.contentType
        );
        
        if (parentId != null) {
          // Use the new admin navigation method instead of the user-facing one
          await _contentModerationService.navigateToAdminContent(
            context, 
            report.contentType, 
            report.contentId
          );
        } else {
          throw Exception('Could not find parent content');
        }
      } else {
        // For direct content (proposals, discussions), navigate directly to admin version
        await _contentModerationService.navigateToAdminContent(
          context, 
          report.contentType, 
          report.contentId
        );
      }
      
      // Removed automatic report resolution when viewing content
      // This allows admins to view content without automatically marking the report as resolved
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not navigate to content: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Method to delete a reported comment
  Future<void> _deleteReportedComment(Report report) async {
    try {
      String? parentId;
      
      if (report.contentType == 'discussion_comment') {
        parentId = await _contentModerationService.findParentContentId(
          report.contentId, 
          'discussion_comment'
        );
        
        if (parentId != null) {
          await _contentModerationService.deleteDiscussionComment(
            report.contentId, 
            parentId
          );
        } else {
          throw Exception('Could not find parent discussion');
        }
      } 
      else if (report.contentType == 'proposal_comment') {
        parentId = await _contentModerationService.findParentContentId(
          report.contentId, 
          'proposal_comment'
        );
        
        if (parentId != null) {
          await _contentModerationService.deleteProposalComment(
            report.contentId, 
            parentId
          );
        } else {
          throw Exception('Could not find parent proposal');
        }
      }
      else {
        throw Exception('Unsupported content type for deletion');
      }
      
      // Mark report as resolved
      await _reportService.updateReportStatus(report.id, 'resolved');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_getContentTypeDisplay(report.contentType)} deleted successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete content: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Handle bulk actions for selected reports
  Future<void> _processBulkAction(String action, List<Report> selectedReports) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action.substring(0, 1).toUpperCase()}${action.substring(1)} Reports'),
        content: Text(
          'Are you sure you want to ${action == 'delete' ? 'delete' : 'mark as $action'} ${selectedReports.length} selected ${selectedReports.length > 1 ? 'reports' : 'report'}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: action == 'delete' ? FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ) : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action.toUpperCase()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!context.mounted) return;
      
      try {
        int successCount = 0;
        for (final report in selectedReports) {
          try {
            await _handleReportAction(report.id, action, false);
            successCount++;
          } catch (e) {
            // Continue with other reports even if one fails
          }
        }
        
        setState(() {
          _isSelectionMode = false;
          _selectedReportIds.clear();
        });
        
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount ${successCount > 1 ? 'reports' : 'report'} processed successfully'),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process some reports: $e')),
        );
      }
    }
  }

  // Filter reports based on search and filters
  List<Report> _filterReports(List<Report> reports) {
    return reports.where((report) {
      // Status filter
      if (_selectedStatusFilter != 'all' && report.status != _selectedStatusFilter) {
        return false;
      }
      
      // Content type filter
      if (_selectedTypeFilter != 'all' && report.contentType != _selectedTypeFilter) {
        return false;
      }
      
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!report.reason.toLowerCase().contains(query) && 
            !report.contentType.toLowerCase().contains(query) &&
            !(report.additionalInfo?.toLowerCase().contains(query) ?? false)) {
          return false;
        }
      }
      
      // Date range filter
      if (_selectedDateRange != null) {
        final reportDate = DateTime(
          report.timestamp.year,
          report.timestamp.month,
          report.timestamp.day,
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
        
        if (reportDate.isBefore(startDate) || reportDate.isAfter(endDate)) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  // Method to get all unique content types
  Set<String> _getUniqueContentTypes(List<Report> reports) {
    return reports.map((e) => e.contentType).toSet();
  }

  // Build the search and filter UI
  Widget _buildSearchAndFilters(List<Report> allReports) {
    final contentTypes = _getUniqueContentTypes(allReports);
    
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
                hintText: 'Search reports...',
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
                  // Status filter
                  FilterChip(
                    label: Text(_selectedStatusFilter == 'all' 
                      ? 'All Statuses' 
                      : 'Status: ${_selectedStatusFilter.substring(0, 1).toUpperCase()}${_selectedStatusFilter.substring(1)}'),
                    selected: _selectedStatusFilter != 'all',
                    onSelected: (selected) {
                      showDialog(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: const Text('Filter by Status'),
                          children: [
                            RadioListTile<String>(
                              title: const Text('All'),
                              value: 'all',
                              groupValue: _selectedStatusFilter,
                              onChanged: (value) {
                                setState(() => _selectedStatusFilter = value!);
                                Navigator.pop(context);
                              },
                            ),
                            RadioListTile<String>(
                              title: const Text('Pending'),
                              value: 'pending',
                              groupValue: _selectedStatusFilter,
                              onChanged: (value) {
                                setState(() => _selectedStatusFilter = value!);
                                Navigator.pop(context);
                              },
                            ),
                            RadioListTile<String>(
                              title: const Text('Resolved'),
                              value: 'resolved',
                              groupValue: _selectedStatusFilter,
                              onChanged: (value) {
                                setState(() => _selectedStatusFilter = value!);
                                Navigator.pop(context);
                              },
                            ),
                            RadioListTile<String>(
                              title: const Text('Dismissed'),
                              value: 'dismissed',
                              groupValue: _selectedStatusFilter,
                              onChanged: (value) {
                                setState(() => _selectedStatusFilter = value!);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.schedule,
                      color: _selectedStatusFilter != 'all'
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Type filter
                  if (contentTypes.isNotEmpty)
                    FilterChip(
                      label: Text(_selectedTypeFilter == 'all' 
                        ? 'All Types' 
                        : 'Type: ${_selectedTypeFilter}'),
                      selected: _selectedTypeFilter != 'all',
                      onSelected: (selected) {
                        showDialog(
                          context: context,
                          builder: (context) => SimpleDialog(
                            title: const Text('Filter by Content Type'),
                            children: [
                              RadioListTile<String>(
                                title: const Text('All'),
                                value: 'all',
                                groupValue: _selectedTypeFilter,
                                onChanged: (value) {
                                  setState(() => _selectedTypeFilter = value!);
                                  Navigator.pop(context);
                                },
                              ),
                              ...contentTypes.map((type) => RadioListTile<String>(
                                title: Text(type),
                                value: type,
                                groupValue: _selectedTypeFilter,
                                onChanged: (value) {
                                  setState(() => _selectedTypeFilter = value!);
                                  Navigator.pop(context);
                                },
                              )).toList(),
                            ],
                          ),
                        );
                      },
                      showCheckmark: false,
                      avatar: Icon(
                        Icons.category,
                        color: _selectedTypeFilter != 'all'
                            ? Theme.of(context).colorScheme.onSecondaryContainer
                            : null,
                      ),
                    ),
                  
                  if (contentTypes.isNotEmpty)
                    const SizedBox(width: 8),
                  
                  // Date range filter
                  FilterChip(
                    label: Text(_selectedDateRange == null
                        ? 'All Dates'
                        : '${DateFormat.MMMd().format(_selectedDateRange!.start)} - ${DateFormat.MMMd().format(_selectedDateRange!.end)}'),
                    selected: _selectedDateRange != null,
                    onSelected: (bool selected) async {
                      if (selected) {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                          initialDateRange: _selectedDateRange ?? DateTimeRange(
                            start: DateTime.now().subtract(const Duration(days: 30)),
                            end: DateTime.now(),
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

                  // Clear filters button
                  if (_searchQuery.isNotEmpty ||
                      _selectedStatusFilter != 'all' ||
                      _selectedTypeFilter != 'all' ||
                      _selectedDateRange != null) ...[
                    const SizedBox(width: 16),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                          _selectedStatusFilter = 'all';
                          _selectedTypeFilter = 'all';
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Report>>(
        stream: _reportService.getAllReports(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allReports = snapshot.data!;
          final filteredReports = _filterReports(allReports);
          final selectedReports = filteredReports
              .where((report) => _selectedReportIds.contains(report.id))
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  children: [
                    if (!_isSelectionMode) ...[
                      Text(
                        'Reports Management',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (filteredReports.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isSelectionMode = true;
                            });
                          },
                          icon: const Icon(Icons.checklist),
                          tooltip: 'Select reports',
                        ),
                    ] else ...[
                      Text(
                        '${_selectedReportIds.length} selected',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            if (_selectedReportIds.length == filteredReports.length) {
                              _selectedReportIds.clear();
                            } else {
                              _selectedReportIds = filteredReports.map((r) => r.id).toSet();
                            }
                          });
                        },
                        icon: Icon(_selectedReportIds.length == filteredReports.length 
                          ? Icons.deselect 
                          : Icons.select_all
                        ),
                        label: Text(_selectedReportIds.length == filteredReports.length 
                          ? 'Deselect All' 
                          : 'Select All'
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = false;
                            _selectedReportIds.clear();
                          });
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                      if (_selectedReportIds.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _processBulkAction('resolved', selectedReports),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Mark as Resolved'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _processBulkAction('dismissed', selectedReports),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Dismiss'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                            foregroundColor: Theme.of(context).colorScheme.onError,
                          ),
                          onPressed: () => _processBulkAction('delete', selectedReports),
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              
              // Search and filters
              _buildSearchAndFilters(allReports),
              
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Divider(),
              ),
              
              // Reports grid or empty message
              Expanded(
                child: filteredReports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.report_off,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No reports found',
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
                          maxCrossAxisExtent: 500,
                          mainAxisExtent: 250, // Increased height to accommodate content preview
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filteredReports.length,
                        itemBuilder: (context, index) {
                          final report = filteredReports[index];
                          final bool isSelected = _selectedReportIds.contains(report.id);
                          
                          // Fetch content preview
                          _fetchContentPreview(report);
                          final preview = _contentPreviews[report.contentId];
                          
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            elevation: 2,
                            child: InkWell(
                              onTap: _isSelectionMode 
                                ? () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedReportIds.remove(report.id);
                                      } else {
                                        _selectedReportIds.add(report.id);
                                      }
                                    });
                                  }
                                : () => _showModerationActionsDialog(report), // Open moderation dialog on tap
                              child: Stack(
                                children: [
                                  // Selection overlay
                                  if (_isSelectionMode && isSelected)
                                    Positioned.fill(
                                      child: Container(
                                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha:0.4),
                                      ),
                                    ),
                                  
                                  // Selection checkbox
                                  if (_isSelectionMode)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isSelected
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.surface,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(context).colorScheme.outline,
                                            width: 1,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2.0),
                                          child: isSelected
                                            ? Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Theme.of(context).colorScheme.onPrimary,
                                              )
                                            : const SizedBox(width: 16, height: 16),
                                        ),
                                      ),
                                    ),
                                  
                                  // Report content
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header with reason and content type
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                report.reason,
                                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.secondaryContainer,
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Text(
                                                report.contentType,
                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        
                                        // Status chip
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: report.status == 'pending'
                                              ? Colors.amber.withValues(alpha:0.2)
                                              : report.status == 'resolved'
                                                ? Colors.green.withValues(alpha:0.2)
                                                : Colors.grey.withValues(alpha:0.2),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Text(
                                            report.status.toUpperCase(),
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: report.status == 'pending'
                                                ? Colors.amber[800]
                                                : report.status == 'resolved'
                                                  ? Colors.green[800]
                                                  : Colors.grey[800],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        
                                        // Content preview section
                                        if (preview != null) ...[
                                          if (preview.title.isNotEmpty)
                                            Text(
                                              preview.title,
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha:0.5),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              preview.preview,
                                              style: Theme.of(context).textTheme.bodySmall,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (preview.authorName != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'By: ${preview.authorName}',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                fontStyle: FontStyle.italic,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ] else if (_contentPreviews.containsKey(report.contentId)) ...[
                                          // We tried to fetch but couldn't get a preview
                                          const Text('Content preview unavailable'),
                                        ] else ...[
                                          // Loading state
                                          const Center(
                                            child: SizedBox(
                                              width: 20, 
                                              height: 20, 
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                        ],
                                        
                                        // Additional info
                                        if (report.additionalInfo != null && report.additionalInfo!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'Additional info: ${report.additionalInfo}',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              fontStyle: FontStyle.italic,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        
                                        const Spacer(),
                                        
                                        // Footer with timestamp and actions
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Reported: ${DateFormat('MMM d, yyyy • h:mm a').format(report.timestamp)}',
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: Theme.of(context).colorScheme.outline,
                                                ),
                                              ),
                                            ),
                                            if (report.status == 'pending' && !_isSelectionMode) ...[
                                              IconButton(
                                                icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                                onPressed: () => _handleReportAction(report.id, 'resolved'),
                                                tooltip: 'Mark as resolved',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.cancel_outlined, color: Colors.amber),
                                                onPressed: () => _handleReportAction(report.id, 'dismissed'),
                                                tooltip: 'Dismiss report',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                                onPressed: () => _handleReportAction(report.id, 'delete'),
                                                tooltip: 'Delete report',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.admin_panel_settings, color: Colors.blue),
                                                onPressed: () => _showModerationActionsDialog(report),
                                                tooltip: 'Moderate content',
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return this.isEmpty ? '' : '${this[0].toUpperCase()}${this.substring(1)}';
  }
}
