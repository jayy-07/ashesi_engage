import 'package:flutter/material.dart';
import '../../auth/models/app_user.dart';
import '../../models/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../widgets/snackbar_helper.dart';

class BannedUserScreen extends StatelessWidget {
  final AppUser user;

  const BannedUserScreen({
    super.key,
    required this.user,
  });

  String _getBanDurationText() {
    if (user.bannedUntil == null) {
      return 'Your account has been permanently banned';
    }

    final now = DateTime.now();
    if (user.bannedUntil!.isBefore(now)) {
      return 'Your ban has expired';
    }

    final duration = user.bannedUntil!.difference(now);
    if (duration.inDays > 0) {
      return 'Your account is banned for ${duration.inDays} day${duration.inDays == 1 ? '' : 's'}';
    } else if (duration.inHours > 0) {
      return 'Your account is banned for ${duration.inHours} hour${duration.inHours == 1 ? '' : 's'}';
    } else {
      return 'Your account is banned for ${duration.inMinutes} minute${duration.inMinutes == 1 ? '' : 's'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.gavel_rounded,
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Account Banned',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _getBanDurationText(),
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (user.banReason != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Reason: ${user.banReason}',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await context.read<AuthService>().signOut();
                      } catch (e) {
                        if (!context.mounted) return;
                        SnackbarHelper.showError(context, 'Error signing out: $e');
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 