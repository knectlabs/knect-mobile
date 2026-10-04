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
        target = NotificationTarget.fromJson(json.objOrNull('data')),
        readAt = json.timeOrNull('readAt'),
        createdAt = json.time('createdAt');

  final String id;
  final String type;
  final String title;
  final String message;
  final NotificationTarget? target;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get unread => readAt == null;
}

/// The API attaches this to approval notifications so the app can open the
/// relevant employee request or manager approval inbox.
class NotificationTarget {
  const NotificationTarget({
    required this.approvalId,
    required this.type,
    required this.id,
  });

  static NotificationTarget? fromJson(Json? json) {
    if (json == null) return null;
    final approvalId = json.strOrNull('approvalId');
    final type = json.strOrNull('targetType');
    final id = json.strOrNull('targetId');
    if (approvalId == null || type == null || id == null) {
      return null;
    }
    return NotificationTarget(approvalId: approvalId, type: type, id: id);
  }

  final String approvalId;
  final String type;
  final String id;
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

  Future<void> markRead(String id) => _api.dio.post('/notifications/$id/read');

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
