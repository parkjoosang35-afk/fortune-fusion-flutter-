import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/fortune_period_model.dart';

/// [신통방통 오늘의 운세] admin_web 공개 API
/// `GET /api/public/fortune-period/today*` 를 호출하는 Repository.
///
/// [2026-11] 기존 주간/월간은 삭제되었고(서버가 410 Gone 응답), `kind`
/// 파라미터는 이제 항상 `FortuneKind.today` 하나만 유효하다 — 시그니처는
/// 호출부 호환 및 향후 확장 여지를 위해 그대로 유지한다.
///
/// [절대 원칙] 이 Repository는 "조회(GET-or-create)"만 수행한다 — 사주정보
/// 저장/수정은 기존 `AuthRepository.updateProfile()`(PATCH
/// `/api/public/auth/profile`)을 그대로 쓰고 이 클래스에 중복 구현하지
/// 않는다. 서버가 사주 FACT(saju_engine) + AI 해석(무당체)을 전담하므로,
/// 여기서는 HTTP 호출 + 에러 분류만 담당한다.
class FortunePeriodRepository {
  static String get _base =>
      '${EnvConfig.adminApiBaseUrl}/api/public/fortune-period';

  /// `GET /api/public/fortune-period/{kind}` — 이번 기간 결과를 가져온다
  /// (없으면 서버가 새로 생성, AI 무당체 해석 LLM 호출 포함). 에러 코드:
  /// - `UNAUTHORIZED`(401): 로그인 필요
  /// - `SAJU_REQUIRED`(409): 사주정보 등록 필요 → 호출부가 등록 화면으로 유도
  /// - `ENGINE_ERROR`(502/400): saju_engine 응답 실패
  ///
  /// [타임아웃 70s — 2026-11] 신규 생성 시 서버가 saju_engine의
  /// `/fortune/today/mudang`(AI LLM 호출, 최대 60s)까지 왕복한다
  /// (admin_web `engine-adapter.ts`의 `DEFAULT_TIMEOUT_MS`도 65s로
  /// 맞춰져 있음 — 그보다 여유 있게 설정).
  Future<ApiResult<FortunePeriodResult>> fetchCurrent(FortuneKind kind) async {
    final token = await AuthTokenStore.getToken();
    if (token == null) {
      return ApiResult.fail('로그인이 필요합니다.', code: 'UNAUTHORIZED');
    }
    final uri = Uri.parse('$_base/${kind.apiValue}');
    try {
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 70));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '운세를 불러오지 못했습니다.',
          code: decoded['reason'] as String?,
        );
      }
      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(FortunePeriodResult.fromJson(data));
    } catch (e) {
      debugPrint('[FortunePeriodRepository] [fetchCurrent] 예외 -> $e');
      return ApiResult.fail('운세를 불러오는 중 오류가 발생했습니다: $e');
    }
  }

  /// `GET /api/public/fortune-period/{kind}/history?limit=6` — 지난 결과
  /// 목록(ArchiveList). 조회 전용, 새로 생성하지 않는다.
  Future<ApiResult<List<FortuneArchiveItem>>> fetchHistory(
    FortuneKind kind, {
    int limit = 6,
  }) async {
    final token = await AuthTokenStore.getToken();
    if (token == null) {
      return ApiResult.fail('로그인이 필요합니다.', code: 'UNAUTHORIZED');
    }
    final uri = Uri.parse('$_base/${kind.apiValue}/history?limit=$limit');
    try {
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '지난 운세 목록을 불러오지 못했습니다.',
          code: decoded['reason'] as String?,
        );
      }
      final data = decoded['data'] as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? const [])
          .map((e) => FortuneArchiveItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(items);
    } catch (e) {
      debugPrint('[FortunePeriodRepository] [fetchHistory] 예외 -> $e');
      return ApiResult.fail('지난 운세 목록을 불러오는 중 오류가 발생했습니다: $e');
    }
  }

  /// `GET /api/public/fortune-period/{kind}/{periodKey}` — 과거 특정 기간
  /// 결과 열람(PastBanner "다시 보기"). 절대 새로 생성하지 않는다(없으면
  /// 404 → `RESULT_NOT_FOUND`).
  Future<ApiResult<FortunePeriodResult>> fetchPast(
    FortuneKind kind,
    String periodKey,
  ) async {
    final token = await AuthTokenStore.getToken();
    if (token == null) {
      return ApiResult.fail('로그인이 필요합니다.', code: 'UNAUTHORIZED');
    }
    final uri = Uri.parse('$_base/${kind.apiValue}/$periodKey');
    try {
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '해당 기간의 운세를 찾을 수 없어요.',
          code: decoded['reason'] as String?,
        );
      }
      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(FortunePeriodResult.fromJson(data));
    } catch (e) {
      debugPrint('[FortunePeriodRepository] [fetchPast] 예외 -> $e');
      return ApiResult.fail('운세를 불러오는 중 오류가 발생했습니다: $e');
    }
  }
}
