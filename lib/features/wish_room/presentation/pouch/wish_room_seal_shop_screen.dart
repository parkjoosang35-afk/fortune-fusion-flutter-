import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/wish_room_provider.dart';
import '../../domain/wish_room_models.dart';
import '../../theme/wish_room_colors.dart';
import '../../theme/wish_room_text_styles.dart';
import '../../widgets/wish_room_sigils.dart';
import '../../widgets/wish_room_pouch_widgets.dart';
import '../wish_room_shortage_dialog.dart';

/// 10. 인장 상점 — 출처: PouchScreens.jsx `ScreenSealShop`
class WishRoomSealShopScreen extends StatelessWidget {
  const WishRoomSealShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    final provider = context.watch<WishRoomProvider>();
    final seals = WishRoomCatalog.seals;

    return WishRoomPouchBg(
      palette: palette,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.5),
                child: WishRoomSigil(size: 280, color: palette.sigil, opacity: 0.18),
              ),
            ),
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
                        WishRoomPouchMonoLabel(text: 'SEAL SHOP · 봉인 인장', palette: palette),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('더 귀한 인장으로\n봉인하기', style: WishRoomText.h1(palette.fg).copyWith(fontSize: 22)),
                          const SizedBox(height: 8),
                          Text('소원마다 다른 인장을 골라 담아 두세요.',
                              style: WishRoomText.body(palette.muted).copyWith(fontSize: 12)),
                        ],
                      ),
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
                        itemCount: seals.length,
                        itemBuilder: (context, i) {
                          final s = seals[i];
                          final owned = provider.inventory.seals.contains(s.id);
                          return WishRoomRewardTile(
                            icon: Transform.rotate(
                              angle: -6 * 3.14159 / 180,
                              child: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: palette.accent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.black.withValues(alpha: 0.2)),
                                  boxShadow: [
                                    BoxShadow(color: palette.accent.withValues(alpha: 0.5), blurRadius: 8),
                                  ],
                                ),
                                child: Text(
                                  s.name,
                                  style: TextStyle(
                                    fontFamily: WishRoomText.fontDisplay,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    color: WishRoomColors.sealTextColor,
                                  ),
                                ),
                              ),
                            ),
                            name: s.name,
                            sub: s.sub,
                            cost: s.cost,
                            owned: owned,
                            palette: palette,
                            onTap: () => _handleBuy(context, provider, s),
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

  Future<void> _handleBuy(BuildContext context, WishRoomProvider provider, WishRoomCatalogItem s) async {
    if (provider.inventory.seals.contains(s.id)) return;
    try {
      await provider.buySeal(s.id);
    } on WishRoomShortageException catch (e) {
      if (!context.mounted) return;
      await showWishRoomShortageDialog(
        context,
        itemName: e.itemName,
        itemIcon: Text(s.name, style: const TextStyle(fontSize: 22)),
        need: e.need,
        have: e.have,
        onGoEarn: () => Navigator.of(context).maybePop(),
        onWatchAd: () => Navigator.of(context).maybePop(),
      );
    }
  }
}
