import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/async/async_value.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/time/format.dart';
import '../../../shared/widgets/state_views.dart';
import '../../shell/signed_in_scope.dart';
import '../data/attendance_repository.dart';

/// Opens the clock flow and refreshes today's status when it completes.
Future<void> openClock(BuildContext context, ClockAction action) async {
  final today = context.read<TodayCubit>();
  final done = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(builder: (_) => ClockScreen(action: action)),
  );
  if (done == true) await today.load();
}

enum _LocationProblem { serviceOff, denied, deniedForever, unavailable }

/// Location check → selfie → submit (08_MOBILE_UX_FLOWS.md, attendance).
class ClockScreen extends StatefulWidget {
  const ClockScreen({required this.action, super.key});

  final ClockAction action;

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  Position? _position;
  _LocationProblem? _locationProblem;
  bool _locating = false;
  XFile? _selfie;
  final _note = TextEditingController();
  String? _submitPhase;
  ApiFailure? _failure;

  bool get _isClockIn => widget.action == ClockAction.clockIn;
  String get _verb => _isClockIn ? 'Clock in' : 'Clock out';

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationProblem = null;
    });
    _LocationProblem? problem;
    Position? position;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        problem = _LocationProblem.serviceOff;
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) {
          problem = _LocationProblem.deniedForever;
        } else if (permission == LocationPermission.denied) {
          problem = _LocationProblem.denied;
        } else {
          // The outer timeout also covers a platform call that never returns
          // (seen when the OS location service hangs).
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 20),
            ),
          ).timeout(const Duration(seconds: 25));
        }
      }
    } catch (_) {
      problem = _LocationProblem.unavailable;
    }
    if (!mounted) return;
    setState(() {
      _locating = false;
      _position = position;
      _locationProblem = problem;
    });
  }

  Future<void> _takeSelfie() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1080,
        imageQuality: 80,
      );
      if (photo != null && mounted) setState(() => _selfie = photo);
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Camera unavailable. Allow camera access in Settings.');
      }
    }
  }

  Future<void> _submit() async {
    final position = _position;
    final selfie = _selfie;
    if (position == null || selfie == null) return;
    final repository = context.read<AttendanceRepository>();
    final navigator = Navigator.of(context);
    setState(() {
      _failure = null;
      _submitPhase = 'Uploading selfie…';
    });
    try {
      final selfieUrl = await repository.uploadImage(selfie.path);
      if (mounted) setState(() => _submitPhase = 'Recording attendance…');
      final record = await repository.clock(
        widget.action,
        ClockPosition(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          isMocked: position.isMocked,
        ),
        selfieUrl: selfieUrl,
        note: _note.text.trim(),
      );
      final done = await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => ClockResultScreen(action: widget.action, record: record),
        ),
      );
      navigator.pop(done ?? true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _failure = apiFailureOf(error);
          _submitPhase = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _submitPhase != null;
    final ready = _position != null && _selfie != null && !busy;
    return Scaffold(
      appBar: AppBar(title: Text(_verb)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _StepCard(
              index: 1,
              title: 'Your location',
              done: _position != null,
              child: _locationBody(context),
            ),
            const SizedBox(height: 12),
            _StepCard(
              index: 2,
              title: 'Selfie',
              done: _selfie != null,
              child: _selfieBody(context),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              enabled: !busy,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                counterText: '',
              ),
            ),
            if (_failure != null) ...[
              const SizedBox(height: 16),
              _FailureBanner(failure: _failure!),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: FilledButton(
          key: const Key('clock.submit'),
          onPressed: ready ? _submit : null,
          child: busy
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(_submitPhase!),
                  ],
                )
              : Text('$_verb now'),
        ),
      ),
    );
  }

  Widget _locationBody(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (_locating) {
      return Row(
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text('Finding your location…', style: muted),
        ],
      );
    }
    final problem = _locationProblem;
    if (problem != null) {
      final (message, action, onPressed) = switch (problem) {
        _LocationProblem.serviceOff => (
            'Location is turned off. Turn it on to record attendance.',
            'Open location settings',
            () async {
              await Geolocator.openLocationSettings();
            },
          ),
        _LocationProblem.denied => (
            'Knect needs your location to confirm you are at the office.',
            'Allow location',
            _locate,
          ),
        _LocationProblem.deniedForever => (
            'Location access is blocked. Allow it in app settings.',
            'Open app settings',
            () async {
              await Geolocator.openAppSettings();
            },
          ),
        _LocationProblem.unavailable => (
            'Could not get a GPS fix. Move to an open area and retry.',
            'Retry',
            _locate,
          ),
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(onPressed: onPressed, child: Text(action)),
              if (problem != _LocationProblem.unavailable &&
                  problem != _LocationProblem.denied)
                TextButton(onPressed: _locate, child: const Text('Check again')),
            ],
          ),
        ],
      );
    }
    final position = _position!;
    final weak = position.accuracy > 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Accuracy ±${position.accuracy.round()} m',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            TextButton.icon(
              onPressed: _submitPhase == null ? _locate : null,
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
        Text(
          '${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)}',
          style: muted,
        ),
        if (weak || position.isMocked) ...[
          const SizedBox(height: 8),
          _Hint(
            weak
                ? 'Weak GPS signal. Move near a window and refresh for a better fix.'
                : 'A mock location app is active. This attendance will be flagged for review.',
          ),
        ],
      ],
    );
  }

  Widget _selfieBody(BuildContext context) {
    final theme = Theme.of(context);
    final selfie = _selfie;
    if (selfie == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Take a clear photo of your face as attendance evidence.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('clock.selfie'),
            onPressed: _takeSelfie,
            icon: const Icon(Icons.photo_camera_front_outlined),
            label: const Text('Take selfie'),
          ),
        ],
      );
    }
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(selfie.path),
            width: 88,
            height: 88,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 16),
        TextButton.icon(
          onPressed: _submitPhase == null ? _takeSelfie : null,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Retake'),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.index,
    required this.title,
    required this.done,
    required this.child,
  });

  final int index;
  final String title;
  final bool done;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor:
                      done ? colors.primary : colors.surfaceContainerHighest,
                  child: done
                      ? Icon(Icons.check, size: 14, color: colors.onPrimary)
                      : Text(
                          '$index',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Text(title, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 18, color: theme.colorScheme.tertiary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failure});

  final ApiFailure failure;

  String get _message {
    final details = failure.details;
    return switch (failure.code) {
      'ATTENDANCE_OUTSIDE_GEOFENCE' =>
        'You are ${details['distanceFromOfficeMeters']} m from '
            '${details['office'] ?? 'the office'}. Move within '
            '${details['allowedRadiusMeters']} m and try again.',
      'FILE_INVALID' => 'The selfie could not be uploaded. Retake it and try again.',
      _ => failureMessage(failure),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_message, style: TextStyle(color: colors.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

/// Confirmation after a successful clock action.
class ClockResultScreen extends StatelessWidget {
  const ClockResultScreen({required this.action, required this.record, super.key});

  final ClockAction action;
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final clockIn = action == ClockAction.clockIn;
    final at = clockIn ? record.clockInAt : record.clockOutAt;
    final distance = clockIn ? record.clockInDistanceM : record.clockOutDistanceM;
    final outside = !clockIn && record.clockOutLocationValid == false;

    final (tone, statusLabel) = clockIn
        ? record.lateMinutes > 0
            ? (StatusTone.warning, 'Late ${Clock.duration(record.lateMinutes)}')
            : (StatusTone.success, 'On time')
        : record.earlyLeaveMinutes > 0
            ? (StatusTone.warning, 'Left ${Clock.duration(record.earlyLeaveMinutes)} early')
            : (StatusTone.success, 'Shift complete');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, true);
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    Icons.check_rounded,
                    size: 44,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  clockIn ? 'You are clocked in' : 'You are clocked out',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  at == null
                      ? Clock.date(record.date)
                      : '${Clock.hm(at, record.timezone)} · ${Clock.date(record.date)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                StatusChip(statusLabel, tone: tone),
                const SizedBox(height: 28),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      if (record.officeName != null)
                        ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(record.officeName!),
                          subtitle: distance == null
                              ? null
                              : Text(
                                  outside
                                      ? '${distance.round()} m away · outside the office area'
                                      : '${distance.round()} m from the office',
                                ),
                        ),
                      if (!clockIn && record.workMinutes != null)
                        ListTile(
                          leading: const Icon(Icons.timelapse_outlined),
                          title: Text(Clock.duration(record.workMinutes!)),
                          subtitle: const Text('Worked today'),
                        ),
                      for (final anomaly in record.anomalies)
                        ListTile(
                          leading: Icon(Icons.flag_outlined, color: colors.tertiary),
                          title: const Text('Flagged for review'),
                          subtitle: Text(anomaly.description ?? anomaly.type),
                        ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
