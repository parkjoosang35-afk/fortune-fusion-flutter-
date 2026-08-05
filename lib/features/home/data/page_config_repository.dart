import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/config/env_config.dart';
import '../domain/page_config_model.dart';

/// [메인화면 관리자 편집기] `GET /api/public/page-configs/home` 대응 Repository.
/// 다른 Repository와 동일한 http 호출 패턴을 그대로 재사용한다
/// (FortuneCategoryRepository, AdBannerRepository 참고).
class HomePageConfigRepository {
  Future<ApiResult<PageConfigData>> getHomeConfig() async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/page-configs/home',
    );
    debugPrint('[HomePageConfigRepository] [getHomeConfig] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 ||
          decoded['success'] != true ||
          decoded['data'] == null) {
        final error = decoded['error'] as String? ?? '메인화면 구성을 불러오지 못했습니다.';
        debugPrint('[HomePageConfigRepository] [getHomeConfig] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final data = PageConfigData.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );
      return ApiResult.ok(data);
    } catch (e) {
      debugPrint('[HomePageConfigRepository] [getHomeConfig] 예외 -> $e');
      return ApiResult.fail('메인화면 구성을 불러오지 못했습니다: $e');
    }
  }
}
