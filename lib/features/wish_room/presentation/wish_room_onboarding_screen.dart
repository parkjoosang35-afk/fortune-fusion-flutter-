import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_bg_atmosphere.dart';
import '../widgets/wish_room_buttons.dart';
import '../widgets/wish_room_candle.dart';

/// 소원방(Wish Room) — 01. 온보딩 화면.
///
/// [디자인 핸드오프 — pixel-perfect 재현] `design_handoff_v2_dramatic.zip`
/// `design_files/wish-screens.jsx`의 `ScreenOnboarding` 컴포넌트를 발명 없이
/// 그대로 재구현한다.
///
/// 구조(원본 그대로): BgAtmosphere(sigilSize 520/opacity 0.5) → 상단
/// eyebrow(神通萬通 · SINTONG) → 중앙(히어로 캔들 100px+glow, 타이틀+서브)
/// → 하단 CTA 2개(btnPrimary "소원방 들어가기" / btnGhost "이미 계정이
/// 있어요").
///
/// [진입 플로우] 이 화면은 "소원방" 탭에 처음 진입할 때 1회 노출되는
/// 게이트로 사용된다([WishRoomEntryGate] 참고, TodoWrite id=10에서 연결).
/// CTA 콜백은 상위에서 주입받아, 이 화면 자체는 라우팅 방법(게이트 플래그
/// 저장 등)에 대해 알지 못하게 한다(순수 프레젠테이션).
class WishRoomOnboardingScreen extends StatelessWidget {
  const WishRoomOnboardingScreen({
    super.key,
    required this.onEnter,
    this.onHaveAccount,
  });

  /// "소원방 들어가기" — 이 화면을 벗어나 04 Home으로 진입.
  final VoidCallback onEnter;

  /// "이미 계정이 있어요" — 별도 로그인 플로우가 없으므로 기본값은 onEnter와
  /// 동일 동작(원본 디자인에는 별도 로그인 폼이 없음 — 앱 전역 인증은 이미
  /// [core/domain/access]에서 별도로 처리되므로 이 버튼은 동일하게 입장만
  /// 시켜준다).
  final VoidCallback? onHaveAccount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: WishRoomBgAtmosphere(sigilSize: 520, sigilOpacity: 0.5),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '神通萬通 · SINTONG',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'IBMPlexMonoWish',
                      fontSize: 10,
                      letterSpacing: 4.0,
                      color: WishRoomColors.textSecondary,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            Positioned(
                              top: -20,
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      WishRoomColors.glow.withValues(
                                        alpha: 0.35,
                                      ),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.6],
                                  ),
                                ),
                              ),
                            ),
                            const Positioned(
                              top: 20,
                              child: WishRoomCandle(size: 100),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        '소원을 담을\n준비가 되셨나요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'NotoSerifKRWish',
                          fontWeight: FontWeight.w900,
                          fontSize: 34,
                          letterSpacing: -0.7,
                          height: 1.15,
                          color: WishRoomColors.textPrimary,
                          shadows: [
                            Shadow(
                              color: WishRoomColors.glowShadow,
                              blurRadius: 30,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SizedBox(
                        width: 280,
                        child: Text(
                          '마음속 깊이 간직해온 바람,\n이곳에 조용히 담아두세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.7,
                            color: WishRoomColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      WishRoomPrimaryButton(
                        label: '소원방 들어가기',
                        onPressed: onEnter,
                      ),
                      const SizedBox(height: 10),
                      WishRoomGhostButton(
                        label: '이미 계정이 있어요',
                        onPressed: onHaveAccount ?? onEnter,
                      ),
                    ],
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
