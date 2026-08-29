import 'dart:math';
import 'package:flutter/material.dart';
import '../../../wish_room/widgets/wish_room_sigil.dart';

/// [Phase C - 03_Welcome_Reward.html 반영] 팝업 배경 장식 3종:
/// 회전 마법진 2겹(`.modal-sigil`/`.modal-sigil-2`), 12방향 빛줄기
/// (`.burst .ray`), 색종이 낙하(`.confetti-piece`).
///
/// [범위 격리 원칙] 색상은 핸드오프 원문 hex를 하드코딩하며(gold/glow),
/// 기존 `WishRoomSigil` 페인터(마법진 도형)는 재사용하되 회전 duration은
/// 이 팝업 전용 값(90s/60s, 핸드오프 스펙)으로 별도 컨트롤러를 둔다
/// (`WishRoomSigilRing`은 duration이 40s/55s로 고정돼 있어 그대로 쓸 수 없음).

/// `.modal-sigil` + `.modal-sigil-2` — 정회전 90s(420px, gold 계열) +
/// 역회전 60s(280px, glow 계열) 두 겹.
class WelcomeRewardSigils extends StatefulWidget {
  const WelcomeRewardSigils({super.key});

  @override
  State<WelcomeRewardSigils> createState() => _WelcomeRewardSigilsState();
}

class _WelcomeRewardSigilsState extends State<WelcomeRewardSigils>
    with TickerProviderStateMixin {
  late final AnimationController _outerController;
  late final AnimationController _innerController;

  @override
  void initState() {
    super.initState();
    _outerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 90),
    )..repeat();
    _innerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _outerController.dispose();
    _innerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _outerController,
          builder: (context, child) => Opacity(
            opacity: 0.35,
            child: Transform.rotate(
              angle: _outerController.value * 2 * pi,
              child: child,
            ),
          ),
          child: const WishRoomSigil(
            size: 420,
            color: Color(0xFFF5D97A), // gold
            opacity: 1.0,
          ),
        ),
        AnimatedBuilder(
          animation: _innerController,
          builder: (context, child) => Opacity(
            opacity: 0.45,
            child: Transform.rotate(
              angle: -_innerController.value * 2 * pi,
              child: child,
            ),
          ),
          child: const WishRoomSigil(
            size: 280,
            color: Color(0xFFE8C8F5), // glow
            opacity: 1.0,
          ),
        ),
      ],
    );
  }
}

/// `.burst .ray` — 중심에서 12방향으로 뻗는 gold 그라디언트 선, 3s 주기로
/// scaleY(0.85↔1.08) + opacity(0.35↔0.75) 펄스.
class WelcomeRewardBurstRays extends StatefulWidget {
  final double length;

  const WelcomeRewardBurstRays({super.key, this.length = 180});

  @override
  State<WelcomeRewardBurstRays> createState() =>
      _WelcomeRewardBurstRaysState();
}

class _WelcomeRewardBurstRaysState extends State<WelcomeRewardBurstRays>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
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
        final t = Curves.easeInOut.transform(_controller.value);
        final opacity = 0.35 + 0.4 * t;
        final scaleY = 0.85 + 0.23 * t;
        return Stack(
          alignment: Alignment.center,
          children: [
            for (int i = 0; i < 12; i++)
              Transform.rotate(
                angle: (i * 30) * pi / 180,
                child: Align(
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: Offset(0, -widget.length * scaleY / 2),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 1.5,
                        height: widget.length * scaleY,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFF5D97A), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ConfettiPiece {
  _ConfettiPiece({
    required this.leftFraction,
    required this.color,
    required this.durationMs,
    required this.delayMs,
    required this.rotation,
    required this.isCircle,
  });

  final double leftFraction;
  final Color color;
  final int durationMs;
  final int delayMs;
  final double rotation;
  final bool isCircle;
}

/// `.confetti-piece` — 22개의 색종이가 위에서 아래로 떨어지며 회전, 각자
/// 다른 duration(2.5~4.5s)/delay(0~3s)로 무한 반복(핸드오프 JS 로직 이식).
class WelcomeRewardConfetti extends StatefulWidget {
  const WelcomeRewardConfetti({super.key});

  @override
  State<WelcomeRewardConfetti> createState() => _WelcomeRewardConfettiState();
}

class _WelcomeRewardConfettiState extends State<WelcomeRewardConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiPiece> _pieces;

  static const _colors = [
    Color(0xFFE8C8F5),
    Color(0xFFF5D97A),
    Color(0xFFA8D5E3),
    Color(0xFFF5C8D5),
  ];

  @override
  void initState() {
    super.initState();
    final rnd = Random(7);
    _pieces = [
      for (int i = 0; i < 22; i++)
        _ConfettiPiece(
          leftFraction: 0.05 + rnd.nextDouble() * 0.9,
          color: _colors[i % _colors.length],
          durationMs: 2500 + rnd.nextInt(2000),
          delayMs: rnd.nextInt(3000),
          rotation: rnd.nextDouble() * 360,
          isCircle: rnd.nextBool(),
        ),
    ];
    // 가장 긴 주기(delay+duration)를 하나의 반복 사이클로 잡아 컨트롤러를 돌린다.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallDistance = constraints.maxHeight > 0
            ? constraints.maxHeight + 30
            : 700.0;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final elapsedMs = _controller.value * 4500;
            return Stack(
              children: [
                for (final piece in _pieces)
                  _buildPiece(piece, elapsedMs, fallDistance),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPiece(_ConfettiPiece piece, double elapsedMs, double fallDistance) {
    // 각 조각은 delay 이후 duration 동안 0→1 진행(핸드오프 keyframes fall).
    final cycleMs = piece.delayMs + piece.durationMs;
    final localMs = elapsedMs % max(cycleMs, 1);
    if (localMs < piece.delayMs) {
      return const SizedBox.shrink();
    }
    final progress =
        ((localMs - piece.delayMs) / piece.durationMs).clamp(0.0, 1.0);
    // opacity: 0→1(첫 10%) → 유지 → 0(끝).
    double opacity;
    if (progress < 0.1) {
      opacity = progress / 0.1;
    } else {
      opacity = 1.0;
    }
    if (progress > 0.92) {
      opacity *= (1 - progress) / 0.08;
    }
    final translateY = progress * fallDistance;
    final rotateDeg = piece.rotation + progress * 720;

    return Positioned(
      left: 0,
      right: 0,
      top: -8,
      child: FractionalTranslation(
        translation: Offset(0, 0),
        child: Align(
          alignment: Alignment(piece.leftFraction * 2 - 1, -1),
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.rotate(
              angle: rotateDeg * pi / 180,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Container(
                  width: 6,
                  height: 10,
                  decoration: BoxDecoration(
                    color: piece.color,
                    borderRadius: piece.isCircle
                        ? BorderRadius.circular(999)
                        : BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
