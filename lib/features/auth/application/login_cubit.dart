import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../data/auth_repository.dart';
import 'auth_cubit.dart';

class LoginState extends Equatable {
  const LoginState({this.submitting = false, this.error});

  final bool submitting;

  /// User-facing message for the last failed attempt.
  final String? error;

  @override
  List<Object?> get props => [submitting, error];
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._repository, this._auth) : super(const LoginState());

  final AuthRepository _repository;
  final AuthCubit _auth;

  Future<void> submit({required String email, required String password}) async {
    if (state.submitting) return;
    if (email.trim().isEmpty || password.isEmpty) {
      emit(const LoginState(error: 'Enter your email and password.'));
      return;
    }
    emit(const LoginState(submitting: true));
    try {
      final user = await _repository.signIn(email: email, password: password);
      emit(const LoginState());
      _auth.signedIn(user);
    } catch (error) {
      emit(LoginState(error: loginErrorMessage(apiFailureOf(error))));
    }
  }
}

String loginErrorMessage(ApiFailure failure) {
  switch (failure.code) {
    case 'INVALID_CREDENTIALS':
    case 'REQUEST_VALIDATION_FAILED':
      return 'Incorrect email or password.';
    case 'ACCOUNT_INACTIVE':
      return 'This account has been deactivated. Contact your HR team.';
    case 'ORGANIZATION_INACTIVE':
      return 'Your organization is not active. Contact your HR team.';
    case 'TOO_MANY_REQUESTS':
      return 'Too many sign-in attempts. Wait a minute and try again.';
  }
  return switch (failure.kind) {
    ApiFailureKind.network => 'No connection. Check your internet and retry.',
    ApiFailureKind.timeout => 'The server is taking too long. Try again.',
    _ => 'Sign-in failed. Try again.',
  };
}
