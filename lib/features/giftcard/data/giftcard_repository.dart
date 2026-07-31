import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/giftcard_model.dart';

/// 06§4.10 `/v1/giftcards/*` 대응 Repository — admin_web 공개 API
/// (`/api/public/giftcard/*`)를 호출한다. [방법 A] 테스트 유저(userId=1) 고정
/// (matching_repository.dart / wallet_repository.dart와 동일 패턴).
class GiftcardRepository {
  static String get _base => '${EnvConfig.adminApiBaseUrl}/api/public/giftcard';

  /// GET /api/public/giftcard/products
  Future<ApiResult<List<GiftcardProductModel>>> getProducts() async {
    final uri = Uri.parse('$_base/products');
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '상품 목록을 불러오지 못했습니다.',
        );
      }
      final list = (decoded['data'] as List<dynamic>)
          .map((e) => _productFromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[GiftcardRepository] [getProducts] 예외 -> $e');
      return ApiResult.fail('상품 목록을 불러오지 못했습니다: $e');
    }
  }

  /// POST /api/public/giftcard/orders - 교환 요청(행복머니 차감은 Provider단에서
  /// WalletProvider.spend와 orchestrate, 02번§1.2 WalletService 단일 인터페이스 원칙).
  /// 재고소진 시에도 서버는 status:"failed" 레코드를 생성해 success:true로 응답한다
  /// (Flutter의 issue.status==failed 감지 → 환불 처리 흐름과 정합성 유지 - 설계결정 참조).
  Future<ApiResult<GiftcardIssueModel>> orderProduct(String productId) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('$_base/orders');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'productId': productId}),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '상품권 교환에 실패했습니다.');
      }
      return ApiResult.ok(
        _issueFromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[GiftcardRepository] [orderProduct] 예외 -> $e');
      return ApiResult.fail('상품권 교환 중 오류가 발생했습니다: $e');
    }
  }

  /// GET /api/public/giftcard/orders/my
  Future<ApiResult<List<GiftcardIssueModel>>> getMyOrders() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('$_base/orders/my?userId=$userId');
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '발급 내역을 불러오지 못했습니다.',
        );
      }
      final list = (decoded['data'] as List<dynamic>)
          .map((e) => _issueFromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[GiftcardRepository] [getMyOrders] 예외 -> $e');
      return ApiResult.fail('발급 내역을 불러오지 못했습니다: $e');
    }
  }

  /// POST /api/public/giftcard/orders/:id/use
  Future<ApiResult<GiftcardIssueModel>> useIssue(String issueId) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('$_base/orders/$issueId/use');
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
        return ApiResult.fail(
          decoded['error'] as String? ?? '상품권을 사용할 수 없습니다.',
        );
      }
      return ApiResult.ok(
        _issueFromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[GiftcardRepository] [useIssue] 예외 -> $e');
      return ApiResult.fail('상품권 사용 중 오류가 발생했습니다: $e');
    }
  }

  GiftcardProductModel _productFromJson(Map<String, dynamic> j) {
    return GiftcardProductModel(
      id: j['id'] as String,
      name: j['name'] as String,
      brand: j['brand'] as String? ?? '',
      requiredPoint: (j['requiredPoint'] as num?)?.toInt() ?? 0,
      stockCount: (j['stockCount'] as num?)?.toInt() ?? 0,
      validDays: (j['validDays'] as num?)?.toInt() ?? 365,
      imageEmoji: j['imageEmoji'] as String? ?? '🎁',
    );
  }

  GiftcardIssueModel _issueFromJson(Map<String, dynamic> j) {
    return GiftcardIssueModel(
      id: j['id'] as String,
      product: _productFromJson(j['product'] as Map<String, dynamic>),
      pointSpent: (j['pointSpent'] as num?)?.toInt() ?? 0,
      status: _statusFromString(j['status'] as String?),
      issuedCode: j['issuedCode'] as String?,
      issuedAt: j['issuedAt'] != null
          ? DateTime.parse(j['issuedAt'] as String)
          : null,
      expiresAt: j['expiresAt'] != null
          ? DateTime.parse(j['expiresAt'] as String)
          : null,
      usedAt: j['usedAt'] != null
          ? DateTime.parse(j['usedAt'] as String)
          : null,
    );
  }

  GiftcardIssueStatus _statusFromString(String? s) {
    switch (s) {
      case 'issued':
        return GiftcardIssueStatus.issued;
      case 'failed':
        return GiftcardIssueStatus.failed;
      case 'cancelled':
        return GiftcardIssueStatus.cancelled;
      case 'expired':
        return GiftcardIssueStatus.expired;
      case 'requested':
      default:
        return GiftcardIssueStatus.requested;
    }
  }
}
