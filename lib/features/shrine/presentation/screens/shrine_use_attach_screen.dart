// shrine_use_attach_screen.dart — 貼(붙이기 — 문설주 입면도).
// [Dart 레퍼런스 없음] design_files/screens-c.jsx UseAttach(220-257줄)를
// 직접 Flutter로 번역했다. 원본 SVG 문 입면도는 CustomPainter로, 부적이
// 위에서 떨어져 자리잡는 연출은 AnimatedSlide+AnimatedOpacity로 치환한다.
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../application/shrine_session_provider.dart';
import '../../domain/shrine_rite_data.dart';
import '../../domain/shrine_session.dart';
import '../../domain/shrine_tokens.dart';
import '../shrine_navigation.dart';
import '../widgets/shrine_bujeok.dart';
import '../widgets/shrine_chrome.dart';
import '../widgets/shrine_scaffold.dart';
import '../widgets/shrine_rite_rail.dart';

const _kAttachSteps = [
  '勅令이 위로 가도록 세워 붙입니다',
  '들어오는 쪽을 향하게 둡니다',
  '떼어지면 버리지 말고 이곳에 봉헌하십시오',
];

class ShrineUseAttachScreen extends StatefulWidget {
  const ShrineUseAttachScreen({super.key});
  @override
  State<ShrineUseAttachScreen> createState() => _ShrineUseAttachScreenState();
}

class _ShrineUseAttachScreenState extends State<ShrineUseAttachScreen> {
  bool _on = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _on = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ShrineSessionProvider>().state;
    final topic = shrineTopics[s.topic]!;
    final ts = s.textSize.scale;
    return ShrineScreenScaffold(
      rail: const ShrineRiteRail(5),
      background: const [
        Positioned.fill(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: RadialGradient(
                        center: Alignment(0, -.4), radius: .78, colors: [Color(0xFF22100B), ShrineColor.bg])))),
      ],
      atmosphere: const ShrineAtmosphere(petals: 0, breath: false),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 108, 22, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('貼 · 붙이기', style: ShrineType.mono()),
            const SizedBox(height: 10),
            Text('현관 위나 문설주에\n붙이십시오.', style: ShrineType.display(23 * ts).copyWith(height: 1.4)),
          ]),
        ),
        SizedBox(
          height: 380,
          child: Stack(alignment: Alignment.topCenter, children: [
            Positioned(
                top: 20,
                child: SizedBox(width: 300, height: 360, child: CustomPaint(painter: _ShrineDoorPainter()))),
            Positioned(
              top: 0,
              child: AnimatedSlide(
                offset: _on ? Offset.zero : const Offset(0, -.5),
                duration: const Duration(milliseconds: 1400),
                curve: ShrineMotion.ease,
                child: AnimatedOpacity(
                  opacity: _on ? 1 : 0,
                  duration: const Duration(milliseconds: 1200),
                  child: Transform.rotate(
                      angle: _on ? 0 : -.1,
                      child: SizedBox(
                          width: 54,
                          child: ShrineBujeok(name: s.name, birth: s.birth, hour: s.hour, topic: topic))),
                ),
              ),
            ),
            Positioned(
                top: 14,
                right: 10,
                child: AnimatedOpacity(
                    opacity: _on ? 1 : 0,
                    duration: const Duration(milliseconds: 1200),
                    child: Text('← 문설주 위', style: ShrineType.mono()))),
          ]),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final t in _kAttachSteps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                        width: 18,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('0${_kAttachSteps.indexOf(t) + 1}',
                              style: ShrineType.mono(c: ShrineColor.gold).copyWith(fontSize: 10)),
                        )),
                    const SizedBox(width: 12),
                    Expanded(child: Text(t, style: ShrineType.saySmall(ts).copyWith(fontSize: 14 * ts))),
                  ]),
                ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 34),
          child: ShrinePill(onTap: () => ShrineNav.pop(context), child: const Text('사용법으로')),
        ),
      ]),
    );
  }
}

/// 문 입면도 — design_files/screens-c.jsx UseAttach의 SVG(300×380 viewBox)를
/// CustomPainter 좌표로 그대로 옮겼다(문틀·문선·손잡이·패널 가로줄 장식).
class _ShrineDoorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 300, sy = size.height / 380;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0x80C9A368)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    Offset o(double x, double y) => Offset(x * sx, y * sy);
    void line(double x1, double y1, double x2, double y2, {double opacity = 1}) => canvas.drawLine(
        o(x1, y1), o(x2, y2), Paint()
          ..style = PaintingStyle.stroke
          ..color = Color.fromRGBO(201, 163, 104, .5 * opacity)
          ..strokeWidth = 1.2);
    // 바깥 문틀
    canvas.drawPath(
        Path()
          ..moveTo(o(20, 380).dx, o(20, 380).dy)
          ..lineTo(o(20, 40).dx, o(20, 40).dy)
          ..lineTo(o(280, 40).dx, o(280, 40).dy)
          ..lineTo(o(280, 380).dx, o(280, 380).dy),
        p);
    line(6, 40, 294, 40);
    line(12, 28, 288, 28);
    // 안쪽 문짝(두 짝)
    canvas.drawPath(
        Path()
          ..moveTo(o(60, 380).dx, o(60, 380).dy)
          ..lineTo(o(60, 90).dx, o(60, 90).dy)
          ..lineTo(o(240, 90).dx, o(240, 90).dy)
          ..lineTo(o(240, 380).dx, o(240, 380).dy),
        p);
    line(150, 90, 150, 380);
    // 손잡이
    canvas.drawCircle(o(140, 240), 4 * sx, p);
    canvas.drawCircle(o(160, 240), 4 * sx, p);
    // 패널 가로줄 장식(희미하게)
    for (var i = 0; i < 6; i++) {
      final y = 120.0 + i * 40;
      line(66, y, 144, y, opacity: .25);
      line(156, y, 234, y, opacity: .25);
    }
  }

  @override
  bool shouldRepaint(_ShrineDoorPainter oldDelegate) => false;
}
