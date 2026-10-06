import '../../../core/async/async_value.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';

/// A colleague in the people directory (`GET /directory`).
class Colleague {
  Colleague.fromJson(Json json)
      : id = json.str('id'),
        fullName = json.str('fullName'),
        profilePhotoUrl = json.strOrNull('profilePhotoUrl'),
        code = json.str('employeeCode'),
        position = json.strOrNull('position'),
        department = json.strOrNull('department'),
        office = json.strOrNull('office'),
        email = json.str('email'),
        phone = json.strOrNull('phone'),
        managerId = json.strOrNull('managerId'),
        onLeaveToday = json['onLeaveToday'] == true;

  final String id;
  final String fullName;
  final String? profilePhotoUrl;
  final String code;
  final String? position;
  final String? department;
  final String? office;
  final String email;
  final String? phone;
  final String? managerId;
  final bool onLeaveToday;

  String get firstName => fullName.split(' ').first;

  /// Position, else department, else the employee code.
  String get subtitle => position ?? department ?? code;
}

class DirectoryRepository {
  DirectoryRepository(this._api);

  final ApiClient _api;

  /// Every current colleague, fetched page by page (100 per page, capped at
  /// 20 pages until the directory gets server-side search in the UI).
  Future<List<Colleague>> all() async {
    final people = <Colleague>[];
    for (var page = 1; page <= 20; page++) {
      final response = await _api.dio.get(
        '/directory',
        queryParameters: {'page': page, 'limit': 100},
      );
      people.addAll(dataList(response).map(Colleague.fromJson));
      final meta = (response.data as Map)['meta'] as Map?;
      if (meta == null || page >= ((meta['totalPages'] as num?) ?? 1)) break;
    }
    return people;
  }
}

/// Directory shared by the Employees tab and the Home "direct reports" card.
class DirectoryCubit extends LoadCubit<List<Colleague>> {
  DirectoryCubit(DirectoryRepository repository) : super(repository.all);
}
