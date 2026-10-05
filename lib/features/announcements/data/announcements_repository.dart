import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';

/// A company announcement published to employees. The API only returns
/// PUBLISHED announcements to employees, organization-scoped. `authorUserId`
/// is never exposed.
class Announcement {
  Announcement.fromJson(Json json)
      : id = json.str('id'),
        title = json.str('title'),
        body = json.str('body'),
        status = json.str('status'),
        publishedAt = json.timeOrNull('publishedAt'),
        authorName = json.strOrNull('authorName'),
        createdAt = json.time('createdAt');

  final String id;
  final String title;
  final String body;

  /// `DRAFT` | `PUBLISHED`. Employee reads only ever see `PUBLISHED`.
  final String status;
  final DateTime? publishedAt;
  final String? authorName;
  final DateTime createdAt;

  /// Prefer the publish time; fall back to creation for ordering/display.
  DateTime get displayDate => publishedAt ?? createdAt;
}

/// Reads for published announcements (Home preview + full list + detail).
/// Business rules and PUBLISHED filtering live in the API.
class AnnouncementsRepository {
  AnnouncementsRepository(this._api);

  final ApiClient _api;

  Future<List<Announcement>> list() async => dataList(
        await _api.dio.get('/announcements', queryParameters: {'limit': 50}),
      ).map(Announcement.fromJson).toList();

  Future<Announcement> getOne(String id) async =>
      Announcement.fromJson(data(await _api.dio.get('/announcements/$id')));
}
