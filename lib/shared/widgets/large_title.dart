import 'package:flutter/material.dart';

/// Large left-aligned page title used by top-level tabs.
class LargeTitle extends StatelessWidget {
  const LargeTitle(this.title, {this.action, this.trailingText, super.key});

  final String title;
  final Widget? action;

  /// Muted text after the title, e.g. a count.
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (trailingText != null) ...[
            const SizedBox(width: 12),
            Text(
              trailingText!,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}
