import 'package:flutter/material.dart';

/// 귀인지도(Guinji Map) 8화면 공통 "캐릭터 페어" bob 애니메이션.
///
/// [design_handoff_guinji_web/Guinji Section.html] `.char-pair-l` /
/// `.char-pair-r` + 두 keyframe 스펙을 그대로 재현한다.
/// - `char-pair-l`: 0%,100% `translateY(0) rotate(-1.5deg)`,
///   50% `translateY(-4px) rotate(1deg)`
/// - `char-pair-r`: 0%,100% `translateY(-4px) rotate(1.5deg)`,
///   50% `translateY(0) rotate(-1deg)` (좌측과 반대 위상)
/// - 화면별 duration: L/S/Y = 3.6s, C = 2.8s (호출부에서 [duration] 지정)
class GuinjiCharPair extends StatefulWidget {
  const GuinjiCharPair({
    super.key,
    required this.leftAsset,
    required this.rightAsset,
    this.duration = const Duration(milliseconds: 3600),
    this.imageSize = 96,
    this.gap = 12,
  });

  final String leftAsset;
  final String rightAsset;
  final Duration duration;
  final double imageSize;
  final double gap;

  @override
  State<GuinjiCharPair> createState() => _GuinjiCharPairState();
}

class _GuinjiCharPairState extends State<GuinjiCharPair>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
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
      builder: (context, child) {
        final t = _controller.value; // 0~1
        // 0%,50%,100% 3점을 선형보간(HTML keyframe과 동일한 형태)
        double bob(double t, {required double from, required double mid}) {
          if (t <= 0.5) {
            return lerpDouble(from, mid, t / 0.5)!;
          }
          return lerpDouble(mid, from, (t - 0.5) / 0.5)!;
        }

        final leftY = bob(t, from: 0, mid: -4);
        final leftRot = bob(t, from: -1.5, mid: 1.0);
        final rightY = bob(t, from: -4, mid: 0);
        final rightRot = bob(t, from: 1.5, mid: -1.0);

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Transform.translate(
              offset: Offset(0, leftY),
              child: Transform.rotate(
                angle: leftRot * (3.14159265 / 180),
                child: Image.asset(
                  widget.leftAsset,
                  width: widget.imageSize,
                  height: widget.imageSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(width: widget.gap),
            Transform.translate(
              offset: Offset(0, rightY),
              child: Transform.rotate(
                angle: rightRot * (3.14159265 / 180),
                child: Image.asset(
                  widget.rightAsset,
                  width: widget.imageSize,
                  height: widget.imageSize,
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

double? lerpDouble(num? a, num? b, double t) {
  if (a == null || b == null) return null;
  return a + (b - a) * t;
}
