import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/pouch_box_model.dart';

/// [행운상자 - 복주머니 탭 신규 기능] admin_web 공개 API
/// (`GET /api/pouch-box/state`, `POST /api/pouch-box/start`,
/// `POST /api/pouch-box/complete`)를 호출한다. FortuneAdRepository와
/// 동일하게 userId는 AuthTokenStore(폴백 1)를 사용한다.
class PouchBoxRepository {
  /// 오늘 현황 조회(그리드 화면 진입 시 CTA 활성화 여부 판단용).
  Future<ApiResult<PouchBoxState>> getState() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/pouch-box/state',
    ).replace(queryParameters: {'userId': '$userId'});
    debugPrint('[PouchBoxRepository] [state] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '현황을 불러오지 못했어요.';
        return ApiResult.fail(error);
      }
      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(PouchBoxState.fromJson(data));
    } catch (e) {
      debugPrint('[PouchBoxRepository] [state] 예외 -> $e');
      return ApiResult.fail('현황을 불러오지 못했어요: $e');
    }
  }

  /// 시청 시작 — 서버가 자격(하루 5회 한도)을 재확인하고 PENDING 세션을 발급한다.
  Future<ApiResult<PouchBoxSession>> start() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/pouch-box/start');
    debugPrint('[PouchBoxRepository] [start] 요청 -> userId=$userId');

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
        final error = decoded['error'] as String? ?? '지금은 열 수 없어요.';
        debugPrint('[PouchBoxRepository] [start] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['reason'] as String?);
      }
      final session = PouchBoxSession.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );
      return ApiResult.ok(session);
    } catch (e) {
      debugPrint('[PouchBoxRepository] [start] 예외 -> $e');
      return ApiResult.fail('시작 처리 중 오류가 발생했어요: $e');
    }
  }

  /// 시청 완료 — 서버가 최종 검증 후 보상을 굴리고(가중확률) 복주머니를
  /// 지급한다(서버 최종 지급 원칙, 클라이언트 랜덤 절대 금지).
  Future<ApiResult<PouchBoxRewardResult>> complete({
    required String sessionId,
    int? watchSeconds,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/pouch-box/complete',
    );
    debugPrint('[PouchBoxRepository] [complete] 요청 -> sessionId=$sessionId');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'sessionId': sessionId,
              if (watchSeconds != null) 'watchSeconds': watchSeconds,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '보상 지급에 실패했어요.';
        debugPrint('[PouchBoxRepository] [complete] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['reason'] as String?);
      }
      final result = PouchBoxRewardResult.fromJson(
        decoded,
        idempotent: decoded['idempotent'] as bool? ?? false,
      );
      return ApiResult.ok(result);
    } catch (e) {
      debugPrint('[PouchBoxRepository] [complete] 예외 -> $e');
      return ApiResult.fail('보상 지급 처리 중 오류가 발생했어요: $e');
    }
  }
}
