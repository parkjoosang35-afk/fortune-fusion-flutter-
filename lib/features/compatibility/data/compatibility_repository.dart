import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/compatibility_model.dart';

/// 06단계 §4.5(`/v1/compatibility`) 대응 Repository — admin_web 공개 API 실 연동.
/// (`POST /api/public/compatibility/request`,
///  `GET  /api/public/compatibility/history`,
///  `GET  /api/public/compatibility/result/:id`)
///
/// [실API 전환 - 갭 처리] admin_web에는 궁합 결과 "보관(save)"/"공유링크 생성"/
/// "보관 결과 비교" 3개 기능에 대응하는 서버 API가 없다(compatibility_results
/// 스키마에 isSaved/shareUrl 컬럼 없음). `AmuletProvider.equip()`과 동일한 패턴으로,
/// 이 3개는 본 Repository에는 정의하지 않고 CompatibilityProvider가 클라이언트
/// 로컬 상태로만 처리한다(앱 재시작 시 초기화).
class CompatibilityRepository {
  /// POST /api/public/compatibility/request
  Future<ApiResult<CompatibilityResultModel>> requestCompatibility({
    required String birthDateA,
    required String birthDateB,
    String? nameA,
    String? nameB,
    CompatibilityType type = CompatibilityType.love,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/compatibility/request',
    );
    debugPrint('[CompatibilityRepository] [request] 요청 -> type=${type.name}');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'type': type.name,
              'nameA': nameA?.isNotEmpty == true ? nameA : '나',
              'nameB': nameB?.isNotEmpty == true ? nameB : '상대방',
              'birthDateA': birthDateA,
              'birthDateB': birthDateB,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '궁합 분석에 실패했습니다.';
        debugPrint('[CompatibilityRepository] [request] 실패 -> $error');
        return ApiResult.fail(error);
      }
      final result = CompatibilityResultModel.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );
      return ApiResult.ok(result);
    } catch (e) {
      debugPrint('[CompatibilityRepository] [request] 예외 -> $e');
      return ApiResult.fail('궁합 분석 중 오류가 발생했습니다: $e');
    }
  }

  /// GET /api/public/compatibility/history?userId=
  Future<ApiResult<List<CompatibilityResultModel>>> getHistory() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/compatibility/history?userId=$userId',
    );
    debugPrint('[CompatibilityRepository] [history] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '궁합 이력을 불러오지 못했습니다.';
        debugPrint('[CompatibilityRepository] [history] 실패 -> $error');
        return ApiResult.fail(error);
      }
      final list = (decoded['data'] as List<dynamic>)
          .map(
            (e) => CompatibilityResultModel.fromJson(e as Map<String, dynamic>),
          )
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[CompatibilityRepository] [history] 예외 -> $e');
      return ApiResult.fail('궁합 이력을 불러오지 못했습니다: $e');
    }
  }

  /// GET /api/public/compatibility/result/:id
  Future<ApiResult<CompatibilityResultModel>> getResultById(String id) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/compatibility/result/$id',
    );
    debugPrint('[CompatibilityRepository] [result] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '궁합 결과를 불러오지 못했습니다.';
        debugPrint('[CompatibilityRepository] [result] 실패 -> $error');
        return ApiResult.fail(error);
      }
      final result = CompatibilityResultModel.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );
      return ApiResult.ok(result);
    } catch (e) {
      debugPrint('[CompatibilityRepository] [result] 예외 -> $e');
      return ApiResult.fail('궁합 결과를 불러오지 못했습니다: $e');
    }
  }
}
