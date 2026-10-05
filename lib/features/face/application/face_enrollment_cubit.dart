import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../data/face_embedder.dart';
import '../data/face_repository.dart';

/// Where the enrollment flow currently is. [idle] covers both "not started" and
/// "finished a step and ready for the next action".
enum FaceEnrollmentStage { idle, capturing, embedding, submitting, success }

/// State for the face enrollment screen: the loaded status plus the progress of
/// an in-flight enroll/reset action.
class FaceEnrollmentState extends Equatable {
  const FaceEnrollmentState({
    this.status,
    this.loadFailure,
    this.stage = FaceEnrollmentStage.idle,
    this.actionFailure,
    this.noFaceDetected = false,
  });

  /// Current enrollment status, once loaded. `null` while first loading or if
  /// the initial load failed (see [loadFailure]).
  final FaceStatus? status;

  /// Set when loading the status failed and there is nothing to show yet.
  final ApiFailure? loadFailure;

  /// Progress of the current enroll/reset action.
  final FaceEnrollmentStage stage;

  /// Set when the last enroll/reset action failed.
  final ApiFailure? actionFailure;

  /// Set when the last submit found no face in the captured photo.
  final bool noFaceDetected;

  bool get isBusy =>
      stage == FaceEnrollmentStage.capturing ||
      stage == FaceEnrollmentStage.embedding ||
      stage == FaceEnrollmentStage.submitting;

  FaceEnrollmentState copyWith({
    FaceStatus? status,
    ApiFailure? loadFailure,
    FaceEnrollmentStage? stage,
    ApiFailure? actionFailure,
    bool? noFaceDetected,
    bool clearLoadFailure = false,
    bool clearActionFailure = false,
  }) {
    return FaceEnrollmentState(
      status: status ?? this.status,
      loadFailure: clearLoadFailure ? null : (loadFailure ?? this.loadFailure),
      stage: stage ?? this.stage,
      actionFailure:
          clearActionFailure ? null : (actionFailure ?? this.actionFailure),
      noFaceDetected: noFaceDetected ?? this.noFaceDetected,
    );
  }

  @override
  List<Object?> get props =>
      [status, loadFailure, stage, actionFailure, noFaceDetected];
}

/// Drives face enrollment: loads status, enrolls a captured reference selfie,
/// and resets. The embedding vector is never emitted into state or logged.
class FaceEnrollmentCubit extends Cubit<FaceEnrollmentState> {
  FaceEnrollmentCubit(this._embedder, this._repository)
      : super(const FaceEnrollmentState()) {
    load();
  }

  final FaceEmbedder _embedder;
  final FaceRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(clearLoadFailure: true));
    try {
      final status = await _repository.status();
      emit(state.copyWith(status: status, clearLoadFailure: true));
    } catch (error) {
      if (!isClosed) emit(state.copyWith(loadFailure: apiFailureOf(error)));
    }
  }

  /// Detects a face in [imagePath], embeds it, and enrolls it as a reference.
  /// Surfaces [FaceEnrollmentState.noFaceDetected] when no face is found.
  Future<void> submit(String imagePath) async {
    if (state.isBusy) return;
    emit(state.copyWith(
      stage: FaceEnrollmentStage.embedding,
      noFaceDetected: false,
      clearActionFailure: true,
    ));
    try {
      final embedding = await _embedder.detectAndEmbed(imagePath);
      if (embedding == null) {
        if (!isClosed) {
          emit(state.copyWith(
            stage: FaceEnrollmentStage.idle,
            noFaceDetected: true,
          ));
        }
        return;
      }
      if (isClosed) return;
      emit(state.copyWith(stage: FaceEnrollmentStage.submitting));
      final status = await _repository.enroll(
        vector: embedding.vector,
        dimension: embedding.dimension,
        modelId: embedding.modelId,
      );
      if (!isClosed) {
        emit(state.copyWith(
          status: status,
          stage: FaceEnrollmentStage.success,
        ));
      }
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(
          stage: FaceEnrollmentStage.idle,
          actionFailure: apiFailureOf(error),
        ));
      }
    }
  }

  /// Clears all reference embeddings for the employee.
  Future<void> reset() async {
    if (state.isBusy) return;
    emit(state.copyWith(
      stage: FaceEnrollmentStage.submitting,
      clearActionFailure: true,
      noFaceDetected: false,
    ));
    try {
      final status = await _repository.reset();
      if (!isClosed) {
        emit(state.copyWith(
          status: status,
          stage: FaceEnrollmentStage.idle,
        ));
      }
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(
          stage: FaceEnrollmentStage.idle,
          actionFailure: apiFailureOf(error),
        ));
      }
    }
  }

  /// Returns the flow to idle after a success/error has been shown.
  void acknowledge() {
    if (state.stage == FaceEnrollmentStage.success) {
      emit(state.copyWith(stage: FaceEnrollmentStage.idle));
    }
  }
}
