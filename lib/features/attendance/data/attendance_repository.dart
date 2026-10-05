import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/storage/device_identity.dart';

/// Today's schedule (`GET /schedules/me/today`).
class TodaySchedule {
  TodaySchedule.fromJson(Json json)
      : outsideLocationAttendancePolicy =
            json.strOrNull('outsideLocationAttendancePolicy') ?? 'BLOCK',
        faceVerificationRequired = json['faceVerificationRequired'] == true,
        faceReferenceReady = json['faceReferenceReady'] == true,
        date = json.str('date'),
        timezone = json.str('timezone'),
        scheduled = json.str('status') == 'SCHEDULED',
        shiftName = json.objOrNull('shift')?.str('name'),
        officeName = json.objOrNull('shift')?.objOrNull('office')?.str('name'),
        startsAt = json.timeOrNull('startsAt'),
        endsAt = json.timeOrNull('endsAt'),
        lateAfter = json.timeOrNull('lateAfter'),
        clockInOpensAt = json.timeOrNull('clockInOpensAt'),
        clockInClosesAt = json.timeOrNull('clockInClosesAt'),
        clockOutOpensAt = json.timeOrNull('clockOutOpensAt'),
        clockOutClosesAt = json.timeOrNull('clockOutClosesAt'),
        office = json['office'] is Map
            ? AttendanceOffice.fromJson(json.obj('office'))
            : null;

  final String outsideLocationAttendancePolicy;
  final bool faceVerificationRequired;
  final bool faceReferenceReady;
  final String date;
  final String timezone;
  final bool scheduled;
  final String? shiftName;
  final String? officeName;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? lateAfter;
  final DateTime? clockInOpensAt;
  final DateTime? clockInClosesAt;
  final DateTime? clockOutOpensAt;
  final DateTime? clockOutClosesAt;

  /// Office whose geofence applies; previewed on the map, decided by the API.
  final AttendanceOffice? office;
}

class AttendanceOffice {
  AttendanceOffice.fromJson(Json json)
      : name = json.str('name'),
        latitude = (json['latitude'] as num).toDouble(),
        longitude = (json['longitude'] as num).toDouble(),
        radiusMeters = (json['radiusMeters'] as num).toDouble();

  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
}

class AttendanceAnomaly {
  AttendanceAnomaly.fromJson(Json json)
      : type = json.str('type'),
        severity = json.str('severity'),
        description = json.strOrNull('description');

  final String type;
  final String severity;
  final String? description;
}

class AttendanceRecord {
  AttendanceRecord.fromJson(Json json)
      : id = json.str('id'),
        employeeId = json.obj('employee').str('id'),
        date = json.str('date'),
        timezone = json.str('timezone'),
        status = json.str('status'),
        shiftName = json.objOrNull('shift')?.str('name'),
        officeName = json.objOrNull('office')?.str('name'),
        clockInAt = json.timeOrNull('clockInAt'),
        clockOutAt = json.timeOrNull('clockOutAt'),
        clockInDistanceM = json.numOrNull('clockInDistanceM'),
        clockOutDistanceM = json.numOrNull('clockOutDistanceM'),
        clockOutLocationValid = json['clockOutLocationValid'] as bool?,
        lateMinutes = json.intOrNull('lateMinutes') ?? 0,
        earlyLeaveMinutes = json.intOrNull('earlyLeaveMinutes') ?? 0,
        workMinutes = json.intOrNull('workMinutes'),
        isSuspicious = json['isSuspicious'] == true,
        anomalies =
            json.list('anomalies').map(AttendanceAnomaly.fromJson).toList();

  final String id;
  final String employeeId;
  final String date;
  final String timezone;
  final String status;
  final String? shiftName;
  final String? officeName;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;
  final double? clockInDistanceM;
  final double? clockOutDistanceM;
  final bool? clockOutLocationValid;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final int? workMinutes;
  final bool isSuspicious;
  final List<AttendanceAnomaly> anomalies;
}

/// Location reading sent with a clock action.
class ClockPosition {
  const ClockPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.isMocked,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final bool isMocked;
}

enum ClockAction { clockIn, clockOut }

class ClockSubmission {
  ClockSubmission.fromJson(Json json)
      : pending = json.str('status') == 'PENDING',
        record = json.str('status') == 'PENDING'
            ? null
            : AttendanceRecord.fromJson(json);
  final bool pending;
  final AttendanceRecord? record;
}

class AttendanceRepository {
  AttendanceRepository(this._api, this._device);

  final ApiClient _api;
  final DeviceIdentity _device;

  Future<TodaySchedule> today() async =>
      TodaySchedule.fromJson(data(await _api.dio.get('/schedules/me/today')));

  Future<AttendanceRecord?> todayRecord() async {
    final json = dataOrNull(await _api.dio.get('/attendance/me/today'));
    return json == null ? null : AttendanceRecord.fromJson(json);
  }

  Future<List<AttendanceRecord>> history({int limit = 31}) async => dataList(
        await _api.dio.get(
          '/attendance/me/history',
          queryParameters: {'limit': limit},
        ),
      ).map(AttendanceRecord.fromJson).toList();

  /// Attendance on [date] (`YYYY-MM-DD`) visible to the caller; managers see
  /// their direct reports.
  Future<List<AttendanceRecord>> team(String date) async => dataList(
        await _api.dio.get(
          '/attendance',
          queryParameters: {'from': date, 'to': date, 'limit': 100},
        ),
      ).map(AttendanceRecord.fromJson).toList();

  /// Uploads an image and returns its URL (`POST /files/images`).
  Future<String> uploadImage(String path) async {
    final extension = path.split('.').last.toLowerCase();
    final subtype = switch (extension) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpeg',
    };
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        path,
        contentType: DioMediaType('image', subtype),
      ),
    });
    return data(await _api.dio.post('/files/images', data: form)).str('url');
  }

  Future<ClockSubmission> clock(
    ClockAction action,
    ClockPosition position, {
    String? selfieUrl,
    String? note,
  }) async {
    final device = await _device.current();
    final path = action == ClockAction.clockIn
        ? '/attendance/clock-in'
        : '/attendance/clock-out';
    final response = await _api.dio.post(path, data: {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'isMocked': position.isMocked,
      'deviceIdentifier': device.identifier,
      if (selfieUrl != null) 'selfieUrl': selfieUrl,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return ClockSubmission.fromJson(data(response));
  }
}
