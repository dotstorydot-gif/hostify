import "package:flutter/material.dart";

/// Reusable loading widgets and utilities
class LoadingUtils {
  /// Show fullscreen loading overlay
  static void showLoadingOverlay(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFFFFD700),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// Hide loading overlay
  static void hideLoadingOverlay(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  
  /// Full screen loading widget
  static Widget fullScreenLoading({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFFFFD700),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
  
  /// Skeleton loading for lists
  static Widget skeletonLoader({int itemCount = 3, double? height}) {
    return ListView.builder(
      itemCount: itemCount,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => _SkeletonItem(),
    );
  }
  
  /// Small inline loading indicator
  static Widget inlineLoader({Color? color, double? size}) {
    return SizedBox(
      width: size ?? 20,
      height: size ?? 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color ?? const Color(0xFFFFD700),
      ),
    );
  }
}

class _SkeletonItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(width: 200, height: 16),
          SizedBox(height: 8),
          _ShimmerBox(width: 150, height: 14),
          SizedBox(height: 12),
          _ShimmerBox(width: double.infinity, height: 12),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  
  const _ShimmerBox({required this.width, required this.height});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Loading state wrapper widget
class LoadingStateBuilder extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final Widget child;
  final Widget? loadingWidget;
  final Widget Function(String error)? errorBuilder;
  final VoidCallback? onRetry;
  
  const LoadingStateBuilder({
    super.key,
    required this.isLoading,
    this.error,
    required this.child,
    this.loadingWidget,
    this.errorBuilder,
    this.onRetry,
  });
  
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return loadingWidget ?? LoadingUtils.fullScreenLoading();
    }
    
    if (error != null) {
      if (errorBuilder != null) {
        return errorBuilder!(error!);
      }
      
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    
    return child;
  }
}
