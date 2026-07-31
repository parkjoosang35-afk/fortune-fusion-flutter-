import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/pass_model.dart';

/// [신규] 열림패스(AlarmPass) Repository — admin_web 공개 API
/// (`GET /api/public/pass/policies`, `GET /api/public/pass/status`,
/// `POST /api/public/pass/claim-ad`, `POST /api/public/pass/claim-partner`,
/// `POST /api/public/pass/consume`)를 호출한다.
///
/// [문서7 API명세초안 승인 반영] WalletRepository와 동일한 실API 연동 패턴
/// (AuthTokenStore.getCurrentUserId + EnvConfig.adminApiBaseUrl + ApiResult)을 그대로 사용.
class PassRepository {
  /// GET /api/public/pass/policies — 홈 화면 열림패스 섹션 CTA 카드 목록
  Future<ApiResult<List<PassPolicyModel>>> getPolicies() async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/pass/policies',
    );
    debugPrint('[PassRepository] [policies] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '열림패스 정책을 불러오지 못했습니다.';
        debugPrint('[PassRepository] [policies] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final list = (decoded['data'] as List<dynamic>)
          .map((e) => PassPolicyModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[PassRepository] [policies] 예외 -> $e');
      return ApiResult.fail('열림패스 정책을 불러오지 못했습니다: $e');
    }
  }

  /// GET /api/public/pass/status — 현재 열림패스 활성 상태(홈 화면 상태바)
  Future<ApiResult<PassStatusModel>> getStatus() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/pass/status?userId=$userId',
    );
    debugPrint('[PassRepository] [status] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '열림패스 상태를 불러오지 못했습니다.';
        debugPrint('[PassRepository] [status] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final status = PassStatusModel.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );
      return ApiResult.ok(status);
    } catch (e) {
      debugPrint('[PassRepository] [status] 예외 -> $e');
      return ApiResult.fail('열림패스 상태를 불러오지 못했습니다: $e');
    }
  }

  /// POST /api/public/pass/claim-ad — 광고 시청 완료 후 열림패스 발급
  Future<ApiResult<PassStatusModel>> claimAd({int? policyId}) async {
    return _claim('claim-ad', policyId: policyId);
  }

  /// POST /api/public/pass/claim-partner — 파트너 랜딩 방문 완료 후 열림패스 발급
  Future<ApiResult<PassStatusModel>> claimPartner({int? policyId}) async {
    return _claim('claim-partner', policyId: policyId);
  }

  Future<ApiResult<PassStatusModel>> _claim(
    String endpoint, {
    int? policyId,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/pass/$endpoint',
    );
    debugPrint('[PassRepository] [$endpoint] 요청 시작 -> userId=$userId');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              if (policyId != null) 'policyId': policyId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '열림패스 발급에 실패했습니다.';
        debugPrint('[PassRepository] [$endpoint] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final expiresAt = DateTime.parse(data['expiresAt'] as String);
      return ApiResult.ok(
        PassStatusModel(
          isActive: true,
          userPassId: data['userPassId'] as int?,
          policyId: data['policyId'] as int?,
          policyName: data['policyName'] as String?,
          expiresAt: expiresAt,
          remainingSec: expiresAt.difference(DateTime.now()).inSeconds,
        ),
      );
    } catch (e) {
      debugPrint('[PassRepository] [$endpoint] 예외 -> $e');
      return ApiResult.fail('열림패스 발급 중 오류가 발생했습니다: $e');
    }
  }

  /// POST /api/public/pass/consume — 시간제 콘텐츠 열람 직전 게이트 체크
  /// 유효한 열림패스가 없으면 실패(ApiResult.fail)를 반환하며, 화면단에서
  /// 이 실패를 감지해 열림패스 발급 유도 UI를 노출한다.
  Future<ApiResult<void>> consume({
    required String contentType,
    dynamic contentId,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/pass/consume',
    );
    debugPrint('[PassRepository] [consume] 요청 -> contentType=$contentType');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'contentType': contentType,
              if (contentId != null) 'contentId': contentId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '유효한 열림패스가 없습니다.';
        debugPrint('[PassRepository] [consume] 실패 -> $error');
        return ApiResult.fail(error);
      }
      return ApiResult.ok(null);
    } catch (e) {
      debugPrint('[PassRepository] [consume] 예외 -> $e');
      return ApiResult.fail('열림패스 검증 중 오류가 발생했습니다: $e');
    }
  }
}
