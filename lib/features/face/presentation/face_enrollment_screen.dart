import '../../../core/theme/knect_tokens.dart';
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/async/async_value.dart';
import '../../../core/network/api_client.dart';
import '../../../core/time/format.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/face_enrollment_cubit.dart';
import '../data/face_embedder.dart';
import '../data/face_repository.dart';

/// Entry point for the Face verification screen, wired with its own embedder,
/// repository, and cubit so it can be pushed from anywhere (e.g. profile). Owns
/// the ML Kit embedder's lifecycle so the native detector is released on close.
class FaceEnrollmentPage extends StatefulWidget {
  const FaceEnrollmentPage({super.key});

  @override
  State<FaceEnrollmentPage> createState() => _FaceEnrollmentPageState();
}

class _FaceEnrollmentPageState extends State<FaceEnrollmentPage> {
  final _embedder = MlKitFaceEmbedder();

  @override
  void dispose() {
    unawaited(_embedder.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    return BlocProvider(
      create: (_) => FaceEnrollmentCubit(_embedder, FaceRepository(api)),
      child: const FaceEnrollmentScreen(),
    );
  }
}

/// Captures a reference selfie, embeds it, and enrolls it for 1:1 attendance
/// face verification. No liveness or anti-spoofing UI — detection + crop only.
class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  String? _cameraError;

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

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    final cubit = context.read<FaceEnrollmentCubit>();
    if (cubit.state.isBusy) return;
    try {
      final photo = await camera.takePicture();
      await cubit.submit(photo.path);
    } on CameraException {
      if (mounted) {
        showMessage(context, 'The photo could not be taken. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face verification')),
      body: BlocConsumer<FaceEnrollmentCubit, FaceEnrollmentState>(
        listenWhen: (previous, current) =>
            previous.stage != current.stage ||
            previous.noFaceDetected != current.noFaceDetected ||
            previous.actionFailure != current.actionFailure,
        listener: (context, state) {
          if (state.noFaceDetected) {
            showMessage(context,
                'No face detected. Center your face in the frame and try again.');
          } else if (state.actionFailure != null) {
            showMessage(context, failureMessage(state.actionFailure!));
          } else if (state.stage == FaceEnrollmentStage.success) {
            showMessage(context, 'Face enrolled. You are all set.');
            context.read<FaceEnrollmentCubit>().acknowledge();
          }
        },
        builder: (context, state) {
          if (state.status == null && state.loadFailure != null) {
            return ErrorView(
              message: failureMessage(state.loadFailure!),
              onRetry: () => context.read<FaceEnrollmentCubit>().load(),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _StatusCard(status: state.status),
              const SizedBox(height: 16),
              _CameraCard(
                controller: _camera,
                error: _cameraError,
                onRetry: _startCamera,
              ),
              const SizedBox(height: 16),
              _ActionBar(
                state: state,
                cameraReady: _camera != null && _cameraError == null,
                onCapture: _capture,
                onReset: () => context.read<FaceEnrollmentCubit>().reset(),
              ),
              const SizedBox(height: 16),
              Text(
                'Your selfie is matched only against your own enrolled face '
                'when you clock in or out. The match decision is made on the '
                'server.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final FaceStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (status == null) {
      return const Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Checking enrollment…'),
        ),
      );
    }
    final enrolled = status!.enrolled;
    final lastAt = status!.lastEnrolledAt;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          enrolled ? Icons.verified_user : Icons.no_accounts,
          color: enrolled
              ? KnectColors.success
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(enrolled ? 'Face enrolled' : 'Not enrolled yet'),
        subtitle: Text(
          enrolled
              ? '${status!.activeCount} reference${status!.activeCount == 1 ? '' : 's'}'
                  '${lastAt == null ? '' : ' · last ${Clock.date(lastAt)}'}'
              : 'Enroll a reference selfie to use face verification.',
        ),
        trailing: enrolled
            ? const StatusChip('Active', tone: StatusTone.success)
            : null,
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({
    required this.controller,
    required this.error,
    required this.onRetry,
  });

  final CameraController? controller;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainerHigh,
          child: Builder(
            builder: (context) {
              if (error != null) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_camera_front_outlined,
                          size: 40, color: theme.colorScheme.error),
                      const SizedBox(height: 12),
                      Text(error!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              if (controller == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return CameraPreview(controller!);
            },
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.state,
    required this.cameraReady,
    required this.onCapture,
    required this.onReset,
  });

  final FaceEnrollmentState state;
  final bool cameraReady;
  final VoidCallback onCapture;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final busy = state.isBusy;
    final label = switch (state.stage) {
      FaceEnrollmentStage.embedding => 'Processing…',
      FaceEnrollmentStage.submitting => 'Saving…',
      _ => state.status?.enrolled == true ? 'Re-enroll face' : 'Enroll face',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: !cameraReady || busy ? null : onCapture,
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.camera_alt_outlined),
          label: Text(label),
        ),
        if (state.status?.enrolled == true) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: busy ? null : onReset,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove enrolled face'),
          ),
        ],
      ],
    );
  }
}
