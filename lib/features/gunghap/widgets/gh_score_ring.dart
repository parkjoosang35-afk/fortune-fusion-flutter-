// ═══════════════════════════════════════════════════════════════
// FILE: gh_score_ring.dart
// [궁합지도 전면 리디자인 v4] design_handoff_gunghap_map_v4
// `flutter_starter/lib/gunghap/widgets/gh_score_ring.dart`(v3 참고 구현)
// 완전 포팅 — 점수 원형 게이지. 0→score 카운트업
// (GHMotion.scoreCount=1400ms easeOutCubic, GHMotion.scoreDelay=350ms
// 지연). size≥90이면 "big" 모드(중앙 숫자 크게 표시).
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';

class GHScoreRing extends StatefulWidget {
  const GHScoreRing({
    super.key,
    required this.score,
    this.size = 136,
    this.sub,
    this.showLabel = true,
    this.animate = true,
  });

  final int score;
  final double size;
  final String? sub;
  final bool showLabel;
  final bool animate;

  @override
  State<GHScoreRing> createState() => _GHScoreRingState();
}

class _GHScoreRingState extends State<GHScoreRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: GHMotion.scoreCount,
  );
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      Future.delayed(GHMotion.scoreDelay, () {
        if (mounted) _c.forward();
      });
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final band = GHBand.of(widget.score);
    final big = widget.size >= 90;
    return AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        final shown = (widget.score * _a.value).round();
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(widget.size),
                painter: _RingPainter(progress: (shown.clamp(0, 100)) / 100, band: band, stroke: big ? 10 : 7),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (rect) => band.gradient.createShader(rect),
                    child: Text(
                      '$shown',
                      style: GHText.resultTitle(
                        size: big ? 40 : 22,
                        // ShaderMask가 BlendMode.modulate로 이 색 위에
                        // 그라데이션을 입히므로 흰색으로 둬야 원색이 그대로
                        // 보인다(기본 GHColors.fg를 쓰면 어둡게 섞인다).
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (widget.showLabel && widget.sub != null)
                    Text(widget.sub!, style: GHText.caption()),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.band, required this.stroke});
  final double progress;
  final GHBand band;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = GHColors.track,
    );

    canvas.drawArc(
      rect,
      -1.5707963267948966, // -90deg
      6.283185307179586 * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = band.gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.band != band;
}
