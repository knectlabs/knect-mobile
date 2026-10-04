import 'package:flutter_bloc/flutter_bloc.dart';

import '../network/api_client.dart';
import '../network/api_failure.dart';

/// Loading / data / error state for screens that read from the API.
sealed class AsyncValue<T> {
  const AsyncValue();
}

final class AsyncLoading<T> extends AsyncValue<T> {
  const AsyncLoading([this.previous]);

  /// Last data, kept while refreshing so content does not flash away.
  final T? previous;
}

final class AsyncData<T> extends AsyncValue<T> {
  const AsyncData(this.value);
  final T value;
}

final class AsyncError<T> extends AsyncValue<T> {
  const AsyncError(this.failure, [this.previous]);
  final ApiFailure failure;
  final T? previous;
}

extension AsyncValueX<T> on AsyncValue<T> {
  T? get valueOrPrevious => switch (this) {
        AsyncData(:final value) => value,
        AsyncLoading(:final previous) => previous,
        AsyncError(:final previous) => previous,
      };
}

/// Cubit that loads one value with [load] and supports pull-to-refresh.
class LoadCubit<T> extends Cubit<AsyncValue<T>> {
  LoadCubit(this._fetch, {bool autoload = true}) : super(const AsyncLoading()) {
    if (autoload) load();
  }

  final Future<T> Function() _fetch;

  Future<void> load() async {
    final previous = state.valueOrPrevious;
    emit(AsyncLoading(previous));
    try {
      final value = await _fetch();
      if (!isClosed) emit(AsyncData(value));
    } catch (error) {
      if (!isClosed) emit(AsyncError(apiFailureOf(error), previous));
    }
  }
}

/// User-facing message for a failed call.
String failureMessage(ApiFailure failure) => switch (failure.kind) {
      ApiFailureKind.network => 'No connection. Check your internet and retry.',
      ApiFailureKind.timeout => 'The server is taking too long. Try again.',
      ApiFailureKind.http
          when failure.statusCode != null && failure.statusCode! >= 500 =>
        'Something went wrong on our side. Try again shortly.',
      ApiFailureKind.http => failure.message,
      _ => 'Something went wrong. Try again.',
    };
