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
        final error = decoded['error'] as String? ?? '프리패스 정책을 불러오지 못했습니다.';
        debugPrint('[PassRepository] [policies] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final list = (decoded['data'] as List<dynamic>)
          .map((e) => PassPolicyModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[PassRepository] [policies] 예외 -> $e');
      return ApiResult.fail('프리패스 정책을 불러오지 못했습니다: $e');
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
        final error = decoded['error'] as String? ?? '프리패스 상태를 불러오지 못했습니다.';
        debugPrint('[PassRepository] [status] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final status = PassStatusModel.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );
      return ApiResult.ok(status);
    } catch (e) {
      debugPrint('[PassRepository] [status] 예외 -> $e');
      return ApiResult.fail('프리패스 상태를 불러오지 못했습니다: $e');
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
        final error = decoded['error'] as String? ?? '프리패스 발급에 실패했습니다.';
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
      return ApiResult.fail('프리패스 발급 중 오류가 발생했습니다: $e');
    }
  }

  // [자율 정리 - 죽은 기능 제거] getPurchaseOptions()/purchaseWithLuckPouch()
  // (복주머니로 프리패스 구매)는 admin_web API까지 구현되어 있었으나 Flutter
  // UI 어디에서도 호출되지 않았다. "프리패스는 시간제 이용권, 복주머니는
  // 재화"라는 정책상 재화로 프리패스를 사는 경로는 열지 않기로 확정되어,
  // Provider의 대응 메서드와 함께 자율적으로 제거한다(admin_web 쪽
  // /api/public/pass/purchase-with-luck-pouch 엔드포인트 자체는 백엔드
  // 인프라이므로 건드리지 않는다).

  /// POST /api/public/pass/expire-on-logout — [로그아웃 시 프리패스 서버측 강제 만료]
  /// 로그아웃하면 이유를 막론하고 현재 활성 프리패스를 서버 DB에서 즉시, 영구적으로
  /// 만료(status=revoked, expiresAt=now)시킨다. 클라이언트 상태만 지우면 재로그인 시
  /// 서버가 여전히 유효하다고 판단해 잔여시간이 복원되는 문제를 방지하기 위함이다.
  /// 반드시 [AuthTokenStore.clear] (토큰 삭제) 이전에 호출해야 userId를 얻을 수 있다.
  Future<ApiResult<void>> expireOnLogout() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/pass/expire-on-logout',
    );
    debugPrint('[PassRepository] [expire-on-logout] 요청 -> userId=$userId');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '프리패스 만료 처리에 실패했습니다.';
        debugPrint('[PassRepository] [expire-on-logout] 실패 -> $error');
        return ApiResult.fail(error);
      }
      return ApiResult.ok(null);
    } catch (e) {
      debugPrint('[PassRepository] [expire-on-logout] 예외 -> $e');
      return ApiResult.fail('프리패스 만료 처리 중 오류가 발생했습니다: $e');
    }
  }

  /// POST /api/public/pass/consume — 시간제 콘텐츠 열람 직전 게이트 체크
  /// 유효한 열림패스가 없으면 실패(ApiResult.fail)를 반환하며, 화면단에서
  /// 이 실패를 감지해 열림패스 발급 유도 UI를 노출한다.
  ///
  /// [STEP8 - Flutter categoryKey 연동] [categoryKey]가 전달되면 서버가
  /// fortune_categories.category_key 기준 "카테고리별 최대 2회" 이용횟수도
  /// 함께 확인한다(예: 이미 saju를 2회 이용한 상태면 403
  /// CATEGORY_LIMIT_REACHED). categoryKey가 null이면(기존 모든 호출부) 서버가
  /// 카테고리 검증을 완전히 건너뛰어 기존 동작과 100% 동일하다.
  ///
  /// [이중 차감 방지] checkOnly는 항상 true로 고정 전송한다 — 이 메서드는
  /// "화면 진입 게이트체크"용이며, 실제 이용횟수 소진(+1)은 게이트를 통과한
  /// 뒤 호출되는 각 운세 Repository(SajuRepository.requestSaju 등)가 담당한다.
  /// 만약 여기서도 소진시키면 "게이트 1회 + 실제 API 1회 = 2회 소진"이 되어
  /// 카테고리당 2회 제한이 실질 1회로 줄어드는 버그가 발생한다.
  Future<ApiResult<void>> consume({
    required String contentType,
    dynamic contentId,
    String? categoryKey,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/pass/consume',
    );
    debugPrint(
      '[PassRepository] [consume] 요청 -> contentType=$contentType categoryKey=$categoryKey',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'contentType': contentType,
              if (contentId != null) 'contentId': contentId,
              if (categoryKey != null) 'categoryKey': categoryKey,
              'checkOnly': true,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '유효한 프리패스가 없습니다.';
        debugPrint('[PassRepository] [consume] 실패 -> $error');
        return ApiResult.fail(
          error,
          code: decoded['reason'] as String?,
        );
      }
      return ApiResult.ok(null);
    } catch (e) {
      debugPrint('[PassRepository] [consume] 예외 -> $e');
      return ApiResult.fail('프리패스 검증 중 오류가 발생했습니다: $e');
    }
  }
}
