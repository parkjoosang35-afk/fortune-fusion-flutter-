import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../luckpouch/application/luck_pouch_provider.dart';
import '../../wish_room/theme/wish_room_theme.dart';
import '../../wish_room/widgets/wish_room_bg_atmosphere.dart';
import '../application/shop_provider.dart';
import '../domain/shop_item_visuals.dart';
import '../domain/shop_models.dart';
import '../widgets/shop_widgets.dart';

/// 부적 상점 — bokjumeoni-plan `01-planning.html`에 "부적(지킴/만월/벗)"으로만
/// 언급되어 JSX 명시 코드가 없다. `ScreenCandleShop`의 세로 리스트 패턴을
/// 준용해 자체 설계하되, 부적은 기간제(durationDays)이므로 보유 중인 경우
/// [InventoryItem.remainingDays]를 조회해 "N일 남음"을 함께 표시한다.
class TalismanShopScreen extends StatefulWidget {
  const TalismanShopScreen({super.key});

  @override
  State<TalismanShopScreen> createState() => _TalismanShopScreenState();
}

class _TalismanShopScreenState extends State<TalismanShopScreen> {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.nameKo}을(를) 얻었어요.')),
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
                ShopHeader(title: 'TALISMAN SHOP · 符', balance: pouch.balance),
                const ShopIntro(
                  title: '소원을 지켜줄\n부적을 지녀보세요',
                  sub: '부적은 정해진 기간 동안만 효력이 있어요.',
                ),
                Expanded(
                  child: shop.isLoading && shop.talismans.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: WishRoomColors.glow,
                          ),
                        )
                      : shop.talismans.isEmpty
                      ? Center(
                          child: Text(
                            '판매 중인 부적이 없어요',
                            style: WishRoomTextStyles.bodySm,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: shop.talismans.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final item = shop.talismans[i];
                            final remainingDays = item.owned
                                ? _remainingDaysFor(shop, item.itemCode)
                                : null;
                            return _TalismanTile(
                              item: item,
                              remainingDays: remainingDays,
                              isPurchasing: shop.isPurchasing(item.itemCode),
                              onTap: () => _handlePurchase(item),
                            );
                          },
                        ),
                ),
                const ShopSubNav(active: 'talisman'),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 보유 중인 부적의 인벤토리 항목을 찾아 남은 기간(일)을 계산한다.
  /// 동일 itemCode가 여러 개면 가장 최근 구매(만료일이 가장 늦은) 항목을 쓴다.
  int? _remainingDaysFor(ShopProvider shop, String itemCode) {
    final matches = shop.inventory.where((e) => e.itemCode == itemCode);
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

class _TalismanTile extends StatelessWidget {
  const _TalismanTile({
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
    final visual = talismanVisualFor(item.itemCode);
    return InkWell(
      onTap: item.owned || isPurchasing ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: WishRoomColors.surfaceCard,
          border: Border.all(color: WishRoomColors.surfaceCardBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: visual.color.withValues(alpha: 0.16),
                border: Border.all(color: visual.color.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(visual.icon, style: const TextStyle(fontSize: 20)),
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
                        ? '${item.descriptionKo} · ${item.durationDays}일간 지속'
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
