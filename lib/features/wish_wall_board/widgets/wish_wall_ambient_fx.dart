import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/wish_wall_theme.dart';

/// 소원벽게시판 · 배경 앰비언스 애니메이션(순수 장식용).
///
/// [디자인 히스토리] 과거 "신통방통 소원방"(wish_room) 모듈에는 계속 회전하는
/// 마법진(Sigil)과 위로 떠오르는 빛가루(Dust) 입자 애니메이션이 있어 화면이
/// 항상 살짝 움직이는 느낌을 줬다. 그 모듈은 복주머니와 별개인 자체 화폐
/// ("조각") 경제 시스템이라 통째로 삭제했지만, 재화와 무관한 순수 시각 효과만
/// 소원벽게시판(wish_wall_board)의 화이트/앰버 톤에 맞게 재구성해 이식한다.
/// 이 파일은 애니메이션/그래픽 전용이며 어떤 재화·잔액도 참조하지 않는다.

/// 화면 전체를 감싸는 배경 앰비언스 — 은은한 회전 마법진 글로우 +
/// 위로 떠오르는 빛가루. `IgnorePointer`로 감싸 터치 이벤트를 가로채지 않는다.
class WishWallAmbientBackground extends StatelessWidget {
  const WishWallAmbientBackground({super.key, this.dustCount = 10});

  final int dustCount;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          const Positioned(
            top: -60,
            right: -40,
            child: _RotatingSigilGlow(size: 260),
          ),
          Positioned.fill(child: _RisingDust(count: dustCount)),
        ],
      ),
    );
  }
}

/// 은은하게 계속 회전하는 마법진 글로우(원형 룬 + 눈금).
/// 소원벽 앰버 액센트 컬러로 아주 낮은 불투명도만 사용해 콘텐츠를 가리지 않는다.
class _RotatingSigilGlow extends StatefulWidget {
  const _RotatingSigilGlow({required this.size});

  final double size;

  @override
  State<_RotatingSigilGlow> createState() => _RotatingSigilGlowState();
}

class _RotatingSigilGlowState extends State<_RotatingSigilGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
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
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(painter: _SigilGlowPainter()),
          ),
        );
      },
    );
  }
}

class _SigilGlowPainter extends CustomPainter {
  static const _runes = ['✧', '✦', '☾', '✵', '✶', '☆', '◇', '⟡'];

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    canvas.save();
    canvas.translate(r, r);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          WishWallColors.accent.withValues(alpha: 0.10),
          WishWallColors.accent.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(-r, -r, size.width, size.height));
    canvas.drawCircle(Offset.zero, r, glowPaint);

    final ringPaint = Paint()
      ..color = WishWallColors.accent.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset.zero, r * 0.82, ringPaint);
    canvas.drawCircle(Offset.zero, r * 0.78, ringPaint..strokeWidth = 0.5);

    final tickPaint = Paint()
      ..color = WishWallColors.accent.withValues(alpha: 0.16)
      ..strokeWidth = 0.6;
    for (int i = 0; i < 24; i++) {
      final a = (i / 24) * math.pi * 2;
      final p1 = Offset(math.cos(a) * r * 0.78, math.sin(a) * r * 0.78);
      final p2 = Offset(math.cos(a) * r * 0.82, math.sin(a) * r * 0.82);
      canvas.drawLine(p1, p2, tickPaint);
    }

    for (int i = 0; i < _runes.length; i++) {
      final a = (i / _runes.length) * math.pi * 2 - math.pi / 2;
      final rr = r * 0.66;
      final x = math.cos(a) * rr;
      final y = math.sin(a) * rr;
      final tp = TextPainter(
        text: TextSpan(
          text: _runes[i],
          style: TextStyle(
            color: WishWallColors.accent.withValues(alpha: 0.18),
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SigilGlowPainter oldDelegate) => false;
}

/// 화면 하단에서 위로 천천히 떠오르며 옅어지는 빛가루 입자.
class _RisingDust extends StatefulWidget {
  const _RisingDust({this.count = 10});

  final int count;

  @override
  State<_RisingDust> createState() => _RisingDustState();
}

class _RisingDustState extends State<_RisingDust>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.count, (i) {
      final durSec = 9 + (i % 5);
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: (durSec * 1000).round()),
      )..repeat();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return Stack(
          children: List.generate(widget.count, (i) {
            final leftFrac = ((i * 17 + 9) % 100) / 100.0;
            final particleSize = (2.0 + (i % 3)).toDouble();
            final durSec = 9 + (i % 5);
            return AnimatedBuilder(
              animation: _controllers[i],
              builder: (context, _) {
                final t = _controllers[i].value;
                final delayFrac = (i * 0.63 % durSec) / durSec;
                final adjT = (t + delayFrac) % 1.0;
                final opacity = adjT < 0.12
                    ? adjT / 0.12
                    : adjT > 0.82
                        ? (1 - adjT) / 0.18
                        : 1.0;
                return Positioned(
                  left: leftFrac * constraints.maxWidth,
                  bottom: -10 + adjT * (h + 20),
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0) * 0.55,
                    child: Container(
                      width: particleSize,
                      height: particleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            WishWallColors.accent,
                            WishWallColors.accent.withValues(alpha: 0),
                          ],
                          stops: const [0.0, 0.7],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        );
      },
    );
  }
}
