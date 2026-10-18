// shrine_use_overview_screen.dart — 用(사용법 개요, 3종).
// 레퍼런스: 신당 디자인 핸드오프 screens/receive.dart UseOverviewScreen +
// UseGlyphPainter / design_files/screens-c.jsx UseOverview.
// 주제별 '어울림' 표시(流=붙이기, 그 외=지니기, 봉헌은 공통·재방문).
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../application/shrine_session_provider.dart';
import '../../domain/shrine_rite_data.dart';
import '../../domain/shrine_session.dart';
import '../../domain/shrine_tokens.dart';
import '../shrine_navigation.dart';
import '../widgets/shrine_chrome.dart';
import '../widgets/shrine_scaffold.dart';
import '../widgets/shrine_rite_rail.dart';

class ShrineUseOverviewScreen extends StatelessWidget {
  const ShrineUseOverviewScreen({super.key});

  static const _uses = [
    (
      ShrineUseKind.attach,
      '貼',
      '붙이기',
      '현관 위나 문설주에 붙이십시오.\n들어오는 것을 막습니다.',
      '流',
      'useAttach',
    ),
    (
      ShrineUseKind.carry,
      '持',
      '지니기',
      '접어 봉투에 넣어 지니십시오.\n꺼내 보지 않아도 됩니다.',
      '緣 · 財 · 命',
      'useCarry',
    ),
    (
      ShrineUseKind.offer,
      '奉',
      '봉헌하기',
      '효력을 다했다고 느끼면,\n다시 이곳으로 오십시오.',
      '공통',
      'useReturn',
    ),
  ];

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
                        center: Alignment.topCenter, radius: 1, colors: [Color(0xFF24100B), ShrineColor.bg])))),
      ],
      atmosphere: const ShrineAtmosphere(petals: 2, breath: false),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 108, 16, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('用 · HOW TO KEEP', style: ShrineType.mono()),
                const SizedBox(height: 10),
                Text('부적은 쓰임이\n세 갈래입니다.',
                    style: ShrineType.display(25 * ts).copyWith(height: 1.35)),
                const SizedBox(height: 8),
                Text.rich(TextSpan(style: ShrineType.saySmall(ts), children: [
                  TextSpan(text: '${topic.name}은 '),
                  TextSpan(text: topic.useWhere, style: const TextStyle(color: ShrineColor.fg)),
                  const TextSpan(text: '에 두는 것이 어울립니다.'),
                ])),
              ])),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(children: [
                for (var i = 0; i < _uses.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ShrineFadeRise(
                      delay: Duration(milliseconds: 200 + i * 100),
                      child: ShrinePress(
                        onTap: () => ShrineNav.go(context, _uses[i].$6),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: _uses[i].$1 == topic.use
                                  ? const Color(0x1AC9A368)
                                  : const Color(0x0AEFE4D2),
                              border: Border.all(
                                  color: _uses[i].$1 == topic.use ? ShrineColor.gold : ShrineColor.line)),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SizedBox(
                                width: 64,
                                height: 64,
                                child: CustomPaint(painter: ShrineUseGlyphPainter(_uses[i].$1))),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Text(_uses[i].$2, style: ShrineType.display(15, c: ShrineColor.gold)),
                                const SizedBox(width: 8),
                                Text(_uses[i].$3,
                                    style: ShrineType.say(ts, size: 16, w: FontWeight.w700)
                                        .copyWith(height: 1.2)),
                                const Spacer(),
                                if (_uses[i].$1 == topic.use) Text('어울림', style: ShrineType.mono(size: 9)),
                              ]),
                              const SizedBox(height: 6),
                              Text(_uses[i].$4,
                                  style: ShrineType.saySmall(ts).copyWith(fontSize: 13.5 * ts, height: 1.7)),
                              const SizedBox(height: 8),
                              Text(_uses[i].$5, style: ShrineType.mono(c: ShrineColor.faint, size: 9)),
                            ])),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          ShrineRedButton('이야기로 가기', ts: ts, onTap: () => ShrineNav.go(context, 'story')),
          const SizedBox(height: 12),
          Center(child: Text('모든 이야기와 부적은 창작 연출물입니다', style: ShrineType.ui(1, size: 10.5, c: ShrineColor.faint))),
        ]),
      ),
    );
  }
}

/// 사용법 글리프 — 64×64 · 금선 1.2 + 한지 부적 조각.
class ShrineUseGlyphPainter extends CustomPainter {
  final ShrineUseKind k;
  ShrineUseGlyphPainter(this.k);
  @override
  void paint(Canvas c, Size s) {
    final g = Paint()
      ..style = PaintingStyle.stroke
      ..color = ShrineColor.gold
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final paper = Paint()..color = const Color(0xD9ECDCB9);
    final red = Paint()
      ..style = PaintingStyle.stroke
      ..color = ShrineColor.jusa
      ..strokeWidth = 1.2;
    switch (k) {
      case ShrineUseKind.attach:
        c.drawPath(
            Path()
              ..moveTo(8, 58)
              ..lineTo(8, 14)
              ..lineTo(56, 14)
              ..lineTo(56, 58),
            g);
        c.drawLine(const Offset(4, 14), const Offset(60, 14), g);
        c.drawLine(const Offset(8, 10), const Offset(56, 10), g);
        c.drawRect(const Rect.fromLTWH(27, 17, 10, 22), paper);
        c.drawRect(const Rect.fromLTWH(27, 17, 10, 22), red);
      case ShrineUseKind.carry:
        c.drawRect(const Rect.fromLTWH(10, 22, 44, 30), g);
        c.drawPath(
            Path()
              ..moveTo(10, 22)
              ..lineTo(32, 38)
              ..lineTo(54, 22),
            g);
        c.drawRect(const Rect.fromLTWH(26, 8, 12, 20), paper);
        c.drawRect(const Rect.fromLTWH(26, 8, 12, 20), red);
      case ShrineUseKind.offer:
        c.drawLine(const Offset(14, 52), const Offset(50, 52), g);
        c.drawPath(
            Path()
              ..moveTo(20, 52)
              ..cubicTo(20, 44, 44, 44, 44, 52),
            g);
        c.drawPath(
            Path()
              ..moveTo(32, 44)
              ..cubicTo(28, 38, 36, 34, 32, 28)
              ..cubicTo(29, 23, 35, 20, 33, 16),
            g..color = const Color(0xCCC9A368));
    }
  }

  @override
  bool shouldRepaint(ShrineUseGlyphPainter oldDelegate) => oldDelegate.k != k;
}
