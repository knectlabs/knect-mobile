import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/time/format.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/navigation.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/application/auth_cubit.dart';
import '../application/announcements_cubit.dart';
import '../data/announcements_repository.dart';
import 'announcement_detail_screen.dart';

/// Full list of published company announcements. Compact rows showing title,
/// author and date, with subtle dividers. Handles loading/empty/error/refresh.
class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AnnouncementsCubit(context.read<AnnouncementsRepository>()),
      child: const _AnnouncementsView(),
    );
  }
}

class _AnnouncementsView extends StatelessWidget {
  const _AnnouncementsView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<AnnouncementsCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: RefreshIndicator(
        onRefresh: cubit.load,
        child: AsyncView<List<Announcement>>(
          value: cubit.state,
          onRetry: cubit.load,
          loading: const SizedBox(height: 320, child: SkeletonList(count: 4)),
          builder: (announcements) => announcements.isEmpty
              ? ListView(
                  children: const [
                    EmptyView(
                      icon: Icons.campaign_outlined,
                      title: 'No announcements',
                      message: 'Company announcements will appear here.',
                    ),
                  ],
                )
              : ListView.separated(
                  itemCount: announcements.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) => AnnouncementTile(
                    announcement: announcements[index],
                  ),
                ),
        ),
      ),
    );
  }
}

/// A compact announcement row: author avatar, title, author + date.
class AnnouncementTile extends StatelessWidget {
  const AnnouncementTile({required this.announcement, super.key});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tz = context.select(
      (AuthCubit auth) => auth.state.user?.organization.timezone,
    );
    final author = announcement.authorName;
    final date = Clock.shortDate(Clock.toZone(announcement.displayDate, tz));
    final subtitle = author != null && author.isNotEmpty
        ? '$author · $date'
        : date;
    return InkWell(
      onTap: () => pushPage(
        context,
        AnnouncementDetailScreen(announcement: announcement),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InitialsAvatar(name: author ?? 'Announcement', radius: 18),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    announcement.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
