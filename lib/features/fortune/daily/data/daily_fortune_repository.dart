import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/api/api_result.dart';
import '../../../../core/auth/auth_token_store.dart';
import '../../../../core/config/env_config.dart';
import '../domain/daily_fortune_model.dart';

/// 06단계 §4.3 `GET /v1/fortune/daily/today` 대응 Repository — admin_web 공개 API
/// (`GET /api/public/fortune/daily?userId=`)를 호출하는 실제 구현체 (Mock→실API 전환).
///
/// [Phase22 - 복주머니 경제철학 이식] 서버가 point_policies.ai_daily_request(30P) 기준
/// 포인트를 차감하고, economy_config.refund_rate(기본 50%)만큼 즉시 환급까지 원자적으로
/// 처리한다. 같은 날 재호출 시에는 서버가 캐시된 기존 결과를 재차감 없이 반환한다
/// (alreadyGenerated 플래그로 구분 가능).
///
/// [로드맵④] 실 로그인 사용자 ID를 [AuthTokenStore]에서 조회한다.
/// 비로그인 상태에서는 폴백 테스트 유저(userId=1)를 그대로 사용한다.
class DailyFortuneRepository {
  Future<ApiResult<DailyFortuneModel>> getToday() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/fortune/daily?userId=$userId',
    );
    debugPrint('[DailyFortuneRepository] [getToday] 요청 시작 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint(
        '[DailyFortuneRepository] [getToday] 응답 수신 -> statusCode=${response.statusCode}',
      );

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '오늘의 운세를 불러오지 못했습니다.';
        debugPrint('[DailyFortuneRepository] [getToday] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final categoryScoresRaw =
          data['categoryScores'] as Map<String, dynamic>? ?? {};
      final categoryScores = categoryScoresRaw.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      );

      final model = DailyFortuneModel(
        id: data['id'] as String,
        date: DateTime.parse(data['date'] as String),
        categoryScores: categoryScores,
        luckyColor: data['luckyColor'] as String,
        luckyNumber: (data['luckyNumber'] as num).toInt(),
        summaryText: data['summaryText'] as String,
      );

      debugPrint(
        '[DailyFortuneRepository] [getToday] 성공 -> alreadyGenerated=${data['alreadyGenerated']}, '
        'refundAmount=${data['refundAmount']}',
      );

      return ApiResult.ok(model);
    } catch (e, st) {
      debugPrint('[DailyFortuneRepository] [getToday] 예외 -> $e');
      if (kDebugMode) debugPrint('$st');
      return ApiResult.fail('오늘의 운세를 불러오지 못했습니다: $e');
    }
  }
}
