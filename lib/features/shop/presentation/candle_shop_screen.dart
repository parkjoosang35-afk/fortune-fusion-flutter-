import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../luckpouch/application/luck_pouch_provider.dart';
import '../../wish_room/theme/wish_room_theme.dart';
import '../../wish_room/widgets/wish_room_bg_atmosphere.dart';
import '../../wish_room/widgets/wish_room_candle.dart';
import '../application/shop_provider.dart';
import '../domain/shop_item_visuals.dart';
import '../domain/shop_models.dart';
import '../widgets/shop_purchase_effect.dart';
import '../widgets/shop_widgets.dart';

/// 촛불 상점 — `new-screens.jsx`의 `ScreenCandleShop` 픽셀 디자인을 그대로
/// Flutter로 재구현한다. 세로 리스트, 연꽃/향초/별초(rare)/유촉(rare) 4종.
class CandleShopScreen extends StatefulWidget {
  const CandleShopScreen({super.key});

  @override
  State<CandleShopScreen> createState() => _CandleShopScreenState();
}

class _CandleShopScreenState extends State<CandleShopScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ShopProvider>().loadAll();
    });
  }

  Future<void> _handlePurchase(ShopCatalogItem item) async {
    final pouch = context.read<LuckPouchProvider>();
    if (pouch.balance < item.price) {
      await ShortageDialog.show(
        context,
        item: item,
        need: item.price,
        have: pouch.balance,
      );
      return;
    }
    final ok = await PurchaseConfirmSheet.show(context, item: item);
    if (ok != true || !mounted) return;
    final shop = context.read<ShopProvider>();
    final success = await shop.purchase(item);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(shop.lastPurchaseError ?? '구매에 실패했습니다.')),
      );
    } else {
      final color = candleColorFor(item.itemCode);
      await showShopPurchaseEffect(
        context,
        glyph: WishRoomCandle(size: 60, color: color, lit: true),
        label: '${item.nameKo}, 손으로 짤예요',
        sublabel: item.durationDays != null
            ? '${item.durationDays}일간 보유돼요'
            : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final pouch = context.watch<LuckPouchProvider>();

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: WishRoomBgAtmosphere(sigilSize: 340, sigilOpacity: 0.16),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                ShopHeader(title: 'CANDLE SHOP · 燭', balance: pouch.balance),
                const ShopIntro(
                  title: '소원을 밝혀줄\n특별한 촛불',
                  sub: '소원 하나에 하나의 촛불을 골라주세요.',
                ),
                Expanded(
                  child: shop.isLoading && shop.candles.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: WishRoomColors.glow,
                          ),
                        )
                      : shop.candles.isEmpty
                      ? Center(
                          child: Text(
                            '판매 중인 촛불이 없어요',
                            style: WishRoomTextStyles.bodySm,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: shop.candles.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final item = shop.candles[i];
                            return _CandleTile(
                              item: item,
                              remainingDays: item.owned
                                  ? _remainingDaysFor(shop, item.itemCode)
                                  : null,
                              isPurchasing: shop.isPurchasing(item.itemCode),
                              onTap: () => _handlePurchase(item),
                            );
                          },
                        ),
                ),
                const ShopSubNav(active: 'candle'),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 보유 중인 촛불의 인벤토리 항목을 찾아 남은 기간(일)을 계산한다.
  int? _remainingDaysFor(ShopProvider shop, String itemCode) {
    final matches = shop.inventory.where(
      (e) => e.itemCode == itemCode && !e.isExpired,
    );
    if (matches.isEmpty) return null;
    InventoryItem latest = matches.first;
    for (final m in matches) {
      if ((m.expiresAt?.millisecondsSinceEpoch ?? 0) >
          (latest.expiresAt?.millisecondsSinceEpoch ?? 0)) {
        latest = m;
      }
    }
    return latest.remainingDays;
  }
}

class _CandleTile extends StatelessWidget {
  const _CandleTile({
    required this.item,
    required this.remainingDays,
    required this.isPurchasing,
    required this.onTap,
  });

  final ShopCatalogItem item;
  final int? remainingDays;
  final bool isPurchasing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = candleColorFor(item.itemCode);
    final rare = rareCandleCodes.contains(item.itemCode);
    return InkWell(
      onTap: item.owned || isPurchasing ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: WishRoomColors.surfaceCard,
          border: Border.all(
            color: rare ? WishRoomColors.glow : WishRoomColors.surfaceCardBorder,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: WishRoomCandle(size: 28, color: color, lit: true),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nameKo,
                    style: const TextStyle(
                      fontFamily: 'GowunBatangWish',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: WishRoomColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.owned && remainingDays != null
                        ? '${item.descriptionKo} · $remainingDays일 남음'
                        : item.durationDays != null
                        ? '${item.descriptionKo} · ${item.durationDays}일간 보유'
                        : item.descriptionKo,
                    style: const TextStyle(
                      fontSize: 11,
                      color: WishRoomColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ShopPriceBadge(
              owned: item.owned,
              price: item.price,
              isPurchasing: isPurchasing,
              ownedLabel: '보유중',
            ),
          ],
        ),
      ),
    );
  }
}
