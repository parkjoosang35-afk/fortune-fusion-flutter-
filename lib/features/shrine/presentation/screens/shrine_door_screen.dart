// shrine_door_screen.dart — 02 문 열림.
// 레퍼런스: design_files/screens-a.jsx S02Door.
// 안전 타이머 6.5s 후 자동으로 shrine(신당 내부)으로 전환(변경 금지 값).
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../application/shrine_session_provider.dart';
import '../../domain/shrine_session.dart';
import '../../domain/shrine_tokens.dart';
import '../shrine_navigation.dart';
import '../widgets/shrine_chrome.dart';
import '../widgets/shrine_scaffold.dart';

class ShrineDoorScreen extends StatefulWidget {
  const ShrineDoorScreen({super.key});
  @override
  State<ShrineDoorScreen> createState() => _ShrineDoorScreenState();
}

class _ShrineDoorScreenState extends State<ShrineDoorScreen> {
  Timer? _autoTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    final rm = context.read<ShrineSessionProvider>().state.reduceMotion;
    _autoTimer = Timer(rm ? const Duration(milliseconds: 400) : ShrineMotion.doorSafety, _goNext);
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    ShrineNav.go(context, 'shrine', replace: true);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ShrineSessionProvider>().state;
    return ShrineScreenScaffold(
      back: false,
      settings: false,
      skip: _goNext,
      background: [
        ShrineSafeVideo('door', reduceMotion: s.reduceMotion, safety: ShrineMotion.doorSafety, onEnd: _goNext),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: .5,
                colors: [Color(0x59FF9650), Color(0x00FF9650)],
                stops: [0, .7],
              ),
            ),
          ),
        ),
      ],
      atmosphere: const ShrineAtmosphere(petals: 0),
      child: Stack(
        children: [
          const _DoorLeaves(),
          Align(
            alignment: const Alignment(0, .78),
            child: ShrineFadeRise(
              delay: const Duration(milliseconds: 3600),
              child: Text('문 너머에서, 무언가 숨을 고릅니다.',
                  style: ShrineType.say(s.textSize.scale).copyWith(
                      shadows: const [Shadow(color: Color(0xFF000000), blurRadius: 20)])),
            ),
          ),
          Positioned(
            left: 120,
            right: 120,
            bottom: 52,
            child: const _SafetyTimerBar(),
          ),
        ],
      ),
    );
  }
}

/// 두 문짝 — 2.8s 열림(변경 금지 값). CSS perspective rotateY를
/// Transform(Matrix4 perspective)으로 근사했다.
class _DoorLeaves extends StatefulWidget {
  const _DoorLeaves();
  @override
  State<_DoorLeaves> createState() => _DoorLeavesState();
}

class _DoorLeavesState extends State<_DoorLeaves> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900) + ShrineMotion.door)
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        // 0.9s 대기 후 2.8s 동안 0→68도 회전(ease curve 근사).
        final delayFrac = 900 / (900 + ShrineMotion.door.inMilliseconds);
        final raw = _c.value <= delayFrac ? 0.0 : (_c.value - delayFrac) / (1 - delayFrac);
        final eased = Curves.easeInOut.transform(raw.clamp(0.0, 1.0));
        final angle = eased * 68 * math.pi / 180;
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.sizeOf(context).width / 2,
              child: Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(angle),
                child: const _DoorLeafPanel(),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.sizeOf(context).width / 2,
              child: Transform(
                alignment: Alignment.centerRight,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(-angle),
                child: const _DoorLeafPanel(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DoorLeafPanel extends StatelessWidget {
  const _DoorLeafPanel();
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF1A0C08), Color(0xFF2A140C), Color(0xFF1A0C08)]),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 90, 18, 120),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0x2EC9A368)),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x14ECDCB9), Color(0x08ECDCB9)],
              ),
            ),
          ),
        ),
      );
}

class _SafetyTimerBar extends StatefulWidget {
  const _SafetyTimerBar();
  @override
  State<_SafetyTimerBar> createState() => _SafetyTimerBarState();
}

class _SafetyTimerBarState extends State<_SafetyTimerBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    final rm = context.read<ShrineSessionProvider>().state.reduceMotion;
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 6500))
      ..forward(from: rm ? 1 : 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 1,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0x1FEFE4D2)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => FractionallySizedBox(
                widthFactor: _c.value,
                child: const DecoratedBox(decoration: BoxDecoration(color: ShrineColor.gold)),
              ),
            ),
          ),
        ),
      );
}
