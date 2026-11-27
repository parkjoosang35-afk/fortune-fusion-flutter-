import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/shrine_order.dart';
import '../domain/talisman_item.dart';

/// 신당(THE SHRINE) v3 — admin_web `/api/public/shrine/*` 5개 엔드포인트를
/// 그대로 얇게 감싼다. [ResultAccessRepository]와 동일한 패턴(ApiResult<T>
/// 래핑, AuthTokenStore.authHeader(), EnvConfig.adminApiBaseUrl)을 쓴다.
/// 지갑차감/일련번호/향 계산은 전부 서버가 하므로 이 클래스는 계산 로직을
/// 전혀 갖지 않는다(§8 서버 전담 원칙).
class ShrineV3Repository {
  /// GET /api/public/shrine/talismans — 67종 전체(또는 category 필터) 카탈로그.
  Future<ApiResult<List<TalismanItem>>> getTalismans({
    String? category,
  }) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/shrine/talismans',
    ).replace(queryParameters: category != null ? {'category': category} : null);
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '부적 목록을 불러오지 못했습니다.',
        );
      }
      final list = (decoded['data'] as List)
          .map((e) => TalismanItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[ShrineV3Repository] [getTalismans] 예외 -> $e');
      return ApiResult.fail('부적 목록을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.');
    }
  }

  /// POST /api/public/shrine/order — 05→07 "부탁하기" 확정(결제 게이트 통과 후).
  Future<ApiResult<ShrineOrder>> createOrder({
    required String talismanSlug,
    required String wish,
    required String paymentMethod,
    required String transactionId,
    String? adSessionId,
  }) async {
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/shrine/order');
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              ...await AuthTokenStore.authHeader(),
            },
            body: jsonEncode({
              'talismanSlug': talismanSlug,
              'wish': wish,
              'paymentMethod': paymentMethod,
              'transactionId': transactionId,
              if (adSessionId != null) 'adSessionId': adSessionId,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '부적을 짓지 못했습니다.',
          code: decoded['reason'] as String?,
        );
      }
      return ApiResult.ok(
        ShrineOrder.fromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[ShrineV3Repository] [createOrder] 예외 -> $e');
      return ApiResult.fail('부적을 짓는 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
    }
  }

  /// GET /api/public/shrine/box — 09 부적함 목록 + summary.
  Future<ApiResult<({List<ShrineOrder> items, ShrineBoxSummary summary})>>
  getBox() async {
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/shrine/box');
    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              ...await AuthTokenStore.authHeader(),
            },
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '부적함을 불러오지 못했습니다.',
          code: response.statusCode == 401 ? 'UNAUTHORIZED' : null,
        );
      }
      final data = decoded['data'] as Map<String, dynamic>;
      final items = (data['items'] as List)
          .map((e) => ShrineOrder.fromJson(e as Map<String, dynamic>))
          .toList();
      final summary = ShrineBoxSummary.fromJson(
        data['summary'] as Map<String, dynamic>,
      );
      return ApiResult.ok((items: items, summary: summary));
    } catch (e) {
      debugPrint('[ShrineV3Repository] [getBox] 예외 -> $e');
      return ApiResult.fail('부적함을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.');
    }
  }

  /// GET /api/public/shrine/box/:id — 10 부적함 상세.
  Future<ApiResult<ShrineOrderDetail>> getBoxDetail(int orderId) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/shrine/box/$orderId',
    );
    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              ...await AuthTokenStore.authHeader(),
            },
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '부적 정보를 불러오지 못했습니다.',
        );
      }
      return ApiResult.ok(
        ShrineOrderDetail.fromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[ShrineV3Repository] [getBoxDetail] 예외 -> $e');
      return ApiResult.fail('부적 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.');
    }
  }

  /// POST /api/public/shrine/box/:id/incense — §7 향 올리기(하루 1회, +3일).
  Future<ApiResult<ShrineIncenseResult>> lightIncense(int orderId) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/shrine/box/$orderId/incense',
    );
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              ...await AuthTokenStore.authHeader(),
            },
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '향을 올리지 못했습니다.',
          code: decoded['reason'] as String?,
        );
      }
      return ApiResult.ok(
        ShrineIncenseResult.fromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[ShrineV3Repository] [lightIncense] 예외 -> $e');
      return ApiResult.fail('향을 올리는 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
    }
  }
}
