// shrine_chrome.dart — 신당(神堂) 공용 컴포넌트 + 상시 오버레이 + 타자기 + 안전한 영상.
// 신당 디자인 핸드오프(widgets/chrome.dart)를 그대로 이식했다. go_router 의존이
// 전혀 없는 순수 위젯 레이어라 로직 변경 없이 포팅(네이밍만 Shrine 접두사로 통일).
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';
import '../../domain/shrine_tokens.dart';

/// 누르면 작아진다 (.97, 0.2s). 커지지 않는다. 스프링 바운스 금지.
class ShrinePress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  const ShrinePress({super.key, required this.child, this.onTap, this.enabled = true});
  @override
  State<ShrinePress> createState() => _ShrinePressState();
}

class _ShrinePressState extends State<ShrinePress> {
  bool _d = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => setState(() => _d = true) : null,
        onTapCancel: () => setState(() => _d = false),
        onTapUp: (_) => setState(() => _d = false),
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
            scale: _d ? ShrineMotion.pressScale : 1,
            duration: ShrineMotion.press,
            curve: ShrineMotion.ease,
            child: widget.child),
      );
}

/// 빨강 버튼 — h56 · r12 · 3단 그라데이션 · 금테 .7 + 안쪽 4px 금테 .28 · 붉은 글로우 · 우측 ›
class ShrineRedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final double ts;
  const ShrineRedButton(this.label, {super.key, this.onTap, this.enabled = true, this.ts = 1});
  @override
  Widget build(BuildContext context) => ShrinePress(
      onTap: onTap,
      enabled: enabled,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ShrineRadius.button),
          gradient: enabled
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [ShrineColor.btnTop, ShrineColor.btnMid, ShrineColor.btnBot],
                  stops: [0, .55, 1])
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF3A1513), Color(0xFF22100E)]),
          border: Border.all(color: enabled ? ShrineColor.btnBorder : const Color(0x38D6AA64)),
          boxShadow: enabled ? ShrineGlow.redButton : null,
        ),
        child: Stack(children: [
          Positioned.fill(
              child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x47D6AA64)))))),
          Center(
              child: Text(label,
                  style: ShrineType.say(ts,
                          size: 16, w: FontWeight.w700, c: enabled ? ShrineColor.btnText : const Color(0x61F8EAD6))
                      .copyWith(height: 1, letterSpacing: .32))),
          Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: Center(
                  child: Text('›',
                      style: ShrineType.say(1, size: 22, c: ShrineColor.btnText.withValues(alpha: .8))
                          .copyWith(height: 1)))),
        ]),
      ));
}

/// 주제 버튼 — h54 · r11 · 좌측 34px 원형 금 인장
class ShrineTopicButton extends StatelessWidget {
  final String seal, label, ro;
  final bool selected, dim;
  final VoidCallback? onTap;
  final double ts;
  const ShrineTopicButton(
      {super.key,
      required this.seal,
      required this.label,
      this.ro = '',
      this.selected = false,
      this.dim = false,
      this.onTap,
      this.ts = 1});
  @override
  Widget build(BuildContext context) => ShrinePress(
      onTap: onTap,
      child: AnimatedOpacity(
          opacity: dim ? .35 : 1,
          duration: ShrineMotion.screen,
          child: AnimatedContainer(
            duration: ShrineMotion.screen,
            height: 54,
            padding: const EdgeInsets.fromLTRB(10, 0, 16, 0),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ShrineRadius.topic),
                gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xEB961C18), Color(0xEB5A0D0B)]),
                border: Border.all(color: selected ? ShrineColor.redHot : const Color(0x8CD6AA64)),
                boxShadow: selected ? ShrineGlow.redSoft : null),
            child: Row(children: [
              Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0x731E0605),
                      border: Border.all(color: const Color(0xBFD6AA64))),
                  child: Text(seal, style: ShrineType.display(16, c: ShrineColor.gold).copyWith(height: 1))),
              const SizedBox(width: 14),
              Text(label,
                  style: ShrineType.say(ts, size: 15.5, w: FontWeight.w700, c: ShrineColor.btnText)
                      .copyWith(height: 1)),
              const Spacer(),
              Text(ro, style: ShrineType.mono(c: const Color(0x80F8EAD6)).copyWith(letterSpacing: 2.4)),
            ]),
          )));
}

/// 필 — h50 · r999 · fg 10% + 1px 28% + blur 10 · Pretendard 500
class ShrinePill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double height;
  const ShrinePill({super.key, required this.child, this.onTap, this.height = 50});
  @override
  Widget build(BuildContext context) => ShrinePress(
      onTap: onTap,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                  height: height,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: const Color(0x1AEFE4D2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x47EFE4D2))),
                  child: DefaultTextStyle(style: ShrineType.ui(1), maxLines: 1, softWrap: false, child: child)))));
}

/// 아이콘 버튼 — 38 원형 · rgba(8,4,4,.5) · 금선 .32 · blur 12
class ShrineIconBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String semantic;
  const ShrineIconBtn({super.key, required this.child, this.onTap, required this.semantic});
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: semantic,
      child: ShrinePress(
          onTap: onTap,
          child: ClipOval(
              child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0x80080404),
                          border: Border.all(color: ShrineColor.goldLine)),
                      child: child)))));
}

/// 화자 배지 — h24 · r5 · #a11d19 + 금테 .5 · "월화" + "月華"
class ShrineSpeakerBadge extends StatelessWidget {
  const ShrineSpeakerBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
          color: ShrineColor.red,
          borderRadius: BorderRadius.circular(ShrineRadius.badge),
          border: Border.all(color: const Color(0x80D6AA64))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('월화', style: ShrineType.say(1, size: 12.5, w: FontWeight.w700, c: ShrineColor.btnText).copyWith(height: 1)),
        const SizedBox(width: 5),
        Text('月華', style: ShrineType.display(10, c: const Color(0xB3F8EAD6)).copyWith(height: 1)),
      ]));
}

/// 대사 패널 — 뒤 영상이 비쳐야 함 (panel .74 + blur 10)
class ShrineDialoguePanel extends StatelessWidget {
  final Widget child;
  const ShrineDialoguePanel({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                  color: ShrineColor.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ShrineColor.goldLine)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [const ShrineSpeakerBadge(), const SizedBox(height: 12), child]))));
}

/// 타자기 — 60/42/38ms. 탭하면 즉시 완성(기다림은 강요하지 않는다).
class ShrineTypewriter extends StatefulWidget {
  final String text;
  final Duration speed;
  final TextStyle style;
  final bool instant;
  final VoidCallback? onDone;
  const ShrineTypewriter(this.text,
      {super.key, required this.speed, required this.style, this.instant = false, this.onDone});
  @override
  State<ShrineTypewriter> createState() => _ShrineTypewriterState();
}

class _ShrineTypewriterState extends State<ShrineTypewriter> {
  int _n = 0;
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    if (widget.instant) {
      _n = widget.text.characters.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone?.call());
      return;
    }
    _t = Timer.periodic(widget.speed, (t) {
      setState(() => _n++);
      if (_n >= widget.text.characters.length) {
        t.cancel();
        widget.onDone?.call();
      }
    });
  }

  void complete() {
    _t?.cancel();
    if (_n < widget.text.characters.length) {
      setState(() => _n = widget.text.characters.length);
      widget.onDone?.call();
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: complete, child: Text(widget.text.characters.take(_n).toString(), style: widget.style));
}

/// 안전한 영상 — 신당_개발지시서_v1.4.pdf §12.2 함정 전량 반영
///  · muted 직접 지정(setVolume(0)) · 1회 재생은 끝난 뒤 재시도 금지
///  · 안전 타이머 6.8s · 실패하면 포스터 이미지
///  · onProgress(t/dur) — burn 마스크 동기화용
class ShrineSafeVideo extends StatefulWidget {
  final String name;
  final bool loop;
  final VoidCallback? onEnd;
  final ValueChanged<double>? onProgress;
  final bool reduceMotion;
  final Duration safety;
  final Alignment align;
  const ShrineSafeVideo(this.name,
      {super.key,
      this.loop = false,
      this.onEnd,
      this.onProgress,
      this.reduceMotion = false,
      this.safety = ShrineMotion.safety,
      this.align = Alignment.center});
  @override
  State<ShrineSafeVideo> createState() => _ShrineSafeVideoState();
}

class _ShrineSafeVideoState extends State<ShrineSafeVideo> {
  VideoPlayerController? _c;
  bool _failed = false, _done = false;
  Timer? _safe;
  void _finish() {
    if (_done) return;
    _done = true;
    widget.onEnd?.call();
  }

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion && !widget.loop) {
      _failed = true;
      _safe = Timer(const Duration(milliseconds: 1500), _finish);
      return;
    }
    final c = VideoPlayerController.asset('$kShrineVideoBase${widget.name}.mp4',
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _c = c;
    c.initialize().then((_) async {
      if (!mounted) return;
      await c.setVolume(0);
      await c.setLooping(widget.loop);
      await c.play();
      setState(() {});
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
    c.addListener(() {
      final v = c.value;
      if (!v.isInitialized || v.duration == Duration.zero) return;
      final t = v.position.inMilliseconds / v.duration.inMilliseconds;
      widget.onProgress?.call(t.clamp(0, 1));
      if (!widget.loop && t >= .999) _finish();
      if (v.hasError) setState(() => _failed = true);
    });
    if (!widget.loop && widget.onEnd != null) _safe = Timer(widget.safety, _finish);
  }

  @override
  void dispose() {
    _safe?.cancel();
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 포스터(.jpg)는 영상(.mp4)과 함께 assets/videos/shrine/ 에 있다(P0에서 복사 완료).
    final poster = Image.asset('$kShrineVideoBase${widget.name}.jpg', fit: BoxFit.cover, alignment: widget.align);
    final c = _c;
    if (_failed || c == null || !c.value.isInitialized) return Positioned.fill(child: poster);
    return Positioned.fill(
        child: FittedBox(
            fit: BoxFit.cover,
            alignment: widget.align,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c))));
  }
}

/// 상시 오버레이 4겹 — 그레인 · 붉은 숨결 · 꽃잎 · 불씨. 모두 IgnorePointer.
/// 움직임 줄이기면 그레인·파티클 숨김.
class ShrineAtmosphere extends StatefulWidget {
  final int petals, embers;
  final bool breath, grain, reduceMotion;
  const ShrineAtmosphere(
      {super.key,
      this.petals = 6,
      this.embers = 0,
      this.breath = true,
      this.grain = true,
      this.reduceMotion = false});
  @override
  State<ShrineAtmosphere> createState() => _ShrineAtmosphereState();
}

class _ShrineAtmosphereState extends State<ShrineAtmosphere> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 90))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(size: Size.infinite, painter: _ShrineAtmoP(_c.value * 90, widget))));
}

class _ShrineAtmoP extends CustomPainter {
  final double t;
  final ShrineAtmosphere w;
  _ShrineAtmoP(this.t, this.w);
  double _r(int s) {
    final x = math.sin(s * 999.0) * 10000;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas c, Size s) {
    if (w.breath) {
      // 5s 붉은 숨결 (하단 radial, screen)
      final a = .25 + .65 * (.5 - .5 * math.cos(t / 5 * 2 * math.pi));
      final r = Rect.fromCenter(
          center: Offset(s.width / 2, s.height * 1.08), width: s.width * 1.8, height: s.height * .8);
      c.drawRect(
          Offset.zero & s,
          Paint()
            ..blendMode = BlendMode.screen
            ..shader = RadialGradient(colors: [
              Color.fromRGBO(161, 29, 25, .55 * a),
              const Color(0x00A11D19)
            ], stops: const [0, .7])
                .createShader(r));
    }
    if (w.reduceMotion) return;
    for (var i = 0; i < w.petals; i++) {
      // 꽃잎 9×13 · 9s linear · 540°
      final dur = 8 + _r(i) * 3, ph = ((t + _r(i + 3) * 9) % dur) / dur;
      final x = (.08 + _r(i + 1) * .88) * s.width - 60 * ph, y = -20 + (s.height + 40) * ph;
      c.save();
      c.translate(x, y);
      c.rotate(ph * 3 * math.pi);
      c.drawPath(
          Path()
            ..moveTo(0, 0)
            ..quadraticBezierTo(9, 0, 9, 13)
            ..quadraticBezierTo(0, 13, 0, 0),
          Paint()
            ..color = Color.fromRGBO(179, 38, 31, i.isOdd ? .5 : .75)
            ..maskFilter = i.isOdd ? const MaskFilter.blur(BlurStyle.normal, 2) : null);
      c.restore();
    }
    for (var i = 0; i < w.embers; i++) {
      // 불씨 3px · 6s ease-in · 아래→위
      final dur = 4 + _r(i + 2) * 3, ph = ((t + _r(i + 7) * 6) % dur) / dur, e = ph * ph;
      final x = (.06 + _r(i + 11) * .88) * s.width + (_r(i + 5) - .5) * 80 * e, y = s.height + 10 - 760 * e;
      final a = ph < .12 ? ph / .12 : 1 - ph;
      c.drawCircle(Offset(x, y), 4,
          Paint()
            ..color = Color.fromRGBO(255, 140, 60, .8 * a)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      c.drawCircle(Offset(x, y), 1.5, Paint()..color = ShrineColor.ember.withValues(alpha: a));
    }
    if (w.grain) {
      // 그레인 .09 · 0.9s steps(4) — 프레임 단위로 시드만 바꿔 '튀게'
      final step = (t / .225).floor();
      final p = Paint()..color = const Color(0x17FFFFFF);
      for (var i = 0; i < 900; i++) {
        c.drawRect(Rect.fromLTWH(_r(i + step * 1000) * s.width, _r(i + step * 1000 + 7) * s.height, 1, 1), p);
      }
    }
  }

  @override
  bool shouldRepaint(_ShrineAtmoP o) => true;
}
