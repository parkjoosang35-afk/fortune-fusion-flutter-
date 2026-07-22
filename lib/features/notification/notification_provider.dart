import 'package:flutter/foundation.dart';

/// 07단계 §2.1 전역 Provider - NotificationProvider(알림 뱃지 카운트, 인앱알림 목록)
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });
}

class NotificationProvider extends ChangeNotifier {
  final List<NotificationItem> _items = [
    NotificationItem(
      id: 'n1',
      title: '오늘의 운세가 도착했어요',
      body: '오늘 하루, 당신의 운세를 확인해보세요.',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    NotificationItem(
      id: 'n2',
      title: '출석 보상 지급 완료',
      body: '연속 출석 3일차 보너스 포인트가 지급되었습니다.',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      isRead: true,
    ),
  ];

  List<NotificationItem> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((e) => !e.isRead).length;

  void markAllRead() {
    for (final item in _items) {
      item.isRead = true;
    }
    notifyListeners();
  }

  void markRead(String id) {
    final item = _items.firstWhere((e) => e.id == id, orElse: () => _items.first);
    item.isRead = true;
    notifyListeners();
  }
}
