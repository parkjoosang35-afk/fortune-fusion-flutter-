// shrine_hanji.dart — 0바이트 한지(신당_개발지시서_v1.4.pdf §5.3): 바탕
// 그라데이션 + 가로5/세로7 결 + 안쪽 그을림 + 괴황지 얼룩. 신당 디자인
// 핸드오프(widgets/hanji.dart)를 로직 변경 없이 그대로 이식했다.
import 'package:flutter/widgets.dart';
import '../../domain/shrine_tokens.dart';

class ShrineHanjiPaper extends StatelessWidget {
  final BorderRadius? radius;
  const ShrineHanjiPaper({super.key, this.radius});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: radius ?? BorderRadius.zero,
        child: CustomPaint(painter: _ShrineHanjiP()),
      );
}

class _ShrineHanjiP extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(
        r,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [ShrineColor.hanji1, ShrineColor.hanji2])
              .createShader(r));
    // 결 — multiply 대신 저알파 선으로 근사
    final h = Paint()
      ..color = const Color(0x0D784F28)
      ..strokeWidth = 1;
    for (double y = 0; y < s.height; y += 7) {
      c.drawLine(Offset(0, y), Offset(s.width, y), h);
    }
    final v = Paint()
      ..color = const Color(0x0A784F28)
      ..strokeWidth = 1;
    for (double x = 0; x < s.width; x += 5) {
      c.drawLine(Offset(x, 0), Offset(x, s.height), v);
    }
    // 괴황지 얼룩
    void blot(Alignment a, double rx, double ry, int alpha) => c.drawRect(
        r,
        Paint()
          ..shader = RadialGradient(
                  center: a, radius: rx, colors: [Color.fromARGB(alpha, 160, 110, 40), const Color(0x00A06E28)])
              .createShader(r));
    blot(const Alignment(-.4, .4), .6, .3, 46);
    blot(const Alignment(.6, -.6), .4, .2, 31);
    // 안쪽 그을림 inset 0 0 50px rgba(120,70,30,.35)
    final edge = Paint()
      ..shader = RadialGradient(radius: .9, colors: const [Color(0x00784620), Color(0x59784620)], stops: const [.62, 1])
          .createShader(Rect.fromCenter(center: r.center, width: s.width * 1.2, height: s.height * 1.05));
    c.drawRect(r, edge);
  }

  @override
  bool shouldRepaint(_ShrineHanjiP oldDelegate) => false;
}
