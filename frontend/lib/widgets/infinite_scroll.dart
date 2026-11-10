import 'package:flutter/material.dart';

import '../core/theme.dart';

/// يستدعي [onLoadMore] عند الاقتراب من نهاية السكرول داخل الكونتينر.
class InfiniteScroll extends StatelessWidget {
  const InfiniteScroll({
    super.key,
    required this.child,
    this.onLoadMore,
    this.hasMore = false,
    this.loadingMore = false,
    this.threshold = 240,
  });

  final Widget child;
  final VoidCallback? onLoadMore;
  final bool hasMore;
  final bool loadingMore;
  final double threshold;

  bool _shouldLoad(ScrollNotification notification) {
    if (onLoadMore == null || !hasMore || loadingMore) return false;
    if (notification is! ScrollUpdateNotification &&
        notification is! OverscrollNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }
    final metrics = notification.metrics;
    if (!metrics.hasPixels || !metrics.hasContentDimensions) return false;
    if (metrics.maxScrollExtent <= 0) return false;
    return metrics.pixels >= metrics.maxScrollExtent - threshold;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (_shouldLoad(notification)) {
          onLoadMore!();
        }
        return false;
      },
      child: child,
    );
  }
}

class InfiniteScrollFooter extends StatelessWidget {
  const InfiniteScrollFooter({
    super.key,
    required this.loadingMore,
    required this.hasMore,
    this.total,
  });

  final bool loadingMore;
  final bool hasMore;
  final int? total;

  @override
  Widget build(BuildContext context) {
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppTheme.soft,
            ),
          ),
        ),
      );
    }
    if (!hasMore && total != null && total! > 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'تم عرض كل النتائج ($total)',
            style: AppTheme.text(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.basic.withValues(alpha: 0.45),
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: 8);
  }
}
