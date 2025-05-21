import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/entities/article.dart';
import '../../../viewmodels/article_viewmodel.dart';
import '../../widgets/article_card.dart';

class SearchArticlesPage extends StatefulWidget {
  const SearchArticlesPage({super.key});

  @override
  State<SearchArticlesPage> createState() => _SearchArticlesPageState();
}

class _SearchArticlesPageState extends State<SearchArticlesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ArticleViewModel>().loadArticles();
    });
  }

  List<Article> _filterArticles(List<Article> articles) {
    return articles.where((article) {
      // Only show published articles
      if (!article.isPublished) return false;

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

      return true;
    }).toList()
      ..sort((a, b) => b.datePublished.compareTo(a.datePublished));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search articles',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
          ),
          style: theme.textTheme.bodyLarge,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: FilterChip(
              label: Text(_selectedDateRange == null
                  ? 'Date'
                  : '${DateFormat.MMMd().format(_selectedDateRange!.start)} - ${DateFormat.MMMd().format(_selectedDateRange!.end)}'),
              selected: _selectedDateRange != null,
              showCheckmark: false,
              avatar: Icon(
                Icons.calendar_today,
                color: _selectedDateRange != null
                    ? theme.colorScheme.onSecondaryContainer
                    : null,
                size: 20,
              ),
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
                            headerBackgroundColor: theme.colorScheme.primaryContainer,
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
            ),
          ),
        ],
      ),
      body: Consumer<ArticleViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_searchQuery.isEmpty && _selectedDateRange == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Type to search articles',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          final filteredArticles = _filterArticles(viewModel.articles);

          if (filteredArticles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No articles found',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_selectedDateRange != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your search or date filter',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: filteredArticles.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final article = filteredArticles[index];
              return ArticleCard(article: article);
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}