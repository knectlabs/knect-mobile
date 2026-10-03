import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState._(this.status, {this.user, this.sessionExpired = false});

  const AuthState.initial() : this._(AuthStatus.initial);

  /// [user] is null until `/auth/me` loads (e.g. when offline at startup).
  const AuthState.authenticated([CurrentUser? user])
      : this._(AuthStatus.authenticated, user: user);

  /// [sessionExpired] distinguishes a session the API ended from a sign-out.
  const AuthState.unauthenticated({bool sessionExpired = false})
      : this._(AuthStatus.unauthenticated, sessionExpired: sessionExpired);

  final AuthStatus status;
  final CurrentUser? user;
  final bool sessionExpired;

  @override
  List<Object?> get props => [status, user, sessionExpired];
}

/// App-wide session state. The router redirects on [AuthStatus].
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthState.initial()) {
    _expiry = _repository.sessionExpired.listen((_) {
      if (state.status == AuthStatus.authenticated) {
        emit(const AuthState.unauthenticated(sessionExpired: true));
      }
    });
  }

  final AuthRepository _repository;
  late final StreamSubscription<void> _expiry;

  /// Restores a stored session before the first frame. The profile loads in
  /// the background so the app also opens offline.
  Future<void> restoreSession() async {
    bool stored;
    try {
      stored = await _repository.hasStoredSession();
    } catch (_) {
      stored = false;
    }
    if (!stored) {
      emit(const AuthState.unauthenticated());
      return;
    }
    emit(const AuthState.authenticated());
    unawaited(refreshProfile());
  }

  /// Loads `/auth/me`. Failures keep the session; a rejected session is
  /// reported through the repository's expiry stream.
  Future<void> refreshProfile() async {
    try {
      final user = await _repository.currentUser();
      if (state.status == AuthStatus.authenticated) {
        emit(AuthState.authenticated(user));
      }
    } catch (_) {
      // Offline or transient failure: keep the current state.
    }
  }

  void signedIn(CurrentUser user) => emit(AuthState.authenticated(user));

  Future<void> signOut() async {
    await _repository.signOut();
    emit(const AuthState.unauthenticated());
  }

  /// Throws when the API cannot be reached; the session is kept then.
  Future<void> signOutEverywhere() async {
    await _repository.signOutEverywhere();
    emit(const AuthState.unauthenticated());
  }

  @override
  Future<void> close() async {
    await _expiry.cancel();
    return super.close();
  }
}
