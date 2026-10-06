import 'package:flutter/material.dart';
import '../../../core/theme/knect_tokens.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/time/format.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/application/auth_cubit.dart';
import '../data/announcements_repository.dart';

/// Full announcement: title, author + date, and body. Accepts an already
/// loaded [announcement]; otherwise loads it by [id] via the repository.
class AnnouncementDetailScreen extends StatefulWidget {
  const AnnouncementDetailScreen({this.announcement, this.id, super.key})
      : assert(announcement != null || id != null,
            'Provide an announcement or an id to load.');

  final Announcement? announcement;
  final String? id;

  @override
  State<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  Announcement? _announcement;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _announcement = widget.announcement;
    if (_announcement == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await context.read<AnnouncementsRepository>().getOne(widget.id!);
      if (mounted) {
        setState(() {
          _announcement = result;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'This announcement could not be loaded.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final announcement = _announcement;
    return Scaffold(
      appBar: AppBar(title: const Text('Announcement')),
      body: announcement != null
          ? _AnnouncementBody(announcement: announcement)
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : ErrorView(
                  message: _error ?? 'Something went wrong. Try again.',
                  onRetry: _load,
                ),
    );
  }
}

class _AnnouncementBody extends StatelessWidget {
  const _AnnouncementBody({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tz = context.select(
      (AuthCubit auth) => auth.state.user?.organization.timezone,
    );
    final author = announcement.authorName;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Align(
            alignment: Alignment.centerLeft,
            child: Chip(
                avatar: const Icon(Icons.campaign_outlined,
                    size: 18, color: KnectColors.strongPrimary),
                label: Text(announcement.status == 'PUBLISHED'
                    ? 'Company announcement'
                    : 'Draft'))),
        const SizedBox(height: KnectSpacing.md),
        Text(
          announcement.title,
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            InitialsAvatar(name: author ?? 'Announcement', radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (author != null && author.isNotEmpty)
                    Text(
                      author,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  Text(
                    Clock.date(Clock.toZone(announcement.displayDate, tz)),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
            margin: EdgeInsets.zero,
            child: Padding(
                padding: KnectSpacing.page,
                child: SelectableText(announcement.body,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.65)))),
      ],
    );
  }
}
