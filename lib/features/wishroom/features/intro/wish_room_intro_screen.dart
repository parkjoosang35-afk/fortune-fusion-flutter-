// SCR-01 진입 인트로 (overlay) + Welcome — docs/SCREENS.md §SCR-01, §Welcome
// 서버가 GET /wish-rooms/me → introMode로 판단(full/short/none). 이 화면이 앱의
// '/wish-room' 진입점 역할을 한다: 로딩 → (방 없음=Welcome) / (방 있음=인트로 후 Shell).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../core/motion/wr_motion.dart';
import '../../core/theme/wr_theme.dart';
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
    await p.loadMyRoom();
    if (!mounted) return;
    if (p.room == null) return; // Welcome 화면으로 자연 분기(build에서 처리)
    final mode = p.introMode;
    if (mode == IntroMode.none) {
      _enterShell();
      return;
    }
    final dur = mode == IntroMode.full ? WrDur.introFull : WrDur.introShort;
    if (mode == IntroMode.full) {
      _skipTimer = Timer(WrDur.introSkipShowAfter, () {
        if (mounted) setState(() => _showSkip = true);
      });
    } else {
      // short: 탭하면 즉시 스킵 가능하도록 바로 노출
      setState(() => _showSkip = true);
    }
    _advanceTimer = Timer(dur, _enterShell);
  }

  void _enterShell() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const WishRoomShell()));
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
        );
      }
      final mode = p.introMode;
      if (mode == IntroMode.none) {
        // boot()가 이미 전환을 예약했으나, 혹시 build가 먼저 그려질 경우를 대비한 안전망.
        return const _DimRoomLoading();
      }
      return GestureDetector(
        onTap: () {
          _skipTimer?.cancel();
          _advanceTimer?.cancel();
          _enterShell();
        },
        child: Stack(children: [
          mode == IntroMode.full ? const _FullIntroBody() : const _ShortIntroBody(),
          if (_showSkip)
            Positioned(
              top: 56, right: 16,
              child: SafeArea(
                child: GestureDetector(
                  onTap: _enterShell,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0x55000000), borderRadius: BorderRadius.circular(999)),
                    child: const Text('건너뛰기 ›', style: TextStyle(color: Colors.white, fontSize: 12)),
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

/// full 모드 — 스플래시(cam-in) → 로딩바 → 문 열림(gate.jpg 확대) → 화이트아웃→리빌.
class _FullIntroBody extends StatefulWidget {
  const _FullIntroBody();
  @override
  State<_FullIntroBody> createState() => _FullIntroBodyState();
}

class _FullIntroBodyState extends State<_FullIntroBody> with TickerProviderStateMixin {
  late final AnimationController _splash = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  late final AnimationController _door = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2000), () { if (mounted) _door.forward(); });
    Future.delayed(const Duration(milliseconds: 3100), () { if (mounted) _reveal.forward(); });
  }

  @override
  void dispose() { _splash.dispose(); _door.dispose(); _reveal.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      // 1) 스플래시
      AnimatedBuilder(animation: _splash, builder: (_, __) => Transform.scale(
        scale: 1.1 - .1 * _splash.value,
        child: Image.asset('assets/wishroom/splash.jpg', fit: BoxFit.cover),
      )),
      Center(
        child: ShaderMask(
          shaderCallback: (b) => const LinearGradient(colors: [Color(0xFFFFF6EC), Color(0xFFFFC8D8), Color(0xFFFF8FB1)]).createShader(b),
          child: const Text('신통방통', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 44, color: Colors.white)),
        ),
      ),
      const Positioned(bottom: 190, left: 0, right: 0, child: Center(child: Text('당신의 소원이 빛이 되는 곳', style: TextStyle(color: Color(0xBBFFFFFF), fontSize: 13)))),
      Positioned(bottom: 120, left: 60, right: 60, child: AnimatedBuilder(animation: _splash, builder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: _splash.value, minHeight: 4, backgroundColor: const Color(0x33FFFFFF),
          valueColor: const AlwaysStoppedAnimation(Color(0xFFF2628F))),
      ))),
      const Positioned(bottom: 96, left: 0, right: 0, child: Center(child: Text('소원방으로 들어가고 있어요', style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12)))),
      // 2) 문 열림
      AnimatedBuilder(animation: _door, builder: (_, __) {
        if (_door.value == 0) return const SizedBox.shrink();
        final scale = 1 + 1.6 * Curves.easeIn.transform(_door.value);
        return Opacity(opacity: (_door.value).clamp(0, 1), child: Transform.scale(scale: scale,
          child: ColorFiltered(colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: _door.value * .9), BlendMode.plus),
            child: Image.asset('assets/wishroom/gate.jpg', fit: BoxFit.cover))));
      }),
      // 3) 리빌 + 카피
      AnimatedBuilder(animation: _reveal, builder: (_, __) {
        if (_reveal.value == 0) return const SizedBox.shrink();
        return Container(
          color: Colors.white.withValues(alpha: (1 - _reveal.value).clamp(0, 1)),
          child: Center(child: Opacity(opacity: _reveal.value, child: const Text(
            '당신의 소원이\n이곳에 머물고 있습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'GowunBatangWish', fontSize: 22, color: Color(0xFF4A2A1C)),
          ))),
        );
      }),
    ]);
  }
}

/// short 모드 — 문 확대부터 바로 시작.
class _ShortIntroBody extends StatefulWidget {
  const _ShortIntroBody();
  @override
  State<_ShortIntroBody> createState() => _ShortIntroBodyState();
}

class _ShortIntroBodyState extends State<_ShortIntroBody> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (_, __) => Transform.scale(
        scale: 1 + 1.2 * _c.value,
        child: ColorFiltered(colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: _c.value * .7), BlendMode.plus),
          child: Image.asset('assets/wishroom/gate.jpg', fit: BoxFit.cover)),
      ));
}

class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen({required this.onCompose, required this.onExplore});
  final VoidCallback onCompose, onExplore;
  @override
  Widget build(BuildContext context) {
    // [버그수정] Theme(...)으로 감싸기 전에는 바깥(AppShell) 테마에 WrColors
    // extension이 없어 context.wr가 null-check 크래시를 낸다. midnight 고정이므로
    // 상수를 직접 참조한다.
    const c = WrColors.midnight;
    return Theme(data: wrTheme(WrPalette.midnight), child: Scaffold(
      backgroundColor: c.bg2,
      body: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/wishroom/splash.jpg', fit: BoxFit.cover),
        Container(color: const Color(0x8A12060E)),
        SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(shaderCallback: (b) => const LinearGradient(colors: [Color(0xFFFFF6EC), Color(0xFFFFC8D8), Color(0xFFFF8FB1)]).createShader(b),
              child: const Text('신통방통 소원방', textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 36, color: Colors.white, height: 1.3))),
            const SizedBox(height: 44),
            SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
              onPressed: onCompose,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2628F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('✿ 첫 소원 담기', style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
            )),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, height: 56, child: OutlinedButton(
              onPressed: onExplore,
              style: OutlinedButton.styleFrom(side: BorderSide(color: c.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Text('다른 소원방 둘러보기', style: TextStyle(color: c.fg, fontSize: 15)),
            )),
          ],
        ))),
      ]),
    ));
  }
}
