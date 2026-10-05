import '../../../core/async/async_value.dart';
import '../data/announcements_repository.dart';

/// Published announcements; load/refresh with [LoadCubit].
class AnnouncementsCubit extends LoadCubit<List<Announcement>> {
  AnnouncementsCubit(AnnouncementsRepository repository)
      : super(repository.list);
}
