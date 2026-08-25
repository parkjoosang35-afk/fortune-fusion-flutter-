// 상점(Shop) 공개 API 공용 헬퍼 — bokjumeoni-plan §03 SERVER API
// `GET /shop/seals`, `/shop/candles`, `/shop/talismans`, `POST /shop/purchase`,
// `GET /inventory` 5개 엔드포인트가 이 파일의 DTO 변환/CORS 상수를 공유한다.
import type { ShopCatalogItem, UserInventoryItem } from "@/generated/prisma/client";

export const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

/** ShopCatalogItem.itemType 값 도메인. schema.prisma 주석과 동일. */
export const SHOP_ITEM_TYPES = ["seal", "candle", "talisman"] as const;
export type ShopItemType = (typeof SHOP_ITEM_TYPES)[number];

export function isShopItemType(v: unknown): v is ShopItemType {
  return typeof v === "string" && (SHOP_ITEM_TYPES as readonly string[]).includes(v);
}

/** ShopCatalogItem(Prisma row) → Flutter 상점 화면 대응 DTO. */
export function toShopCatalogDto(item: ShopCatalogItem) {
  return {
    itemType: item.itemType,
    itemCode: item.itemCode,
    nameKo: item.nameKo,
    descriptionKo: item.descriptionKo,
    price: item.price,
    durationDays: item.durationDays,
    displayPriority: item.displayPriority,
    isActive: item.isActive,
  };
}

/** UserInventoryItem(+catalogItem include) → Flutter 보물함 화면 대응 DTO. */
export function toInventoryItemDto(
  row: UserInventoryItem & { catalogItem: ShopCatalogItem }
) {
  const expiresAt = row.expiresAt ? row.expiresAt.toISOString() : null;
  const isExpired = row.expiresAt != null && row.expiresAt.getTime() <= Date.now();
  return {
    id: row.id,
    itemType: row.catalogItem.itemType,
    itemCode: row.catalogItem.itemCode,
    nameKo: row.catalogItem.nameKo,
    descriptionKo: row.catalogItem.descriptionKo,
    purchasePrice: row.purchasePrice,
    purchasedAt: row.createdAt.toISOString(),
    expiresAt,
    isExpired,
  };
}
