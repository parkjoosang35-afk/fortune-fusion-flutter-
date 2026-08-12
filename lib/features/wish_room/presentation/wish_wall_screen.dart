import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_room_provider.dart';
import '../theme/wish_room_colors.dart';
import '../theme/wish_room_text_styles.dart';
import '../widgets/wish_room_sigils.dart';
import '../widgets/wish_room_pouch_widgets.dart';
import '../widgets/wish_room_wish_card.dart';
import 'home/wish_room_compose_screen.dart';
import 'home/wish_room_detail_screen.dart';

/// 소원벽(Wish Wall) — 앱 하단 5탭 중 하나(구 "커뮤니티" 탭 자리 대체).
///
/// [WishRoomFeedScreen]("모두의 소원" 피드, 소원방 내부 4탭 전용 화면)과
/// 같은 데이터 소스(`WishRoomProvider.wishes`)와 비주얼 언어를 그대로 쓰되,
/// 여기서는 소원방 자체 진입(WishRoomShell) 없이도 앱쉘에서 곧바로 접근
/// 가능해야 하므로, 이 화면이 직접 `WishRoomProvider.init()`을 보장한다
/// (인트로 화면을 거치지 않고 처음 진입해도 Hive box가 열리도록).
///
/// 하단 내비게이션은 앱쉘의 공용 BottomNavigationBar를 그대로 쓰고, 소원방
/// 내부 4탭 전용 [WishRoomBottomNav]는 이 화면에는 넣지 않는다(대신 FAB로
/// 소원 작성 화면 진입).
class WishWallScreen extends StatefulWidget {
  const WishWallScreen({super.key});

  @override
  State<WishWallScreen> createState() => _WishWallScreenState();
}

class _WishWallScreenState extends State<WishWallScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<WishRoomProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.midnight;
    final provider = context.watch<WishRoomProvider>();
    final wallWishes = [...provider.wishes]
      ..sort((a, b) => b.cheersReceived.compareTo(a.cheersReceived));

    return WishRoomPouchBg(
      palette: palette,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: provider.ready
            ? FloatingActionButton(
                backgroundColor: palette.glow,
                foregroundColor: WishRoomColors.onGlowText,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WishRoomComposeScreen(),
                  ),
                ),
                child: const Icon(Icons.add),
              )
            : null,
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
                      text: 'WISH WALL · 소원벽',
                      palette: palette,
                    ),
                  ),
                  Expanded(
                    child: !provider.ready
                        ? Center(
                            child: CircularProgressIndicator(
                              color: palette.glow,
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(
                              20,
                              4,
                              20,
                              32,
                            ),
                            children: [
                              Center(
                                child: WishRoomSeal(text: '合', size: 52),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '소원벽',
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
                              if (wallWishes.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 40,
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        '아직 모인 소원이 없어요\n나의 소원을 먼저 벽에 걸어보세요',
                                        textAlign: TextAlign.center,
                                        style: WishRoomText.body(
                                          palette.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      WishRoomPouchButton(
                                        label: '❖ 첫 소원 걸어두기',
                                        primary: true,
                                        palette: palette,
                                        onPressed: () =>
                                            Navigator.of(context).push(
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
                                ...wallWishes.map(
                                  (w) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 10,
                                    ),
                                    child: WishRoomWishCard(
                                      wish: w,
                                      palette: palette,
                                      anonymous: true,
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              WishRoomDetailScreen(
                                                wishId: w.id,
                                              ),
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
          ],
        ),
      ),
    );
  }
}
