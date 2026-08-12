import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_room_provider.dart';
import '../application/wish_room_tab_controller.dart';
import '../theme/wish_room_colors.dart';
import '../theme/wish_room_text_styles.dart';
import '../widgets/wish_room_sigils.dart';
import '../widgets/wish_room_pouch_widgets.dart';
import 'pouch/wish_room_pouch_home_screen.dart';
import 'pouch/wish_room_ledger_screen.dart';

/// 신통방통 소원방 · 4탭 메인 셸
///
/// 탭 구성(WishRoomBottomNav.items 순서와 동일):
///  - home(나의 소원) : 소원방 본체 홈 — 재제작 예정, 현재는 임시 화면
///  - feed(모두의 소원): 익명 소원 피드 — 재제작 예정, 현재는 임시 화면
///  - pouch(복주머니) : 완성된 복주머니 홈([WishRoomPouchHomeScreen])
///  - me(기록)        : 조용한 장부([WishRoomLedgerScreen])
///
/// 탭 전환은 [WishRoomTabController]가 담당한다(Provider로 셸 범위에 등록).
/// 각 탭 화면 내부에 이미 그려진 [WishRoomBottomNav]의 onSelect는
/// `context.read<WishRoomTabController>().go(id)`를 호출해 IndexedStack의
/// 인덱스만 바꾸며, Navigator push/pop은 전혀 사용하지 않는다.
class WishRoomShell extends StatelessWidget {
  const WishRoomShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WishRoomTabController>(
      create: (_) => WishRoomTabController(),
      child: const _WishRoomShellBody(),
    );
  }
}

class _WishRoomShellBody extends StatelessWidget {
  const _WishRoomShellBody();

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<WishRoomTabController>();

    return Scaffold(
      backgroundColor: WishRoomColors.crystal.bg2,
      body: IndexedStack(
        index: tab.index,
        children: const [
          _WishRoomHomePlaceholder(),
          _WishRoomFeedPlaceholder(),
          WishRoomPouchHomeScreen(),
          WishRoomLedgerScreen(),
        ],
      ),
    );
  }
}

class _WishRoomHomePlaceholder extends StatelessWidget {
  const _WishRoomHomePlaceholder();

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.midnight;
    final provider = context.watch<WishRoomProvider>();
    return WishRoomPouchBg(
      palette: palette,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.4),
                child: WishRoomSigil(size: 320, color: palette.sigil, opacity: 0.2),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 100),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const WishRoomCandle(size: 70),
                    const SizedBox(height: 24),
                    Text(
                      '나의 소원방',
                      textAlign: TextAlign.center,
                      style: WishRoomText.h1(palette.fg),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      provider.wishes.isEmpty
                          ? '아직 밝힌 소원이 없어요\n곧 이 자리에서 소원을 적어볼 수 있어요'
                          : '${provider.wishes.length}개의 소원을 밝히고 있어요',
                      textAlign: TextAlign.center,
                      style: WishRoomText.body(palette.muted).copyWith(height: 1.7),
                    ),
                  ],
                ),
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

class _WishRoomFeedPlaceholder extends StatelessWidget {
  const _WishRoomFeedPlaceholder();

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.midnight;
    return WishRoomPouchBg(
      palette: palette,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.4),
                child: WishRoomSigil(size: 320, color: palette.sigil, opacity: 0.2),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 100),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const WishRoomSeal(text: '合', size: 56),
                    const SizedBox(height: 24),
                    Text(
                      '모두의 소원',
                      textAlign: TextAlign.center,
                      style: WishRoomText.h1(palette.fg),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '익명의 소원들이 모이는 자리입니다\n곧 이곳에서 함께 빌어줄 수 있어요',
                      textAlign: TextAlign.center,
                      style: WishRoomText.body(palette.muted).copyWith(height: 1.7),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: WishRoomBottomNav(
                active: 'feed',
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
