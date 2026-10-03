import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';

/// The signed-in user's employee profile (`GET /employees/me`).
class EmployeeProfile {
  EmployeeProfile.fromJson(Json json)
      : id = json.str('id'),
        code = json.str('employeeCode'),
        fullName = json.str('fullName'),
        email = json.strOrNull('email'),
        phone = json.strOrNull('phone'),
        joinDate = json.str('joinDate'),
        status = json.str('status'),
        department = Ref.from(json.objOrNull('department')),
        position = Ref.from(json.objOrNull('position')),
        office = Ref.from(json.objOrNull('office')),
        manager = Ref.from(json.objOrNull('manager')),
        emergencyContactName = json.strOrNull('emergencyContactName'),
        emergencyContactPhone = json.strOrNull('emergencyContactPhone');

  final String id;
  final String code;
  final String fullName;
  final String? email;
  final String? phone;
  final String joinDate;
  final String status;
  final Ref? department;
  final Ref? position;
  final Ref? office;
  final Ref? manager;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  String get firstName => fullName.split(' ').first;
}

class EmployeeRepository {
  EmployeeRepository(this._api);

  final ApiClient _api;

  /// Null when the account has no employee profile (admins, HR without one).
  Future<EmployeeProfile?> me() async {
    try {
      return EmployeeProfile.fromJson(data(await _api.dio.get('/employees/me')));
    } catch (error) {
      if (apiFailureOf(error).statusCode == 404) return null;
      rethrow;
    }
  }
}
