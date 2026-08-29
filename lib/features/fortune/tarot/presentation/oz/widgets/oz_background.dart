import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../oz_theme.dart';

/// [타로 오즈 리스킨] 딥퍼플 그라디언트 + 별빛 배경.
///
/// README 절대 금지사항("단색 배경 금지, 항상 그라디언트+별") 준수.
/// [OzStarField]는 CustomPainter로 정적 별을 그리고(성능 부담 없음),
/// 필요 시 [twinkle]을 켜면 은은한 반짝임 애니메이션을 더한다.
class OzBackground extends StatelessWidget {
  final bool twinkle;
  final double starDensity;
  const OzBackground({super.key, this.twinkle = true, this.starDensity = 46});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: OzColors.bgGradient),
        child: Stack(
          children: [
            // 좌상단 은은한 라일락 광원(oz-styles.css .canvas radial-gradient 재현)
            Positioned(
              left: -60,
              top: -40,
              child: _GlowBlob(color: const Color(0x26B48CDC), size: 320),
            ),
            Positioned(
              right: -80,
              top: 220,
              child: _GlowBlob(color: const Color(0x0DF5D98A), size: 360),
            ),
            Positioned.fill(
              child: OzStarField(density: starDensity, twinkle: twinkle),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// 결정적(deterministic) 의사난수 별들을 그리는 별빛 필드.
/// oz-illustrations.jsx의 StarField 로직(인덱스 기반 결정적 배치)을
/// Flutter CustomPainter로 재현.
class OzStarField extends StatefulWidget {
  final double density;
  final bool twinkle;
  const OzStarField({super.key, this.density = 46, this.twinkle = true});

  @override
  State<OzStarField> createState() => _OzStarFieldState();
}

class _OzStarFieldState extends State<OzStarField>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (!widget.twinkle) return;
      setState(() => _t = elapsed.inMilliseconds / 1000.0);
    });
    if (widget.twinkle) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _StarFieldPainter(density: widget.density, time: _t),
        size: Size.infinite,
      ),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  final double density;
  final double time;
  _StarFieldPainter({required this.density, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final count = density.round();
    final paint = Paint()..color = OzColors.fg;
    for (var i = 0; i < count; i++) {
      final x = ((i * 137.5 + 23) % 100) / 100 * size.width;
      final y = ((i * 91.3 + 17) % 100) / 100 * size.height;
      final baseOpacity = 0.35 + (i % 5) * 0.12;
      final twinkle = sin(time * 1.4 + i * 0.7) * 0.18;
      final opacity = (baseOpacity + twinkle).clamp(0.12, 0.95);
      final r = 0.6 + (i % 4) * 0.35;
      paint.color = OzColors.fg.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), r, paint);
      // 5개마다 하나씩 4각 스파클(큰 별)
      if (i % 9 == 0) {
        _drawSparkle(canvas, Offset(x, y), r * 3, opacity);
      }
    }
  }

  void _drawSparkle(Canvas canvas, Offset c, double size, double opacity) {
    final paint = Paint()
      ..color = OzColors.gold.withValues(alpha: opacity * 0.9);
    final path = Path()
      ..moveTo(c.dx, c.dy - size)
      ..lineTo(c.dx + size * 0.22, c.dy - size * 0.22)
      ..lineTo(c.dx + size, c.dy)
      ..lineTo(c.dx + size * 0.22, c.dy + size * 0.22)
      ..lineTo(c.dx, c.dy + size)
      ..lineTo(c.dx - size * 0.22, c.dy + size * 0.22)
      ..lineTo(c.dx - size, c.dy)
      ..lineTo(c.dx - size * 0.22, c.dy - size * 0.22)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.density != density;
}
