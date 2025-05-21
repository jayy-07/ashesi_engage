import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/services/auth_service.dart';
import '../../../viewmodels/article_viewmodel.dart';
import 'search_articles_page.dart';

class SearchArticlesWrapper extends StatelessWidget {
  const SearchArticlesWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        ChangeNotifierProxyProvider<AuthService, ArticleViewModel>(
          create: (context) => ArticleViewModel(),
          update: (context, auth, previous) => 
            previous ?? ArticleViewModel(),
        ),
      ],
      child: const SearchArticlesPage(),
    );
  }
}