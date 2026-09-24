import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/share_result_model.dart';

/// 결과 공유(Share Result) — admin_web 3개 공개 API 대응 Repository.
///
/// [백엔드 대응 — sintong-share-proposal.pdf §5]
/// - `POST   /api/public/share`            → [createShareLink] (인증 필수)
/// - `GET    /api/public/share/{shareId}`  → [fetchSharedResult] (인증 불필요)
/// - `DELETE /api/public/share/{shareId}`  → [deleteShareLink] (인증 필수, 본인 소유만)
///
/// [GuinjiRepository와의 관계] 동일한 요청/응답 패턴(JWT Bearer, ApiResult
/// 래핑, 15초 타임아웃, try/catch 예외를 실패 메시지로 변환)을 그대로
/// 따른다 — 신규 인프라를 도입하지 않고 기존 관례를 재사용한다.
class ShareApiService {
  /// 공유 링크 생성. [payload]는 화면이 표시에 필요한 값만 담은 Map이어야
  /// 하며, 원본 민감정보(생년월일 원본/실명/사진/전화번호/소원 원문 등)를
  /// 절대 포함해서는 안 된다(호출부 책임 — 서버는 이를 강제 검증하지 않음).
  Future<ApiResult<CreatedShareLink>> createShareLink({
    required ShareResultType resultType,
    required String title,
    required String description,
    required Map<String, dynamic> payload,
    String? imageUrl,
    String? sourceRefId,
  }) async {
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/share');
    debugPrint('[ShareApiService] [createShareLink] 요청 -> $uri');

    try {
      final authHeader = await AuthTokenStore.authHeader();
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', ...authHeader},
            body: jsonEncode({
              'resultType': resultType.apiValue,
              'title': title,
              'description': description,
              'payload': payload,
              if (imageUrl != null) 'imageUrl': imageUrl,
              if (sourceRefId != null) 'sourceRefId': sourceRefId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '공유 링크 생성에 실패했습니다.';
        debugPrint('[ShareApiService] [createShareLink] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(CreatedShareLink.fromJson(data));
    } catch (e) {
      debugPrint('[ShareApiService] [createShareLink] 예외 -> $e');
      return ApiResult.fail('공유 링크 생성 중 오류가 발생했습니다: $e');
    }
  }

  /// 공유된 결과 조회 — 인증 불필요(비로그인 열람자도 접근 가능).
  Future<ApiResult<SharedResultDto>> fetchSharedResult(String shareId) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/share/$shareId',
    );
    debugPrint('[ShareApiService] [fetchSharedResult] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '공유된 결과를 찾을 수 없어요.';
        debugPrint('[ShareApiService] [fetchSharedResult] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(SharedResultDto.fromJson(data));
    } catch (e) {
      debugPrint('[ShareApiService] [fetchSharedResult] 예외 -> $e');
      return ApiResult.fail('공유된 결과 조회 중 오류가 발생했습니다: $e');
    }
  }

  /// 공유 링크 삭제(soft-delete) — 본인 소유 링크만 가능.
  Future<ApiResult<void>> deleteShareLink(String shareId) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/share/$shareId',
    );
    debugPrint('[ShareApiService] [deleteShareLink] 요청 -> $uri');

    try {
      final authHeader = await AuthTokenStore.authHeader();
      final response = await http
          .delete(uri, headers: {'Accept': 'application/json', ...authHeader})
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '공유 링크 삭제에 실패했습니다.';
        debugPrint('[ShareApiService] [deleteShareLink] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['code'] as String?);
      }

      return ApiResult.ok(null);
    } catch (e) {
      debugPrint('[ShareApiService] [deleteShareLink] 예외 -> $e');
      return ApiResult.fail('공유 링크 삭제 중 오류가 발생했습니다: $e');
    }
  }
}
