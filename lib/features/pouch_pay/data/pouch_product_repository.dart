// [Google Play Billing 실연동 — 2026-11-26] admin_web이 새로 제공하는
// GET /api/public/pouch/products 를 호출해 복주머니 충전상품 카탈로그를
// 가져온다. 지금까지 하드코딩되어 있던 `kPouchPacks`(pouch_pay_catalog.dart)와
// 동일한 6종이 서버에 시드되어 있으므로(dev-seed-pouch-products.ts), 기존 화면은
// 그대로 두고 이 레포지토리가 반환하는 [PouchProductModel] 쪽에만
// `googlePlayProductId`가 추가로 실려온다 — 이 필드가 채워진 상품만 실결제
// 버튼이 활성화된다(PouchPayService 참고).
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';

/// 서버 PouchProduct 1건. pouch_pay_catalog.dart의 PouchPack과 필드가
/// 거의 동일하지만, 서버가 실제 소스(SoT)이므로 별도 모델로 분리한다.
class PouchProductModel {
  final String id; // clientId (p100 등) — PouchPack.id와 호환
  final String name;
  final int base;
  final int bonus;
  final int price;
  final String? tag;
  /// Play Console "일회성 제품" 상품 ID. null이면 아직 등록 전(정책준비중) —
  /// 이 경우 실결제 버튼을 비활성화해야 한다.
  final String? googlePlayProductId;

  const PouchProductModel({
    required this.id,
    required this.name,
    required this.base,
    required this.bonus,
    required this.price,
    this.tag,
    this.googlePlayProductId,
  });

  int get total => base + bonus;
  int get bonusPct => base == 0 ? 0 : ((bonus / base) * 100).round();

  bool get canRealPurchase => googlePlayProductId != null && googlePlayProductId!.isNotEmpty;
}

class PouchProductRepository {
  static String get _base => '${EnvConfig.adminApiBaseUrl}/api/public/pouch';

  Future<ApiResult<List<PouchProductModel>>> getProducts() async {
    final uri = Uri.parse('$_base/products');
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '복주머니 상품을 불러오지 못했습니다.',
        );
      }
      final list = (decoded['data'] as List<dynamic>)
          .map((e) => _fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[PouchProductRepository] [getProducts] 예외 -> $e');
      return ApiResult.fail('복주머니 상품을 불러오지 못했습니다: $e');
    }
  }

  /// [Google Play Billing 실연동] Flutter가 Google Play 결제를 완료시킨 뒤
  /// 받은 purchaseToken을 서버로 보내 실제 검증 + 복주머니 지급을 요청한다.
  /// 반환값은 실제로 지급된 복주머니 총량(알림용) — 잔액 자체는 호출부가
  /// 별도로 LuckPouchProvider.load()를 호출해 서버 최신값으로 갱신해야 한다.
  Future<ApiResult<int>> confirmRealPurchase({
    required String googlePlayProductId,
    required String purchaseToken,
  }) async {
    final uri = Uri.parse('$_base/confirm-purchase');
    try {
      final headers = {
        'Content-Type': 'application/json',
        ...await AuthTokenStore.authHeader(),
      };
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'googlePlayProductId': googlePlayProductId,
              'purchaseToken': purchaseToken,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '복주머니 결제 확인에 실패했습니다.');
      }
      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok((data['grantedAmount'] as num?)?.toInt() ?? 0);
    } catch (e) {
      debugPrint('[PouchProductRepository] [confirmRealPurchase] 예외 -> $e');
      return ApiResult.fail('복주머니 결제 확인 중 오류가 발생했습니다: $e');
    }
  }

  PouchProductModel _fromJson(Map<String, dynamic> j) {
    return PouchProductModel(
      id: j['id'] as String,
      name: j['name'] as String,
      base: (j['base'] as num?)?.toInt() ?? 0,
      bonus: (j['bonus'] as num?)?.toInt() ?? 0,
      price: (j['price'] as num?)?.toInt() ?? 0,
      tag: j['tag'] as String?,
      googlePlayProductId: j['googlePlayProductId'] as String?,
    );
  }
}
