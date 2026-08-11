import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_animations.dart';
import '../widgets/wish_room_background.dart';
import '../widgets/wish_room_candle.dart';
import 'wish_room_shell.dart';

/// [대형 작업 — 디자인 핸드오프 8개 화면 재구현] 입장(Onboarding) 화면.
///
/// `design_handoff/wish-screens.jsx`의 `ScreenOnboarding` 스펙을 그대로
/// 재구현한다: `BgAtmosphere(sigilSize:520, sigilOpacity:0.5)` 위에
/// 상단 신전 태그("神通萬通 · SINTONG") + 중앙 촛불(100px, radial glow) +
/// "소원을 담을\n준비가 되셨나요" 히어로 타이틀 + 부제 + 하단
/// btnPrimary("소원방 들어가기") + btnGhost("이미 계정이 있어요").
///
/// [버튼 동작] 이 앱에는 별도의 로그인/회원가입 절차가 없으므로(서버 API도
/// 계정 생성 없이 바로 소원방 데이터를 제공) 두 버튼 모두 동일하게 메인
/// 화면(Shell)으로 진입한다 — "이미 계정이 있어요"를 눌러도 별도 기능이
/// 없는 죽은 버튼처럼 보이지 않도록, 두 CTA 모두 완전히 동작하는 동일한
/// 진입 경로로 연결한다.
///
/// [자동 전환 유지] 기존 1400ms 후 자동 전환 타이머와 화면 전체 탭으로
/// 즉시 전환되는 동작은 100% 그대로 유지한다(테스트
/// `wish_room_entry_flow_test.dart`가 검증하는 흐름 불변) — 새로 추가한
/// 버튼들은 그 기존 동작 위에 스펙이 요구하는 명시적 CTA를 얹은 것이다.
///
/// [Shell 전환] 전환 대상은 [WishRoomShell](하단 탭: 나의 소원/모두의
/// 소원/신전관리)이다.
class WishRoomEntryScreen extends StatefulWidget {
  const WishRoomEntryScreen({super.key});

  @override
  State<WishRoomEntryScreen> createState() => _WishRoomEntryScreenState();
}

class _WishRoomEntryScreenState extends State<WishRoomEntryScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), _enterMainScreen);
  }

  void _enterMainScreen() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const WishRoomShell(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: GestureDetector(
        onTap: _enterMainScreen,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            const Positioned.fill(
              child: WishRoomBackground(mainSigilSize: 520, mainSigilOpacity: 0.5),
            ),
            SafeArea(
              child: DramaticEntrance(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: WishRoomSpacing.lg,
                    vertical: WishRoomSpacing.md,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: WishRoomSpacing.sm),
                      Text('神通萬通 · SINTONG', style: WishRoomTextStyles.eyebrowWide),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 130,
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
                                          WishRoomColors.glow.withValues(alpha: 0.35),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.6],
                                      ),
                                    ),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(top: 20),
                                  child: WishRoomCandle(size: 100),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: WishRoomSpacing.lg),
                          Text(
                            '소원을 담을\n준비가 되셨나요',
                            textAlign: TextAlign.center,
                            style: WishRoomTextStyles.heroTitle,
                          ),
                          const SizedBox(height: WishRoomSpacing.md),
                          Text(
                            '마음속 깊이 간직해온 바람,\n이곳에 조용히 담아두세요.',
                            textAlign: TextAlign.center,
                            style: WishRoomTextStyles.bodySm,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: TapBounce(
                              onTap: _enterMainScreen,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: WishRoomColors.glow,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: WishRoomColors.glowShadow,
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '소원방 들어가기',
                                  style: WishRoomTextStyles.buttonLabel.copyWith(
                                    color: const Color(0xFF2A1A0A),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: WishRoomSpacing.sm),
                          SizedBox(
                            width: double.infinity,
                            child: TapBounce(
                              onTap: _enterMainScreen,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: WishRoomColors.surfaceCardBorder,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '이미 계정이 있어요',
                                  style: WishRoomTextStyles.pillLabel.copyWith(
                                    fontSize: 13,
                                    color: WishRoomColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
