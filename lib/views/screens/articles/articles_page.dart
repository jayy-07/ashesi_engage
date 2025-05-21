import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/article_viewmodel.dart';
import '../../../models/entities/article.dart';
import '../../widgets/article_card.dart';
import 'search_articles_wrapper.dart';

class ArticlesPage extends StatefulWidget {
  const ArticlesPage({super.key});

  @override
  State<ArticlesPage> createState() => _ArticlesPageState();
}

class _ArticlesPageState extends State<ArticlesPage> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // Load articles when the page opens
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

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchArticlesWrapper(),
                ),
              );
            },
            child: SearchBar(
              enabled: false,
              hintText: 'Search articles',
              padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 16.0)),
              leading: const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(Icons.search),
              ),
              elevation: WidgetStateProperty.all(0.0),
              backgroundColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) {
                  return Theme.of(context).colorScheme.surfaceContainerHighest;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      children: [
        _buildSearchBar(context),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 64.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No articles found',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_searchQuery.isNotEmpty || _selectedDateRange != null)
                  Text(
                    'Try adjusting your filters',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  Text(
                    'Check back later for updates',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                if (_searchQuery.isNotEmpty || _selectedDateRange != null) ...[
                  const SizedBox(height: 24),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Articles'),
      ),
      body: Consumer<ArticleViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final filteredArticles = _filterArticles(viewModel.articles);

          return filteredArticles.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  key: const PageStorageKey('articles_list'),
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredArticles.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildSearchBar(context);
                    }
                    final article = filteredArticles[index - 1];
                    return ArticleCard(article: article);
                  },
                );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}