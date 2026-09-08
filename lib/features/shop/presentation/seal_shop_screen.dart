import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../luckpouch/application/luck_pouch_provider.dart';
import '../../wish_room/theme/wish_room_theme.dart';
import '../../wish_room/widgets/wish_room_bg_atmosphere.dart';
import '../../wish_room/widgets/wish_room_seal.dart';
import '../application/shop_provider.dart';
import '../domain/shop_item_visuals.dart';
import '../domain/shop_models.dart';
import '../widgets/shop_purchase_effect.dart';
import '../widgets/shop_widgets.dart';

const String _sealShopGuideSeenKey = 'shop_guide_seen_seal';

/// 인장 상점 — bokjumeoni-plan `03-dev-spec.html` `SealShopScreen` 코드
/// 스펙 및 `new-screens.jsx`의 `ScreenSealShop` 픽셀 디자인을 그대로
/// Flutter로 재구현한다. 2열 그리드, 옥/은/거북/학/금박 5종.
class SealShopScreen extends StatefulWidget {
  const SealShopScreen({super.key});

  @override
  State<SealShopScreen> createState() => _SealShopScreenState();
}

class _SealShopScreenState extends State<SealShopScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<ShopProvider>().loadAll();
      // [요청1 — 사용법 안내창] 처음 방문한 경우에만 자동으로 안내를 띄운다.
      // 이후에는 ShopHeader의 "?" 아이콘으로 언제든 다시 열 수 있다.
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final seen = prefs.getBool(_sealShopGuideSeenKey) ?? false;
      if (!seen) {
        await prefs.setBool(_sealShopGuideSeenKey, true);
        if (!mounted) return;
        ShopGuideDialog.show(context, ShopGuideType.seal);
      }
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
      final visual = sealVisualFor(item.itemCode);
      await showShopPurchaseEffect(
        context,
        glyph: WishRoomSeal(
          text: visual.glyph,
          color: visual.rare ? const Color(0xFFD4AF37) : WishRoomColors.accent,
          size: 72,
        ),
        label: '${item.nameKo}, 좋은 기운이 들어왔어요',
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
            child: WishRoomBgAtmosphere(sigilSize: 340, sigilOpacity: 0.18),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                ShopHeader(
                  title: 'SEAL SHOP · 印章',
                  balance: pouch.balance,
                  guideType: ShopGuideType.seal,
                ),
                const ShopIntro(
                  title: '소원을 봉인할\n새 인장을 만나보세요',
                  sub: '구매하면 정해진 기간 동안 보유돼요 · 소원을 봉인할 때 골라 쓰세요.',
                ),
                Expanded(
                  child: shop.isLoading && shop.seals.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: WishRoomColors.glow,
                          ),
                        )
                      : shop.seals.isEmpty
                      ? Center(
                          child: Text(
                            '판매 중인 인장이 없어요',
                            style: WishRoomTextStyles.bodySm,
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.9,
                              ),
                          itemCount: shop.seals.length,
                          itemBuilder: (_, i) {
                            final item = shop.seals[i];
                            return _SealTile(
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
                const ShopSubNav(active: 'seal'),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 보유 중인 인장의 인벤토리 항목을 찾아 남은 기간(일)을 계산한다.
  /// 동일 itemCode가 여러 개면 만료일이 가장 늦은 항목을 쓴다.
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

class _SealTile extends StatelessWidget {
  const _SealTile({
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
    final visual = sealVisualFor(item.itemCode);
    return InkWell(
      onTap: item.owned || isPurchasing ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        decoration: BoxDecoration(
          color: WishRoomColors.surfaceCard,
          border: Border.all(
            color: visual.rare
                ? WishRoomColors.glow
                : WishRoomColors.surfaceCardBorder,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            WishRoomSeal(
              text: visual.glyph,
              color: visual.rare
                  ? const Color(0xFFD4AF37)
                  : WishRoomColors.accent,
              size: 44,
            ),
            const SizedBox(height: 8),
            Text(
              item.nameKo,
              style: const TextStyle(
                fontFamily: 'GowunBatangWish',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: WishRoomColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              item.owned && remainingDays != null
                  ? '$remainingDays일 남음'
                  : item.durationDays != null
                  ? '${item.durationDays}일간 보유'
                  : item.descriptionKo,
              style: const TextStyle(
                fontSize: 10,
                color: WishRoomColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
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
