import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/compatibility_model.dart';

/// [궁합(C그룹) 신규 구현] 궁합 Repository.
///
/// admin_web에 이미 완성되어 있던 `/api/public/compatibility/*` 3종
/// (request/result/history)을 호출한다 — 이름 운세 Repository와 동일한
/// http 호출 패턴을 그대로 재사용한다(신규 구조 없음, 기존 패턴 재사용).
/// 궁합은 admin_web 쪽에서 이미 "완전 무료"(복주머니 차감 없음) 정책으로
/// 구현되어 있으므로, 클라이언트에서도 별도 과금 로직을 추가하지 않는다.
class CompatibilityRepository {
  final List<CompatibilityResultModel> _history = [];

  Future<ApiResult<CompatibilityResultModel>> requestCompatibility({
    required CompatibilityType type,
    required String nameA,
    required String nameB,
    required String birthDateA,
    required String birthDateB,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/compatibility/request',
    );
    debugPrint(
      '[CompatibilityRepository] [request] 요청 -> $uri ($nameA x $nameB)',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'type': type.apiValue,
              'nameA': nameA,
              'nameB': nameB,
              'birthDateA': birthDateA,
              'birthDateB': birthDateB,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '궁합 분석에 실패했습니다.';
        debugPrint('[CompatibilityRepository] [request] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final result = CompatibilityResultModel.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );
      _history.insert(0, result);
      return ApiResult.ok(result);
    } catch (e) {
      debugPrint('[CompatibilityRepository] [request] 예외 -> $e');
      return ApiResult.fail('궁합 분석 중 오류가 발생했습니다: $e');
    }
  }

  /// `GET /api/public/compatibility/history` — 서버 영속 이력 조회.
  /// 서버 조회에 실패해도(오프라인 등) 이번 세션에서 누적된 로컬 결과는
  /// 그대로 보여줄 수 있도록 폴백을 유지한다(이름 운세와 동일 패턴).
  Future<ApiResult<List<CompatibilityResultModel>>> getHistory() async {
    try {
      final userId = await AuthTokenStore.getCurrentUserId();
      final uri = Uri.parse(
        '${EnvConfig.adminApiBaseUrl}/api/public/compatibility/history?userId=$userId',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        debugPrint('[CompatibilityRepository] [getHistory] 서버 조회 실패, 로컬로 폴백');
        return ApiResult.ok(List.unmodifiable(_history));
      }
      final list = (decoded['data'] as List<dynamic>)
          .map(
            (e) =>
                CompatibilityResultModel.fromJson(e as Map<String, dynamic>),
          )
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[CompatibilityRepository] [getHistory] 예외 -> $e, 로컬로 폴백');
      return ApiResult.ok(List.unmodifiable(_history));
    }
  }
}
