import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Cache for Firebase Storage URLs to prevent excessive token requests
final _urlCache = <String, _CachedUrl>{};

class _CachedUrl {
  final String url;
  final DateTime expiry;

  _CachedUrl(this.url, this.expiry);

  bool get isValid => DateTime.now().isBefore(expiry);
}

class UserAvatar extends StatefulWidget {
  final String? imageUrl;
  final double radius;
  final String? fallbackInitial;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.radius = 16,
    this.fallbackInitial,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  String? _cachedAuthUrl;
  bool _isLoadingUrl = false;

  @override
  void initState() {
    super.initState();
    _loadAuthenticatedUrl();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      _loadAuthenticatedUrl();
    }
  }

  Future<void> _loadAuthenticatedUrl() async {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return;

    // Skip if not a Firebase Storage URL
    if (!url.contains('firebase') || !url.contains('storage')) {
      _cachedAuthUrl = url;
      return;
    }

    // Check cache first
    final cached = _urlCache[url];
    if (cached != null && cached.isValid) {
      if (mounted) {
        setState(() {
          _cachedAuthUrl = cached.url;
          _isLoadingUrl = false;
        });
      }
      return;
    }

    // Load new URL if not in cache or expired
    if (mounted) {
      setState(() => _isLoadingUrl = true);
    }

    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      final downloadUrl = await ref.getDownloadURL();
      
      // Cache the URL with 1 hour expiry
      _urlCache[url] = _CachedUrl(
        downloadUrl,
        DateTime.now().add(const Duration(hours: 1)),
      );
      
      if (mounted) {
        setState(() {
          _cachedAuthUrl = downloadUrl;
          _isLoadingUrl = false;
        });
      }
    } catch (e) {
      debugPrint('Error getting authenticated URL: $e');
      if (mounted) {
        setState(() => _isLoadingUrl = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUrl) {
      return _buildLoadingAvatar(context);
    }

    if (_cachedAuthUrl != null) {
      return RepaintBoundary(
        child: SizedBox(
          width: widget.radius * 2,
          height: widget.radius * 2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildLoadingAvatar(context),
              ClipOval(
                child: Image.network(
                  _cachedAuthUrl!,
                  width: widget.radius * 2,
                  height: widget.radius * 2,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Avatar load error for $_cachedAuthUrl: ${error.toString()}');
                    return _buildFallbackAvatar(context);
                  },
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded || frame != null) {
                      return child;
                    }
                    return const SizedBox.shrink();
                  },
                  cacheWidth: (widget.radius * 2 * MediaQuery.of(context).devicePixelRatio).toInt(),
                  cacheHeight: (widget.radius * 2 * MediaQuery.of(context).devicePixelRatio).toInt(),
                  gaplessPlayback: true,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildFallbackAvatar(context);
  }

  Widget _buildLoadingAvatar(BuildContext context) {
    return SizedBox(
      width: widget.radius * 2,
      height: widget.radius * 2,
      child: Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        highlightColor: Theme.of(context).colorScheme.surface,
        period: const Duration(milliseconds: 1500),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(BuildContext context) {
    final initial = widget.fallbackInitial ?? '?';
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        initial,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
          fontSize: widget.radius * 0.875,
        ),
      ),
    );
  }
}