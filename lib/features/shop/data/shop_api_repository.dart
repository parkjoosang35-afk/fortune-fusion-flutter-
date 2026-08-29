import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/shop_models.dart';
import 'shop_repository.dart';

/// [ShopRepository] 실 API 구현체 — admin_web `/api/public/shop/*`,
/// `/api/public/inventory` 엔드포인트와 통신한다.
///
/// [절대 원칙] 가격 신뢰 원칙에 따라 `purchase()`는 절대 price를 body에
/// 담아 보내지 않는다. 서버가 `ShopCatalogItem.price`를 재조회해서만
/// 차감하므로, 클라이언트는 itemType/itemCode만 전달한다.
class ApiShopRepository implements ShopRepository {
  String get _shopBase => '${EnvConfig.adminApiBaseUrl}/api/public/shop';
  String get _inventoryBase =>
      '${EnvConfig.adminApiBaseUrl}/api/public/inventory';

  Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final auth = await AuthTokenStore.authHeader();
    return {if (json) 'Content-Type': 'application/json', ...auth};
  }

  Never _fail(String context, Object error) {
    debugPrint('[ApiShopRepository] [$context] 실패 -> $error');
    throw Exception('$context 요청에 실패했습니다: $error');
  }

  Future<List<ShopCatalogItem>> _fetchCatalog(String path) async {
    final uri = Uri.parse('$_shopBase/$path');
    try {
      final res = await http.get(uri);
      final body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode != 200 || body['success'] != true) {
        _fail('GET /shop/$path', body['error'] ?? res.statusCode);
      }
      final data = body['data'] as List<dynamic>? ?? const [];
      return data
          .map((e) => ShopCatalogItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is Exception) rethrow;
      _fail('GET /shop/$path', e);
    }
  }

  @override
  Future<List<ShopCatalogItem>> fetchSeals() => _fetchCatalog('seals');

  @override
  Future<List<ShopCatalogItem>> fetchCandles() => _fetchCatalog('candles');

  @override
  Future<List<ShopCatalogItem>> fetchTalismans() => _fetchCatalog('talismans');

  @override
  Future<List<InventoryItem>> fetchInventory() async {
    final uri = Uri.parse(_inventoryBase);
    try {
      final res = await http.get(uri, headers: await _authHeaders());
      final body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode != 200 || body['success'] != true) {
        _fail('GET /inventory', body['error'] ?? res.statusCode);
      }
      final data = body['data'] as List<dynamic>? ?? const [];
      return data
          .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is Exception) rethrow;
      _fail('GET /inventory', e);
    }
  }

  @override
  Future<PurchaseResult> purchase({
    required ShopItemType itemType,
    required String itemCode,
  }) async {
    final uri = Uri.parse('$_shopBase/purchase');
    late final http.Response res;
    try {
      res = await http.post(
        uri,
        headers: await _authHeaders(json: true),
        // [가격 신뢰 원칙] price는 절대 전달하지 않는다 — 서버가 재조회한다.
        body: jsonEncode({'itemType': itemType.apiValue, 'itemCode': itemCode}),
      );
    } catch (e) {
      throw ShopException(
        ShopPurchaseFailureReason.unknown,
        '네트워크 오류로 구매에 실패했습니다.',
      );
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ShopException(
        ShopPurchaseFailureReason.unknown,
        '구매 응답을 해석할 수 없습니다.',
      );
    }

    if (res.statusCode == 200 && body['success'] == true) {
      return PurchaseResult.fromJson(body['data'] as Map<String, dynamic>);
    }

    final reasonStr = body['reason'] as String?;
    final message = body['error'] as String? ?? '구매에 실패했습니다.';
    final ShopPurchaseFailureReason reason;
    if (res.statusCode == 404) {
      reason = ShopPurchaseFailureReason.itemNotFound;
    } else if (res.statusCode == 409) {
      reason = ShopPurchaseFailureReason.itemInactive;
    } else if (reasonStr == 'INSUFFICIENT_BALANCE') {
      reason = ShopPurchaseFailureReason.insufficientBalance;
    } else if (res.statusCode == 400) {
      reason = ShopPurchaseFailureReason.itemTypeMismatch;
    } else {
      reason = ShopPurchaseFailureReason.unknown;
    }
    throw ShopException(reason, message);
  }
}
