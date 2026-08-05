import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/config/env_config.dart';
import '../domain/healing_quote_model.dart';

/// "힐링 문구" 관리자 콘텐츠 Repository — admin_web 공개 API
/// (`GET /api/public/healing-quotes`)를 호출한다.
///
/// [사용자 요청] "오늘의 운세 이야기"를 완전히 삭제하고 데이터베이스에서 불러온 힐링 문구를
/// 1분마다 자동 순환 노출한다. 이 API는 LuckyNumberRepository와 달리 단일 슬롯이 아니라
/// 활성 문구 "전체 목록"을 배열로 반환한다 — 앱이 받은 리스트를 로컬에서 순환시키기 때문.
class HealingQuoteRepository {
  Future<ApiResult<List<HealingQuoteModel>>> getActiveQuotes() async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/healing-quotes',
    );

    debugPrint('[HealingQuoteRepository] [1] 요청 시작 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      debugPrint(
        '[HealingQuoteRepository] [2] 응답 수신 -> statusCode=${response.statusCode}',
      );

      if (response.statusCode != 200) {
        return ApiResult.fail(
          '힐링 문구 서버 응답 오류 (HTTP ${response.statusCode})',
          code: 'HTTP_${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final success = decoded['success'] == true;
      final rawData = decoded['data'];

      if (!success) {
        return ApiResult.fail('힐링 문구 응답 형식이 올바르지 않습니다.');
      }

      if (rawData == null || rawData is! List) {
        debugPrint('[HealingQuoteRepository] [3] 활성 문구 없음(빈 목록)');
        return ApiResult.ok(const []);
      }

      final quotes = rawData
          .whereType<Map<String, dynamic>>()
          .map((json) => HealingQuoteModel.fromJson(json))
          .toList();

      debugPrint('[HealingQuoteRepository] [4] 모델 변환 완료 -> ${quotes.length}건');

      return ApiResult.ok(quotes);
    } catch (e, st) {
      debugPrint('[HealingQuoteRepository] [X] 예외 발생 -> $e');
      if (kDebugMode) debugPrint('$st');
      return ApiResult.fail('힐링 문구를 불러오지 못했습니다: $e');
    }
  }
}
