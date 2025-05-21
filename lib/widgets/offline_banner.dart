import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';

enum OfflineActionType {
  none,
  pendingUpload,
  pendingSync
}

class OfflineBanner extends StatelessWidget {
  final OfflineActionType actionType;
  final VoidCallback? onRetry;

  const OfflineBanner({
    super.key, 
    this.actionType = OfflineActionType.none,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, child) {
        if (connectivity.isOnline && actionType == OfflineActionType.none) {
          return const SizedBox.shrink();
        }

        String message;
        Color backgroundColor;
        Color textColor;

        switch (actionType) {
          case OfflineActionType.pendingUpload:
            message = 'This will be uploaded when you\'re back online';
            backgroundColor = Theme.of(context).colorScheme.tertiaryContainer;
            textColor = Theme.of(context).colorScheme.onTertiaryContainer;
            break;
          case OfflineActionType.pendingSync:
            message = 'Changes will sync when you\'re back online';
            backgroundColor = Theme.of(context).colorScheme.secondaryContainer;
            textColor = Theme.of(context).colorScheme.onSecondaryContainer;
            break;
          case OfflineActionType.none:
            message = 'You\'re offline. Some features may be limited.';
            backgroundColor = Theme.of(context).colorScheme.errorContainer;
            textColor = Theme.of(context).colorScheme.onErrorContainer;
            break;
        }

        return Container(
          width: double.infinity,
          color: backgroundColor,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Icon(
                  actionType == OfflineActionType.none 
                    ? Icons.wifi_off_rounded
                    : Icons.sync_rounded,
                  color: textColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: textColor),
                  ),
                ),
                if (onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    child: Text(
                      'Retry',
                      style: TextStyle(color: textColor),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
} 