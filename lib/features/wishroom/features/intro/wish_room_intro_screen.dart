// SCR-01 진입 인트로(overlay) + Welcome — docs/SCREENS.md §SCR-01, §Welcome ·
// app2/screens-a2.jsx › Intro()/Welcome() + app2/fx2.jsx › NavPill()/PetalRain() 1:1 이식.
// 서버가 GET /wish-rooms/me → introMode로 판단(full/short/none). 이 화면이 앱의
// '/wish-room' 진입점 역할을 한다: 로딩 → (방 없음=Welcome) / (방 있음=인트로 후 Shell).
//
// [전면 재작성 — 원본 state machine 1:1] 기존 구현은 Future.delayed 하드코딩 근사치로
// 18개 방사형 광선(halo-rays)·PetalRain·NavPill·정확한 타이밍이 모두 누락돼 있었다.
// 원본 Intro({mode,onDone})의 4단계 React state(st:0→3)를 Flutter에도 동일한 정수
// state(_st)로 재현하고, setTimeout 체인의 ms 값을 Timer로 1:1 이식한다.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/motion/wr_motion.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/fx/wr_fx.dart';
import '../../core/wr_canvas.dart';
import '../../wishroom_shell.dart';
import '../compose/compose_screen.dart';

class WishRoomIntroScreen extends StatefulWidget {
  const WishRoomIntroScreen({super.key});
  @override
  State<WishRoomIntroScreen> createState() => _WishRoomIntroScreenState();
}

class _WishRoomIntroScreenState extends State<WishRoomIntroScreen> {
  bool _showSkip = false;
  Timer? _skipTimer, _advanceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
    _advanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    final p = context.read<WishRoomProvider>();
    // [버그수정 — 실제 런타임 검증으로 발견] WrCatalog.load()가 앱 전체에서
    // 호출되는 지점이 전혀 없어 ComposeScreen 등 WrCatalog.I를 참조하는 화면이
    // LateInitializationError로 전부 크래시했다. 소원방의 공용 진입점인 이
    // _boot()에서 loadMyRoom()과 함께(병렬) 반드시 로드해, 이후 하위 화면들이
    // 안전하게 WrCatalog.I를 동기 참조할 수 있도록 보장한다.
    await Future.wait([p.loadMyRoom(), WrCatalog.load()]);
    if (!mounted) return;
    if (p.room == null) return; // Welcome 화면으로 자연 분기(build에서 처리)
    final mode = p.introMode;
    if (mode == IntroMode.none) {
      _enterShell();
      return;
    }
    // 원본: full모드는 1000ms 후 스킵 노출, short모드는 즉시 노출(skip 초기값 mode!=='full').
    if (mode == IntroMode.full) {
      _skipTimer = Timer(WrDur.introSkipShowAfter, () {
        if (mounted) setState(() => _showSkip = true);
      });
    } else {
      setState(() => _showSkip = true);
    }
    final dur = mode == IntroMode.full ? WrDur.introFull : WrDur.introShort;
    _advanceTimer = Timer(dur, _enterShell);
  }

  void _enterShell() {
    if (!mounted) return;
    debugPrint('WR_PHASE intro.end');
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const WishRoomShell()));
  }

  void _exitHome() {
    // app2 NavPill exitHome — 소원방 영역 전체를 벗어나 앱 홈으로.
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WishRoomProvider>(builder: (context, p, __) {
      if (p.isLoading || !p.loaded) {
        return const _DimRoomLoading();
      }
      if (p.room == null) {
        return _WelcomeScreen(
          onCompose: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ComposeScreen())),
          onExplore: _enterShell,
          onBack: () => Navigator.of(context).maybePop(),
          onExitHome: _exitHome,
        );
      }
      final mode = p.introMode;
      if (mode == IntroMode.none) {
        // boot()가 이미 전환을 예약했으나, 혹시 build가 먼저 그려질 경우를 대비한 안전망.
        return const _DimRoomLoading();
      }
      return GestureDetector(
        // 원본: short 모드만 탭 즉시 스킵(onClick={() => mode!=='full' && finish()}).
        // full 모드는 탭으로 스킵되지 않고, 우상단 '건너뛰기' 버튼으로만 스킵 가능.
        onTap: mode == IntroMode.full ? null : () {
          _skipTimer?.cancel();
          _advanceTimer?.cancel();
          _enterShell();
        },
        child: Stack(children: [
          mode == IntroMode.full ? const _FullIntroBody() : const _ShortIntroBody(),
          if (_showSkip && mode == IntroMode.full)
            Positioned(
              top: 56, right: 16,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () { _skipTimer?.cancel(); _advanceTimer?.cancel(); _enterShell(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(color: WrC.glass, borderRadius: BorderRadius.circular(999), border: Border.all(color: WrC.line)),
                    child: Text('건너뛰기 ›', style: WrF.body(14, w: FontWeight.w900, color: WrC.fg)),
                  ),
                ),
              ),
            ),
        ]),
      );
    });
  }
}

class _DimRoomLoading extends StatelessWidget {
  const _DimRoomLoading();
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF12060E),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFFF5CF6A))),
      );
}

/// 18개 방사형 광선(halo-rays) — 원본 30s linear infinite 회전, opacity .5.
/// Intro st<=1(스플래시 구간)에서만 표시. 420×420, left:50% top:42%.
class _HaloRays extends StatefulWidget {
  const _HaloRays({this.n = 18, this.size = 420, this.rayLen = 210, this.duration = const Duration(seconds: 30)});
  final int n;
  final double size, rayLen;
  final Duration duration;
  @override
  State<_HaloRays> createState() => _HaloRaysState();
}

class _HaloRaysState extends State<_HaloRays> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: Opacity(opacity: .5, child: AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Transform.rotate(angle: _c.value * 2 * math.pi, child: SizedBox(
        width: widget.size, height: widget.size,
        child: Stack(children: [
          for (var i = 0; i < widget.n; i++)
            Positioned(
              left: widget.size / 2 - 1, top: widget.size / 2,
              child: Transform.rotate(
                angle: i * (360 / widget.n) * math.pi / 180,
                alignment: Alignment.topCenter,
                child: Container(
                  width: 2, height: widget.rayLen,
                  decoration: const BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0xB3FFE6AA), Colors.transparent])),
                ),
              ),
            ),
        ]),
      )),
    )));
  }
}

/// full 모드 — 원본 Intro({mode:'full'}) 1:1. React state(st:0→3) 그대로 이식:
/// st<=1: 스플래시(halo-rays + PetalRain16 + 타이틀블록 + [st==1 only]로딩바)
/// st==2: 문열림(zoom-through 1.2s) + PetalRain20 + white-out 오버레이
/// st==3: #fff4dc 리버스 페이드 + (풀모드) 캡션
class _FullIntroBody extends StatefulWidget {
  const _FullIntroBody();
  @override
  State<_FullIntroBody> createState() => _FullIntroBodyState();
}

class _FullIntroBodyState extends State<_FullIntroBody> with TickerProviderStateMixin {
  int _st = 0;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    // 원본: [1100:st1, 2000:st2, 3100:st3] (4600:finish는 상위 WishRoomIntroScreen이 담당)
    debugPrint('WR_PHASE intro.st0');
    _timers.add(Timer(WrDur.introFullSt1, () { if (mounted) { debugPrint('WR_PHASE intro.st1'); setState(() => _st = 1); } }));
    _timers.add(Timer(WrDur.introFullSt2, () { if (mounted) { debugPrint('WR_PHASE intro.st2'); setState(() => _st = 2); } }));
    _timers.add(Timer(WrDur.introFullSt3, () { if (mounted) { debugPrint('WR_PHASE intro.st3'); setState(() => _st = 3); } }));
  }

  @override
  void dispose() { for (final t in _timers) { t.cancel(); } super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      if (_st <= 1) _SplashStage(showLoading: _st == 1),
      if (_st == 2) const _GateStage(zoomDuration: Duration(milliseconds: 1200)),
      if (_st == 3) const _RevealStage(mode: 'full'),
    ]);
  }
}

/// short 모드 — 원본 Intro({mode:'short'}) 1:1. st 초기값 2(문부터 시작) → 700ms후 st3.
class _ShortIntroBody extends StatefulWidget {
  const _ShortIntroBody();
  @override
  State<_ShortIntroBody> createState() => _ShortIntroBodyState();
}

class _ShortIntroBodyState extends State<_ShortIntroBody> {
  int _st = 2;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(WrDur.introShortSt3, () { if (mounted) setState(() => _st = 3); });
  }

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      if (_st == 2) const _GateStage(zoomDuration: Duration(milliseconds: 800)),
      if (_st == 3) const _RevealStage(mode: 'short'),
    ]);
  }
}

/// st<=1 스플래시 단계 — cam-in 2s + halo-rays + PetalRain(16, 3-5s, spread 1.5)
/// + 잉크 타이틀 블록(神通萬通·SINTONG / 신통방통 / 당신의 소원이 빛이 되는 곳)
/// + [showLoading=true 일 때만] "소원방으로 들어가고 있어요" + 로딩바 .9s.
class _SplashStage extends StatefulWidget {
  const _SplashStage({required this.showLoading});
  final bool showLoading;
  @override
  State<_SplashStage> createState() => _SplashStageState();
}

class _SplashStageState extends State<_SplashStage> with SingleTickerProviderStateMixin {
  // cam-in 2s cubic-bezier(.22,1,.36,1): scale 1.18→1, brightness .25→1, blur 4→0.
  late final AnimationController _cam = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..forward();
  // loading .9s — st==1 진입 시점(부모 기준 1100ms)부터 재생.
  AnimationController? _loading;

  @override
  void didUpdateWidget(covariant _SplashStage old) {
    super.didUpdateWidget(old);
    if (widget.showLoading && _loading == null) _startLoading();
  }

  @override
  void initState() {
    super.initState();
    if (widget.showLoading) _startLoading();
  }

  void _startLoading() {
    _loading = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    setState(() {});
  }

  @override
  void dispose() { _cam.dispose(); _loading?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.black, child: Stack(fit: StackFit.expand, children: [
      AnimatedBuilder(animation: _cam, builder: (_, __) {
        final t = WrCurves.out.transform(_cam.value);
        final scale = 1.18 - .18 * t;
        final brightness = .25 + .75 * t;
        final blur = 4 * (1 - t);
        return Transform.scale(scale: scale, child: ImageFiltered(
          imageFilter: ui_imageBlur(blur),
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(_brightnessMatrix(brightness)),
            child: Image.asset('assets/wishroom/splash.jpg', fit: BoxFit.cover),
          ),
        ));
      }),
      Positioned(left: 0, right: 0, top: MediaQuery.of(context).size.height * .42 - 210,
        child: const Center(child: _HaloRays())),
      const WrPetalRain(n: 16, dur: (3.0, 5.0), spread: 1.5),
      Positioned(left: 0, right: 0, top: 112, child: _InkTitleBlock(
        subtitle: '당신의 소원이 빛이 되는 곳',
      )),
      if (widget.showLoading)
        Positioned(left: 50, right: 50, bottom: 110, child: Column(children: [
          Text('소원방으로 들어가고 있어요', style: WrF.body(14, color: WrC.fg).copyWith(shadows: _tshadow)),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: Container(
            height: 4, color: const Color(0x26FFFFFF),
            child: _loading == null ? const SizedBox.shrink() : AnimatedBuilder(
              animation: _loading!,
              builder: (_, __) => FractionallySizedBox(
                alignment: Alignment.centerLeft, widthFactor: _loading!.value,
                child: Container(decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [WrC.blossom, Color(0xFFFFD98A)]),
                  boxShadow: [BoxShadow(color: WrC.blossom, blurRadius: 10)])),
              ),
            ),
          )),
        ])),
    ]));
  }
}

/// st==2 문 열림 단계 — zoom-through(gate.jpg scale 1→2.6, brightness 1→2.4)
/// + PetalRain(20, 1.4-2.4s, spread .4) + white-out 레이디얼 오버레이(mixBlendMode:screen 근사).
class _GateStage extends StatefulWidget {
  const _GateStage({required this.zoomDuration});
  final Duration zoomDuration;
  @override
  State<_GateStage> createState() => _GateStageState();
}

class _GateStageState extends State<_GateStage> with TickerProviderStateMixin {
  late final AnimationController _zoom = AnimationController(vsync: this, duration: widget.zoomDuration)..forward();
  late final AnimationController _white = AnimationController(vsync: this, duration: widget.zoomDuration)..forward();

  @override
  void dispose() { _zoom.dispose(); _white.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      AnimatedBuilder(animation: _zoom, builder: (_, __) {
        final t = WrCurves.door.transform(_zoom.value); // cubic-bezier(.7,0,.3,1)
        final scale = 1 + 1.6 * t;
        final brightness = 1 + 1.4 * t;
        return Transform.scale(scale: scale, child: ColorFiltered(
          colorFilter: ColorFilter.matrix(_brightnessMatrix(brightness)),
          child: Image.asset('assets/wishroom/gate.jpg', fit: BoxFit.cover, alignment: const Alignment(0, .1)),
        ));
      }),
      WrPetalRain(n: 20, dur: (1.4, 2.4), spread: .4),
      // white-out: 0%op0 → 60%op1 → 100%op0, ease-in, radial-gradient + screen blend 근사.
      AnimatedBuilder(animation: _white, builder: (_, __) {
        final v = _white.value;
        final op = v < .6 ? (v / .6) : (1 - (v - .6) / .4);
        return IgnorePointer(child: Opacity(opacity: op.clamp(0, 1), child: const DecoratedBox(
          decoration: BoxDecoration(gradient: RadialGradient(
            colors: [Color(0xFFFFF8E6), Color(0x99FFE6B4), Colors.transparent],
            stops: [0, .3, .6],
          )),
        )));
      }),
    ]);
  }
}

/// st==3 리빌 단계 — 배경 #fff4dc가 fade .6s reverse(즉 1→0으로 사라짐)로 드러나고,
/// full 모드에서만 중앙 캡션("당신의 소원이\n이곳에 머물고 있습니다.")이 ink 1.2s로 나타남.
class _RevealStage extends StatelessWidget {
  const _RevealStage({required this.mode});
  final String mode; // 'full' | 'short'
  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      Container(color: const Color(0xFFFFF4DC)),
      if (mode == 'full')
        Positioned(left: 0, right: 0, top: 380, child: _InkFade(
          delay: const Duration(milliseconds: 200),
          duration: const Duration(milliseconds: 1200),
          child: Text('당신의 소원이\n이곳에 머물고 있습니다.',
            textAlign: TextAlign.center,
            style: WrF.display(22, color: const Color(0xFF4A2A1C), height: 1.5).copyWith(shadows: _tshadow)),
        )),
    ]);
  }
}

/// .mono "神通萬通 · SINTONG" + .disp "신통방통"(핑크 그라디언트) + .serif 부제.
/// ink 1.6-2s 애니메이션(透明→불투명 + blur 8→0).
class _InkTitleBlock extends StatelessWidget {
  const _InkTitleBlock({required this.subtitle});
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return _InkFade(
      duration: const Duration(milliseconds: 1400),
      delay: const Duration(milliseconds: 200),
      child: Column(children: [
        Text('神通萬通 · SINTONG', style: WrF.mono(size: 10, color: const Color(0xBFFFDCE6))),
        const SizedBox(height: 10),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF6EC), Color(0xFFFFC8D8), Color(0xFFFF8FB1)], stops: [0, .6, 1]).createShader(b),
          child: Text('신통방통', style: WrF.display(44, color: Colors.white)),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: WrF.body(15, color: WrC.fg).copyWith(shadows: _tshadow)),
      ]),
    );
  }
}

/// ink keyframe — opacity 0→1 + blur(8px)→none.
class _InkFade extends StatefulWidget {
  const _InkFade({required this.child, this.duration = const Duration(milliseconds: 1400), this.delay = Duration.zero});
  final Widget child;
  final Duration duration, delay;
  @override
  State<_InkFade> createState() => _InkFadeState();
}

class _InkFadeState extends State<_InkFade> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () { if (mounted) _c.forward(); });
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _c, builder: (_, __) {
      final blur = 8 * (1 - _c.value);
      return Opacity(opacity: _c.value, child: ImageFiltered(imageFilter: ui_imageBlur(blur), child: widget.child));
    });
  }
}

const _tshadow = [Shadow(color: Color(0xBF000000), blurRadius: 12, offset: Offset(0, 2)), Shadow(color: Color(0x59F2628F), blurRadius: 20)];

/// -------------------- Welcome (소원방 없음) --------------------
/// 원본 Welcome({app}) 1:1: NavPill(좌상단) + splash.jpg drift 24s + PetalRain(10,8-12s,spread8)
/// + ink 타이틀블록(부제 2줄) + rise-in 1.2s 버튼 2개.
class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen({required this.onCompose, required this.onExplore, required this.onBack, required this.onExitHome});
  final VoidCallback onCompose, onExplore, onBack, onExitHome;
  @override
  Widget build(BuildContext context) {
    return Theme(data: wrThemeData(), child: Scaffold(
      backgroundColor: WrC.bg2,
      body: WrCanvasScaler(child: Stack(fit: StackFit.expand, children: [
        const _DriftBg(),
        Container(color: const Color(0x8A12060E)),
        const WrPetalRain(n: 10, dur: (8.0, 12.0), spread: 8),
        Positioned(left: 14, top: 52, child: WrNavPill(onBack: onBack, onExitHome: onExitHome)),
        Positioned(left: 0, right: 0, top: 110, child: _InkFade(
          duration: const Duration(milliseconds: 1600),
          child: Column(children: [
            Text('神通萬通 · SINTONG', style: WrF.mono(size: 10, color: const Color(0xBFFFDCE6))),
            const SizedBox(height: 10),
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF6EC), Color(0xFFFFC8D8), Color(0xFFFF8FB1)], stops: [0, .6, 1]).createShader(b),
              child: Text('신통방통 소원방', style: WrF.display(42, color: Colors.white)),
            ),
            const SizedBox(height: 10),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Text(
              '당신의 소원이 머무는 특별한 공간\n함께 응원하고, 꾸미고, 이루어가요',
              textAlign: TextAlign.center,
              style: WrF.body(14.5, color: WrC.fg, height: 1.7).copyWith(shadows: _tshadow),
            )),
          ]),
        )),
        Positioned(left: 20, right: 20, bottom: 120, child: _RiseIn(
          delay: const Duration(milliseconds: 600),
          duration: const Duration(milliseconds: 1200),
          child: Column(children: [
            SizedBox(width: double.infinity, height: WrSize.btnH, child: GestureDetector(
              onTap: onCompose,
              child: Container(decoration: WrDeco.btnPink, alignment: Alignment.center,
                child: Text('✿ 첫 소원 담기', style: WrF.body(WrSize.btnFont, w: FontWeight.w700, color: Colors.white))),
            )),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: WrSize.btnH, child: GestureDetector(
              onTap: onExplore,
              child: Container(decoration: WrDeco.btnDark, alignment: Alignment.center,
                child: Text('다른 소원방 둘러보기', style: WrF.body(15, color: WrC.fg))),
            )),
          ]),
        )),
      ])),
    ));
  }
}

/// drift 24s ease-in-out infinite — scale 1↔1.025 + translate(0,0)↔(-4,-3).
class _DriftBg extends StatefulWidget {
  const _DriftBg();
  @override
  State<_DriftBg> createState() => _DriftBgState();
}

class _DriftBgState extends State<_DriftBg> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat(reverse: true);
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _c, builder: (_, __) {
      final t = Curves.easeInOut.transform(_c.value);
      final scale = 1 + .025 * t;
      return Transform.translate(offset: Offset(-4 * t, -3 * t), child: Transform.scale(
        scale: scale, alignment: Alignment.center,
        child: Image.asset('assets/wishroom/splash.jpg', fit: BoxFit.cover),
      ));
    });
  }
}

/// rise-in — opacity 0→1 + translateY(20px)→0.
class _RiseIn extends StatefulWidget {
  const _RiseIn({required this.child, this.duration = const Duration(milliseconds: 1200), this.delay = Duration.zero});
  final Widget child;
  final Duration duration, delay;
  @override
  State<_RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<_RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () { if (mounted) _c.forward(); });
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _c, builder: (_, __) {
      final t = Curves.easeOut.transform(_c.value);
      return Opacity(opacity: _c.value, child: Transform.translate(offset: Offset(0, 20 * (1 - t)), child: widget.child));
    });
  }
}

/// NavPill — 뒤로가기 + 신통방통 홈 pill. app2/fx2.jsx › NavPill() 1:1.
/// 모든 화면 좌상단 공통이므로 다른 화면에서도 재사용 가능하도록 public으로 노출.
class WrNavPill extends StatelessWidget {
  const WrNavPill({super.key, required this.onBack, required this.onExitHome});
  final VoidCallback onBack, onExitHome;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: WrC.glass, borderRadius: BorderRadius.circular(999), border: Border.all(color: WrC.line)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _pillBtn(onBack, Icons.arrow_back_ios_new, size: 10),
        Container(width: 1, height: 16, color: WrC.line),
        _pillBtn(onExitHome, Icons.home_rounded, size: 16),
      ]),
    );
  }

  Widget _pillBtn(VoidCallback onTap, IconData icon, {required double size}) {
    return GestureDetector(onTap: onTap, child: SizedBox(width: 30, height: 30,
      child: Icon(icon, size: size, color: WrC.fg)));
  }
}

// -------------------- 공용 헬퍼: ColorFilter.matrix brightness, ImageFilter.blur --------------------
List<double> _brightnessMatrix(double b) => [
      b, 0, 0, 0, 0,
      0, b, 0, 0, 0,
      0, 0, b, 0, 0,
      0, 0, 0, 1, 0,
    ];

// dart:ui ImageFilter.blur 래퍼(함수명은 기존 코드 네이밍 컨벤션에 맞춤).
// ignore: non_constant_identifier_names
ImageFilter ui_imageBlur(double sigma) => ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
