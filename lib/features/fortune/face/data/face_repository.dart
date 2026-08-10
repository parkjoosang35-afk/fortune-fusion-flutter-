import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/api/api_result.dart';
import '../../../../core/auth/auth_token_store.dart';
import '../../../../core/config/env_config.dart';
import '../domain/face_model.dart';

/// [관상 AI프롬프트 실연동 - 실사진 분석 버그 수정] `POST /api/public/fortune/face` 대응 Repository.
/// name/saju Repository와 동일한 http 호출 패턴을 그대로 재사용한다.
///
/// [버그 수정] 기존에는 촬영/선택된 얼굴 사진(image)이 서버로 전송되지 않아,
/// 손/사물 등 아무 사진을 올려도 항상 그럴듯한 관상 결과가 나오는 문제가 있었다.
/// 이제 이미지를 base64로 인코딩해 서버로 전송하고, 백엔드가 Vision 모델로
/// 실제 사진을 검증/분석한다. 얼굴이 아닌 사진이면 서버가 422로 명확히 거부한다.
class FaceRepository {
  final List<FaceResultModel> _history = [];

  Future<ApiResult<FaceResultModel>> analyze({Uint8List? image}) async {
    if (image == null) {
      return ApiResult.fail('얼굴 사진을 먼저 촬영하거나 선택해주세요.');
    }
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/fortune/face');
    final imageBase64 = base64Encode(image);
    debugPrint(
      '[FaceRepository] [analyze] 요청 -> $uri (userId=$userId, imageBytes=${image.length})',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'image': imageBase64}),
          )
          .timeout(const Duration(seconds: 50));

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
