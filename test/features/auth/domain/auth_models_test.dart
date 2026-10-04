import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knect_mobile/core/storage/device_identity.dart';
import 'package:knect_mobile/features/auth/domain/auth_models.dart';

void main() {
  final sessionJson = <String, Object?>{
    'data': {
      'tokenType': 'Bearer',
      'accessToken': 'access',
      'accessTokenExpiresAt': '2026-10-03T01:15:00.000Z',
      'refreshToken': 'refresh',
      'refreshTokenExpiresAt': '2026-11-02T01:00:00.000Z',
      'user': {
        'id': 'user-1',
        'email': 'hr@acme.test',
        'role': 'HR',
        'lastLoginAt': '2026-10-03T01:00:00.000Z',
        'organization': {
          'id': 'org-1',
          'name': 'PT Acme',
          'code': 'ACME',
          'timezone': 'Asia/Jakarta',
        },
      },
    },
  };

  test('parses the session contract', () {
    final session = AuthSession.fromJson(unwrapData(sessionJson));

    expect(session.tokens.accessToken, 'access');
    expect(session.tokens.refreshToken, 'refresh');
    expect(session.user.role, UserRole.hr);
    expect(session.user.organization.code, 'ACME');
    expect(session.user.lastLoginAt, DateTime.utc(2026, 10, 3, 1));
  });

  test('rejects payloads that break the contract', () {
    expect(() => unwrapData({'error': {}}), throwsA(isA<ContractException>()));
    expect(
      () => CurrentUser.fromJson({
        'id': 'u',
        'email': 'x@y.test',
        'role': 'HR_ADMIN',
        'organization': {},
      }),
      throwsA(isA<ContractException>()),
    );
    expect(
      () => AuthSession.fromJson({'accessToken': 1}),
      throwsA(isA<ContractException>()),
    );
    expect(const ContractException('x').toString(), contains('x'));
  });

  test('generates RFC 4122 v4 installation identifiers', () {
    final id = uuidV4(Random(1));
    expect(
      id,
      matches(
        RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'),
      ),
    );
    expect(uuidV4(Random(2)), isNot(id));
  });

  test('reports the platform accepted by the API', () {
    expect(SecureDeviceIdentity.platformName(TargetPlatform.iOS), 'IOS');
    expect(
        SecureDeviceIdentity.platformName(TargetPlatform.android), 'ANDROID');
    expect(
      const DeviceInfo(identifier: 'id', platform: 'IOS').toJson(),
      {'identifier': 'id', 'platform': 'IOS'},
    );
  });
}
