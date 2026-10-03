import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/storage/token_storage.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState(this.status);

  const AuthState.initial() : status = AuthStatus.initial;
  const AuthState.authenticated() : status = AuthStatus.authenticated;
  const AuthState.unauthenticated() : status = AuthStatus.unauthenticated;

  final AuthStatus status;

  @override
  List<Object?> get props => [status];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._tokenStorage) : super(const AuthState.initial());

  final TokenStorage _tokenStorage;

  Future<void> restoreSession() async {
    try {
      final tokens = await _tokenStorage.readTokens();
      emit(
        tokens == null
            ? const AuthState.unauthenticated()
            : const AuthState.authenticated(),
      );
    } catch (_) {
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> establishSession(AuthTokens tokens) async {
    await _tokenStorage.writeTokens(tokens);
    emit(const AuthState.authenticated());
  }

  Future<void> signOut() async {
    await _tokenStorage.clearTokens();
    emit(const AuthState.unauthenticated());
  }
}
