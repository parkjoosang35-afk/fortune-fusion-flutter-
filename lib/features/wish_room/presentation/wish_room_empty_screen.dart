import 'package:flutter/material.dart';

import '../../../core/router/main_bottom_nav_bar.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_bg_atmosphere.dart';
import '../widgets/wish_room_buttons.dart';
import '../widgets/wish_room_candle.dart';

/// 소원방(Wish Room) — 02. 빈 상태(Empty State) 화면.
///
/// [디자인 핸드오프 — pixel-perfect 재현] `wish-screens.jsx`의
/// `ScreenEmpty` 컴포넌트를 발명 없이 그대로 재구현한다.
///
/// 구조(원본 그대로): BgAtmosphere(sigilSize 340/opacity 0.15/dust 없음) →
/// 상단 eyebrow("나의 소원방") → 중앙(불꺼진 캔들 80px·opacity 0.4, 타이틀
/// "아직 소원이/담기지 않았어요", 서브텍스트, "♢ 0 개의 소원 ♢" 오너먼트)
/// → 하단 CTA("+ 첫 소원 담기").
///
/// [사용 시점] [WishRoomHomeScreen]의 소원 목록이 0개일 때는 이미 홈 화면
/// 내부에서 축소된 빈 상태 UI를 자체적으로 그리고 있으므로(과거 세션 구현,
/// `_WishListSection`의 empty 분기), 이 전체화면 버전은 (a) 04 Home에서
/// 별도로 "빈 상태 전체화면"을 강조해 보여줘야 하는 온보딩 직후 첫 진입
/// 시나리오, (b) 향후 별도 라우트가 필요할 때를 위해 독립 화면으로
/// 제공한다.
class WishRoomEmptyScreen extends StatelessWidget {
  const WishRoomEmptyScreen({
    super.key,
    required this.onCompose,
    this.onBack,
    this.showMainBottomNav = false,
  });

  /// "+ 첫 소원 담기" — 03 Compose 화면으로 이동.
  final VoidCallback onCompose;

  /// [홈으로 돌아가기 — 사주/타로와 동일한 패턴] push로 들어온 경우
  /// (`Navigator.canPop()==true`)에만 상위에서 넘어온다. null이면 좌상단
  /// 뒤로가기 버튼을 렌더링하지 않는다.
  final VoidCallback? onBack;

  /// [하단바 통일 작업] [WishRoomHomeScreen]이 push된 인스턴스일 때만
  /// true로 전달되어 전역 5탭 하단바를 함께 보여준다.
  final bool showMainBottomNav;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      bottomNavigationBar: showMainBottomNav
          ? const MainBottomNavBar(currentIndex: 2)
          : null,
      body: Stack(
        children: [
          const Positioned.fill(
            child: WishRoomBgAtmosphere(
              sigilSize: 340,
              sigilOpacity: 0.15,
              dust: false,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const Text(
                        '나의 소원방',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'IBMPlexMonoWish',
                          fontSize: 10,
                          letterSpacing: 3.0,
                          color: WishRoomColors.textSecondary,
                        ),
                      ),
                      if (onBack != null)
                        Positioned(
                          left: 0,
                          child: InkWell(
                            onTap: onBack,
                            borderRadius: BorderRadius.circular(16),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              size: 20,
                              color: WishRoomColors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Opacity(
                          opacity: 0.4,
                          child: WishRoomCandle(
                            size: 80,
                            color: WishRoomColors.textTertiary,
                            lit: false,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          '🌙 아직 빌어둔 소원이\n없어요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'NotoSerifKRWish',
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            height: 1.35,
                            color: WishRoomColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '첫 촛불을 켜보세요.\n마음속 이야기, 조용히 들어드릴게요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.7,
                            color: WishRoomColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '♢',
                              style: TextStyle(
                                fontFamily: 'IBMPlexMonoWish',
                                fontSize: 10,
                                letterSpacing: 2.0,
                                color: WishRoomColors.textSecondary,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '0 개의 소원',
                              style: TextStyle(
                                fontFamily: 'IBMPlexMonoWish',
                                fontSize: 10,
                                letterSpacing: 2.0,
                                color: WishRoomColors.textSecondary,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '♢',
                              style: TextStyle(
                                fontFamily: 'IBMPlexMonoWish',
                                fontSize: 10,
                                letterSpacing: 2.0,
                                color: WishRoomColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  WishRoomPrimaryButton(
                    label: '+ 첫 소원 담기',
                    onPressed: onCompose,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
