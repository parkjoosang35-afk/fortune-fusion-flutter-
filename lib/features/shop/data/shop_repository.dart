import '../domain/shop_models.dart';

/// 상점(Shop) Repository 인터페이스 — bokjumeoni-plan §03 SERVER API
/// `GET /shop/seals|candles|talismans`, `POST /shop/purchase`,
/// `GET /inventory` 5개 엔드포인트에 대응한다.
///
/// [아키텍처 패턴] `wish_wall_repository.dart` / `wish_wall_api_repository.dart`
/// 와 동일한 인터페이스+구현체 분리 패턴을 따른다. 현재는 [ApiShopRepository]
/// 단일 구현체만 존재한다(Mock 없음 — 서버 API가 이미 완성되어 있으므로).
abstract class ShopRepository {
  /// 인장 카탈로그. 비로그인 사용자도 조회 가능(구매 전 미리보기).
  Future<List<ShopCatalogItem>> fetchSeals();

  /// 촛불 카탈로그. 비로그인 사용자도 조회 가능.
  Future<List<ShopCatalogItem>> fetchCandles();

  /// 부적 카탈로그. 비로그인 사용자도 조회 가능.
  Future<List<ShopCatalogItem>> fetchTalismans();

  /// 로그인 사용자의 보유 인벤토리(인장/촛불/부적 전체). 보물함 화면과
  /// 상점 화면의 "owned" 뱃지 표시에 공용으로 사용된다.
  Future<List<InventoryItem>> fetchInventory();

  /// 상품 구매. 서버가 가격을 재조회해 원자적으로 처리한다(클라이언트는
  /// itemType/itemCode만 전달 — price는 절대 보내지 않는다).
  ///
  /// 실패 시 [ShopException]을 던진다(reason으로 UI 분기).
  Future<PurchaseResult> purchase({
    required ShopItemType itemType,
    required String itemCode,
  });
}
