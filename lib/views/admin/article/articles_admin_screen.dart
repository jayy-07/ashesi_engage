import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../viewmodels/article_viewmodel.dart';
import '../../../models/entities/article.dart';
import 'write_article_page.dart';
import 'article_detail_page.dart';

class ArticlesAdminScreen extends StatefulWidget {
  const ArticlesAdminScreen({super.key});

  @override
  State<ArticlesAdminScreen> createState() => _ArticlesAdminScreenState();
}

class _ArticlesAdminScreenState extends State<ArticlesAdminScreen> {
  bool _isSelectionMode = false;
  Set<String> _selectedArticleIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  Set<String> _selectedAuthors = {};
  bool _showPublished = true;
  bool _showDrafts = true;
  bool _showFeatured = false;
  final TextEditingController _authorSearchController = TextEditingController();
  String _authorSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    
    // Start listening to article updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<ArticleViewModel>();
      viewModel.startListening();
      viewModel.loadArticles(); // Initial load
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _authorSearchController.dispose();
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

  List<Article> _filterArticles(List<Article> articles) {
    return articles.where((article) {
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!article.title.toLowerCase().contains(query) &&
            !article.plainContent.toLowerCase().contains(query) &&
            !article.authorName.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Date range filter
      if (_selectedDateRange != null) {
        final articleDate = DateTime(
          article.datePublished.year,
          article.datePublished.month,
          article.datePublished.day,
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
        if (articleDate.isBefore(startDate) || articleDate.isAfter(endDate)) {
          return false;
        }
      }

      // Author filter
      if (_selectedAuthors.isNotEmpty && !_selectedAuthors.contains(article.authorName)) {
        return false;
      }

      // Published/Draft filter
      if (!_showPublished && article.isPublished) return false;
      if (!_showDrafts && !article.isPublished) return false;

      // Featured filter
      if (_showFeatured && !article.isFeatured) return false;

      return true;
    }).toList();
  }

  Set<String> _getUniqueAuthors(List<Article> articles) {
    return articles.map((e) => e.authorName).toSet();
  }

  Future<void> _deleteSelectedArticles() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Articles'),
        content: Text(
          'Are you sure you want to delete ${_selectedArticleIds.length} selected article${_selectedArticleIds.length > 1 ? 's' : ''}?'
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
      final viewModel = context.read<ArticleViewModel>();
      
      try {
        for (final id in _selectedArticleIds) {
          await viewModel.deleteArticle(id);
        }
        
        setState(() {
          _selectedArticleIds.clear();
          _isSelectionMode = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected articles deleted'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete articles: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteArticle(String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Article'),
        content: const Text('Are you sure you want to delete this article?'),
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
      try {
        await context.read<ArticleViewModel>().deleteArticle(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Article deleted'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete article: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Widget _buildSearchAndFilters(List<Article> articles) {
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
                hintText: 'Search articles...',
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
                  
                  // Author filter
                  FilterChip(
                    label: Text(_selectedAuthors.isEmpty 
                        ? 'Select Authors' 
                        : _selectedAuthors.length == 1 
                            ? _selectedAuthors.first 
                            : '${_selectedAuthors.length} Authors'),
                    selected: _selectedAuthors.isNotEmpty,
                    onSelected: (bool selected) {
                      _showMultiSelectFilterDialog(
                        context: context,
                        title: 'Authors',
                        selectedValues: _selectedAuthors,
                        options: _getUniqueAuthors(articles),
                        onChanged: (value) => setState(() => _selectedAuthors = value),
                        searchController: _authorSearchController,
                        searchQuery: _authorSearchQuery,
                        onSearchChanged: (value) => setState(() => _authorSearchQuery = value),
                      );
                    },
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.person,
                      color: _selectedAuthors.isNotEmpty
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Status filters
                  FilterChip(
                    label: const Text('Published'),
                    selected: _showPublished,
                    showCheckmark: false,
                    onSelected: (bool selected) {
                      setState(() {
                        _showPublished = selected;
                        if (!_showPublished && !_showDrafts) {
                          _showDrafts = true;
                        }
                      });
                    },
                    avatar: Icon(
                      Icons.publish,
                      color: _showPublished
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Drafts'),
                    selected: _showDrafts,
                    showCheckmark: false,
                    onSelected: (bool selected) {
                      setState(() {
                        _showDrafts = selected;
                        if (!_showPublished && !_showDrafts) {
                          _showPublished = true;
                        }
                      });
                    },
                    avatar: Icon(
                      Icons.edit_note,
                      color: _showDrafts
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Featured'),
                    selected: _showFeatured,
                    showCheckmark: false,
                    onSelected: (bool selected) {
                      setState(() {
                        _showFeatured = selected;
                      });
                    },
                    avatar: Icon(
                      Icons.star,
                      color: _showFeatured
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : null,
                    ),
                  ),

                  // Clear filters button
                  if (_searchQuery.isNotEmpty ||
                      _selectedDateRange != null ||
                      _selectedAuthors.isNotEmpty ||
                      !_showPublished ||
                      !_showDrafts ||
                      _showFeatured) ...[
                    const SizedBox(width: 16),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                          _selectedDateRange = null;
                          _selectedAuthors.clear();
                          _showPublished = true;
                          _showDrafts = true;
                          _showFeatured = false;
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
      body: Consumer<ArticleViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final articles = _filterArticles(viewModel.articles);
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  children: [
                    if (!_isSelectionMode) ...[
                      Text(
                        'Manage Articles',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (articles.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isSelectionMode = true;
                            });
                          },
                          icon: const Icon(Icons.checklist),
                          tooltip: 'Select articles',
                        ),
                    ] else ...[
                      Text(
                        '${_selectedArticleIds.length} selected',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            if (_selectedArticleIds.length == articles.length) {
                              _selectedArticleIds.clear();
                            } else {
                              _selectedArticleIds = articles.map((e) => e.id).toSet();
                            }
                          });
                        },
                        icon: Icon(_selectedArticleIds.length == articles.length 
                          ? Icons.deselect 
                          : Icons.select_all
                        ),
                        label: Text(_selectedArticleIds.length == articles.length 
                          ? 'Deselect All' 
                          : 'Select All'
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = false;
                            _selectedArticleIds.clear();
                          });
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                      if (_selectedArticleIds.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                            foregroundColor: Theme.of(context).colorScheme.onError,
                          ),
                          onPressed: () => _deleteSelectedArticles(),
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete Selected'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              _buildSearchAndFilters(articles),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Divider(),
              ),
              Expanded(
                child: articles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.article_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No articles found',
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
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: articles.length,
                        itemBuilder: (context, index) {
                          final article = articles[index];
                          final isSelected = _selectedArticleIds.contains(article.id);
                          
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: _isSelectionMode
                                  ? () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedArticleIds.remove(article.id);
                                        } else {
                                          _selectedArticleIds.add(article.id);
                                        }
                                      });
                                    }
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ArticleDetailPage.wrapped(
                                            article: article,
                                          ),
                                        ),
                                      );
                                    },
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (article.thumbnailUrl != null)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              article.thumbnailUrl!,
                                              width: 120,
                                              height: 120,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                article.title,
                                                style: Theme.of(context).textTheme.titleLarge,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                article.plainContent,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.access_time,
                                                    size: 16,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    timeago.format(article.datePublished),
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  if (article.isFeatured)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context).colorScheme.secondaryContainer,
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.star,
                                                            size: 14,
                                                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            'Featured',
                                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  if (!article.isPublished)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context).colorScheme.surfaceVariant,
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        'Draft',
                                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!_isSelectionMode)
                                          PopupMenuButton<String>(
                                            icon: Icon(
                                              Icons.more_vert,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                            itemBuilder: (context) => [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: const ListTile(
                                                  leading: Icon(Icons.edit_outlined),
                                                  title: Text('Edit'),
                                                  dense: true,
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: article.isPublished ? 'unpublish' : 'publish',
                                                child: ListTile(
                                                  leading: Icon(
                                                    article.isPublished
                                                        ? Icons.unpublished_outlined
                                                        : Icons.publish_outlined,
                                                  ),
                                                  title: Text(
                                                    article.isPublished ? 'Unpublish' : 'Publish',
                                                  ),
                                                  dense: true,
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: article.isFeatured ? 'unfeature' : 'feature',
                                                enabled: article.isPublished || article.isFeatured,
                                                child: ListTile(
                                                  leading: Icon(
                                                    article.isFeatured
                                                        ? Icons.star_outline
                                                        : Icons.star,
                                                    color: (!article.isPublished && !article.isFeatured)
                                                        ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha:0.38)
                                                        : null,
                                                  ),
                                                  title: Text(
                                                    article.isFeatured ? 'Unfeature' : 'Feature',
                                                    style: (!article.isPublished && !article.isFeatured)
                                                        ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha:.38))
                                                        : null,
                                                  ),
                                                  subtitle: (!article.isPublished && !article.isFeatured)
                                                      ? Text(
                                                          'Must be published first',
                                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                            color: Theme.of(context).colorScheme.error,
                                                          ),
                                                        )
                                                      : null,
                                                  dense: true,
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: ListTile(
                                                  leading: Icon(Icons.delete_outline),
                                                  title: Text('Delete'),
                                                  dense: true,
                                                ),
                                              ),
                                            ],
                                            onSelected: (value) async {
                                              switch (value) {
                                                case 'edit':
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => ChangeNotifierProvider(
                                                        create: (_) => ArticleViewModel(),
                                                        child: WriteArticlePage(
                                                          article: article,
                                                        ),
                                                      ),
                                                      fullscreenDialog: true,
                                                    ),
                                                  );
                                                  break;
                                                case 'publish':
                                                  await viewModel.togglePublished(article.id, true);
                                                  break;
                                                case 'unpublish':
                                                  await viewModel.togglePublished(article.id, false);
                                                  break;
                                                case 'feature':
                                                  await viewModel.toggleFeatured(article.id, true);
                                                  break;
                                                case 'unfeature':
                                                  await viewModel.toggleFeatured(article.id, false);
                                                  break;
                                                case 'delete':
                                                  await _confirmDeleteArticle(article.id);
                                                  break;
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (_isSelectionMode)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: IconButton(
                                        icon: Icon(
                                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedArticleIds.remove(article.id);
                                            } else {
                                              _selectedArticleIds.add(article.id);
                                            }
                                          });
                                        },
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
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChangeNotifierProvider(
                      create: (_) => ArticleViewModel(),
                      child: const WriteArticlePage(),
                    ),
                    fullscreenDialog: true,
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Write Article'),
            ),
    );
  }
}