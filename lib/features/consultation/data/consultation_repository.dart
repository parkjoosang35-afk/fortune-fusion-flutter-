import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/consultation_ad_source_model.dart';
import '../domain/consultation_model.dart';

/// 04A E-7 `consultation_sessions`/`consultation_messages` 대응 Repository.
///
/// [AI 상담 채팅 실연동] 과거 Mock(고정 답변 풀 + 90ms 지연 스트리밍 재현)에서
/// admin_web의 실제 공개 API 3종으로 완전히 교체한다:
///   - GET  /api/public/consultation/ad-sources   (세션 시작 전 광고게이트용 목록)
///   - POST /api/public/consultation/ad-reward-complete (광고 시청 성공 기록)
///   - POST /api/public/consultation/session      (세션 시작 — 오늘 1세션, idempotent)
///   - POST /api/public/consultation/message      (턴 처리 — 실LLM 응답)
///
/// [OpenPassRepository]와 동일한 실API 연동 패턴(AuthTokenStore.getCurrentUserId +
/// EnvConfig.adminApiBaseUrl + ApiResult)을 그대로 따른다. 서버가 이미 실LLM
/// 텍스트를 한 번에 완성해 내려주므로(SSE 스트리밍이 아님), [streamReply]는
/// 응답 텍스트를 어절 단위로 잘라 기존과 동일한 90ms 지연 타이핑 UX만 재현한다
/// (§15: 화면단(ConsultationProvider/MessageBubble)의 스트리밍 표시 로직은
/// 건드리지 않고, 이 Repository 내부에서만 흡수한다).
class ConsultationRepository {
  static const _base = '/api/public/consultation';

  /// GET /api/public/consultation/ad-sources — 세션 시작 전 광고게이트에
  /// 노출할 리워드 광고소스 목록(사주/타로 프리패스와 완전히 독립).
  Future<ApiResult<List<ConsultationAdSourceModel>>> getAdSources() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}$_base/ad-sources',
    ).replace(queryParameters: {'userId': '$userId'});
    debugPrint('[ConsultationRepository] [ad-sources] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '광고 정보를 불러오지 못했습니다.';
        debugPrint('[ConsultationRepository] [ad-sources] 실패 -> $error');
        return ApiResult.fail(error);
      }
      final data = decoded['data'] as Map<String, dynamic>;
      final list = (data['adSources'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ConsultationAdSourceModel.fromJson)
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[ConsultationRepository] [ad-sources] 예외 -> $e');
      return ApiResult.fail('광고 정보를 불러오지 못했습니다: $e');
    }
  }

  /// POST /api/public/consultation/ad-reward-complete — 광고 시청 성공 →
  /// PassPolicy/UserPass 발급 없이 순수 시청기록(OpenPassAdRewardLog)만 생성.
  /// 반환된 [adRewardLogId]를 [createSession]의 `adRewardLogId`로 그대로
  /// 전달해야 오늘의 세션 생성 게이트를 통과할 수 있다.
  Future<ApiResult<int>> completeAdReward({required int adSourceId}) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}$_base/ad-reward-complete',
    );
    debugPrint(
      '[ConsultationRepository] [ad-reward-complete] 요청 -> userId=$userId adSourceId=$adSourceId',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'adSourceId': adSourceId}),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '광고 시청 처리에 실패했습니다.';
        debugPrint(
          '[ConsultationRepository] [ad-reward-complete] 거부 -> $error',
        );
        return ApiResult.fail(error, code: decoded['reason'] as String?);
      }
      final adRewardLogId =
          (decoded['data'] as Map<String, dynamic>)['adRewardLogId'] as int;
      return ApiResult.ok(adRewardLogId);
    } catch (e) {
      debugPrint('[ConsultationRepository] [ad-reward-complete] 예외 -> $e');
      return ApiResult.fail('광고 시청 처리 중 오류가 발생했습니다: $e');
    }
  }

  /// POST /api/public/consultation/session — 상담 세션 시작.
  /// 오늘 이미 세션이 있으면 [adRewardLogId] 없이도 그대로 재사용된다(서버가
  /// idempotent하게 처리). 오늘 첫 세션이면 [adRewardLogId](광고 시청 완료
  /// 기록)가 반드시 필요하며, 없거나 유효하지 않으면 서버가 403 +
  /// `reason: AD_REWARD_REQUIRED` 등으로 거부한다.
  Future<ApiResult<ConsultationSessionModel>> createSession({
    required String type,
    int? adRewardLogId,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}$_base/session');
    debugPrint(
      '[ConsultationRepository] [session] 요청 -> userId=$userId type=$type adRewardLogId=$adRewardLogId',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'type': type,
              if (adRewardLogId != null) 'adRewardLogId': adRewardLogId,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '상담 세션을 시작하지 못했습니다.';
        debugPrint('[ConsultationRepository] [session] 거부 -> $error');
        return ApiResult.fail(error, code: decoded['reason'] as String?);
      }
      final session = ConsultationSessionModel.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );
      return ApiResult.ok(session);
    } catch (e) {
      debugPrint('[ConsultationRepository] [session] 예외 -> $e');
      return ApiResult.fail('상담 세션을 시작하지 못했습니다: $e');
    }
  }

  /// POST /api/public/consultation/message — 턴 처리(실LLM 응답).
  /// 서버가 한 번에 완성된 텍스트를 반환하므로, 이 스트림은 그 텍스트를
  /// 어절 단위로 90ms 지연 방출해 기존 타이핑 UX를 그대로 재현한다.
  /// 서버가 거부(턴 한도/500자 초과/세션 없음 등)하면 [ConsultationRequestException]을
  /// 던진다 — 호출부(ConsultationProvider)가 이를 잡아 사유별 안내를 표시해야 한다.
  Stream<String> streamReply({
    required int sessionId,
    required String userMessage,
  }) async* {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}$_base/message');
    debugPrint(
      '[ConsultationRepository] [message] 요청 -> userId=$userId sessionId=$sessionId',
    );

    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'sessionId': sessionId,
              'message': userMessage,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('[ConsultationRepository] [message] 예외 -> $e');
      throw ConsultationRequestException('상담 응답을 받아오지 못했습니다: $e');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw ConsultationRequestException('상담 응답 형식이 올바르지 않습니다: $e');
    }

    if (decoded['success'] != true) {
      final error = decoded['error'] as String? ?? '상담 응답 처리 중 오류가 발생했습니다.';
      debugPrint('[ConsultationRepository] [message] 거부 -> $error');
      throw ConsultationRequestException(
        error,
        code: decoded['reason'] as String? ?? decoded['code'] as String?,
        turnCount: decoded['turnCount'] as int?,
        maxTurns: decoded['maxTurns'] as int?,
      );
    }

    final turn = ConsultationTurnResult.fromJson(
      decoded['data'] as Map<String, dynamic>,
    );
    _lastTurnResult = turn;

    final tokens = turn.reply.split(RegExp(r'(?<=\s)'));
    for (final token in tokens) {
      await Future.delayed(const Duration(milliseconds: 90));
      yield token;
    }
  }

  /// [streamReply] 직후 갱신된 turnCount/maxTurns를 조회하기 위한 값.
  /// Stream 자체는 String 청크만 방출하므로, 마지막 호출의 부가 정보를
  /// 별도로 노출한다(ConsultationProvider가 턴 카운트 UI 갱신에 사용).
  ConsultationTurnResult? _lastTurnResult;
  ConsultationTurnResult? get lastTurnResult => _lastTurnResult;
}
