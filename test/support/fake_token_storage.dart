import 'package:kerjancok_mobile/core/storage/token_storage.dart';

class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage([this.tokens]);

  AuthTokens? tokens;
  Object? readError;

  @override
  Future<void> clearTokens() async {
    tokens = null;
  }

  @override
  Future<AuthTokens?> readTokens() async {
    if (readError case final error?) {
      throw error;
    }
    return tokens;
  }

  @override
  Future<void> writeTokens(AuthTokens tokens) async {
    this.tokens = tokens;
  }
}
