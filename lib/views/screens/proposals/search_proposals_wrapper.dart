import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/services/auth_service.dart';
import '../../../viewmodels/proposals_viewmodel.dart';
import 'search_proposals_page.dart';

class SearchProposalsWrapper extends StatelessWidget {
  const SearchProposalsWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        ChangeNotifierProxyProvider<AuthService, ProposalsViewModel>(
          create: (context) => ProposalsViewModel(context.read<AuthService>()),
          update: (context, auth, previous) => 
            previous ?? ProposalsViewModel(auth),
        ),
      ],
      child: const SearchProposalsPage(),
    );
  }
}
