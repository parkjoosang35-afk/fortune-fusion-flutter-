import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/wish_room_provider.dart';
import '../../domain/wish_room_models.dart';
import '../../theme/wish_room_colors.dart';
import '../../theme/wish_room_text_styles.dart';
import '../../widgets/wish_room_sigils.dart';
import '../../widgets/wish_room_pouch_widgets.dart';
import '../wish_room_shortage_dialog.dart';

/// 11. 촛불 상점 — 출처: PouchScreens.jsx `ScreenCandleShop`
class WishRoomCandleShopScreen extends StatelessWidget {
  const WishRoomCandleShopScreen({super.key});

  static const _candleColors = [
    Color(0xFFF5A8B8), // 연꽃초
    Color(0xFFE8C8F5), // 별초
    Color(0xFFC8A8FF), // 향초
    Color(0xFFFFB87F), // 촛농이 별이 되는 초
  ];

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    final provider = context.watch<WishRoomProvider>();
    final candles = WishRoomCatalog.candles;

    return WishRoomPouchBg(
      palette: palette,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.5),
                child: WishRoomSigil(size: 280, color: palette.sigil, opacity: 0.16),
              ),
            ),
            Positioned.fill(child: WishRoomDust(count: 8, color: palette.glow)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        WishRoomPouchIconButton(
                          icon: Icons.arrow_back,
                          palette: palette,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        WishRoomPouchMonoLabel(text: 'CANDLE · 촛불', palette: palette),
                        WishRoomShardCounter(
                          count: provider.balance,
                          sizeVariant: WishRoomShardCounterSize.sm,
                          textColor: palette.fg,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('어떤 촛불로\n밝히시겠어요', style: WishRoomText.h1(palette.fg).copyWith(fontSize: 22)),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: candles.length,
                        itemBuilder: (context, i) {
                          final c = candles[i];
                          final owned = provider.inventory.candles.contains(c.id);
                          final color = _candleColors[i % _candleColors.length];
                          return WishRoomRewardTile(
                            icon: SizedBox(
                              width: 32,
                              height: 44,
                              child: Stack(
                                alignment: Alignment.topCenter,
                                children: [
                                  Positioned(
                                    top: 0,
                                    child: Container(
                                      width: 12,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          colors: [const Color(0xFFFFF8DD), const Color(0xFFFFD47A), color.withValues(alpha: 0.3)],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [BoxShadow(color: color, blurRadius: 8)],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 18,
                                    child: Container(
                                      width: 18,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.white.withValues(alpha: 0.15), color, color, Colors.black.withValues(alpha: 0.2)],
                                          stops: const [0.0, 0.3, 0.7, 1.0],
                                        ),
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10)],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            name: c.name,
                            sub: c.sub,
                            cost: c.cost,
                            owned: owned,
                            palette: palette,
                            onTap: () => _handleBuy(context, provider, c),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBuy(BuildContext context, WishRoomProvider provider, WishRoomCatalogItem c) async {
    if (provider.inventory.candles.contains(c.id)) return;
    try {
      await provider.buyCandle(c.id);
    } on WishRoomShortageException catch (e) {
      if (!context.mounted) return;
      await showWishRoomShortageDialog(
        context,
        itemName: e.itemName,
        itemIcon: const Icon(Icons.local_fire_department, size: 22),
        need: e.need,
        have: e.have,
        onGoEarn: () => Navigator.of(context).maybePop(),
        onWatchAd: () => Navigator.of(context).maybePop(),
      );
    }
  }
}
