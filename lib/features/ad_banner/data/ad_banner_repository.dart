import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/config/env_config.dart';
import '../domain/ad_banner_model.dart';

/// CMS 제휴광고 배너 Repository — 다른 기능들과 달리 이 Repository는 Mock이 아니라
/// admin_web에 신설한 공개 API(`GET /api/public/banners`)를 실제 HTTP로 호출한다.
///
/// [원인 진단 배경] 기존에는 이 계층 자체가 존재하지 않아, 관리자에서 배너를 '활성'으로
/// 설정해도 Flutter 쪽에서는 그 데이터를 가져올 방법이 없었다(요청 자체가 발생하지 않음).
/// 이번 구현으로 프론트에서 "어느 단계에서 배너가 누락되는지" 직접 로그로 추적할 수 있도록,
/// 요청 URL/응답 상태코드/파싱 결과를 각 단계마다 debugPrint로 출력한다.
class AdBannerRepository {
  /// [position] 예: 'home_top' | 'home_middle' | 'home_bottom'. null이면 전체 조회.
  Future<ApiResult<List<AdBannerModel>>> getActiveBanners({
    String? position,
  }) async {
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/banners')
        .replace(queryParameters: position != null ? {'position': position} : null);

    debugPrint('[AdBannerRepository] [1] 요청 시작 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      debugPrint(
        '[AdBannerRepository] [2] 응답 수신 -> statusCode=${response.statusCode}, '
        'bodyLength=${response.body.length}',
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[AdBannerRepository] [X] 실패 -> statusCode=${response.statusCode}, body=${response.body}',
        );
        return ApiResult.fail(
          '배너 서버 응답 오류 (HTTP ${response.statusCode})',
          code: 'HTTP_${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final success = decoded['success'] == true;
      final rawList = decoded['data'];

      debugPrint(
        '[AdBannerRepository] [3] JSON 파싱 -> success=$success, '
        'count=${decoded['count']}, rawListType=${rawList.runtimeType}',
      );

      if (!success || rawList is! List) {
        return ApiResult.fail('배너 응답 형식이 올바르지 않습니다.');
      }

      final banners = rawList
          .whereType<Map<String, dynamic>>()
          .map(AdBannerModel.fromJson)
          .toList();

      debugPrint(
        '[AdBannerRepository] [4] 모델 변환 완료 -> ${banners.length}건 '
        '(ids=${banners.map((b) => b.id).toList()}, positions=${banners.map((b) => b.positionCode).toSet()})',
      );

      return ApiResult.ok(banners);
    } catch (e, st) {
      debugPrint('[AdBannerRepository] [X] 예외 발생 -> $e');
      if (kDebugMode) debugPrint('$st');
      return ApiResult.fail('배너를 불러오지 못했습니다: $e');
    }
  }
}
