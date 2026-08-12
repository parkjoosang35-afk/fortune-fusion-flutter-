import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/wish_room_provider.dart';
import '../../application/wish_room_tab_controller.dart';
import '../../theme/wish_room_colors.dart';
import '../../theme/wish_room_text_styles.dart';
import '../../widgets/wish_room_sigils.dart';
import '../../widgets/wish_room_pouch_widgets.dart';
import 'wish_room_earn_list_screen.dart';
import 'wish_room_catalog_screen.dart';
import 'wish_room_ledger_screen.dart';

/// 06. 복주머니 홈 — 출처: PouchScreens.jsx `ScreenPouchHome`
class WishRoomPouchHomeScreen extends StatelessWidget {
  const WishRoomPouchHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    final provider = context.watch<WishRoomProvider>();

    final monthEarned = provider.ledger
        .where((e) => e.amount > 0 && _isThisMonth(e.date))
        .fold<int>(0, (sum, e) => sum + e.amount);
    final monthSpent = provider.ledger
        .where((e) => e.amount < 0 && _isThisMonth(e.date))
        .fold<int>(0, (sum, e) => sum - e.amount);

    return WishRoomPouchBg(
      palette: palette,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.6),
                child: WishRoomSigil(
                  size: 480,
                  color: palette.sigil,
                  opacity: 0.28,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        WishRoomPouchIconButton(
                          icon: Icons.arrow_back,
                          palette: palette,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        WishRoomPouchMonoLabel(
                          text: 'POUCH · 福袋',
                          palette: palette,
                        ),
                        WishRoomPouchIconButton(
                          icon: Icons.more_horiz,
                          palette: palette,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        const SizedBox(height: 12),
                        Center(
                          child: SizedBox(
                            width: 140,
                            height: 140,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const WishRoomPouch(size: 116),
                                const Positioned(
                                  top: -6,
                                  left: -14,
                                  child: WishRoomShard(size: 16),
                                ),
                                const Positioned(
                                  top: 18,
                                  right: -18,
                                  child: WishRoomShard(size: 12),
                                ),
                                const Positioned(
                                  top: -14,
                                  right: 4,
                                  child: WishRoomShard(size: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: WishRoomPouchMonoLabel(
                            text: '지금 담긴 조각',
                            palette: palette,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: WishRoomShardCounter(
                            count: provider.balance,
                            sizeVariant: WishRoomShardCounterSize.xl,
                            textColor: palette.fg,
                            glow: true,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            '이번 달 · +$monthEarned 담김  ·  $monthSpent 나눔',
                            textAlign: TextAlign.center,
                            style: WishRoomText.body(
                              palette.muted,
                            ).copyWith(fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _BigCta(
                                label: '오늘의 조각',
                                sub: '${_remainingAd(provider)}개 남음',
                                primary: true,
                                palette: palette,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const WishRoomEarnListScreen(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _BigCta(
                                label: '복 나눠 담기',
                                sub: '카탈로그',
                                primary: false,
                                palette: palette,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const WishRoomCatalogScreen(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('최근에', style: WishRoomText.h3(palette.fg)),
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const WishRoomLedgerScreen(),
                                ),
                              ),
                              child: Text(
                                '전체 →',
                                style: WishRoomText.monoSm(palette.muted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (provider.ledger.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              '아직 담긴 것이 없어요',
                              textAlign: TextAlign.center,
                              style: WishRoomText.body(palette.muted),
                            ),
                          )
                        else
                          ...provider.ledger
                              .take(4)
                              .map(
                                (e) => WishRoomLedgerRow(
                                  label: e.label,
                                  sub: e.sub,
                                  amount: e.amount,
                                  date: _relativeDate(e.date),
                                  palette: palette,
                                ),
                              ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: WishRoomBottomNav(
                active: 'pouch',
                palette: palette,
                onSelect: (id) => context.read<WishRoomTabController>().go(id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _isThisMonth(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month;
  }

  static int _remainingAd(WishRoomProvider p) =>
      (5 - p.todayLimits.adCount).clamp(0, 5);

  static String _relativeDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return '$diff일 전';
  }
}

class _BigCta extends StatelessWidget {
  const _BigCta({
    required this.label,
    required this.sub,
    required this.primary,
    required this.palette,
    this.onTap,
  });

  final String label;
  final String sub;
  final bool primary;
  final WishRoomPaletteTokens palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: primary ? palette.glow : palette.card,
            border: primary ? null : Border.all(color: palette.line),
            borderRadius: BorderRadius.circular(14),
            boxShadow: primary
                ? [BoxShadow(color: palette.glowShadow, blurRadius: 20)]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: WishRoomText.fontBody,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: primary ? WishRoomColors.onGlowText : palette.fg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  fontFamily: WishRoomText.fontBody,
                  fontSize: 10,
                  color: primary
                      ? WishRoomColors.onGlowText.withValues(alpha: 0.7)
                      : palette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
