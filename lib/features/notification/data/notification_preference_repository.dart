import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';

/// 알림 수신 설정 항목 — admin_web `notification_preferences` 테이블
/// (04A N-3 확정 화이트리스트: marketing/fortune_update/matching/community) 대응.
class NotificationPreferenceItem {
  final String category;
  final bool isEnabled;

  const NotificationPreferenceItem({
    required this.category,
    required this.isEnabled,
  });

  factory NotificationPreferenceItem.fromJson(Map<String, dynamic> json) {
    return NotificationPreferenceItem(
      category: json['category'] as String? ?? '',
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }
}

/// `GET/PUT /api/public/notifications/preferences` 호출 — Flutter
/// SettingsScreen의 알림 카테고리별 on/off 토글 대응 Repository.
class NotificationPreferenceRepository {
  Future<ApiResult<List<NotificationPreferenceItem>>> getPreferences() async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/notifications/preferences',
    );
    try {
      final headers = await AuthTokenStore.authHeader();
      final response = await http
          .get(uri, headers: {'Accept': 'application/json', ...headers})
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '알림 설정을 불러오지 못했습니다.';
        debugPrint('[NotificationPreferenceRepository] [get] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final list = (decoded['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(NotificationPreferenceItem.fromJson)
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[NotificationPreferenceRepository] [get] 예외 -> $e');
      return ApiResult.fail('알림 설정을 불러오지 못했습니다: $e');
    }
  }

  Future<ApiResult<bool>> updatePreference({
    required String category,
    required bool isEnabled,
  }) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/notifications/preferences',
    );
    try {
      final headers = await AuthTokenStore.authHeader();
      final response = await http
          .put(
            uri,
            headers: {'Content-Type': 'application/json', ...headers},
            body: jsonEncode({'category': category, 'isEnabled': isEnabled}),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '알림 설정 저장에 실패했습니다.';
        debugPrint('[NotificationPreferenceRepository] [update] 실패 -> $error');
        return ApiResult.fail(error);
      }
      return ApiResult.ok(true);
    } catch (e) {
      debugPrint('[NotificationPreferenceRepository] [update] 예외 -> $e');
      return ApiResult.fail('알림 설정 저장 중 오류가 발생했습니다: $e');
    }
  }
}
