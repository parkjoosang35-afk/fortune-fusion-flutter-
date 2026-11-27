/// 상점(Shop) 도메인 모델 — bokjumeoni-plan §03 SERVER API 대응.
///
/// [데이터 출처] admin_web `src/app/api/public/shop/_shared.ts`의
/// `toShopCatalogDto()` / `toInventoryItemDto()`가 내려주는 JSON 구조를
/// 그대로 따른다(필드 추가/누락 없이 서버 응답과 1:1 매핑).
library;

/// ShopCatalogItem.itemType 값 도메인 — 서버 `_shared.ts`의
/// `SHOP_ITEM_TYPES = ["seal", "candle", "talisman"]`과 동일.
enum ShopItemType { seal, candle, talisman }

extension ShopItemTypeX on ShopItemType {
  String get apiValue {
    switch (this) {
      case ShopItemType.seal:
        return 'seal';
      case ShopItemType.candle:
        return 'candle';
      case ShopItemType.talisman:
        return 'talisman';
    }
  }

  static ShopItemType fromApiValue(String value) {
    switch (value) {
      case 'seal':
        return ShopItemType.seal;
      case 'candle':
        return ShopItemType.candle;
      case 'talisman':
        return ShopItemType.talisman;
      default:
        throw ArgumentError('알 수 없는 itemType: $value');
    }
  }
}

/// 상점 카탈로그 1개 품목 — `GET /shop/seals|candles|talismans` 응답 항목.
class ShopCatalogItem {
  final ShopItemType itemType;
  final String itemCode;
  final String nameKo;
  final String descriptionKo;
  final int price;
  final int? durationDays;
  final int displayPriority;
  final bool isActive;

  /// [클라이언트 전용 필드] 서버 카탈로그 응답에는 없는 값으로, 사용자의
  /// 보유 여부(`GET /inventory` 조회 결과와 대조)를 화면에 표시하기 위해
  /// [ShopProvider]가 채워 넣는다. 카탈로그 API 자체는 이 필드를 모른다.
  final bool owned;

  const ShopCatalogItem({
    required this.itemType,
    required this.itemCode,
    required this.nameKo,
    required this.descriptionKo,
    required this.price,
    required this.durationDays,
    required this.displayPriority,
    required this.isActive,
    this.owned = false,
  });

  factory ShopCatalogItem.fromJson(Map<String, dynamic> json) {
    return ShopCatalogItem(
      itemType: ShopItemTypeX.fromApiValue(json['itemType'] as String),
      itemCode: json['itemCode'] as String,
      nameKo: json['nameKo'] as String? ?? '',
      descriptionKo: json['descriptionKo'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      durationDays: (json['durationDays'] as num?)?.toInt(),
      displayPriority: (json['displayPriority'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  ShopCatalogItem copyWith({bool? owned}) {
    return ShopCatalogItem(
      itemType: itemType,
      itemCode: itemCode,
      nameKo: nameKo,
      descriptionKo: descriptionKo,
      price: price,
      durationDays: durationDays,
      displayPriority: displayPriority,
      isActive: isActive,
      owned: owned ?? this.owned,
    );
  }
}

/// 사용자가 보유한 인벤토리 품목 — `GET /inventory` 응답 항목이자
/// `POST /shop/purchase` 성공 응답의 데이터 본문.
class InventoryItem {
  final int id;
  final ShopItemType itemType;
  final String itemCode;
  final String nameKo;
  final String descriptionKo;
  final int purchasePrice;
  final DateTime purchasedAt;
  final DateTime? expiresAt;
  final bool isExpired;

  const InventoryItem({
    required this.id,
    required this.itemType,
    required this.itemCode,
    required this.nameKo,
    required this.descriptionKo,
    required this.purchasePrice,
    required this.purchasedAt,
    required this.expiresAt,
    required this.isExpired,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: (json['id'] as num).toInt(),
      itemType: ShopItemTypeX.fromApiValue(json['itemType'] as String),
      itemCode: json['itemCode'] as String,
      nameKo: json['nameKo'] as String? ?? '',
      descriptionKo: json['descriptionKo'] as String? ?? '',
      purchasePrice: (json['purchasePrice'] as num?)?.toInt() ?? 0,
      purchasedAt:
          DateTime.tryParse(json['purchasedAt'] as String? ?? '') ??
          DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      isExpired: json['isExpired'] as bool? ?? false,
    );
  }

  /// 남은 기간(일). durationDays가 없는 품목(현재는 없음, 향후 영구 품목
  /// 추가 시를 위해 nullable 유지)은 null.
  int? get remainingDays {
    if (expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now()).inHours;
    if (diff <= 0) return 0;
    return (diff / 24).ceil();
  }
}

/// `POST /shop/purchase` 성공 응답 — 인벤토리 항목 + 구매 후 잔액.
class PurchaseResult {
  final InventoryItem item;
  final int walletBalanceAfter;

  const PurchaseResult({required this.item, required this.walletBalanceAfter});

  factory PurchaseResult.fromJson(Map<String, dynamic> json) {
    return PurchaseResult(
      item: InventoryItem.fromJson(json),
      walletBalanceAfter: (json['walletBalanceAfter'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 구매 실패 사유 — 서버 에러코드(`route.ts` catch 분기)를 그대로 매핑.
enum ShopPurchaseFailureReason {
  itemNotFound,
  itemTypeMismatch,
  itemInactive,
  insufficientBalance,
  unknown,
}

/// 상점 API 호출 실패 시 던지는 예외. [reason]으로 UI가 분기 처리할 수
/// 있게 하고, [message]는 사용자에게 그대로 보여줄 수 있는 한국어 문구.
class ShopException implements Exception {
  final ShopPurchaseFailureReason reason;
  final String message;

  const ShopException(this.reason, this.message);

  @override
  String toString() => message;
}
