// shrine_use_carry_screen.dart — 持(지니기 — 부적 3분할 접기).
// [Dart 레퍼런스 없음] 신당 디자인 핸드오프에 Dart 버전이 없어
// design_files/screens-c.jsx UseCarry(179-218줄)를 직접 Flutter로 번역했다.
// CSS 3D(perspective + rotateX + transformStyle:preserve-3d)는 Flutter의
// Transform(Matrix4 with perspective entry) + TweenAnimationBuilder로
// 치환한다(원본 의도: 상단 1/3을 뒤로 접고, 하단 1/3을 뒤로 덮어 세 겹으로
// 만든 뒤 봉투 모양으로 축소).
import 'dart:async';
import 'dart:math' as math;
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

const _kCarrySteps = [
  '펼친 채로 한 번 바라봅니다',
  '위에서 삼분의 일을 접습니다',
  '아래를 덮어 세 겹으로 접습니다',
  '봉투에 넣고, 꺼내 보지 않습니다',
];

class ShrineUseCarryScreen extends StatefulWidget {
  const ShrineUseCarryScreen({super.key});
  @override
  State<ShrineUseCarryScreen> createState() => _ShrineUseCarryScreenState();
}

class _ShrineUseCarryScreenState extends State<ShrineUseCarryScreen> {
  int _s = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (mounted) setState(() => _s = (_s + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ShrineSessionProvider>().state;
    final topic = shrineTopics[s.topic]!;
    final ts = s.textSize.scale;
    const width = 160.0;
    const ratio = 9 / 20;
    const totalHeight = width / ratio;
    const segHeight = totalHeight / 3;
    final folding = _s == 3; // 봉투로 축소되는 단계

    Widget bujeokFor(int k) {
      // k=0 상단/1 중단/2 하단 1/3만 보이도록 OverflowBox + translate로 자른다
      // (CSS top: -k*100% 와 동일 원리).
      return ClipRect(
        child: SizedBox(
          height: segHeight,
          child: OverflowBox(
            minHeight: totalHeight,
            maxHeight: totalHeight,
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: Offset(0, -k * segHeight),
              child: SizedBox(
                  width: width,
                  height: totalHeight,
                  child: ShrineBujeok(name: s.name, birth: s.birth, hour: s.hour, topic: topic)),
            ),
          ),
        ),
      );
    }

    Widget foldSegment(int k) {
      final angle = k == 0
          ? (_s >= 1 ? -178 * math.pi / 180 : 0.0)
          : k == 2
              ? (_s >= 2 ? 178 * math.pi / 180 : 0.0)
              : 0.0;
      return Positioned(
        left: 0,
        right: 0,
        top: k * segHeight,
        height: segHeight,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: angle),
          duration: const Duration(milliseconds: 1400),
          curve: ShrineMotion.ease,
          builder: (_, value, child) => Transform(
            alignment: k == 0 ? Alignment.bottomCenter : Alignment.topCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateX(value),
            child: child,
          ),
          child: bujeokFor(k),
        ),
      );
    }

    return ShrineScreenScaffold(
      rail: const ShrineRiteRail(5),
      background: const [
        Positioned.fill(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: RadialGradient(
                        center: Alignment(0, -.36), radius: .78, colors: [Color(0xFF22100B), ShrineColor.bg])))),
      ],
      atmosphere: const ShrineAtmosphere(petals: 0, breath: false),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 108, 22, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('持 · 지니기', style: ShrineType.mono()),
            const SizedBox(height: 10),
            Text('세 번 접어 지니십시오.', style: ShrineType.display(23 * ts)),
          ]),
        ),
        SizedBox(
          height: 380,
          child: Stack(alignment: Alignment.topCenter, children: [
            AnimatedSlide(
              offset: folding ? const Offset(0, .34) : Offset.zero,
              duration: const Duration(milliseconds: 1400),
              curve: ShrineMotion.ease,
              child: AnimatedOpacity(
                opacity: folding ? 0 : 1,
                duration: const Duration(milliseconds: 1200),
                child: AnimatedScale(
                  scale: folding ? .6 : 1,
                  duration: const Duration(milliseconds: 1400),
                  curve: ShrineMotion.ease,
                  child: SizedBox(
                    width: width,
                    height: totalHeight,
                    child: Stack(clipBehavior: Clip.none, children: [
                      // 그리는 순서: 중단(뒤) → 상단·하단(앞) — CSS z-index와 동일 효과
                      foldSegment(1),
                      foldSegment(0),
                      foldSegment(2),
                    ]),
                  ),
                ),
              ),
            ),
            Positioned(
              top: segHeight * .55,
              child: AnimatedOpacity(
                opacity: folding ? 1 : 0,
                duration: const Duration(milliseconds: 1200),
                child: SizedBox(
                    width: 200,
                    height: 120,
                    child: Stack(children: [
                      Positioned.fill(
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Color(0xFFD8C393), Color(0xFFC9B07C)])))),
                      Positioned.fill(child: CustomPaint(painter: _CarryEnvelopeFlap())),
                    ])),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _kCarrySteps.length; i++)
                AnimatedOpacity(
                  opacity: i == _s ? 1 : .35,
                  duration: const Duration(milliseconds: 1000),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      SizedBox(
                          width: 18,
                          child: Text('0${i + 1}',
                              style: ShrineType.mono(c: ShrineColor.gold).copyWith(fontSize: 10))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(_kCarrySteps[i],
                              style: ShrineType.saySmall(ts).copyWith(
                                  fontSize: 14 * ts, color: i == _s ? ShrineColor.fg : ShrineColor.muted))),
                    ]),
                  ),
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

class _CarryEnvelopeFlap extends CustomPainter {
  @override
  void paint(Canvas c, Size s) => c.drawPath(
      Path()
        ..moveTo(2, 2)
        ..lineTo(s.width / 2, s.height * .55)
        ..lineTo(s.width - 2, 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x593A2616));
  @override
  bool shouldRepaint(_CarryEnvelopeFlap oldDelegate) => false;
}
