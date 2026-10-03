import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Identifies this app installation so the API can bind sessions to a device.
class DeviceInfo {
  const DeviceInfo({required this.identifier, required this.platform});

  final String identifier;

  /// `ANDROID` or `IOS`, as accepted by `POST /auth/login`.
  final String platform;

  Map<String, Object?> toJson() => {
        'identifier': identifier,
        'platform': platform,
      };
}

abstract interface class DeviceIdentity {
  Future<DeviceInfo> current();
}

/// Generates a random installation identifier once and keeps it in secure
/// storage. It is not a hardware identifier and resets on reinstall.
class SecureDeviceIdentity implements DeviceIdentity {
  SecureDeviceIdentity({FlutterSecureStorage? storage, Random? random})
      : _storage = storage ?? const FlutterSecureStorage(),
        _random = random ?? Random.secure();

  static const _key = 'device.installation_id';

  final FlutterSecureStorage _storage;
  final Random _random;
  String? _cached;

  @override
  Future<DeviceInfo> current() async {
    final identifier = _cached ??= await _readOrCreate();
    return DeviceInfo(identifier: identifier, platform: platformName());
  }

  Future<String> _readOrCreate() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = uuidV4(_random);
    await _storage.write(key: _key, value: created);
    return created;
  }

  @visibleForTesting
  static String platformName([TargetPlatform? platform]) {
    return switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.iOS => 'IOS',
      _ => 'ANDROID',
    };
  }
}

/// RFC 4122 version 4 UUID from a secure random source.
String uuidV4(Random random) {
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
