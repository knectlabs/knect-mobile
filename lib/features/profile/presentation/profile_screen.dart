import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/async/async_value.dart';
import '../../../core/time/format.dart';
import '../../../core/theme/knect_tokens.dart';
import '../../../shared/widgets/knect_feature_icon.dart';

import '../../auth/application/auth_cubit.dart';
import '../../auth/domain/auth_models.dart';
import '../../employee/data/employee_repository.dart';
import '../../shell/signed_in_scope.dart';
import '../../../shared/widgets/profile_photo_avatar.dart';
import '../../../shared/widgets/large_title.dart';
import '../../../shared/widgets/navigation.dart';
import 'profile_photo_screen.dart';

/// Account tab: who the user is, their employee info, and sign-out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  Future<void> _signOut({required bool everywhere}) async {
    final auth = context.read<AuthCubit>();
    final messenger = ScaffoldMessenger.of(context);
    if (everywhere) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign out of all devices?'),
          content: const Text(
            'You will need to sign in again on every phone and browser.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _busy = true);
    try {
      if (everywhere) {
        await auth.signOutEverywhere();
      } else {
        await auth.signOut();
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not reach the server. Try again when online.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.select((AuthCubit cubit) => cubit.state.user);
    final profileState = context.watch<ProfileCubit>().state;
    final profile = profileState.valueOrPrevious;

    void open(String title, List<_Row> rows) =>
        pushPage(context, _InfoPage(title: title, rows: rows));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([
            context.read<AuthCubit>().refreshProfile(),
            context.read<ProfileCubit>().load(),
          ]),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const LargeTitle('Account'),
              if (user == null && profile == null)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _ProfileUnavailable(),
                )
              else
                _AccountHeader(user: user, profile: profile),
              if (profile == null &&
                  user != null &&
                  profileState is AsyncError<EmployeeProfile?>)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _ProfileUnavailable(),
                ),
              if (profile != null) ...[
                const _SectionTitle('My Info'),
                _MenuTile(
                  icon: Icons.account_circle_outlined,
                  label: 'Personal Info',
                  onTap: () => open('Personal Info', [
                    (Icons.person_outline, 'Full name', profile.fullName),
                    (Icons.badge_outlined, 'Employee ID', profile.code),
                    (Icons.mail_outline, 'Email', profile.email ?? user?.email),
                    (Icons.phone_outlined, 'Phone', profile.phone),
                  ]),
                ),
                _MenuTile(
                  icon: Icons.work_outline,
                  label: 'Employment Info',
                  onTap: () => open('Employment Info', [
                    (Icons.work_outline, 'Position', profile.position?.name),
                    (
                      Icons.groups_outlined,
                      'Department',
                      profile.department?.name
                    ),
                    (Icons.place_outlined, 'Office', profile.office?.name),
                    (
                      Icons.supervisor_account_outlined,
                      'Manager',
                      profile.manager?.name
                    ),
                    (
                      Icons.event_outlined,
                      'Join date',
                      Clock.date(profile.joinDate)
                    ),
                    (
                      Icons.verified_outlined,
                      'Status',
                      _status(profile.status)
                    ),
                  ]),
                ),
                _MenuTile(
                  icon: Icons.emergency_outlined,
                  label: 'Emergency Contact Info',
                  onTap: () => open('Emergency Contact Info', [
                    (
                      Icons.person_outline,
                      'Name',
                      profile.emergencyContactName
                    ),
                    (
                      Icons.phone_outlined,
                      'Phone',
                      profile.emergencyContactPhone
                    ),
                  ]),
                ),
              ],
              const _SectionTitle('Settings'),
              _MenuTile(
                icon: Icons.face_retouching_natural,
                label: 'Profile photo',
                onTap: () => pushPage(context, const ProfilePhotoScreen()),
              ),
              _MenuTile(
                key: const Key('profile.signOut'),
                icon: Icons.logout,
                label: 'Sign out',
                showChevron: false,
                onTap: _busy ? null : () => _signOut(everywhere: false),
              ),
              _MenuTile(
                icon: Icons.devices_outlined,
                label: 'Sign out of all devices',
                showChevron: false,
                onTap: _busy ? null : () => _signOut(everywhere: true),
              ),
              if (user != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Text(
                    'Signed in as ${user.email} · ${user.role.label}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _status(String status) => switch (status) {
      'ACTIVE' => 'Active',
      'PROBATION' => 'Probation',
      'RESIGNED' => 'Resigned',
      'TERMINATED' => 'Terminated',
      final other => other,
    };

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.user, required this.profile});

  final CurrentUser? user;
  final EmployeeProfile? profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final name = profile?.fullName ?? user?.email ?? '';
    final role = [profile?.position?.name, profile?.department?.name]
        .whereType<String>()
        .join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(role.isEmpty ? (user?.role.label ?? '') : role,
                    style: muted),
                if (user != null) Text(user!.organization.name, style: muted),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ProfilePhotoAvatar(
              name: name, photoUrl: profile?.profilePhotoUrl, radius: 30),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showChevron = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          tileColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(KnectRadius.field)),
            child: KnectFeatureIcon(icon: icon, size: 24),
          ),
          title: Text(label),
          trailing: showChevron ? const Icon(Icons.chevron_right) : null,
          onTap: onTap,
        ),
        const Divider(height: 1, indent: 72),
      ],
    );
  }
}

typedef _Row = (IconData icon, String label, String? value);

class _InfoPage extends StatelessWidget {
  const _InfoPage({required this.title, required this.rows});

  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final (icon, label, value) = rows[index];
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Icon(icon),
            title: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            subtitle: Text(
              value ?? 'Not set',
              style: theme.textTheme.bodyLarge?.copyWith(
                color:
                    value == null ? theme.colorScheme.onSurfaceVariant : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileUnavailable extends StatelessWidget {
  const _ProfileUnavailable();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.cloud_off_outlined),
        title: const Text('Profile not loaded'),
        subtitle: const Text('Pull down to retry when you are online.'),
      ),
    );
  }
}
