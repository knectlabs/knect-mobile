import 'package:flutter/material.dart';

import '../../core/async/async_value.dart';

/// Renders an [AsyncValue]: skeleton while first loading, error with retry,
/// otherwise [builder] (also during refresh, using the previous value).
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    required this.value,
    required this.builder,
    required this.onRetry,
    this.loading,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    final data = value.valueOrPrevious;
    if (data != null) return builder(data);
    return switch (value) {
      AsyncError(:final failure) => ErrorView(
          message: failureMessage(failure),
          onRetry: onRetry,
        ),
      _ => loading ?? const SkeletonList(),
    };
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 14),
          Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Lightweight shimmer-free skeleton rows.
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.count = 4, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 72,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/// Coloured status label (approval / attendance states).
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {this.tone = StatusTone.neutral, super.key});

  final String label;
  final StatusTone tone;

  factory StatusChip.approval(String status) => StatusChip(
        switch (status) {
          'PENDING' => 'Pending',
          'APPROVED' => 'Approved',
          'REJECTED' => 'Rejected',
          'CANCELLED' => 'Cancelled',
          _ => status,
        },
        tone: switch (status) {
          'APPROVED' => StatusTone.success,
          'REJECTED' => StatusTone.danger,
          'PENDING' => StatusTone.warning,
          _ => StatusTone.neutral,
        },
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (background, foreground) = switch (tone) {
      StatusTone.success => (
          const Color(0xFF1F8A5B).withValues(alpha: dark ? 0.25 : 0.12),
          dark ? const Color(0xFF7FD8AE) : const Color(0xFF13643F),
        ),
      StatusTone.warning => (
          const Color(0xFFC98A0B).withValues(alpha: dark ? 0.25 : 0.14),
          dark ? const Color(0xFFF2C66D) : const Color(0xFF7A5205),
        ),
      StatusTone.danger => (
          colors.error.withValues(alpha: dark ? 0.2 : 0.12),
          dark ? colors.error : colors.onErrorContainer,
        ),
      StatusTone.neutral => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

enum StatusTone { neutral, success, warning, danger }

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}
