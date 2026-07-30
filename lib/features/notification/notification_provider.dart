import 'package:flutter/foundation.dart';
import 'data/notification_repository.dart';

/// 07단계 §2.1 전역 Provider - NotificationProvider(알림 뱃지 카운트, 인앱알림 목록)
///
/// [실API 전환] admin_web 공개 API(`/api/public/notifications`,
/// `/api/public/notifications/[id]/read`, `/api/public/notifications/read-all`)로
/// 완전 Mock(하드코딩 2건)을 교체한다. 화면단(home_screen_cosmic.dart, notifications_screen.dart)이
/// 참조하는 `items`/`unreadCount` getter와 `markAllRead()` 시그니처는 그대로 유지해
/// Presentation 레이어 변경을 최소화한다.
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

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['sentAt'] as String? ?? '') ?? DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}

class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _repository;
  NotificationProvider(this._repository);

  List<NotificationItem> _items = [];
  bool _isLoading = false;
  String? _lastError;

  List<NotificationItem> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((e) => !e.isRead).length;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final result = await _repository.getList();
    if (result.success && result.data != null) {
      final rows = result.data!['notifications'] as List<Map<String, dynamic>>;
      _items = rows.map(NotificationItem.fromJson).toList();
      _lastError = null;
    } else {
      _lastError = result.errorMessage;
    }
    _isLoading = false;
    notifyListeners();
  }

  /// 알림 목록 화면 진입 시 전체 읽음 처리(서버 반영 + 로컬 상태 동기화).
  Future<void> markAllRead() async {
    for (final item in _items) {
      item.isRead = true;
    }
    notifyListeners();

    final result = await _repository.markAllRead();
    if (!result.success) {
      _lastError = result.errorMessage;
      notifyListeners();
    }
  }

  /// 단건 읽음 처리(서버 반영 + 로컬 상태 동기화).
  Future<void> markRead(String id) async {
    final item = _items.where((e) => e.id == id).firstOrNull;
    if (item == null || item.isRead) return;
    item.isRead = true;
    notifyListeners();

    final numericId = int.tryParse(id);
    if (numericId == null) return;
    final result = await _repository.markRead(numericId);
    if (!result.success) {
      _lastError = result.errorMessage;
      notifyListeners();
    }
  }
}
