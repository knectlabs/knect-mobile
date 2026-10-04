import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../firebase_options.dart';
import '../network/api_client.dart';
import '../storage/device_identity.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

typedef ForegroundNotificationHandler = void Function(RemoteMessage message);
typedef OpenNotificationHandler = void Function(RemoteMessage message);

/// Connects FCM delivery to the authenticated device; the API notification
/// record remains the source of truth for Inbox state and read status.
class FirebaseNotifications {
  FirebaseNotifications({
    required ApiClient api,
    required DeviceIdentity deviceIdentity,
    FirebaseMessaging? messaging,
  })  : _api = api,
        _deviceIdentity = deviceIdentity,
        _messaging = messaging ?? FirebaseMessaging.instance;

  final ApiClient _api;
  final DeviceIdentity _deviceIdentity;
  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  ForegroundNotificationHandler? _onForeground;
  OpenNotificationHandler? _onOpened;
  bool _started = false;

  void setHandlers({
    required ForegroundNotificationHandler onForeground,
    required OpenNotificationHandler onOpened,
  }) {
    _onForeground = onForeground;
    _onOpened = onOpened;
  }

  Future<void> start() async {
    if (_started) {
      await _registerCurrentToken();
      return;
    }
    _started = true;
    final permission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus == AuthorizationStatus.denied) return;

    _foreground = FirebaseMessaging.onMessage.listen((message) {
      _onForeground?.call(message);
    });
    _opened = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _onOpened?.call(message);
    });
    _tokenRefresh = _messaging.onTokenRefresh.listen((token) {
      unawaited(_register(token));
    });
    try {
      await _registerCurrentToken();
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _onOpened?.call(initial);
    } catch (_) {
      // The app session remains usable when Firebase or the network is down.
    }
  }

  Future<void> unregister() async {
    final device = await _deviceIdentity.current();
    try {
      await _api.dio.post<void>(
        '/auth/devices/push-token/remove',
        data: {'deviceIdentifier': device.identifier},
      );
    } on DioException {
      // A later authenticated token registration replaces any stale token.
    } finally {
      await _cancelSubscriptions();
      _started = false;
    }
  }

  Future<void> dispose() async {
    await _cancelSubscriptions();
  }

  Future<void> _cancelSubscriptions() async {
    await _tokenRefresh?.cancel();
    await _foreground?.cancel();
    await _opened?.cancel();
    _tokenRefresh = null;
    _foreground = null;
    _opened = null;
  }

  Future<void> _registerCurrentToken() async {
    final token = await _messaging.getToken();
    if (token != null) await _register(token);
  }

  Future<void> _register(String token) async {
    final device = await _deviceIdentity.current();
    try {
      await _api.dio.post<void>(
        '/auth/devices/push-token',
        data: {'deviceIdentifier': device.identifier, 'token': token},
      );
    } on DioException {
      // FCM token delivery is retried on the next refresh or app start.
    }
  }
}
