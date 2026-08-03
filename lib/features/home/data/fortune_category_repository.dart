import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/config/env_config.dart';
import '../domain/fortune_category_model.dart';

/// [운세 카테고리 확장] 전체보기(all_categories_screen.dart) 화면용
/// Repository. `GET /api/public/fortune/categories` 대응 — 다른 카테고리
/// Repository와 동일한 http 호출 패턴을 그대로 재사용한다.
class FortuneCategoryRepository {
  Future<ApiResult<List<FortuneCategoryGroupData>>> getGroups() async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/fortune/categories',
    );
    debugPrint('[FortuneCategoryRepository] [getGroups] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '카테고리 목록을 불러오지 못했습니다.';
        debugPrint('[FortuneCategoryRepository] [getGroups] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final groups = (data['groups'] as List<dynamic>)
          .map(
            (e) => FortuneCategoryGroupData.fromJson(e as Map<String, dynamic>),
          )
          .toList();
      return ApiResult.ok(groups);
    } catch (e) {
      debugPrint('[FortuneCategoryRepository] [getGroups] 예외 -> $e');
      return ApiResult.fail('카테고리 목록을 불러오지 못했습니다: $e');
    }
  }
}
