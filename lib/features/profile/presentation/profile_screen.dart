import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/application/auth_cubit.dart';
import '../../auth/domain/auth_models.dart';

/// Profile placeholder (Phase 1A): account identity and sign-out. Employment
/// details arrive with the employee domain in Phase 1B.
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

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AuthCubit>().refreshProfile(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
