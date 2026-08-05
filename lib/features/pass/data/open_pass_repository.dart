import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/open_pass_models.dart';

/// [열림패스 첨부/광고소스 연동] admin_web `/api/public/open-pass/*` Repository.
///
/// admin_web 어드민 화면(첨부 관리/광고소스 관리/상품 바인딩)에서 등록한
/// 값을 앱이 그대로 조회/반영하기 위한 6개 공개 API를 각각 감싼다.
/// - GET  /api/public/open-pass/products
/// - GET  /api/public/open-pass/products/{id}
/// - GET  /api/public/open-pass/products/{id}/display-config
/// - GET  /api/public/open-pass/products/{id}/ad-config
/// - POST /api/public/open-pass/reward-complete
/// - POST /api/public/open-pass/reward-failed
///
/// [PassRepository]와 동일한 실API 연동 패턴(AuthTokenStore.getCurrentUserId +
/// EnvConfig.adminApiBaseUrl + ApiResult)을 그대로 따른다.
class OpenPassRepository {
  static const _base = '/api/public/open-pass';

  /// GET /api/public/open-pass/products — 상품 목록(히어로/프로모 배너 포함).
  Future<ApiResult<List<OpenPassProductModel>>> getProducts() async {
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}$_base/products');
    debugPrint('[OpenPassRepository] [products] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '프리패스 상품 목록을 불러오지 못했습니다.';
        debugPrint('[OpenPassRepository] [products] 실패 -> $error');
        return ApiResult.fail(error);
      }
      final list = (decoded['data'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(OpenPassProductModel.fromJson)
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[OpenPassRepository] [products] 예외 -> $e');
      return ApiResult.fail('프리패스 상품 목록을 불러오지 못했습니다: $e');
    }
  }

  /// GET /api/public/open-pass/products/{id} — 상세(첨부 전체 + 광고소스 목록).
  /// [userId]를 전달하면 서버가 각 광고소스별 시청 가능 여부(eligible)까지
  /// 함께 계산해 내려준다(§15: 앱이 임의로 쿨다운/한도를 재판단하지 않음).
  Future<ApiResult<OpenPassProductDetailModel>> getProductDetail(
    int policyId, {
    String platform = 'android',
    bool includeUser = true,
  }) async {
    final userId = includeUser ? await AuthTokenStore.getCurrentUserId() : null;
    final uri =
        Uri.parse(
          '${EnvConfig.adminApiBaseUrl}$_base/products/$policyId',
        ).replace(
          queryParameters: {
            'platform': platform,
            if (userId != null) 'userId': '$userId',
          },
        );
    debugPrint('[OpenPassRepository] [products/$policyId] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '프리패스 상품 정보를 불러오지 못했습니다.';
        debugPrint('[OpenPassRepository] [products/$policyId] 실패 -> $error');
        return ApiResult.fail(error);
      }
      final detail = OpenPassProductDetailModel.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );
      return ApiResult.ok(detail);
    } catch (e) {
      debugPrint('[OpenPassRepository] [products/$policyId] 예외 -> $e');
      return ApiResult.fail('프리패스 상품 정보를 불러오지 못했습니다: $e');
    }
  }

  /// GET /api/public/open-pass/products/{id}/display-config — 배너/첨부만 별도 조회.
  Future<ApiResult<OpenPassDisplayConfigModel>> getDisplayConfig(
    int policyId,
  ) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}$_base/products/$policyId/display-config',
    );
    debugPrint('[OpenPassRepository] [display-config] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '배너 정보를 불러오지 못했습니다.';
        return ApiResult.fail(error);
      }
      return ApiResult.ok(
        OpenPassDisplayConfigModel.fromJson(
          decoded['data'] as Map<String, dynamic>,
        ),
      );
    } catch (e) {
      debugPrint('[OpenPassRepository] [display-config] 예외 -> $e');
      return ApiResult.fail('배너 정보를 불러오지 못했습니다: $e');
    }
  }

  /// GET /api/public/open-pass/products/{id}/ad-config — 광고소스만 별도 조회.
  Future<ApiResult<List<OpenPassAdSourceBindingModel>>> getAdConfig(
    int policyId, {
    String platform = 'android',
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}$_base/products/$policyId/ad-config',
    ).replace(queryParameters: {'platform': platform, 'userId': '$userId'});
    debugPrint('[OpenPassRepository] [ad-config] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '광고 정보를 불러오지 못했습니다.';
        return ApiResult.fail(error);
      }
      final data = decoded['data'] as Map<String, dynamic>;
      final list = (data['adSources'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OpenPassAdSourceBindingModel.fromJson)
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[OpenPassRepository] [ad-config] 예외 -> $e');
      return ApiResult.fail('광고 정보를 불러오지 못했습니다: $e');
    }
  }

  /// POST /api/public/open-pass/reward-complete — 광고 시청 성공 후 실제 지급 요청.
  /// 실패(쿨다운/일일한도 초과 등)는 [OpenPassRewardDeniedException]으로 던진다.
  Future<ApiResult<OpenPassRewardGrantModel>> rewardComplete({
    required int policyId,
    required int adSourceId,
    required String idempotencyKey,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}$_base/reward-complete');
    debugPrint(
      '[OpenPassRepository] [reward-complete] 요청 -> userId=$userId policyId=$policyId adSourceId=$adSourceId',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'policyId': policyId,
              'adSourceId': adSourceId,
              'idempotencyKey': idempotencyKey,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '보상 지급에 실패했습니다.';
        debugPrint('[OpenPassRepository] [reward-complete] 거부 -> $error');
        return ApiResult.fail(error, code: decoded['reason'] as String?);
      }
      final grant = OpenPassRewardGrantModel.fromJson(
        decoded['data'] as Map<String, dynamic>,
        idempotent: decoded['idempotent'] as bool? ?? false,
      );
      return ApiResult.ok(grant);
    } catch (e) {
      debugPrint('[OpenPassRepository] [reward-complete] 예외 -> $e');
      return ApiResult.fail('보상 지급 처리 중 오류가 발생했습니다: $e');
    }
  }

  /// POST /api/public/open-pass/reward-failed — 광고 실패/노필 시 대체 크리에이티브 조회.
  Future<ApiResult<OpenPassRewardFailedModel>> rewardFailed({
    int? policyId,
    required int adSourceId,
    required String reason,
    String? idempotencyKey,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}$_base/reward-failed');
    debugPrint(
      '[OpenPassRepository] [reward-failed] 요청 -> userId=$userId reason=$reason',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              if (policyId != null) 'policyId': policyId,
              'adSourceId': adSourceId,
              'reason': reason,
              if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '처리 중 오류가 발생했습니다.';
        return ApiResult.fail(error);
      }
      return ApiResult.ok(
        OpenPassRewardFailedModel.fromJson(
          decoded['data'] as Map<String, dynamic>,
        ),
      );
    } catch (e) {
      debugPrint('[OpenPassRepository] [reward-failed] 예외 -> $e');
      return ApiResult.fail('처리 중 오류가 발생했습니다: $e');
    }
  }
}
