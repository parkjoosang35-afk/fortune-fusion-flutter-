import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_buttons.dart';
import '../widgets/wish_room_sigil.dart';
import 'wish_room_compose_screen.dart';

/// 소원방(Wish Room) — 08. 소원 성취 축하(Celebration, "이뤄졌을 때") 화면.
///
/// [디자인 핸드오프 — pixel-perfect 재현] `wish-screens.jsx`의
/// `ScreenCelebration` 컴포넌트를 그대로 재구현한다: 커스텀 radial 배경
/// (accent 중심 → bg-1 → bg-2) → 대형 정회전 마법진(640px, opacity 0.6) +
/// 소형 역회전 마법진(400px, opacity 0.3) → 14개 꽃잎 낙하 애니메이션 →
/// eyebrow"✿ FULFILLED ✿" → 成 글리프(82px, glow drop-shadow) → 타이틀
/// "소원이 이루어�었어요"+본문(달성 소원 문구) → "🕯 N일 만에 이룬 소원" 뱃지
/// → CTA 2개("감사의 소원 남기기" primary / "소원방으로 돌아가기" ghost).
///
/// [05 Detail → 08 Celebration 연결 지점] 05 Detail의 "✿ 이뤄졌어요" 확인
/// 다이얼로그는 현재 이 화면을 push하지 않고 자기완결적으로 스낵바만
/// 띄운다(문서 §데이터 갭: [WishPost]에 실제 fulfilled 상태 필드가 없어
/// 어느 소원이 "방금 성취됐는지"를 신뢰성 있게 이 화면에 전달할 방법이
/// 아직 없음). 이 화면은 그 갭이 해소될 때(또는 05 Detail이 로컬로 문구를
/// 직접 넘겨주는 방식으로 확장될 때) [wishText]/[daysToFulfill] 파라미터를
/// 통해 바로 연결할 수 있도록 완전히 독립적으로 구현했다(라우팅 정리
/// 단계 #10에서 필요 시 연결).
class WishRoomCelebrationScreen extends StatefulWidget {
  const WishRoomCelebrationScreen({
    super.key,
    this.wishText = '엄마 무릎 수술이\n무사히 잘 끝났어요',
    this.daysToFulfill = 89,
  });

  /// 이뤄진 소원의 본문(줄바꿈 포함 표시).
  final String wishText;

  /// "N일 만에 이룬 소원" 배지의 N.
  final int daysToFulfill;

  @override
  State<WishRoomCelebrationScreen> createState() =>
      _WishRoomCelebrationScreenState();
}

class _WishRoomCelebrationScreenState extends State<WishRoomCelebrationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _petals;
  late final List<_PetalSeed> _seeds;

  static const int _petalCount = 14;
  static const double _fallSeconds = 6.0;

  @override
  void initState() {
    super.initState();
    // [anim] petal-fall 6s linear infinite, stagger delay = i*0.4s % 5s.
    _petals = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_fallSeconds * 1000).round()),
    )..repeat();
    _seeds = List.generate(_petalCount, (i) {
      final left = (i * 11 + 5) % 100 / 100.0;
      final delay = (i * 0.4) % 5.0;
      final rot = (i * 25).toDouble();
      final amber = i % 2 == 1;
      return _PetalSeed(left: left, delaySeconds: delay, rotationDeg: rot, amber: amber);
    });
  }

  @override
  void dispose() {
    _petals.dispose();
    super.dispose();
  }

  void _goCompose() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WishRoomComposeScreen()),
    );
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: Stack(
        children: [
          // Custom radial background (accent 중심 → bg-1 → bg-2)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 1.1,
                  colors: [
                    WishRoomColors.accent,
                    WishRoomColors.backgroundSoft,
                    WishRoomColors.backgroundDeep,
                  ],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          // 대형 정회전 마법진
          const Positioned.fill(
            child: Center(
              child: WishRoomSigilRing(size: 640, opacity: 0.6),
            ),
          ),
          // 소형 역회전 마법진
          const Positioned.fill(
            child: Center(
              child: WishRoomSigilRing(
                size: 400,
                opacity: 0.3,
                reverse: true,
                color: WishRoomColors.textPrimary,
              ),
            ),
          ),
          // 14개 꽃잎 낙하
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _petals,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _PetalPainter(
                        seeds: _seeds,
                        progress: _petals.value,
                        periodSeconds: _fallSeconds,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                children: [
                  const Text(
                    '✿ FULFILLED ✿',
                    style: TextStyle(
                      fontFamily: 'IBMPlexMonoWish',
                      fontSize: 10,
                      letterSpacing: 4.0,
                      color: WishRoomColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '成',
                            style: TextStyle(
                              fontFamily: 'NotoSerifKRWish',
                              fontWeight: FontWeight.w900,
                              fontSize: 82,
                              height: 1.0,
                              color: WishRoomColors.glow,
                              shadows: [
                                Shadow(
                                  color: WishRoomColors.glow,
                                  blurRadius: 30,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '소원이\n이루어졌어요',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'NotoSerifKRWish',
                              fontWeight: FontWeight.w900,
                              fontSize: 30,
                              height: 1.2,
                              color: WishRoomColors.textPrimary,
                              shadows: [
                                Shadow(
                                  color: WishRoomColors.glowShadow,
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.wishText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: WishRoomColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: WishRoomColors.surfaceCard,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: WishRoomColors.glow),
                            ),
                            child: Text(
                              '🕯 ${widget.daysToFulfill}일 만에 이룬 소원',
                              style: const TextStyle(
                                fontFamily: 'IBMPlexMonoWish',
                                fontSize: 11,
                                letterSpacing: 1.5,
                                color: WishRoomColors.glow,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      WishRoomPrimaryButton(
                        label: '감사의 소원 남기기',
                        onPressed: _goCompose,
                      ),
                      const SizedBox(height: 10),
                      WishRoomGhostButton(
                        label: '소원방으로 돌아가기',
                        onPressed: _goHome,
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

class _PetalSeed {
  final double left; // 0~1
  final double delaySeconds;
  final double rotationDeg;
  final bool amber; // true=accent 색, false=glow 색

  const _PetalSeed({
    required this.left,
    required this.delaySeconds,
    required this.rotationDeg,
    required this.amber,
  });
}

/// `petal-fall 6s {delay}s linear infinite` — 화면 위(-20px)에서 아래로
/// 떨어지는 8x12 타원형(teardrop 근사) 꽃잎 파티클.
class _PetalPainter extends CustomPainter {
  final List<_PetalSeed> seeds;
  final double progress; // 0~1
  final double periodSeconds;

  const _PetalPainter({
    required this.seeds,
    required this.progress,
    required this.periodSeconds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final elapsedNow = progress * periodSeconds;
    final travel = size.height + 40; // -20px 시작 → 화면 아래 + 20px

    for (final seed in seeds) {
      final localT =
          ((elapsedNow - seed.delaySeconds) % periodSeconds) / periodSeconds;
      final t = localT < 0 ? localT + 1 : localT;

      final dx = seed.left * size.width;
      final dy = -20 + t * travel;
      final color = seed.amber ? WishRoomColors.accent : WishRoomColors.glow;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(seed.rotationDeg * 3.1415926535 / 180);
      final rrect = RRect.fromRectAndCorners(
        const Rect.fromLTWH(-4, -6, 8, 12),
        topLeft: const Radius.circular(6.4),
        topRight: const Radius.circular(1.6),
        bottomLeft: const Radius.circular(6.4),
        bottomRight: const Radius.circular(1.6),
      );
      final paint = Paint()..color = color.withValues(alpha: 0.8);
      canvas.drawRRect(rrect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PetalPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
