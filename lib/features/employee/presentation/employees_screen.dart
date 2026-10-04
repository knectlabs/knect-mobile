import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/async/async_value.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/large_title.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/directory_repository.dart';

/// Employees tab: people directory with colleagues on leave today and an
/// A–Z list with call, email, and WhatsApp shortcuts.
class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<DirectoryCubit>();
    final people = cubit.state.valueOrPrevious;
    final query = _search.text.trim().toLowerCase();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LargeTitle(
              'Employees',
              trailingText: people == null ? null : '${people.length}',
              action: IconButton(
                key: const Key('employees.search'),
                tooltip: _searching ? 'Close search' : 'Search',
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _search.clear();
                }),
                icon: Icon(_searching ? Icons.close : Icons.search),
              ),
            ),
            if (_searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  controller: _search,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search by name or position',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: cubit.load,
                child: AsyncView(
                  value: cubit.state,
                  onRetry: cubit.load,
                  builder: (people) {
                    final matches = query.isEmpty
                        ? people
                        : people
                            .where((p) =>
                                p.fullName.toLowerCase().contains(query) ||
                                (p.position ?? '')
                                    .toLowerCase()
                                    .contains(query) ||
                                (p.department ?? '')
                                    .toLowerCase()
                                    .contains(query))
                            .toList();
                    return _DirectoryList(
                        people: matches, showAway: query.isEmpty);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectoryList extends StatelessWidget {
  const _DirectoryList({required this.people, required this.showAway});

  final List<Colleague> people;
  final bool showAway;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final away = people.where((p) => p.onLeaveToday).toList();
    final rows = <Widget>[];

    if (showAway) {
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: Text(
          'On leave today',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ));
      rows.add(
        away.isEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Everyone is working today.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : SizedBox(
                height: 84,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: away.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) => SizedBox(
                    width: 64,
                    child: Column(
                      children: [
                        InitialsAvatar(name: away[index].fullName, radius: 24),
                        const SizedBox(height: 6),
                        Text(
                          away[index].firstName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      );
      rows.add(const Divider(height: 24));
    }

    if (people.isEmpty) {
      rows.add(const EmptyView(
        icon: Icons.person_search_outlined,
        title: 'No one found',
        message: 'Try another name or position.',
      ));
    }

    String? letter;
    for (final person in people) {
      final initial =
          person.fullName.isEmpty ? '#' : person.fullName[0].toUpperCase();
      if (initial != letter) {
        letter = initial;
        rows.add(Container(
          width: double.infinity,
          color: theme.colorScheme.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Text(initial, style: theme.textTheme.titleSmall),
        ));
      }
      rows.add(_PersonTile(person: person));
      rows.add(const Divider(height: 1, indent: 76));
    }

    return ListView(padding: const EdgeInsets.only(bottom: 24), children: rows);
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person});

  final Colleague person;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final phone = person.phone;

    Future<void> open(Uri uri) async {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication)
          .catchError((_) => false);
      if (!opened && context.mounted) {
        showMessage(context, 'No app on this phone can open that.');
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
      child: Row(
        children: [
          InitialsAvatar(name: person.fullName, radius: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(person.fullName, style: theme.textTheme.titleSmall),
                Text(
                  person.onLeaveToday
                      ? '${person.subtitle} · On leave'
                      : person.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Call',
            onPressed: phone == null
                ? null
                : () => open(Uri(scheme: 'tel', path: phone)),
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(
            tooltip: 'Email',
            onPressed: () => open(Uri(scheme: 'mailto', path: person.email)),
            icon: const Icon(Icons.mail_outline),
          ),
          IconButton(
            tooltip: 'WhatsApp',
            onPressed: phone == null
                ? null
                : () => open(Uri.https('wa.me', '/${whatsappNumber(phone)}')),
            icon: const Icon(Icons.chat_outlined),
          ),
        ],
      ),
    );
  }
}

/// Digits for wa.me in international form; Indonesian "08…" becomes "628…".
String whatsappNumber(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return digits.startsWith('0') ? '62${digits.substring(1)}' : digits;
}
