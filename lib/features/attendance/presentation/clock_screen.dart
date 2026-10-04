import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../core/async/async_value.dart';
import '../../../core/brand/brand.dart';
import '../../../core/geo/distance.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/time/format.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/application/auth_cubit.dart';
import '../../shell/signed_in_scope.dart';
import '../data/attendance_repository.dart';

/// Opens the clock flow and refreshes today's status when it completes.
Future<void> openClock(BuildContext context, ClockAction action) async {
  final today = context.read<TodayCubit>();
  final schedule = today.state.valueOrPrevious?.schedule;
  if (schedule == null) return;
  final done = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(
      builder: (_) => ClockLocationScreen(action: action, schedule: schedule),
    ),
  );
  if (done == true) await today.load();
}

String _verb(ClockAction action) =>
    action == ClockAction.clockIn ? 'Clock in' : 'Clock out';

/* Shared chrome */

const _headerColor = BrandColors.darkPurple;

PreferredSizeWidget _stepAppBar(
  ClockAction action,
  int step, {
  List<Widget>? actions,
}) {
  return AppBar(
    backgroundColor: _headerColor,
    foregroundColor: Colors.white,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    centerTitle: true,
    title: Column(
      children: [
        Text(
          _verb(action),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        Text(
          'Step $step of 2',
          style: TextStyle(
              fontSize: 12, color: Colors.white.withValues(alpha: 0.75)),
        ),
      ],
    ),
    actions: actions,
  );
}

/// Shift and date on the brand band under the app bar.
class _ScheduleBand extends StatelessWidget {
  const _ScheduleBand({required this.schedule});

  final TodaySchedule schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tz = schedule.timezone;
    final times = schedule.startsAt == null || schedule.endsAt == null
        ? ''
        : ' (${Clock.hm(schedule.startsAt!, tz)} - ${Clock.hm(schedule.endsAt!, tz)})';
    return ColoredBox(
      color: _headerColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  schedule.shiftName ?? 'Shift',
                  schedule.office?.name ?? schedule.officeName
                ].whereType<String>().join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    '${Clock.shortDate(schedule.date)} ${schedule.date.substring(0, 4)}$times',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SizedBox(width: double.infinity, child: child),
      );
}

/* Step 1: location */

enum _LocationProblem { serviceOff, denied, deniedForever, unavailable }

class ClockLocationScreen extends StatefulWidget {
  const ClockLocationScreen(
      {required this.action, required this.schedule, super.key});

  final ClockAction action;
  final TodaySchedule schedule;

  @override
  State<ClockLocationScreen> createState() => _ClockLocationScreenState();
}

class _ClockLocationScreenState extends State<ClockLocationScreen> {
  final _map = MapController();
  Position? _position;
  _LocationProblem? _problem;
  bool _locating = false;

  AttendanceOffice? get _office => widget.schedule.office;

  double? get _distance {
    final position = _position;
    final office = _office;
    if (position == null || office == null) return null;
    return distanceMeters(position.latitude, position.longitude,
        office.latitude, office.longitude);
  }

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _problem = null;
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
      _problem = problem;
    });
    if (position != null) _fitCamera();
  }

  void _fitCamera() {
    final points = [
      if (_position != null) LatLng(_position!.latitude, _position!.longitude),
      if (_office != null) LatLng(_office!.latitude, _office!.longitude),
    ];
    if (points.isEmpty) return;
    try {
      if (points.length == 1 || (_distance ?? 0) < 150) {
        _map.move(points.first, 17);
      } else {
        _map.fitCamera(CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(72),
          maxZoom: 17,
        ));
      }
    } catch (_) {
      // Map not laid out yet; its initial camera already covers the points.
    }
  }

  Future<void> _next() async {
    final distance = _distance;
    final office = _office;
    String? note;
    if (distance != null && office != null && distance > office.radiusMeters) {
      final result = await showModalBottomSheet<_OutOfRangeResult>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _OutOfRangeSheet(
          action: widget.action,
          distance: distance,
          office: office,
        ),
      );
      if (!mounted || result == null) return;
      if (result.recheck) {
        unawaited(_locate());
        return;
      }
      note = result.note;
    }
    final navigator = Navigator.of(context);
    final record = await navigator.push<AttendanceRecord>(
      MaterialPageRoute(
        builder: (_) => ClockSelfieScreen(
          action: widget.action,
          schedule: widget.schedule,
          position: _position!,
          outsideNote: note,
        ),
      ),
    );
    if (record != null && mounted) {
      unawaited(navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              ClockResultScreen(action: widget.action, record: record),
        ),
        result: true,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _stepAppBar(widget.action, 1, actions: [
        IconButton(
          tooltip: 'Refresh location',
          onPressed: _locating ? null : _locate,
          icon: const Icon(Icons.refresh),
        ),
      ]),
      body: Column(
        children: [
          _ScheduleBand(schedule: widget.schedule),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _buildMap(context)),
                if (_problem != null || _locating)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    child: _LocationStatusCard(
                      locating: _locating,
                      problem: _problem,
                      onRetry: _locate,
                    ),
                  ),
                if (_position != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    // Clear of the map attribution line.
                    bottom: 40,
                    child: _LocationSummary(
                      position: _position!,
                      distance: _distance,
                      office: _office,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomAction(
        child: FilledButton(
          key: const Key('clock.next'),
          onPressed: _position == null || _locating ? null : _next,
          child: const Text('Next'),
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final office = _office;
    final position = _position;
    final officePoint =
        office == null ? null : LatLng(office.latitude, office.longitude);
    final userPoint =
        position == null ? null : LatLng(position.latitude, position.longitude);
    final center = userPoint ?? officePoint;
    if (center == null) {
      return ColoredBox(
        color: colors.surfaceContainerHigh,
        child: Center(
          child: Icon(Icons.map_outlined,
              size: 48, color: colors.onSurfaceVariant),
        ),
      );
    }
    final user = context.read<AuthCubit>().state.user;
    final profile = context.read<ProfileCubit>().state.valueOrPrevious;
    final name = profile?.fullName ?? user?.email ?? '?';
    final initials = name
        .split(RegExp(r'[\s@.]'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 17,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.knect.mobile',
        ),
        if (officePoint != null)
          CircleLayer(circles: [
            CircleMarker(
              point: officePoint,
              radius: office!.radiusMeters,
              useRadiusInMeter: true,
              color: BrandColors.primaryViolet.withValues(alpha: 0.14),
              borderColor: BrandColors.primaryViolet,
              borderStrokeWidth: 1.5,
            ),
          ]),
        MarkerLayer(markers: [
          if (officePoint != null)
            Marker(
              point: officePoint,
              width: 36,
              height: 36,
              alignment: Alignment.topCenter,
              child: const Icon(Icons.location_on,
                  size: 36, color: BrandColors.deepViolet),
            ),
          if (userPoint != null)
            Marker(
              point: userPoint,
              width: 48,
              height: 48,
              child: _Avatar(initials: initials),
            ),
        ]),
        const SimpleAttributionWidget(
            source: Text('OpenStreetMap contributors')),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: BrandColors.brandGradient,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _LocationStatusCard extends StatelessWidget {
  const _LocationStatusCard({
    required this.locating,
    required this.problem,
    required this.onRetry,
  });

  final bool locating;
  final _LocationProblem? problem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (locating) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Finding your location…', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }
    final (message, action, onPressed) = switch (problem!) {
      _LocationProblem.serviceOff => (
          'Location is turned off. Turn it on to record attendance.',
          'Open location settings',
          () => Geolocator.openLocationSettings(),
        ),
      _LocationProblem.denied => (
          'Knect needs your location to confirm you are at the office.',
          'Allow location',
          () async => onRetry(),
        ),
      _LocationProblem.deniedForever => (
          'Location access is blocked. Allow it in app settings.',
          'Open app settings',
          () => Geolocator.openAppSettings(),
        ),
      _LocationProblem.unavailable => (
          'Could not get a GPS fix. Move to an open area and retry.',
          'Retry',
          () async => onRetry(),
        ),
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_off_outlined,
                    color: theme.colorScheme.error),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(message, style: theme.textTheme.bodyMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onPressed, child: Text(action)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationSummary extends StatelessWidget {
  const _LocationSummary(
      {required this.position, required this.distance, required this.office});

  final Position position;
  final double? distance;
  final AttendanceOffice? office;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inside =
        distance != null && office != null && distance! <= office!.radiusMeters;
    final warnings = [
      if (position.accuracy > 100)
        'Weak GPS signal (±${position.accuracy.round()} m)',
      if (position.isMocked) 'Mock location detected; this will be flagged',
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  distance == null
                      ? Icons.my_location
                      : inside
                          ? Icons.check_circle
                          : Icons.error_outline,
                  size: 20,
                  color: distance == null
                      ? theme.colorScheme.primary
                      : inside
                          ? const Color(0xFF1F8A5B)
                          : theme.colorScheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    distance == null
                        ? 'Location found · ±${position.accuracy.round()} m'
                        : inside
                            ? 'You are in the office area'
                            : '${formatDistance(distance!)} from ${office!.name}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            for (final warning in warnings)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 30),
                child: Text(
                  warning,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.tertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* Out of range */

class _OutOfRangeResult {
  const _OutOfRangeResult.recheck()
      : recheck = true,
        note = null;
  const _OutOfRangeResult.proceed(this.note) : recheck = false;

  final bool recheck;
  final String? note;
}

class _OutOfRangeSheet extends StatefulWidget {
  const _OutOfRangeSheet(
      {required this.action, required this.distance, required this.office});

  final ClockAction action;
  final double distance;
  final AttendanceOffice office;

  @override
  State<_OutOfRangeSheet> createState() => _OutOfRangeSheetState();
}

class _OutOfRangeSheetState extends State<_OutOfRangeSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Clock-out outside the area is accepted and flagged for review; clock-in
    // outside it is rejected by the API.
    final canContinue = widget.action == ClockAction.clockOut;
    final where =
        '${formatDistance(widget.distance)} from ${widget.office.name}';
    final radius = formatDistance(widget.office.radiusMeters);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 0, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
                const SizedBox(width: 4),
                Text('You are out of range',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wrong_location_outlined,
                    size: 48, color: theme.colorScheme.error),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              canContinue
                  ? 'You are $where. You can still clock out with a note; '
                      'it will be flagged for your supervisor to review.'
                  : 'You are $where. Clock in is only allowed within $radius '
                      'of the office. Move closer and check again.',
              style: theme.textTheme.bodyMedium,
            ),
            if (canContinue) ...[
              const SizedBox(height: 16),
              TextField(
                key: const Key('clock.outsideNote'),
                controller: _note,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Notes *',
                  hintText: 'e.g. Meeting at the client office',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (canContinue)
              FilledButton(
                onPressed: _note.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(
                        context, _OutOfRangeResult.proceed(_note.text.trim())),
                child: const Text('Continue clock out'),
              )
            else
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, const _OutOfRangeResult.recheck()),
                child: const Text('Recheck location'),
              ),
            if (canContinue) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, const _OutOfRangeResult.recheck()),
                child: const Text('Recheck location'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/* Step 2: selfie */

class ClockSelfieScreen extends StatefulWidget {
  const ClockSelfieScreen({
    required this.action,
    required this.schedule,
    required this.position,
    this.outsideNote,
    super.key,
  });

  final ClockAction action;
  final TodaySchedule schedule;
  final Position position;

  /// Set when continuing outside the office area; notes are then required.
  final String? outsideNote;

  @override
  State<ClockSelfieScreen> createState() => _ClockSelfieScreenState();
}

class _ClockSelfieScreenState extends State<ClockSelfieScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  String? _cameraError;
  late final _note = TextEditingController(text: widget.outsideNote);
  String? _phase;
  ApiFailure? _failure;

  bool get _noteRequired => widget.outsideNote != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (state == AppLifecycleState.inactive && camera != null) {
      _camera = null;
      camera.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    setState(() => _cameraError = null);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('NoCamera', null);
      final front = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() => _cameraError = switch (error.code) {
            'CameraAccessDenied' ||
            'CameraAccessDeniedWithoutPrompt' ||
            'CameraAccessRestricted' =>
              'Camera access is blocked. Allow it in app settings to take a selfie.',
            'NoCamera' => 'No camera found on this device.',
            _ => 'The camera could not start. Try again.',
          });
    }
  }

  Future<void> _submit() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _phase != null) return;
    final note = _note.text.trim();
    if (_noteRequired && note.isEmpty) {
      setState(() => _failure = const ApiFailure(
            kind: ApiFailureKind.unknown,
            code: 'NOTE_REQUIRED',
            message:
                'Add a note explaining why you are outside the office area.',
          ));
      return;
    }
    final repository = context.read<AttendanceRepository>();
    final navigator = Navigator.of(context);
    setState(() {
      _failure = null;
      _phase = 'Taking photo…';
    });
    try {
      final photo = await camera.takePicture();
      if (mounted) setState(() => _phase = 'Uploading selfie…');
      final selfieUrl = await repository.uploadImage(photo.path);
      if (mounted) setState(() => _phase = 'Recording attendance…');
      final position = widget.position;
      final record = await repository.clock(
        widget.action,
        ClockPosition(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          isMocked: position.isMocked,
        ),
        selfieUrl: selfieUrl,
        note: note,
      );
      navigator.pop(record);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = null;
        _failure = error is CameraException
            ? const ApiFailure(
                kind: ApiFailureKind.unknown,
                code: 'CAMERA',
                message: 'The photo could not be taken. Try again.',
              )
            : apiFailureOf(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _phase != null;
    return Scaffold(
      appBar: _stepAppBar(widget.action, 2),
      body: Column(
        children: [
          _ScheduleBand(schedule: widget.schedule),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _preview(context)),
                if (_camera != null)
                  const Positioned.fill(
                    child: IgnorePointer(
                        child: CustomPaint(painter: _FaceGuidePainter())),
                  ),
              ],
            ),
          ),
          Material(
            color: theme.colorScheme.surfaceContainerLowest,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('clock.note'),
                    controller: _note,
                    enabled: !busy,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: _noteRequired ? 'Notes *' : 'Notes (optional)',
                      prefixIcon: const Icon(Icons.notes),
                      counterText: '',
                    ),
                  ),
                  if (_failure != null) ...[
                    const SizedBox(height: 10),
                    _FailureText(failure: _failure!),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('clock.submit'),
                    onPressed: _camera == null || busy ? null : _submit,
                    child: busy
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Text(_phase!),
                            ],
                          )
                        : const Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final camera = _camera;
    if (camera != null && camera.value.isInitialized) {
      final size = camera.value.previewSize;
      return ColoredBox(
        color: Colors.black,
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              // previewSize is landscape; the UI is portrait.
              width: size?.height ?? 720,
              height: size?.width ?? 1280,
              child: CameraPreview(camera),
            ),
          ),
        ),
      );
    }
    final error = _cameraError;
    return ColoredBox(
      color: const Color(0xFF2A2638),
      child: Center(
        child: error == null
            ? const CircularProgressIndicator(color: Colors.white)
            : Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_outlined,
                        color: Colors.white, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          onPressed: _startCamera,
                          child: const Text('Try again'),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.white),
                          onPressed: Geolocator.openAppSettings,
                          child: const Text('App settings'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Dashed oval that frames the face.
class _FaceGuidePainter extends CustomPainter {
  const _FaceGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width * 0.62;
    final height = width * 1.32;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.46),
      width: width,
      height: height,
    );
    // Dim everything outside the oval.
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addOval(rect),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final metric in (Path()..addOval(rect)).computeMetrics()) {
      for (double d = 0; d < metric.length; d += 22) {
        canvas.drawPath(metric.extractPath(d, d + 12), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FailureText extends StatelessWidget {
  const _FailureText({required this.failure});

  final ApiFailure failure;

  @override
  Widget build(BuildContext context) {
    final details = failure.details;
    final message = switch (failure.code) {
      'ATTENDANCE_OUTSIDE_GEOFENCE' =>
        'You are ${formatDistance((details['distanceFromOfficeMeters'] as num? ?? 0).toDouble())} from '
            '${details['office'] ?? 'the office'}. Go back, move within '
            '${details['allowedRadiusMeters']} m, and check again.',
      'FILE_INVALID' => 'The selfie could not be uploaded. Try again.',
      'NOTE_REQUIRED' || 'CAMERA' => failure.message,
      _ => failureMessage(failure),
    };
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
    );
  }
}

/* Result */

/// Confirmation after a successful clock action.
class ClockResultScreen extends StatelessWidget {
  const ClockResultScreen(
      {required this.action, required this.record, super.key});

  final ClockAction action;
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final clockIn = action == ClockAction.clockIn;
    final at = clockIn ? record.clockInAt : record.clockOutAt;
    final distance =
        clockIn ? record.clockInDistanceM : record.clockOutDistanceM;
    final outside = !clockIn && record.clockOutLocationValid == false;

    final (tone, statusLabel) = clockIn
        ? record.lateMinutes > 0
            ? (StatusTone.warning, 'Late ${Clock.duration(record.lateMinutes)}')
            : (StatusTone.success, 'On time')
        : record.earlyLeaveMinutes > 0
            ? (
                StatusTone.warning,
                'Left ${Clock.duration(record.earlyLeaveMinutes)} early'
              )
            : (StatusTone.success, 'Shift complete');

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              CircleAvatar(
                radius: 40,
                backgroundColor: colors.primaryContainer,
                child: Icon(Icons.check_rounded,
                    size: 44, color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: 20),
              Text(
                clockIn ? 'You are clocked in' : 'You are clocked out',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                at == null
                    ? Clock.date(record.date)
                    // Calendar date of the action itself; an overnight shift's
                    // business date can be the day before.
                    : '${Clock.hm(at, record.timezone)} · '
                        '${Clock.date(Clock.toZone(at, record.timezone))}',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: colors.onSurfaceVariant),
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
                                    ? '${formatDistance(distance)} away · outside the office area'
                                    : '${formatDistance(distance)} from the office',
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
                        leading:
                            Icon(Icons.flag_outlined, color: colors.tertiary),
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
    );
  }
}
