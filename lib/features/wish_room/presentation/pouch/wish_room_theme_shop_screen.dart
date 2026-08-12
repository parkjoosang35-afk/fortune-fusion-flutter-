import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/wish_room_provider.dart';
import '../../application/wish_room_shortage_policy.dart';
import '../../domain/wish_room_models.dart';
import '../../theme/wish_room_colors.dart';
import '../../theme/wish_room_text_styles.dart';
import '../../widgets/wish_room_sigils.dart';
import '../../widgets/wish_room_pouch_widgets.dart';
import '../wish_room_shortage_dialog.dart';
import 'wish_room_ad_watch_screen.dart';
import 'wish_room_earn_list_screen.dart';

/// 12. 테마 상점 — 출처: PouchScreens.jsx `ScreenThemeShop`
class WishRoomThemeShopScreen extends StatelessWidget {
  const WishRoomThemeShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    final provider = context.watch<WishRoomProvider>();
    final themes = WishRoomCatalog.themes;

    final previewPalettes = {
      'theme_midnight': WishRoomColors.midnight,
      'theme_hanji': WishRoomColors.hanji,
      'theme_crystal': WishRoomColors.crystal,
    };

    return WishRoomPouchBg(
      palette: palette,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.5),
                child: WishRoomSigil(
                  size: 240,
                  color: palette.sigil,
                  opacity: 0.15,
                ),
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
                        WishRoomPouchMonoLabel(
                          text: 'THEME · 소원방 테마',
                          palette: palette,
                        ),
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
                      child: Text(
                        '소원방의 하늘\n바꿔 담기',
                        style: WishRoomText.h1(
                          palette.fg,
                        ).copyWith(fontSize: 22),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.separated(
                        itemCount: themes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final t = themes[i];
                          final owned = provider.inventory.themes.contains(
                            t.id,
                          );
                          final isCurrent = _themeIdFor(t.id) == provider.theme;
                          final preview =
                              previewPalettes[t.id] ?? WishRoomColors.midnight;
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: palette.card,
                              border: Border.all(
                                color: isCurrent ? palette.glow : palette.line,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: palette.line),
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [preview.bg1, preview.bg2],
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: preview.glow,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: preview.glow,
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: preview.crystal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        t.name,
                                        style: WishRoomText.h3(palette.fg),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isCurrent ? '지금 사용 중' : t.sub,
                                        style: WishRoomText.monoSm(
                                          palette.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: palette.glowShadow,
                                      border: Border.all(color: palette.glow),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '사용 중',
                                      style: WishRoomText.body(palette.glow)
                                          .copyWith(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  )
                                else if (owned)
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: palette.line),
                                      shape: const StadiumBorder(),
                                    ),
                                    onPressed: () =>
                                        provider.setTheme(_themeIdFor(t.id)),
                                    child: Text(
                                      '바꾸기',
                                      style: WishRoomText.body(
                                        palette.fg,
                                      ).copyWith(fontSize: 11),
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTap: () =>
                                        _handleBuy(context, provider, t),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: palette.glowShadow,
                                        border: Border.all(color: palette.glow),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const WishRoomShard(size: 11),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${t.cost}',
                                            style: TextStyle(
                                              fontFamily:
                                                  WishRoomText.fontDisplay,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                              color: palette.glow,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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

  static WishRoomThemeId _themeIdFor(String catalogId) => switch (catalogId) {
    'theme_hanji' => WishRoomThemeId.hanji,
    'theme_crystal' => WishRoomThemeId.crystal,
    _ => WishRoomThemeId.midnight,
  };

  Future<void> _handleBuy(
    BuildContext context,
    WishRoomProvider provider,
    WishRoomCatalogItem t,
  ) async {
    if (provider.inventory.themes.contains(t.id)) return;
    try {
      await provider.buyTheme(t.id);
    } on WishRoomShortageException catch (e) {
      if (!context.mounted) return;
      final offerAd = wishRoomShouldOfferAdShortcut(
        provider,
        shortage: e.need - e.have,
        itemCost: e.need,
      );
      await showWishRoomShortageDialog(
        context,
        itemName: e.itemName,
        itemIcon: const Icon(Icons.palette, size: 22),
        need: e.need,
        have: e.have,
        onGoEarn: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WishRoomEarnListScreen()),
        ),
        onWatchAd: offerAd
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WishRoomAdWatchScreen(),
                ),
              )
            : null,
      );
    }
  }
}
