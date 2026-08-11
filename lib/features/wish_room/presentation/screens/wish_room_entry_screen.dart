import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_animations.dart';
import '../widgets/wish_room_background.dart';
import '../widgets/wish_room_candle.dart';
import 'wish_room_screen.dart';

/// [소원방 Riverpod 실험판] 입장 화면.
///
/// [디자인 핸드오프 적용 — "마법진이 소환되는 신전"] README `1. Onboarding` 스펙:
/// "Full-bleed atmospheric background (radial gradient + rotating sigil +
/// rising dust motes). Centered column with... large glowing candle(100px)
/// + radial glow + serif title + subtitle". 기존에는 단색 그라디언트
/// 배경(DecoratedBox)이었지만, 이미 구현된 [WishRoomBackground](정/역회전
/// 마법진 + 상승 먼지 파티클 포함)로 교체해 스펙과 동일한 "신전 진입"
/// 분위기를 낸다. 중앙 콘텐츠 위에는 [WishRoomCandle](100px)을 추가했다.
///
/// 화면 진입 연출은 기존 커스텀 FadeTransition+ScaleTransition 대신
/// `anim-dramatic` 스펙(spring easing, 1s)을 그대로 구현한 [DramaticEntrance]
/// 로 교체했다. 탭하면 즉시 메인 화면으로 건너뛰는 기존 동작과, 1400ms 후
/// 자동 전환되는 기존 타이머 로직은 100% 그대로 유지한다(테스트
/// `wish_room_entry_flow_test.dart`가 검증하는 문구/흐름 불변).
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
        pageBuilder: (_, __, ___) => const WishRoomScreen(),
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
        child: Stack(
          children: [
            const Positioned.fill(child: WishRoomBackground()),
            Center(
              child: DramaticEntrance(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const WishRoomCandle(size: 100),
                    const SizedBox(height: WishRoomSpacing.lg),
                    Text('당신의 소원이 머무는 방', style: WishRoomTextStyles.titleXl),
                    const SizedBox(height: WishRoomSpacing.md),
                    Text('조용히 문을 엽니다…', style: WishRoomTextStyles.bodySm),
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
