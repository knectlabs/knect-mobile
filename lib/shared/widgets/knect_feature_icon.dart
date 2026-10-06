import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class KnectFeatureIcon extends StatelessWidget {
  const KnectFeatureIcon({required this.icon, this.size = 24, super.key});

  final IconData icon;
  final double size;

  static final _assets = {
    Icons.beach_access_outlined: 'time_off',
    Icons.location_on_outlined: 'live_attendance',
    Icons.more_time_outlined: 'overtime',
    Icons.edit_calendar_outlined: 'correction',
    Icons.history_outlined: 'attendance_history',
    Icons.assignment_outlined: 'requests',
    Icons.receipt_long_outlined: 'payslip',
    Icons.account_balance_wallet_outlined: 'reimbursement',
    Icons.flag_outlined: 'goals',
    Icons.rate_review_outlined: 'reviews',
    Icons.fact_check_outlined: 'approvals',
    Icons.apps_outlined: 'all_apps',
    Icons.account_circle_outlined: 'personal_info',
    Icons.work_outline: 'employment_info',
    Icons.emergency_outlined: 'emergency_contact',
    Icons.face_retouching_natural: 'profile_photo',
    Icons.logout: 'clock_out',
    Icons.devices_outlined: 'devices',
  };

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final asset = _assets[icon];
    if (asset == null) return Icon(icon, size: size, color: color);
    return Center(
      child: SvgPicture.asset(
        'assets/icons/$asset.svg',
        width: size,
        height: size,
        excludeFromSemantics: true,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}
