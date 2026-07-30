import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';

/// 07단계 §2.1 NotificationProvider 대응 Repository — admin_web 공개 API
/// (`GET /api/public/notifications`, `POST /api/public/notifications/[id]/read`,
/// `POST /api/public/notifications/read-all`)를 호출한다.
///
/// [실API 전환] 기존 하드코딩 2건짜리 완전 Mock을 실제 서버 데이터로 교체한다.
/// 서버는 where(userId)만 사용하고 정렬은 서버 메모리에서 처리하므로(복합 인덱스 불필요),
/// 클라이언트는 서버가 이미 정렬해 내려준 목록을 그대로 신뢰한다.
class NotificationRepository {
  Future<ApiResult<Map<String, dynamic>>> getList({int limit = 50}) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/notifications?userId=$userId&limit=$limit',
    );
    debugPrint('[NotificationRepository] [getList] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '알림 목록을 불러오지 못했습니다.';
        debugPrint('[NotificationRepository] [getList] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok({
        'notifications': (data['notifications'] as List)
            .cast<Map<String, dynamic>>(),
        'unreadCount': data['unreadCount'] as int? ?? 0,
      });
    } catch (e) {
      debugPrint('[NotificationRepository] [getList] 예외 -> $e');
      return ApiResult.fail('알림 목록을 불러오지 못했습니다: $e');
    }
  }

  /// POST /api/public/notifications/[id]/read — 단건 읽음 처리.
  Future<ApiResult<bool>> markRead(int id) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/notifications/$id/read',
    );
    debugPrint('[NotificationRepository] [markRead] 요청 -> $uri');

    try {
      final response = await http
          .post(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '읽음 처리에 실패했습니다.';
        debugPrint('[NotificationRepository] [markRead] 실패 -> $error');
        return ApiResult.fail(error);
      }
      return ApiResult.ok(true);
    } catch (e) {
      debugPrint('[NotificationRepository] [markRead] 예외 -> $e');
      return ApiResult.fail('읽음 처리 중 오류가 발생했습니다: $e');
    }
  }

  /// POST /api/public/notifications/read-all — 전체 읽음 처리.
  Future<ApiResult<int>> markAllRead() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/notifications/read-all',
    );
    debugPrint('[NotificationRepository] [markAllRead] 요청 -> userId=$userId');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '전체 읽음 처리에 실패했습니다.';
        debugPrint('[NotificationRepository] [markAllRead] 실패 -> $error');
        return ApiResult.fail(error);
      }
      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data['updatedCount'] as int? ?? 0);
    } catch (e) {
      debugPrint('[NotificationRepository] [markAllRead] 예외 -> $e');
      return ApiResult.fail('전체 읽음 처리 중 오류가 발생했습니다: $e');
    }
  }
}
