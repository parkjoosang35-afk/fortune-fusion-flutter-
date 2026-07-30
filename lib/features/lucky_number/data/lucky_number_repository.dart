import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/config/env_config.dart';
import '../domain/lucky_number_model.dart';

/// "오늘의 행운숫자" 관리자 콘텐츠 Repository — admin_web 공개 API
/// (`GET /api/public/lucky-number`)를 호출한다.
///
/// [사용자 요청] "오늘의 행운숫자 섹션은 꼭 광고을 아니 하던것 진핼해" — AdBannerRepository를
/// 재사용하지 않고 별도 Repository로 구현한다. 이 API는 position 파라미터가 없고,
/// 단일 슬롯(nullable 단일 객체)만 반환한다는 점이 AdBannerRepository와 다르다.
class LuckyNumberRepository {
  Future<ApiResult<LuckyNumberModel?>> getActiveContent() async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/lucky-number',
    );

    debugPrint('[LuckyNumberRepository] [1] 요청 시작 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      debugPrint(
        '[LuckyNumberRepository] [2] 응답 수신 -> statusCode=${response.statusCode}',
      );

      if (response.statusCode != 200) {
        return ApiResult.fail(
          '행운숫자 서버 응답 오류 (HTTP ${response.statusCode})',
          code: 'HTTP_${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final success = decoded['success'] == true;
      final rawData = decoded['data'];

      if (!success) {
        return ApiResult.fail('행운숫자 응답 형식이 올바르지 않습니다.');
      }

      if (rawData == null) {
        debugPrint('[LuckyNumberRepository] [3] 활성 콘텐츠 없음(null)');
        return ApiResult.ok(null);
      }

      final content = LuckyNumberModel.fromJson(
        rawData as Map<String, dynamic>,
      );
      debugPrint(
        '[LuckyNumberRepository] [4] 모델 변환 완료 -> id=${content.id}, type=${content.contentType}',
      );

      return ApiResult.ok(content);
    } catch (e, st) {
      debugPrint('[LuckyNumberRepository] [X] 예외 발생 -> $e');
      if (kDebugMode) debugPrint('$st');
      return ApiResult.fail('행운숫자 콘텐츠를 불러오지 못했습니다: $e');
    }
  }
}
