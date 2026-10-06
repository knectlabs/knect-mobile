import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knect_mobile/core/config/app_config.dart';
import 'package:knect_mobile/core/network/api_client.dart';
import 'package:knect_mobile/core/theme/app_theme.dart';
import 'package:knect_mobile/shared/widgets/clock_action_buttons.dart';
import 'package:knect_mobile/features/employee/data/directory_repository.dart';
import 'package:knect_mobile/shared/widgets/profile_photo_avatar.dart';

import 'support/fake_token_storage.dart';

class _PhotoAdapter implements HttpClientAdapter {
  RequestOptions? request;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromBytes(
        base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII='),
        200);
  }
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
        'clock actions remain readable and respect availability (${dark ? 'dark' : 'light'})',
        (tester) async {
      var inCalls = 0;
      var outCalls = 0;
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        home: Scaffold(
            body: SizedBox(
                width: 280,
                child: ClockActionButtons(
                  keyPrefix: 'test',
                  canClockIn: true,
                  canClockOut: false,
                  onClockIn: () => inCalls++,
                  onClockOut: () => outCalls++,
                ))),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('test.clockIn')));
      await tester.tap(find.byKey(const Key('test.clockOut')));
      expect(inCalls, 1);
      expect(outCalls, 0);
      expect(tester.getTopLeft(find.text('Clock Out')).dy,
          greaterThan(tester.getTopLeft(find.text('Clock In')).dy));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('directory photo is displayed using the configured API host',
      (tester) async {
    final person = Colleague.fromJson({
      'id': '1',
      'fullName': 'Rina Putri',
      'employeeCode': 'KN1',
      'email': 'rina@example.test',
      'profilePhotoUrl':
          'https://old-tunnel.example/api/v1/files/org/photo.png',
    });
    final adapter = _PhotoAdapter();
    final api = ApiClient(
      config: AppConfig.fromEnvironment(
          apiBaseUrl: 'https://current.example/api/v1'),
      tokenStorage: FakeTokenStorage(),
      dio: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(api.close);
    await tester.pumpWidget(RepositoryProvider.value(
      value: api,
      child: MaterialApp(
          home: Scaffold(
              body: ProfilePhotoAvatar(
        name: person.fullName,
        photoUrl: person.profilePhotoUrl,
      ))),
    ));
    await tester.pumpAndSettle();
    expect(adapter.request!.uri.host, 'current.example');
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('RP'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
