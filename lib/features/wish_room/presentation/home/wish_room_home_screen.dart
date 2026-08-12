import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/wish_room_provider.dart';
import '../../application/wish_room_tab_controller.dart';
import '../../theme/wish_room_colors.dart';
import '../../theme/wish_room_text_styles.dart';
import '../../widgets/wish_room_sigils.dart';
import '../../widgets/wish_room_pouch_widgets.dart';
import '../../widgets/wish_room_wish_card.dart';
import 'wish_room_compose_screen.dart';
import 'wish_room_detail_screen.dart';

/// 03 · 나의 소원 홈 (Wish Home) — dev-spec §1 재제작 대상, JSX 미커업.
///
/// [WishRoomShell]의 `_WishRoomHomePlaceholder`를 대체한다. 촛불 제단
/// 이미지(WishRoomCandle) + 오늘 밝힌 소원 개수 + 소원 목록(WishRoomWishCard)
/// + 새 소원 작성 FAB로 구성했다. 탭 전환 계약(WishRoomTabController)과
/// 하단 내비([WishRoomBottomNav])는 기존 Pouch/Ledger 화면과 동일 패턴 유지.
class WishRoomHomeScreen extends StatelessWidget {
  const WishRoomHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.midnight;
    final provider = context.watch<WishRoomProvider>();
    final wishes = provider.wishes;
    final activeWishes = wishes.where((w) => !w.isFulfilled).toList();
    final fulfilledCount = wishes.length - activeWishes.length;

    return WishRoomPouchBg(
      palette: palette,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(
          backgroundColor: palette.glow,
          foregroundColor: WishRoomColors.onGlowText,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WishRoomComposeScreen()),
          ),
          child: const Icon(Icons.add),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.55),
                child: WishRoomSigil(
                  size: 340,
                  color: palette.sigil,
                  opacity: 0.18,
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
                        WishRoomPouchMonoLabel(
                          text: 'HOME · 나의 소원',
                          palette: palette,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                      children: [
                        Center(
                          child: WishRoomCandle(
                            size: 78,
                            lit: activeWishes.isNotEmpty,
                            color: palette.glow,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '나의 소원방',
                          textAlign: TextAlign.center,
                          style: WishRoomText.h1(palette.fg),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          wishes.isEmpty
                              ? '아직 밝힌 소원이 없어요\n첫 소원을 두루마리에 적어보세요'
                              : '${activeWishes.length}개의 소원을 밝히고 있어요'
                                    '${fulfilledCount > 0 ? ' · $fulfilledCount개 이루어짐' : ''}',
                          textAlign: TextAlign.center,
                          style: WishRoomText.body(
                            palette.muted,
                          ).copyWith(height: 1.7),
                        ),
                        const SizedBox(height: 24),
                        if (wishes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            child: Column(
                              children: [
                                WishRoomPouchButton(
                                  label: '❖ 첫 소원 봉인하기',
                                  primary: true,
                                  palette: palette,
                                  expand: true,
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const WishRoomComposeScreen(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...wishes.map(
                            (w) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: WishRoomWishCard(
                                wish: w,
                                palette: palette,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        WishRoomDetailScreen(wishId: w.id),
                                  ),
                                ),
                              ),
                            ),
                          ),
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
                active: 'home',
                palette: palette,
                onSelect: (id) => context.read<WishRoomTabController>().go(id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
