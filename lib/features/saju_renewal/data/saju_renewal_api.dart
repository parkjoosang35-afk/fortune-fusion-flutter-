import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import 'models/topic_card.dart';
import 'models/interpret_result.dart';

/// [신통방통 정통사주 리뉴얼 — STEP 6.5 Flutter 연동] STEP 3~4에서 완성된
/// 신규 API 2종(`/api/public/saju-renewal/topics/select`,
/// `/api/public/saju-renewal/interpret`)만 호출하는 전용 클라이언트.
///
/// [절대 금지 원칙]
/// - 기존 `saju_v3_api.dart`(69종, `/saju/v3/*`, X-Free-Pass 헤더)를
///   재활용하지 않는다 — 완전히 새로 작성한다.
/// - 레거시(`/saju/v3/*`, `/api/public/fortune/saju`)와 신규
///   (`/api/public/saju-renewal/*`)를 명확히 분리한다.
/// - 생년월일을 요청 바디로 보내지 않는다. 두 API 모두 서버가
///   User.profile(DB)에 저장된 값을 사용하므로, 이 클라이언트는 항상
///   `profile_id`(=로그인 userId 문자열)만 보낸다. 출생정보 저장은
///   AuthProvider.updateProfile()이 별도로 담당한다(이 클래스의 책임
///   밖 — 화면/Provider 계층에서 먼저 호출해야 함).
/// - 표준 JWT Bearer 인증(AuthTokenStore.authHeader())만 사용한다.
///   saju_v3 전용 X-Free-Pass 브릿지는 이 클라이언트와 무관하다.
class SajuRenewalApi {
  SajuRenewalApi({String? baseUrl})
    : _baseUrl = baseUrl ?? EnvConfig.adminApiBaseUrl;

  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 20);

  /// POST /api/public/saju-renewal/topics/select
  ///
  /// [excludeTopicIds] — "다른 사주 이야기" 재요청 시 이미 노출된 topic_id를
  /// 넘겨 서버가 선정 풀에서 제외하게 한다(화면④~⑧ "다른 사주 이야기" 흐름).
  /// [limit] — 다음 후보 최대 개수(서버 기본값은 4, 생략 시 서버 기본값 사용).
  ///
  /// 에러코드(ApiResult.errorCode)로 내려오는 값: PROFILE_ID_REQUIRED /
  /// PROFILE_ID_MISMATCH / INVALID_EXCLUDE_TOPIC_IDS / INVALID_LIMIT /
  /// BIRTH_INFO_REQUIRED(400) / FACT_ENGINE_UNAVAILABLE(503) / UNAUTHORIZED(401).
  Future<ApiResult<TopicsSelectResult>> selectTopics({
    List<String>? excludeTopicIds,
    int? limit,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('$_baseUrl/api/public/saju-renewal/topics/select');
    final body = <String, dynamic>{
      'profile_id': userId.toString(),
      if (excludeTopicIds != null && excludeTopicIds.isNotEmpty)
        'exclude_topic_ids': excludeTopicIds,
      if (limit != null) 'limit': limit,
    };
    debugPrint('[SajuRenewalApi] [selectTopics] 요청 -> $uri body=$body');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              ...await AuthTokenStore.authHeader(),
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final message = decoded['error'] as String? ?? '사주 이야기를 불러오지 못했습니다.';
        final reason = decoded['reason'] as String?;
        debugPrint(
          '[SajuRenewalApi] [selectTopics] 실패(${response.statusCode}) -> $message reason=$reason',
        );
        return ApiResult.fail(
          message,
          code: response.statusCode == 401 ? 'UNAUTHORIZED' : reason,
        );
      }
      return ApiResult.ok(
        TopicsSelectResult.fromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[SajuRenewalApi] [selectTopics] 예외 -> $e');
      return ApiResult.fail('사주 이야기를 불러오는 중 오류가 발생했습니다: $e');
    }
  }

  /// POST /api/public/saju-renewal/interpret (mode="summary")
  ///
  /// 화면⑤ "첫 이야기 미리보기"/"다른 이야기 미리보기"에서 사용. 서버가
  /// topic_id를 재검증하므로(클라이언트 선언 신뢰 안 함) 응답이 실패할
  /// 수 있다(TOPIC_CONDITION_NOT_SATISFIED 등) — 호출부가 반드시
  /// errorCode를 확인해 "다른 이야기를 선택해주세요" 등 안내로 처리해야
  /// 한다.
  Future<ApiResult<InterpretSummaryResult>> interpretSummary({
    required String topicId,
    List<String>? evidenceFactKeys,
  }) async {
    final result = await _interpret(
      topicId: topicId,
      mode: 'summary',
      evidenceFactKeys: evidenceFactKeys,
    );
    if (!result.success) {
      return ApiResult.fail(
        result.errorMessage ?? '이야기를 불러오지 못했습니다.',
        code: result.errorCode,
      );
    }
    final summary = result.data!.summary;
    if (summary == null) {
      return ApiResult.fail('이야기 형식이 올바르지 않습니다.');
    }
    return ApiResult.ok(summary);
  }

  /// POST /api/public/saju-renewal/interpret (mode="detail")
  ///
  /// 화면⑦ "상세 사주 이야기"(Access Gate 통과 후)에서 사용. 서버가
  /// (userId, topicId, mode, birthKey) 조합으로 멱등 캐시를 두므로, 동일
  /// 조합 재요청 시 LLM 재호출 없이 캐시된 결과가 즉시 반환된다(중복 클릭
  /// 방어는 이 캐시 + Flutter 측 버튼 disable 이중 방어).
  Future<ApiResult<InterpretDetailResult>> interpretDetail({
    required String topicId,
    List<String>? evidenceFactKeys,
  }) async {
    final result = await _interpret(
      topicId: topicId,
      mode: 'detail',
      evidenceFactKeys: evidenceFactKeys,
    );
    if (!result.success) {
      return ApiResult.fail(
        result.errorMessage ?? '이야기를 불러오지 못했습니다.',
        code: result.errorCode,
      );
    }
    final detail = result.data!.detail;
    if (detail == null) {
      return ApiResult.fail('이야기 형식이 올바르지 않습니다.');
    }
    return ApiResult.ok(detail);
  }

  Future<ApiResult<InterpretResponse>> _interpret({
    required String topicId,
    required String mode,
    List<String>? evidenceFactKeys,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('$_baseUrl/api/public/saju-renewal/interpret');
    final body = <String, dynamic>{
      'profile_id': userId.toString(),
      'topic_id': topicId,
      'mode': mode,
      if (evidenceFactKeys != null) 'evidence_fact_keys': evidenceFactKeys,
    };
    debugPrint('[SajuRenewalApi] [interpret] 요청 -> $uri body=$body');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              ...await AuthTokenStore.authHeader(),
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final message = decoded['error'] as String? ?? '이야기를 불러오지 못했습니다.';
        final reason = decoded['reason'] as String?;
        debugPrint(
          '[SajuRenewalApi] [interpret] 실패(${response.statusCode}) -> $message reason=$reason',
        );
        return ApiResult.fail(
          message,
          code: response.statusCode == 401 ? 'UNAUTHORIZED' : reason,
        );
      }
      final data = decoded['data'] as Map<String, dynamic>;
      final cached = decoded['cached'] as bool? ?? false;
      if (mode == 'summary') {
        return ApiResult.ok(InterpretResponse.summaryOf(data, cached: cached));
      }
      return ApiResult.ok(InterpretResponse.detailOf(data, cached: cached));
    } catch (e) {
      debugPrint('[SajuRenewalApi] [interpret] 예외 -> $e');
      return ApiResult.fail('이야기를 불러오는 중 오류가 발생했습니다: $e');
    }
  }
}
