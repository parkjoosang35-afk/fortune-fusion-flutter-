import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/wish_room_provider.dart';
import '../../application/wish_room_tab_controller.dart';
import '../../theme/wish_room_colors.dart';
import '../../theme/wish_room_text_styles.dart';
import '../../widgets/wish_room_sigils.dart';
import '../../widgets/wish_room_pouch_widgets.dart';
import '../../widgets/wish_room_wish_card.dart';
import 'wish_room_detail_screen.dart';

/// 05 · 모두의 소원 (Feed) — dev-spec §1 재제작 대상, JSX 미커업.
///
/// dev-spec §6 `/api/feed?category=all` 는 서버 다중 사용자 피드를 전제로
/// 하지만, 현재 앱은 로컬(단일 사용자) Hive 저장소만 있어 실제 타인의 소원을
/// 가져올 백엔드가 없다. 그래서 이 화면은 익명 피드 UX 골격(region/ageGroup
/// 마스킹 표시 · 함께 빌기 진입)을 그대로 갖추고, 데이터 소스로는
/// `provider.wishes`(가장 많이 함께 빈 순)를 사용한다 — 서버 연동 시
/// `_feedWishes`만 실제 API 호출로 교체하면 된다.
class WishRoomFeedScreen extends StatelessWidget {
  const WishRoomFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.midnight;
    final provider = context.watch<WishRoomProvider>();
    final feedWishes = [...provider.wishes]
      ..sort((a, b) => b.cheersReceived.compareTo(a.cheersReceived));

    return WishRoomPouchBg(
      palette: palette,
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                    child: WishRoomPouchMonoLabel(
                      text: 'FEED · 모두의 소원',
                      palette: palette,
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                      children: [
                        Center(child: WishRoomSeal(text: '合', size: 52)),
                        const SizedBox(height: 14),
                        Text(
                          '모두의 소원',
                          textAlign: TextAlign.center,
                          style: WishRoomText.h1(palette.fg),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '익명의 소원들이 모이는 자리입니다\n마음이 가는 곳에 함께 빌어주세요',
                          textAlign: TextAlign.center,
                          style: WishRoomText.body(
                            palette.muted,
                          ).copyWith(height: 1.7),
                        ),
                        const SizedBox(height: 24),
                        if (feedWishes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Text(
                              '아직 모인 소원이 없어요\n나의 소원을 먼저 밝혀보세요',
                              textAlign: TextAlign.center,
                              style: WishRoomText.body(palette.muted),
                            ),
                          )
                        else
                          ...feedWishes.map(
                            (w) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: WishRoomWishCard(
                                wish: w,
                                palette: palette,
                                anonymous: true,
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
