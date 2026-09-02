import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/guinji_theme.dart';
import '../widgets/guinji_sigil_ring.dart';
import '../widgets/guinji_ui_kit.dart';

/// C · Calculating — `/guinji/calc` (호스트) / `/g/:mapToken/calc` (게스트)
///
/// [design_handoff_guinji_web/Guinji Section.html] 1436~1524줄 마크업을
/// 재현한다. 캐스팅 중인 캐릭터 페어 + 회전 sigil(12s) + 로딩 오브(펄스
/// 2s) + 진행바(shimmer 2s) + 스켈레톤 라인 3개(shimmer 1.4s) 구성.
///
/// 두 플로우(호스트 지도 생성 / 게스트 참여 계산)에서 동일한 UI를 재사용할
/// 수 있도록 [onComplete] 콜백만 받고, 실제 계산 API 호출은 상위(라우팅)
/// 에서 담당하게 한다. 데모 목적으로는 일정 시간 후 자동으로 다음 화면으로
/// 진행하는 타이머를 내장한다.
class GuinjiCalculatingScreen extends StatefulWidget {
  const GuinjiCalculatingScreen({
    super.key,
    this.autoAdvanceAfter = const Duration(milliseconds: 1600),
    this.onComplete,
  });

  static const routeName = '/guinji/calc';

  final Duration autoAdvanceAfter;
  final VoidCallback? onComplete;

  @override
  State<GuinjiCalculatingScreen> createState() =>
      _GuinjiCalculatingScreenState();
}

class _GuinjiCalculatingScreenState extends State<GuinjiCalculatingScreen> {
  Timer? _advanceTimer;

  @override
  void initState() {
    super.initState();
    _advanceTimer = Timer(widget.autoAdvanceAfter, () {
      if (mounted) widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDarker,
      body: GuinjiScreenScaffold(
        bgAlignment: const Alignment(0, -0.2),
        bgOpacity: 0.25,
        extraBackground: const Align(
          alignment: Alignment(0, -0.55),
          child: Opacity(
            opacity: 0.3,
            child: GuinjiSigilRing(
              size: 280,
              color: GuinjiColors.lavender,
              opacity: 0.6,
              duration: Duration(seconds: 12),
            ),
          ),
        ),
        child: Column(
          children: [
            const GuinjiTopBar(breadcrumb: 'C · CALCULATING'),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _CastingOrb(),
                  const SizedBox(height: 16),
                  const Text(
                    '사주 4기둥을 세우는 중',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: GuinjiFonts.body,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: GuinjiColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '오행의 흐름을 읽고\n귀인의 결을 짚어봅니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: GuinjiFonts.body,
                      fontSize: 12,
                      height: 1.5,
                      color: GuinjiColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _ShimmerProgressBar(),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: const [
                        _SkeletonLine(widthFactor: 0.6),
                        SizedBox(height: 8),
                        _SkeletonLine(widthFactor: 0.8),
                        SizedBox(height: 8),
                        _SkeletonLine(widthFactor: 0.5),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: GuinjiColors.gold.withValues(alpha: 0.12),
                      border: Border.all(
                        color: GuinjiColors.gold.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '평균 800ms 이내에 완료됩니다',
                      style: TextStyle(
                        fontFamily: GuinjiFonts.body,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: GuinjiColors.gold,
                      ),
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

/// 캐스팅 캐릭터 페어(좌: 신통도령 casting, 우: 방통선녀 pointing) +
/// 중앙 펄스 오브(占, 2s pulse) + 8s 회전 점선 링.
///
/// HTML은 `.char-pair-l`/`.char-pair-r` bob 애니메이션(2.8s)을 캐릭터
/// 각각에, `orb-pulse`(2s)를 중앙 오브에 독립적으로 적용한다. 기존
/// [GuinjiCharPair]는 정확히 2개 자식(좌/우)만 감싸는 형태라 중앙에 별도
/// 오브를 끼워 넣을 수 없으므로, 여기서는 동일한 bob 수식을 재사용하는
/// 전용 3분할 Row를 직접 구성한다.
class _CastingOrb extends StatefulWidget {
  const _CastingOrb();

  @override
  State<_CastingOrb> createState() => _CastingOrbState();
}

class _CastingOrbState extends State<_CastingOrb>
    with TickerProviderStateMixin {
  late final AnimationController _bobController;
  late final AnimationController _pulseController;
  late final AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _bobController.dispose();
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  double _bob(double t, {required double from, required double mid}) {
    if (t <= 0.5) return from + (mid - from) * (t / 0.5);
    return mid + (from - mid) * ((t - 0.5) / 0.5);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bobController, _pulseController, _ringController]),
      builder: (context, _) {
        final t = _bobController.value;
        final leftY = _bob(t, from: 0, mid: -4);
        final leftRot = _bob(t, from: -1.5, mid: 1.0);
        final rightY = _bob(t, from: -4, mid: 0);
        final rightRot = _bob(t, from: 1.5, mid: -1.0);

        final pt = _pulseController.value;
        final scale = pt <= 0.5
            ? 1.0 + 0.08 * (pt / 0.5)
            : 1.08 - 0.08 * ((pt - 0.5) / 0.5);
        final orbOpacity = pt <= 0.5
            ? 0.9 + 0.1 * (pt / 0.5)
            : 1.0 - 0.1 * ((pt - 0.5) / 0.5);

        final ringAngle = _ringController.value * 2 * 3.14159265;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Transform.translate(
              offset: Offset(0, leftY),
              child: Transform.rotate(
                angle: leftRot * (3.14159265 / 180),
                child: Image.asset(
                  'assets/images/guinji/doryeong/casting.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 84,
              height: 84,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: ringAngle,
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: GuinjiColors.lavender.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: orbOpacity,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 84,
                        height: 84,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              GuinjiColors.lavender,
                              GuinjiColors.lavender.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                        child: const Text(
                          '占',
                          style: TextStyle(
                            fontFamily: GuinjiFonts.display,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Transform.translate(
              offset: Offset(0, rightY),
              child: Transform.rotate(
                angle: rightRot * (3.14159265 / 180),
                child: Image.asset(
                  'assets/images/guinji/seonnyeo/pointing.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShimmerProgressBar extends StatefulWidget {
  const _ShimmerProgressBar();

  @override
  State<_ShimmerProgressBar> createState() => _ShimmerProgressBarState();
}

class _ShimmerProgressBarState extends State<_ShimmerProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.75 + (_controller.value * 0.25);
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 200,
            height: 3,
            decoration: BoxDecoration(
              color: GuinjiColors.surfaceCard,
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.65,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [GuinjiColors.lavender, GuinjiColors.gold],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: GuinjiColors.lavender.withValues(alpha: 0.6),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonLine extends StatefulWidget {
  const _SkeletonLine({required this.widthFactor});

  final double widthFactor;

  @override
  State<_SkeletonLine> createState() => _SkeletonLineState();
}

class _SkeletonLineState extends State<_SkeletonLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widget.widthFactor,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Container(
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                begin: Alignment(-1 + 4 * t, 0),
                end: Alignment(1 + 4 * t, 0),
                colors: [
                  GuinjiColors.surfaceCard,
                  GuinjiColors.lavender.withValues(alpha: 0.15),
                  GuinjiColors.surfaceCard,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
