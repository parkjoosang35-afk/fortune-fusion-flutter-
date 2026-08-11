import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';
import 'wish_room_dust.dart';
import 'wish_room_sigil.dart';

/// [소원방 Riverpod 실험판] 별빛/안개 반짝임 배경.
///
/// 단 하나의 AnimationController(repeat)를 여러 별빛 Dot이 공유하고,
/// 전체를 RepaintBoundary로 감싸 메인 콘텐츠(CustomScrollView) rebuild와
/// 페인팅을 분리한다. sparkleLevel이 높을수록(연속 기도일수가 쌓일수록)
/// 반짝임 개수/강도가 점진적으로 늘어난다.
///
/// [UI 전면 개선 — 배경 효과 강화] 기존 24개 단색 별빛 트윙클에 다음을
/// 추가했다: (1) 별의 색을 골드 단색에서 골드/연보라 2색으로 다변화해
/// 밤하늘 깊이감을 더함, (2) 천천히 흐르는 네뷸라(성운) 광원 2개를
/// RadialGradient로 추가해 배경이 완전히 정적이지 않고 아주 느리게
/// 살아 움직이는 느낌을 줌, (3) 별 크기에 미세한 편차를 둬 원경/근경
/// 느낌을 강화. 별도의 AnimationController(느린 12초 주기)를 추가로
/// 두되, 기존 4초 별빛 컨트롤러와 완전히 독립적으로 동작해 기존 로직을
/// 건드리지 않는다.
///
/// [디자인 핸드오프 적용 — "마법진이 소환되는 신전"] 기존 별빛/네뷸라
/// 레이어는 전혀 건드리지 않고, 그 위에 `design_handoff` V2("달빛
/// 크리스탈"/`anim-dramatic`) 스펙의 배경 장식 2종을 추가로 얹었다:
/// - 정/역회전하는 마법진 2개([WishRoomSigilRing], 40s/55s, `BgAtmosphere`
///   원본 스펙의 "메인 sigil + 역회전 보조 sigil" 레이어 구성을 재현)
/// - 상승하는 크리스탈 먼지 파티클([WishRoomDust], anim-dramatic 4s)
///
/// [showSigil]로 이 신규 레이어 노출 여부를 제어할 수 있어, 기존 화면들의
/// 시각적 합의 없이 우선 opt-in 방식으로 적용할 수 있게 했다.
class WishRoomBackground extends StatefulWidget {
  final double sparkleLevel; // 0.0 ~ 1.0

  /// [디자인 핸드오프] 마법진 + 먼지 파티클 레이어 노출 여부.
  final bool showSigil;

  /// [디자인 핸드오프 8개 화면 재구현] `BgAtmosphere({sigilSize, sigilOpacity,
  /// dust})` 스펙 대응 — 화면마다 메인 마법진 크기/불투명도가 다르다
  /// (Onboarding 520 / Empty 340 / Compose 280 / Home 340 / Detail 420 /
  /// Feed 200 / BoxOpening 620 / Celebration 640). 기존 호출부(기본값 340/
  /// 0.22)는 값을 지정하지 않아도 그대로 동작하도록 기본값을 유지한다.
  final double mainSigilSize;
  final double mainSigilOpacity;

  /// 상승 먼지 파티클 노출 여부(`dust: false`인 화면 — Empty/Compose 등).
  final bool showDust;

  const WishRoomBackground({
    super.key,
    this.sparkleLevel = 0.3,
    this.showSigil = true,
    this.mainSigilSize = 340,
    this.mainSigilOpacity = 0.22,
    this.showDust = true,
  });

  @override
  State<WishRoomBackground> createState() => _WishRoomBackgroundState();
}

class _WishRoomBackgroundState extends State<WishRoomBackground>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _nebulaController;
  late final List<_StarSeed> _seeds;

  static const int _maxStars = 24;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    // [배경 효과 강화] 네뷸라 광원이 아주 느리게 떠다니도록 하는 별도
    // 컨트롤러. 기존 별빛 트윙클(4초 주기)보다 훨씬 느린 12초 주기로
    // 눈에 거슬리지 않게 은은히 순환한다.
    _nebulaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    final rng = Random(7);
    _seeds = List.generate(
      _maxStars,
      (i) => _StarSeed(
        dx: rng.nextDouble(),
        dy: rng.nextDouble(),
        phase: rng.nextDouble(),
        size: 1.2 + rng.nextDouble() * 2.4,
        // [배경 효과 강화] 별마다 색을 살짝 다르게(골드/연보라 계열)
        // 부여해 단조로움을 줄인다. 30% 확률로 연보라 별로 처리.
        isViolet: rng.nextDouble() < 0.3,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _nebulaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleStars = (8 + widget.sparkleLevel * (_maxStars - 8)).round();

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: WishRoomColors.backgroundGradient,
            ),
          ),
          // [배경 효과 강화] 아주 느리게 떠다니는 네뷸라 광원 2개.
          AnimatedBuilder(
            animation: _nebulaController,
            builder: (context, _) {
              return CustomPaint(
                painter: _NebulaPainter(progress: _nebulaController.value),
              );
            },
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _StarfieldPainter(
                  seeds: _seeds.take(visibleStars).toList(),
                  progress: _controller.value,
                  intensity: widget.sparkleLevel,
                ),
              );
            },
          ),
          // [디자인 핸드오프 — "마법진이 소환되는 신전"] 정/역회전 마법진
          // 2개 + 상승하는 크리스탈 먼지. 각각 독립된 AnimationController를
          // 가지므로(WishRoomSigilRing/WishRoomDust 내부) 기존 별빛/네뷸라
          // 애니메이션과 완전히 분리되어 동작한다. RepaintBoundary로 감싸
          // 배경 전체 리페인트를 상위 스크롤/리스트 rebuild와 분리한다.
          if (widget.showSigil)
            RepaintBoundary(
              child: Center(
                child: WishRoomSigilRing(
                  size: widget.mainSigilSize,
                  color: WishRoomColors.sigil,
                  opacity: widget.mainSigilOpacity,
                ),
              ),
            ),
          if (widget.showSigil)
            RepaintBoundary(
              child: Align(
                alignment: const Alignment(0.6, -0.5),
                child: WishRoomSigilRing(
                  size: widget.mainSigilSize * 180 / 340,
                  color: WishRoomColors.crystal,
                  opacity: 0.16,
                  reverse: true,
                ),
              ),
            ),
          if (widget.showSigil && widget.showDust)
            Positioned.fill(
              child: WishRoomDust(count: 10, color: WishRoomColors.glow),
            ),
        ],
      ),
    );
  }
}

/// [배경 효과 강화] 천천히 순환하는 은은한 네뷸라(성운) 광원 페인터.
/// 별빛 트윙클과는 별개의 레이어로, 아주 낮은 알파값의 RadialGradient
/// 2개를 서로 다른 위상으로 움직여 배경에 깊이감을 더한다.
class _NebulaPainter extends CustomPainter {
  final double progress;

  _NebulaPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * pi;

    final center1 = Offset(
      size.width * (0.25 + 0.12 * sin(t)),
      size.height * (0.22 + 0.08 * cos(t * 0.8)),
    );
    final center2 = Offset(
      size.width * (0.78 + 0.1 * cos(t * 0.6)),
      size.height * (0.55 + 0.1 * sin(t * 0.7)),
    );

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          WishRoomColors.gold.withValues(alpha: 0.10),
          WishRoomColors.gold.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center1, radius: size.width * 0.55),
      );
    canvas.drawCircle(center1, size.width * 0.55, paint1);

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF8C6BE0).withValues(alpha: 0.09),
          const Color(0xFF8C6BE0).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center2, radius: size.width * 0.5),
      );
    canvas.drawCircle(center2, size.width * 0.5, paint2);
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _StarSeed {
  final double dx;
  final double dy;
  final double phase;
  final double size;
  final bool isViolet;

  const _StarSeed({
    required this.dx,
    required this.dy,
    required this.phase,
    required this.size,
    this.isViolet = false,
  });
}

class _StarfieldPainter extends CustomPainter {
  final List<_StarSeed> seeds;
  final double progress;
  final double intensity;

  _StarfieldPainter({
    required this.seeds,
    required this.progress,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final seed in seeds) {
      final twinkle = (sin((progress + seed.phase) * 2 * pi) + 1) / 2;
      final alpha = (0.15 + 0.5 * twinkle * (0.4 + intensity)).clamp(0.0, 0.9);
      // [배경 효과 강화] 별 색상을 골드/연보라 2계열로 다변화.
      paint.color = seed.isViolet
          ? const Color(0xFFC9B6F5).withValues(alpha: alpha)
          : WishRoomColors.goldSoft.withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(seed.dx * size.width, seed.dy * size.height),
        seed.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.intensity != intensity;
}
