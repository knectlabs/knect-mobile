import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:knect_mobile/features/attendance/data/attendance_repository.dart';
import 'package:knect_mobile/features/attendance/presentation/clock_screen.dart';
import 'package:knect_mobile/core/config/app_config.dart';
import 'package:knect_mobile/core/network/api_client.dart';
import 'package:knect_mobile/core/theme/knect_tokens.dart';
import 'package:knect_mobile/features/announcements/presentation/announcement_detail_screen.dart';
import 'package:knect_mobile/features/auth/application/auth_cubit.dart';
import 'package:knect_mobile/features/auth/domain/auth_models.dart';
import 'package:knect_mobile/main.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_token_storage.dart';

class _Fixtures implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final Object? value = switch (options.path) {
      '/employees/me' => {
          'id': 'employee-1',
          'employeeCode': 'KN-001',
          'fullName': 'Rina Putri',
          'email': testUser.email,
          'joinDate': '2026-10-01',
          'status': 'ACTIVE'
        },
      '/schedules/me/today' => {
          'date': '2026-10-06',
          'timezone': 'Asia/Jakarta',
          'status': 'SCHEDULED',
          'startsAt': '2026-10-06T02:00:00Z',
          'endsAt': '2026-10-06T10:00:00Z',
          'shift': {'name': 'Regular Shift'},
          'faceVerificationRequired': true,
          'faceReferenceReady': true
        },
      '/attendance/me/today' => null,
      '/notifications/me/unread-count' => {'unread': 0},
      '/announcements' => [
          {
            'id': 'announcement-1',
            'title': 'Welcome to your workday',
            'body':
                'Company updates are now in one place.\n\nPlease review your schedule and submit requests from the Requests tab.',
            'status': 'PUBLISHED',
            'authorName': 'People Team',
            'createdAt': '2026-10-06T01:00:00Z'
          }
        ],
      _ => <Object>[],
    };
    return ResponseBody.fromString(jsonEncode({'data': value}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }
}

Future<void> _pump(WidgetTester tester, {bool signedIn = true}) async {
  final repository = FakeAuthRepository(stored: signedIn)
    ..user = CurrentUser(
        id: 'manager-1',
        email: 'rina.putri@acme.test',
        role: UserRole.manager,
        organization: testUser.organization);
  final auth = AuthCubit(repository);
  await auth.restoreSession();
  final config = AppConfig.fromEnvironment(
      environmentName: 'development',
      apiBaseUrl: 'http://localhost:3000/api/v1');
  final dio = Dio()..httpClientAdapter = _Fixtures();
  await tester.pumpWidget(RepaintBoundary(
      key: const Key('visual.capture'),
      child: KnectApp(
          config: config,
          apiClient: ApiClient(
              config: config, tokenStorage: FakeTokenStorage(), dio: dio),
          authRepository: repository,
          authCubit: auth)));
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (Platform.environment['KNECT_CAPTURE_UI'] != '1') return;
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('visual.capture')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('.agents/tasks/mobile-visual-system');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    for (final pair in [
      ('Roboto', 'KNECT_UI_FONT'),
      ('MaterialIcons', 'KNECT_UI_ICON_FONT')
    ]) {
      final path = Platform.environment[pair.$2];
      if (path == null) continue;
      final loader = FontLoader(pair.$1)
        ..addFont(File(path)
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)));
      await loader.load();
    }
  });
  for (final size in [(390.0, 1.0), (320.0, 1.0), (320.0, 1.3)]) {
    final (width, scale) = size;
    testWidgets('priority screens build at width $width and text scale $scale',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(tester);
      expect(find.text('Rina Putri'), findsOneWidget);
      expect(Theme.of(tester.element(find.text('Rina Putri'))).brightness,
          Brightness.light);
      expect(tester.takeException(), isNull);
      await _capture(tester, 'home-$width');
      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();
      expect(find.text('Need My Approval'), findsOneWidget);
      expect(find.text('No notifications'), findsOneWidget);
      await _capture(tester, 'inbox-$width');
      await tester.tap(find.text('Need My Approval'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Request', skipOffstage: false).last);
      await tester.pumpAndSettle();
      expect(find.text('Approval inbox'), findsOneWidget);
      await _capture(tester, 'requests-$width');
      await tester.tap(find.byKey(const Key('requests.new')));
      await tester.pumpAndSettle();
      expect(find.text('Attendance correction'), findsOneWidget);
      await tester.tap(find.text('Overtime').last);
      await tester.pumpAndSettle();
      expect(find.text('Request overtime'), findsOneWidget);
      expect(find.byKey(const Key('request.submit')), findsOneWidget);
      await _capture(tester, 'overtime-form-$width');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Personal Info'), findsOneWidget);
      expect(find.byKey(const Key('profile.signOut')), findsOneWidget);
      await _capture(tester, 'account-$width');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Welcome to your workday'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Welcome to your workday'));
      await tester.pumpAndSettle();
      expect(find.byType(AnnouncementDetailScreen), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      await _capture(tester, 'announcement-$width');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('attendance location and selfie error states use light chrome',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const camera = MethodChannel('plugins.flutter.io/camera');
    const location = MethodChannel('flutter.baseflow.com/geolocator');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        camera, (call) async => call.method == 'availableCameras' ? [] : null);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        location,
        (call) async =>
            call.method == 'isLocationServiceEnabled' ? false : null);
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(camera, null);
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(location, null);
    });
    await _pump(tester);
    final schedule = TodaySchedule.fromJson({
      'date': '2026-10-06',
      'timezone': 'Asia/Jakarta',
      'status': 'SCHEDULED',
      'startsAt': '2026-10-06T02:00:00Z',
      'endsAt': '2026-10-06T10:00:00Z',
      'shift': {'name': 'Regular Shift'},
      'faceVerificationRequired': true,
      'faceReferenceReady': true
    });
    final navigator = Navigator.of(
        tester.element(find.byKey(const Key('home.name'))),
        rootNavigator: true);
    navigator.push(MaterialPageRoute<void>(
        builder: (_) => ClockLocationScreen(
            action: ClockAction.clockIn, schedule: schedule)));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'attendance-location');
    navigator.pop();
    await tester.pumpAndSettle();
    navigator.push(MaterialPageRoute<void>(
        builder: (_) => ClockSelfieScreen(
            action: ClockAction.clockIn,
            schedule: schedule,
            position: Position(
                latitude: -6.2,
                longitude: 106.8,
                timestamp: DateTime.now(),
                accuracy: 5,
                altitude: 0,
                heading: 0,
                speed: 0,
                speedAccuracy: 0,
                altitudeAccuracy: 0,
                headingAccuracy: 0))));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 2'), findsOneWidget);
    expect(find.text('No camera found on this device.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'attendance-selfie');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('normal text and primary action labels meet AA contrast', () {
    for (final (foreground, background) in [
      (KnectColors.surface, KnectColors.strongPrimary),
      (KnectColors.textPrimary, KnectColors.background),
      (KnectColors.textSecondary, KnectColors.surface),
      (KnectColors.mutedText, KnectColors.lilacSurface),
    ]) {
      final a = foreground.computeLuminance();
      final b = background.computeLuminance();
      expect(((a > b ? a : b) + 0.05) / ((a > b ? b : a) + 0.05),
          greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('sign in follows the device dark mode', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await _pump(tester, signedIn: false);
    expect(
        Theme.of(tester.element(find.text('Sign in to your account')))
            .brightness,
        Brightness.dark);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'login');
  });
}
