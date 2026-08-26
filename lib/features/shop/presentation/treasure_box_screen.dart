import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../wish_room/theme/wish_room_theme.dart';
import '../../wish_room/widgets/wish_room_bg_atmosphere.dart';
import '../../wish_room/widgets/wish_room_candle.dart';
import '../../wish_room/widgets/wish_room_seal.dart';
import '../application/shop_provider.dart';
import '../domain/shop_item_visuals.dart';
import '../domain/shop_models.dart';
import '../widgets/shop_widgets.dart';

/// 보물함 — `new-screens.jsx`의 `ScreenTreasureBox` 픽셀 디자인을 그대로
/// 재구현한다. 원본은 인장/촛불 2개 섹션이지만, 우리 카탈로그는 부적도
/// 판매하므로 동일한 4열 그리드 패턴을 부적 섹션까지 확장했다.
///
/// [데이터 출처] 카탈로그(인장/촛불/부적) 전체 목록을 그리드로 나열하고,
/// [ShopProvider.loadAll]이 `GET /inventory` 조회 결과로 채워 넣은
/// [ShopCatalogItem.owned] 플래그로 보유/미보유 상태를 렌더링한다.
class TreasureBoxScreen extends StatefulWidget {
  const TreasureBoxScreen({super.key});

  @override
  State<TreasureBoxScreen> createState() => _TreasureBoxScreenState();
}

class _TreasureBoxScreenState extends State<TreasureBoxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ShopProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();

    final ownedSeals = shop.seals.where((e) => e.owned).length;
    final ownedCandles = shop.candles.where((e) => e.owned).length;
    final ownedTalismans = shop.talismans.where((e) => e.owned).length;
    final totalOwned = ownedSeals + ownedCandles + ownedTalismans;
    final total = shop.seals.length + shop.candles.length + shop.talismans.length;

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: WishRoomBgAtmosphere(sigilSize: 280, sigilOpacity: 0.14),
          ),
          SafeArea(
            child: shop.isLoading && shop.seals.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: WishRoomColors.glow),
                  )
                : Column(
                    children: [
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _IconBtn(
                              icon: Icons.arrow_back,
                              onTap: () => Navigator.of(context).maybePop(),
                            ),
                            Text(
                              'TREASURE · 寶物匣',
                              style: WishRoomTextStyles.eyebrow,
                            ),
                            const SizedBox(width: 34, height: 34),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('나의 보물함', style: WishRoomTextStyles.screenTitle),
                                    const SizedBox(height: 6),
                                    Text(
                                      '매일 하나씩, 조용히 채워지는 나만의 함',
                                      style: WishRoomTextStyles.bodySm,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '◇ $totalOwned / $total  ·  인장 $ownedSeals · 촛불 $ownedCandles · 부적 $ownedTalismans',
                                      style: const TextStyle(
                                        fontFamily: 'IBMPlexMonoWish',
                                        fontSize: 10,
                                        letterSpacing: 2,
                                        color: WishRoomColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _SectionLabel('◈ 인장'),
                              _SealGrid(items: shop.seals),
                              const SizedBox(height: 12),
                              _SectionLabel('◈ 촛불'),
                              _CandleGrid(items: shop.candles),
                              const SizedBox(height: 12),
                              _SectionLabel('◈ 부적'),
                              _TalismanGrid(items: shop.talismans),
                              const SizedBox(height: 16),
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 20),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: WishRoomColors.surfaceCard,
                                  border: Border.all(
                                    color: WishRoomColors.surfaceCardBorder,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '"모아둔 것들이 어느새 이만큼."',
                                  textAlign: TextAlign.center,
                                  style: WishRoomTextStyles.bodySm.copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const ShopSubNav(active: 'treasure'),
                      const SizedBox(height: 16),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: WishRoomColors.surfaceCard,
          border: Border.all(color: WishRoomColors.surfaceCardBorder),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: WishRoomColors.textPrimary),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'GowunBatangWish',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: WishRoomColors.textPrimary,
        ),
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({required this.owned, required this.child});
  final bool owned;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: owned ? WishRoomColors.surfaceCard : Colors.transparent,
          border: owned
              ? Border.all(color: WishRoomColors.glowShadow)
              : Border.all(color: WishRoomColors.surfaceCardBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _SealGrid extends StatelessWidget {
  const _SealGrid({required this.items});
  final List<ShopCatalogItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          final visual = sealVisualFor(item.itemCode);
          return _GridCell(
            owned: item.owned,
            child: item.owned
                ? WishRoomSeal(
                    text: visual.glyph,
                    color: visual.rare
                        ? const Color(0xFFD4AF37)
                        : WishRoomColors.accent,
                    size: 30,
                  )
                : Text(
                    visual.glyph,
                    style: TextStyle(
                      fontFamily: 'NotoSerifKRWish',
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: WishRoomColors.textSecondary.withValues(alpha: 0.35),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _CandleGrid extends StatelessWidget {
  const _CandleGrid({required this.items});
  final List<ShopCatalogItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          final color = candleColorFor(item.itemCode);
          return _GridCell(
            owned: item.owned,
            child: Opacity(
              opacity: item.owned ? 1.0 : 0.3,
              child: WishRoomCandle(
                size: 30,
                color: item.owned ? color : WishRoomColors.textSecondary,
                lit: item.owned,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TalismanGrid extends StatelessWidget {
  const _TalismanGrid({required this.items});
  final List<ShopCatalogItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          final visual = talismanVisualFor(item.itemCode);
          return _GridCell(
            owned: item.owned,
            child: Opacity(
              opacity: item.owned ? 1.0 : 0.3,
              child: Text(visual.icon, style: const TextStyle(fontSize: 22)),
            ),
          );
        },
      ),
    );
  }
}
