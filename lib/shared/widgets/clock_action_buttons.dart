import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ClockActionButtons extends StatelessWidget {
  const ClockActionButtons({
    required this.keyPrefix,
    required this.canClockIn,
    required this.canClockOut,
    required this.onClockIn,
    required this.onClockOut,
    super.key,
  });

  final String keyPrefix;
  final bool canClockIn;
  final bool canClockOut;
  final VoidCallback onClockIn;
  final VoidCallback onClockOut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget button(bool clockIn) {
      final enabled = clockIn ? canClockIn : canClockOut;
      final foreground = enabled ? colors.onSurface : colors.onSurfaceVariant;
      final iconColor = enabled
          ? (clockIn
              ? (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFF166534))
              : colors.error)
          : foreground;
      return OutlinedButton.icon(
        key: Key('$keyPrefix.${clockIn ? 'clockIn' : 'clockOut'}'),
        onPressed: enabled ? (clockIn ? onClockIn : onClockOut) : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          disabledForegroundColor: foreground,
          backgroundColor: colors.surfaceContainerLowest,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          side: BorderSide(color: colors.outlineVariant),
        ),
        icon: SvgPicture.asset(
          'assets/icons/${clockIn ? 'clock_in' : 'clock_out'}.svg',
          width: 22,
          height: 22,
          excludeFromSemantics: true,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        ),
        label: Text(clockIn ? 'Clock In' : 'Clock Out'),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(16) > 20) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              button(true),
              const SizedBox(height: 8),
              button(false),
            ]);
      }
      return Row(children: [
        Expanded(child: button(true)),
        const SizedBox(width: 12),
        Expanded(child: button(false)),
      ]);
    });
  }
}
