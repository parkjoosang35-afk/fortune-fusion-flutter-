import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/config/env_config.dart';
import '../domain/intro_config_model.dart';

/// [인트로 전면 개편] `GET /api/public/intro-config` 대응 Repository.
/// HomePageConfigRepository와 동일한 http 호출 패턴을 재사용한다.
class IntroConfigRepository {
  Future<ApiResult<IntroConfigModel>> getIntroConfig() async {
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/intro-config');
    debugPrint('[IntroConfigRepository] [getIntroConfig] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 ||
          decoded['success'] != true ||
          decoded['data'] == null) {
        final error = decoded['error'] as String? ?? '인트로 설정을 불러오지 못했습니다.';
        debugPrint('[IntroConfigRepository] [getIntroConfig] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final data = IntroConfigModel.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );
      return ApiResult.ok(data);
    } catch (e) {
      debugPrint('[IntroConfigRepository] [getIntroConfig] 예외 -> $e');
      return ApiResult.fail('인트로 설정을 불러오지 못했습니다: $e');
    }
  }
}
