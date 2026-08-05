import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/name_fortune_model.dart';

/// [운세 카테고리 확장] 이름 운세(성명학) Repository.
/// `POST /api/public/fortune/name` 대응 — 사주/궁합 Repository와 동일한
/// http 호출 패턴을 그대로 재사용한다(신규 구조 없음, 기존 패턴 재사용).
class NameFortuneRepository {
  final List<NameFortuneResultModel> _history = [];

  Future<ApiResult<NameFortuneResultModel>> requestNameFortune({
    required String name,
    String? hanja,
    String? birthDate,
    String? gender,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/fortune/name',
    );
    debugPrint('[NameFortuneRepository] [request] 요청 -> $uri (name=$name)');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'name': name,
              'hanja': hanja,
              'birthDate': birthDate,
              'gender': gender,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '이름 운세 분석에 실패했습니다.';
        debugPrint('[NameFortuneRepository] [request] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final result = NameFortuneResultModel.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );
      _history.insert(0, result);
      return ApiResult.ok(result);
    } catch (e) {
      debugPrint('[NameFortuneRepository] [request] 예외 -> $e');
      return ApiResult.fail('이름 운세 분석 중 오류가 발생했습니다: $e');
    }
  }

  /// [남은 미세조정] `GET /api/public/fortune/name/history`가 신설되어,
  /// 궁합(CompatibilityRepository.getHistory())과 동일한 패턴으로 서버
  /// 영속 이력을 조회한다. 서버 조회에 실패해도(오프라인 등) 이번 세션에서
  /// 누적된 로컬 결과는 그대로 보여줄 수 있도록 폴백을 유지한다.
  Future<ApiResult<List<NameFortuneResultModel>>> getHistory() async {
    try {
      final userId = await AuthTokenStore.getCurrentUserId();
      final uri = Uri.parse(
        '${EnvConfig.adminApiBaseUrl}/api/public/fortune/name/history?userId=$userId',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        debugPrint('[NameFortuneRepository] [getHistory] 서버 조회 실패, 로컬로 폴백');
        return ApiResult.ok(List.unmodifiable(_history));
      }
      final list = (decoded['data'] as List<dynamic>)
          .map(
            (e) => NameFortuneResultModel.fromJson(e as Map<String, dynamic>),
          )
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[NameFortuneRepository] [getHistory] 예외 -> $e, 로컬로 폴백');
      return ApiResult.ok(List.unmodifiable(_history));
    }
  }
}
