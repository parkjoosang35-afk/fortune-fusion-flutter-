// shrine_bujeok.dart — 붓글씨 부적. 화면·1080×1920 PNG·A5 인쇄가 같은 위젯을 쓴다
// (지시서 §7.4 "화면에서 본 그 부적이 종이가 된다"). 신당 디자인 핸드오프
// (widgets/bujeok.dart)를 그대로 이식하되, [사용자 확정 결정 ②]에 따라
// saju(birth, hour) 플레이스홀더 호출을 ShrineSajuAdapter.verticalPillarText()
// (기존 정통사주 만세력 엔진 재사용)로 교체했다 — 이 한 줄 외에는 로직
// 변경이 없다(레이아웃 비율·쓰기 순서·붓글씨 3겹 등 변경 금지 값 그대로).
//
// 모든 치수는 부적 폭 W 에 대한 비율(HTML cqw 단위 = W/100). 비율 기본 9:20.
//   p    : 쓰기 진행률 0..1 (勅→令→부호상→이름 n자→부호하→사주→인장, 1자 0.9s)
//   burn : 0..1 아래에서 위로 사라지는 마스크(burnLine)
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import '../../domain/shrine_rite_data.dart';
import '../../domain/shrine_saju_adapter.dart';
import '../../domain/shrine_tokens.dart';
import 'shrine_hanji.dart';
import 'shrine_sigils.dart';

class ShrineBujeok extends StatelessWidget {
  final String name;
  final DateTime birth;
  final String? hour;
  final ShrineTopicDef topic;
  final double p;
  final double burn;
  final double ratio; // width / height
  final bool frame;
  const ShrineBujeok({
    super.key,
    required this.name,
    required this.birth,
    this.hour,
    required this.topic,
    this.p = 1,
    this.burn = 0,
    this.ratio = 9 / 20,
    this.frame = true,
  });

  List<String> get _chars => name.isEmpty ? ['　'] : name.characters.take(4).toList();
  List<String> get _seq => ['勅', '令', 'top', for (var i = 0; i < _chars.length; i++) 'n$i', 'bot', 'saju', 'seal'];
  double _lp(String id) {
    final s = _seq;
    return (p * s.length - s.indexOf(id)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: ratio,
      child: LayoutBuilder(builder: (ctx, c) {
        final w = c.maxWidth, h = c.maxHeight, u = w / 100; // u == 1cqw
        final nameSize = math.min(25.0, 70 / math.max(_chars.length, 2)) * 1.25 * u;
        // [사용자 확정 결정 ②] 기존 정통사주 만세력 엔진으로 실제 계산한
        // 사주 세로쓰기 문자열(신당 스타터의 saju(birth, hour) 플레이스홀더를 대체).
        final sajuText = ShrineSajuAdapter.verticalPillarText(birth: birth, hourLabel: hour);
        Widget paper = Stack(children: [
          const Positioned.fill(child: ShrineHanjiPaper()),
          if (frame) Positioned.fill(child: CustomPaint(painter: _FramePainter())),
          // ① 勅令
          Positioned(
              top: h * .046,
              left: 0,
              right: 0,
              child: Column(children: [
                ShrineBrushReveal(
                    p: _lp('勅'),
                    child: Text('勅', style: ShrineType.display(17 * u, c: ShrineColor.jusa).copyWith(height: 1))),
                SizedBox(height: u),
                ShrineBrushReveal(
                    p: _lp('令'),
                    child: Text('令', style: ShrineType.display(17 * u, c: ShrineColor.jusa).copyWith(height: 1))),
              ])),
          // ② 부호 상단
          Positioned(
              top: h * .21,
              left: w * .19,
              right: w * .19,
              child: ShrineBrushReveal(p: _lp('top'), child: SigilTop(chars: topic.top))),
          // ③ 이름
          Positioned(
              top: h * .365,
              height: h * .29,
              left: 0,
              right: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _chars.length; i++)
                    ShrineBrushReveal(p: _lp('n$i'), child: Text(_chars[i], style: ShrineType.brush(nameSize)))
                ],
              )),
          // 이름 양옆 세로 줄긋기
          Positioned(
              top: h * .36,
              height: h * .30,
              left: w * .22,
              width: w * .56,
              child: ShrineBrushReveal(p: _lp('top'), child: CustomPaint(painter: _SideRulePainter()))),
          // ④ 사주 세로쓰기(좌) · 부적명 한자(우)
          Positioned(
              top: h * .375,
              left: w * .095,
              child: ShrineBrushReveal(
                  p: _lp('saju'), child: ShrineVerticalText(sajuText, size: 5.2 * u, spacing: .18))),
          Positioned(
              top: h * .375,
              right: w * .095,
              child: ShrineBrushReveal(
                  p: _lp('saju'), child: ShrineVerticalText(topic.hanja, size: 5.2 * u, spacing: .3))),
          // ② 부호 하단
          Positioned(
              top: h * .655,
              left: w * .27,
              right: w * .27,
              child: ShrineBrushReveal(p: _lp('bot'), child: SigilBottom(topic: topic.key))),
          // ⑤ 인장 — 등장 시 1.6 → 1, −4°
          Positioned(
              bottom: h * .038,
              left: w / 2 - 10.5 * u,
              width: 21 * u,
              height: 21 * u,
              child: AnimatedOpacity(
                  opacity: _lp('seal') > 0 ? .92 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: AnimatedScale(
                      scale: _lp('seal') > 0 ? 1 : 1.6,
                      duration: ShrineMotion.stamp,
                      curve: ShrineMotion.stampEase,
                      child: Transform.rotate(
                          angle: -4 * math.pi / 180,
                          child: Container(
                            decoration:
                                BoxDecoration(color: ShrineColor.jusa, borderRadius: BorderRadius.circular(1.6 * u)),
                            alignment: Alignment.center,
                            child: Text(topic.key,
                                style: ShrineType.display(14 * u, c: ShrineColor.hanji1).copyWith(height: 1)),
                          ))))),
        ]);
        paper = ClipRRect(borderRadius: BorderRadius.circular(1.2 * u), child: paper);
        if (burn > 0) {
          // 아래에서 위로: transparent [0, burn] → 불투명 [burn+7%]
          paper = ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: const [Color(0x00000000), Color(0x00000000), Color(0xFF000000)],
                stops: [0, burn.clamp(0, 1), (burn + .07).clamp(0, 1)]).createShader(r),
            child: paper,
          );
        }
        return Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: paper),
          if (burn > 0 && burn < 1) // 타는 가장자리
            Positioned(
                left: -w * .02,
                right: -w * .02,
                bottom: h * burn - 2 * u,
                height: 7 * u,
                child: const IgnorePointer(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: RadialGradient(
                                colors: [Color(0xF2FFAA50), Color(0x99E0412F), Color(0x00E0412F)],
                                stops: [0, .4, .72]))))),
        ]);
      }),
    );
  }
}

/// 붓글씨가 써지는 3겹 — 반드시 유지(지시서 §6).
///  1) clip  inset(0 0 (1-p)*100% 0)  위→아래로 드러남
///  2) blur  (1-p)*2px               먹이 스밈
///  3) rotate (p-1)*4deg             손의 기울기
class ShrineBrushReveal extends StatelessWidget {
  final double p;
  final Widget child;
  const ShrineBrushReveal({super.key, required this.p, required this.child});
  @override
  Widget build(BuildContext context) {
    final q = p.clamp(0.0, 1.0);
    if (q <= 0) return Opacity(opacity: 0, child: child);
    return Transform.rotate(
      angle: (q - 1) * 4 * math.pi / 180,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: (1 - q) * 2, sigmaY: (1 - q) * 2),
        child: ClipRect(clipper: _TopReveal(q), child: child),
      ),
    );
  }
}

class _TopReveal extends CustomClipper<Rect> {
  final double q;
  _TopReveal(this.q);
  @override
  Rect getClip(Size s) => Rect.fromLTWH(-4, -4, s.width + 8, s.height * q + 4);
  @override
  bool shouldReclip(_TopReveal o) => o.q != q;
}

class ShrineVerticalText extends StatelessWidget {
  final String text;
  final double size, spacing;
  const ShrineVerticalText(this.text, {super.key, required this.size, this.spacing = .2});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        for (final ch in text.replaceAll(' ', '').characters)
          Padding(
              padding: EdgeInsets.only(bottom: size * spacing),
              child: Text(ch,
                  style: ShrineType.display(size, w: FontWeight.w700, c: ShrineColor.jusa.withValues(alpha: .9))
                      .copyWith(height: 1))),
      ]);
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..color = ShrineColor.jusa;
    c.drawRect(Rect.fromLTWH(s.width * .045, s.height * .018, s.width * .91, s.height * .964),
        p..strokeWidth = s.width * .013);
    c.drawRect(Rect.fromLTWH(s.width * .07, s.height * .029, s.width * .86, s.height * .942),
        p..strokeWidth = s.width * .0045);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _SideRulePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..color = ShrineColor.jusa
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    c.drawPath(
        Path()
          ..moveTo(s.width * .06, s.height * .02)
          ..quadraticBezierTo(s.width * .03, s.height * .5, s.width * .07, s.height * .98),
        p);
    c.drawPath(
        Path()
          ..moveTo(s.width * .94, s.height * .02)
          ..quadraticBezierTo(s.width * .97, s.height * .5, s.width * .93, s.height * .98),
        p);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// 쓰기 애니메이션 래퍼 — 글자당 0.9s. 움직임 줄이기면 즉시 p=1.
class ShrineAnimatedBujeok extends StatefulWidget {
  final String name;
  final DateTime birth;
  final String? hour;
  final ShrineTopicDef topic;
  final bool reduceMotion;
  final VoidCallback? onDone;
  final double ratio;
  const ShrineAnimatedBujeok({
    super.key,
    required this.name,
    required this.birth,
    this.hour,
    required this.topic,
    this.reduceMotion = false,
    this.onDone,
    this.ratio = 9 / 20,
  });
  @override
  State<ShrineAnimatedBujeok> createState() => _ShrineAnimatedBujeokState();
}

class _ShrineAnimatedBujeokState extends State<ShrineAnimatedBujeok> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    final n = 6 + widget.name.characters.take(4).length;
    _c = AnimationController(vsync: this, duration: ShrineMotion.brushPerChar * n)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone?.call();
      });
    widget.reduceMotion ? _c.value = 1 : _c.forward();
    if (widget.reduceMotion) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone?.call());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _c,
      builder: (_, __) => ShrineBujeok(
          name: widget.name, birth: widget.birth, hour: widget.hour, topic: widget.topic, p: _c.value, ratio: widget.ratio));
}
