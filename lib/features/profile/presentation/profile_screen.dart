import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/async/async_value.dart';
import '../../../core/time/format.dart';

import '../../auth/application/auth_cubit.dart';
import '../../auth/domain/auth_models.dart';
import '../../employee/data/employee_repository.dart';
import '../../shell/signed_in_scope.dart';

/// Employee profile (employment and contact), account, and sign-out.
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
    final user = context.select((AuthCubit cubit) => cubit.state.user);
    final profileState = context.watch<ProfileCubit>().state;
    final profile = profileState.valueOrPrevious;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          context.read<AuthCubit>().refreshProfile(),
          context.read<ProfileCubit>().load(),
        ]),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (profile != null) ...[
              _ProfileHeader(profile: profile),
              const SizedBox(height: 20),
              _Section(title: 'Employment', rows: [
                (Icons.badge_outlined, 'Employee ID', profile.code),
                (Icons.work_outline, 'Position', profile.position?.name),
                (Icons.groups_outlined, 'Department', profile.department?.name),
                (Icons.place_outlined, 'Office', profile.office?.name),
                (Icons.supervisor_account_outlined, 'Manager', profile.manager?.name),
                (Icons.event_outlined, 'Joined', Clock.date(profile.joinDate)),
              ]),
              const SizedBox(height: 16),
              _Section(title: 'Contact', rows: [
                (Icons.phone_outlined, 'Phone', profile.phone),
                (
                  Icons.contact_emergency_outlined,
                  'Emergency contact',
                  profile.emergencyContactName == null
                      ? null
                      : [profile.emergencyContactName, profile.emergencyContactPhone]
                          .whereType<String>()
                          .join(' · '),
                ),
              ]),
              const SizedBox(height: 16),
            ] else if (profileState is AsyncError<EmployeeProfile?>) ...[
              const _ProfileUnavailable(),
              const SizedBox(height: 16),
            ],
            if (user == null)
              const _ProfileUnavailable()
            else
              _AccountCard(user: user),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const Key('profile.signOut'),
              onPressed: _busy ? null : () => _signOut(everywhere: false),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => _signOut(everywhere: true),
              child: const Text('Sign out of all devices'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final EmployeeProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = profile.fullName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final role = [profile.position?.name, profile.department?.name]
        .whereType<String>()
        .join(' · ');
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            initials,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          profile.fullName,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (role.isNotEmpty)
          Text(
            role,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

typedef _Row = (IconData icon, String label, String? value);

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: theme.textTheme.titleSmall),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (index, (icon, label, value)) in rows.indexed) ...[
                if (index > 0) const Divider(height: 1, indent: 56),
                ListTile(
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
                      color: value == null ? theme.colorScheme.onSurfaceVariant : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user});

  final CurrentUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                user.email.substring(0, 1).toUpperCase(),
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
            title: Text(user.email),
            subtitle: Text(user.role.label),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.apartment_outlined),
            title: Text(user.organization.name),
            subtitle: Text(user.organization.timezone),
          ),
        ],
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
