import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';

class AppNotification {
  AppNotification.fromJson(Json json)
      : id = json.str('id'),
        type = json.str('type'),
        title = json.str('title'),
        message = json.strOrNull('message') ?? '',
        readAt = json.timeOrNull('readAt'),
        createdAt = json.time('createdAt');

  final String id;
  final String type;
  final String title;
  final String message;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get unread => readAt == null;
}

class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<List<AppNotification>> list() async => dataList(
        await _api.dio.get('/notifications/me', queryParameters: {'limit': 50}),
      ).map(AppNotification.fromJson).toList();

  Future<int> unreadCount() async =>
      data(await _api.dio.get('/notifications/me/unread-count'))
          .integer('unread');

  Future<void> markRead(String id) =>
      _api.dio.post('/notifications/$id/read');

  Future<void> markAllRead() => _api.dio.post('/notifications/read-all');
}

/// Unread badge count shared by the app bar bell; failures keep the last value.
class UnreadCountCubit extends Cubit<int> {
  UnreadCountCubit(this._repository) : super(0);

  final NotificationsRepository _repository;

  Future<void> refresh() async {
    try {
      final count = await _repository.unreadCount();
      if (!isClosed) emit(count);
    } catch (_) {}
  }
}
