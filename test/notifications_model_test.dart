import 'package:flutter_test/flutter_test.dart';
import 'package:kerjancok_mobile/features/notifications/data/notifications_repository.dart';

void main() {
  test('parses an approval notification target for mobile navigation', () {
    final notification = AppNotification.fromJson({
      'id': 'notice-1',
      'type': 'APPROVAL_REQUESTED',
      'title': 'New leave request to review',
      'message': 'Rina: Annual leave',
      'data': {
        'approvalId': 'approval-1',
        'targetType': 'LEAVE_REQUEST',
        'targetId': 'leave-1',
      },
      'readAt': null,
      'createdAt': '2026-10-04T01:00:00.000Z',
    });

    expect(notification.unread, isTrue);
    expect(notification.target?.approvalId, 'approval-1');
    expect(notification.target?.type, 'LEAVE_REQUEST');
    expect(notification.target?.id, 'leave-1');
  });

  test('keeps notifications without a complete deep-link payload readable', () {
    final notification = AppNotification.fromJson({
      'id': 'notice-2',
      'type': 'SYSTEM',
      'title': 'Hello',
      'message': '',
      'data': {'targetId': 'partial'},
      'readAt': '2026-10-04T01:00:00.000Z',
      'createdAt': '2026-10-04T00:00:00.000Z',
    });

    expect(notification.unread, isFalse);
    expect(notification.target, isNull);
  });
}
