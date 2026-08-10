import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/api/api_result.dart';
import '../../../../core/auth/auth_token_store.dart';
import '../../../../core/config/env_config.dart';
import '../domain/face_model.dart';

/// [관상 AI프롬프트 실연동] `POST /api/public/fortune/face` 대응 Repository.
/// name/saju Repository와 동일한 http 호출 패턴을 그대로 재사용한다.
///
/// [범위 결정 - 관상/손금 AI프롬프트 실연동] completeText()는 텍스트 전용 LLM이라
/// 실제 업로드된 얼굴 사진을 인식/분석할 수 없다. 따라서 "사진 촬영 UI"는 그대로
/// 유지하되(09단계 §7 개인정보보호 원칙에 따라 이미지는 여전히 서버로 전송되지
/// 않고 클라이언트에서 즉시 파기됨), 백엔드는 로그인 사용자 프로필(생년월일/성별)
/// 등 텍스트 정보를 기반으로 실제 LLM 해석 텍스트를 생성해 반환한다.
class FaceRepository {
  final List<FaceResultModel> _history = [];

  Future<ApiResult<FaceResultModel>> analyze({Uint8List? image}) async {
    // [범위 결정] image는 현재 백엔드로 전송되지 않는다(텍스트 전용 LLM 제약).
    // 촬영/선택 UX는 유지하되, 분석 요청 자체는 로그인 사용자 프로필 기반으로 수행된다.
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/fortune/face');
    debugPrint('[FaceRepository] [analyze] 요청 -> $uri (userId=$userId)');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 45));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '관상 분석에 실패했습니다.';
        debugPrint('[FaceRepository] [analyze] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final result = FaceResultModel(
        id: data['id'] as String,
        features: Map<String, String>.from(data['features'] as Map),
        topicResults: Map<String, String>.from(data['topicResults'] as Map),
        summary: data['summary'] as String,
        createdAt: DateTime.parse(data['createdAt'] as String),
      );
      _history.insert(0, result);
      return ApiResult.ok(result);
    } catch (e) {
      debugPrint('[FaceRepository] [analyze] 예외 -> $e');
      return ApiResult.fail('관상 분석 중 오류가 발생했습니다: $e');
    }
  }

  /// 서버 영속 이력을 조회한다. 서버 조회에 실패해도(오프라인 등) 이번 세션에서
  /// 누적된 로컬 결과는 그대로 보여줄 수 있도록 폴백을 유지한다(name_fortune_repository와 동일 패턴).
  Future<ApiResult<List<FaceResultModel>>> getHistory() async {
    try {
      final userId = await AuthTokenStore.getCurrentUserId();
      final uri = Uri.parse(
        '${EnvConfig.adminApiBaseUrl}/api/public/fortune/face/history?userId=$userId',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        debugPrint('[FaceRepository] [getHistory] 서버 조회 실패, 로컬로 폴백');
        return ApiResult.ok(List.unmodifiable(_history));
      }
      final list = (decoded['data'] as List<dynamic>)
          .map(
            (e) => FaceResultModel(
              id: e['id'] as String,
              features: Map<String, String>.from(e['features'] as Map),
              topicResults: Map<String, String>.from(e['topicResults'] as Map),
              summary: e['summary'] as String,
              createdAt: DateTime.parse(e['createdAt'] as String),
            ),
          )
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[FaceRepository] [getHistory] 예외 -> $e, 로컬로 폴백');
      return ApiResult.ok(List.unmodifiable(_history));
    }
  }
}
