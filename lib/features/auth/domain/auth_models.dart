import 'package:equatable/equatable.dart';

import '../../../core/storage/token_storage.dart';

/// Thrown when an API payload does not match the documented contract.
class ContractException implements Exception {
  const ContractException(this.message);

  final String message;

  @override
  String toString() => 'ContractException: $message';
}

T _field<T>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is T) return value;
  throw ContractException('Unexpected "$key" in API response.');
}

enum UserRole {
  superAdmin('SUPER_ADMIN', 'Super admin'),
  companyAdmin('COMPANY_ADMIN', 'Company admin'),
  hr('HR', 'HR'),
  manager('MANAGER', 'Manager'),
  employee('EMPLOYEE', 'Employee');

  const UserRole(this.value, this.label);

  final String value;
  final String label;

  static UserRole parse(String value) => UserRole.values.firstWhere(
        (role) => role.value == value,
        orElse: () => throw ContractException('Unknown role "$value".'),
      );
}

class OrganizationSummary extends Equatable {
  const OrganizationSummary({
    required this.id,
    required this.name,
    required this.code,
    required this.timezone,
  });

  factory OrganizationSummary.fromJson(Map<String, Object?> json) {
    return OrganizationSummary(
      id: _field<String>(json, 'id'),
      name: _field<String>(json, 'name'),
      code: _field<String>(json, 'code'),
      timezone: _field<String>(json, 'timezone'),
    );
  }

  final String id;
  final String name;
  final String code;
  final String timezone;

  @override
  List<Object?> get props => [id, name, code, timezone];
}

/// The signed-in user (`GET /auth/me`, `user` in session responses).
class CurrentUser extends Equatable {
  const CurrentUser({
    required this.id,
    required this.email,
    required this.role,
    required this.organization,
    this.lastLoginAt,
  });

  factory CurrentUser.fromJson(Map<String, Object?> json) {
    final lastLogin = json['lastLoginAt'];
    return CurrentUser(
      id: _field<String>(json, 'id'),
      email: _field<String>(json, 'email'),
      role: UserRole.parse(_field<String>(json, 'role')),
      lastLoginAt: lastLogin is String ? DateTime.tryParse(lastLogin) : null,
      organization: OrganizationSummary.fromJson(
        _field<Map<String, Object?>>(json, 'organization'),
      ),
    );
  }

  final String id;
  final String email;
  final UserRole role;
  final DateTime? lastLoginAt;
  final OrganizationSummary organization;

  @override
  List<Object?> get props => [id, email, role, lastLoginAt, organization];
}

/// Session issued by `POST /auth/login` and `POST /auth/refresh`.
class AuthSession extends Equatable {
  const AuthSession({required this.tokens, required this.user});

  factory AuthSession.fromJson(Map<String, Object?> json) {
    return AuthSession(
      tokens: AuthTokens(
        accessToken: _field<String>(json, 'accessToken'),
        refreshToken: _field<String>(json, 'refreshToken'),
      ),
      user: CurrentUser.fromJson(_field<Map<String, Object?>>(json, 'user')),
    );
  }

  final AuthTokens tokens;
  final CurrentUser user;

  @override
  List<Object?> get props => [tokens, user];
}

/// Reads `{"data": {...}}` envelopes.
Map<String, Object?> unwrapData(Object? body) {
  if (body is Map && body['data'] is Map) {
    return Map<String, Object?>.from(body['data'] as Map);
  }
  throw const ContractException('Expected a {"data": {...}} response.');
}
