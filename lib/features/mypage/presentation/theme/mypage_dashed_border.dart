import 'package:flutter/material.dart';
import 'mypage_minimal_theme.dart';

/// [마이페이지 리뉴얼] README §S02/§S04 "광고 영역 150px, radius 16, 1px
/// dashed" 스펙의 점선 테두리 박스.
///
/// Flutter에 내장 점선 테두리가 없어 전용 `CustomPainter`로 구현한다(새
/// 패키지 의존성 추가 없음). 원래 `coupang_pass_sheet.dart`(S02)에서 비공개
/// 위젯으로 처음 만들었으나, `fortune_ad_watch_dialog.dart`(S04)도 README상
/// 완전히 동일한 광고 영역 스펙을 공유하므로 중복 구현을 피하기 위해 여기
/// 공용 위젯으로 추출했다.
class MyPageDashedBorderBox extends StatelessWidget {
  const MyPageDashedBorderBox({
    super.key,
    required this.child,
    required this.radius,
    required this.height,
    this.color = MyPageColors.ink3,
  });

  final Widget child;
  final double radius;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MyPageDashedRRectPainter(radius: radius, color: color),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Padding(padding: const EdgeInsets.all(1), child: child),
      ),
    );
  }
}

class _MyPageDashedRRectPainter extends CustomPainter {
  _MyPageDashedRRectPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const dashWidth = 5.0;
    const dashGap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MyPageDashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
