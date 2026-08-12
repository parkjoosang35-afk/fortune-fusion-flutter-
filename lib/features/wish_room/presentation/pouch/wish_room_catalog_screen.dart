import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/wish_room_provider.dart';
import '../../theme/wish_room_colors.dart';
import '../../theme/wish_room_text_styles.dart';
import '../../widgets/wish_room_sigils.dart';
import '../../widgets/wish_room_pouch_widgets.dart';
import 'wish_room_seal_shop_screen.dart';
import 'wish_room_candle_shop_screen.dart';
import 'wish_room_theme_shop_screen.dart';

/// 09. 사용처 카탈로그 — 출처: PouchScreens.jsx `ScreenCatalog`
class WishRoomCatalogScreen extends StatelessWidget {
  const WishRoomCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    final provider = context.watch<WishRoomProvider>();

    final categories = [
      _CategorySpec('印', '봉인 인장', '5가지 · 30~60', () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WishRoomSealShopScreen()))),
      _CategorySpec('燭', '특별한 촛불', '4가지 · 40~100', () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WishRoomCandleShopScreen()))),
      _CategorySpec('空', '소원방 테마', '2가지 · 50', () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WishRoomThemeShopScreen()))),
      _CategorySpec('贈', '복 나눔', '자유', null),
      _CategorySpec('符', '부적', '2가지 · 60~100', null),
    ];

    return WishRoomPouchBg(
      palette: palette,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.5),
                child: WishRoomSigil(size: 260, color: palette.sigil, opacity: 0.15),
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
                        WishRoomPouchMonoLabel(text: 'CATALOG · 나눠 담기', palette: palette),
                        const SizedBox(width: 34),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '복을 어디에\n나눠 담으시겠어요',
                            style: WishRoomText.h1(palette.fg).copyWith(fontSize: 22),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: palette.card,
                              border: Border.all(color: palette.line),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('지금 담긴', style: WishRoomText.body(palette.muted).copyWith(fontSize: 11)),
                                const SizedBox(width: 8),
                                WishRoomShardCounter(
                                  count: provider.balance,
                                  sizeVariant: WishRoomShardCounterSize.sm,
                                  textColor: palette.fg,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.separated(
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final c = categories[i];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: c.onTap,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: palette.card,
                                  border: Border.all(color: palette.line),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: palette.glow.withValues(alpha: 0.12),
                                        border: Border.all(color: palette.line),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        c.icon,
                                        style: TextStyle(
                                          fontFamily: WishRoomText.fontDisplay,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 22,
                                          color: palette.glow,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(c.name, style: WishRoomText.h3(palette.fg)),
                                          const SizedBox(height: 2),
                                          Text(c.sub, style: WishRoomText.monoSm(palette.muted)),
                                        ],
                                      ),
                                    ),
                                    Text('→', style: TextStyle(color: palette.muted, fontSize: 16)),
                                  ],
                                ),
                              ),
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
}

class _CategorySpec {
  const _CategorySpec(this.icon, this.name, this.sub, this.onTap);
  final String icon;
  final String name;
  final String sub;
  final VoidCallback? onTap;
}
