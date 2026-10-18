// shrine_scaffold.dart — 신당(神堂) 공통 스캐폴드 + 모션 프리미티브.
// 신당 디자인 핸드오프(screens/shell.dart)의 ScreenScaffold/BottomFade/
// FadeRise/InkBleed/EmberPulse/TapInvite를 그대로 이식했다. 단, DeviceFrame
// (폰 프레임 시뮬레이터, go_router 라우터 생성부, screenFor 스위치)은
// [통합 Fix 01/04]에 따라 제거한다 — 이 앱은 자체 MaterialApp/Navigator
// 안에서 실행되므로 신당만의 폰 프레임이 필요 없고, 화면 매핑은
// shrine_screen_router.dart 가 전담한다.
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../application/shrine_session_provider.dart';
import '../../domain/shrine_tokens.dart';
import '../shrine_navigation.dart';
import 'shrine_chrome.dart';
import 'shrine_settings_sheet.dart';

/// 모든 화면 공통: 배경 레이어 → 분위기 → 내용 → 상단 크롬(뒤로·레일·SKIP·설정) → 오버레이
/// SKIP · 뒤로 · 설정은 항상 보인다(지시서 §9 탈출구 숨기기 금지).
class ShrineScreenScaffold extends StatelessWidget {
  final List<Widget> background;
  final Widget child;
  final Widget? rail, overlay, atmosphere;
  final VoidCallback? skip;
  final bool back, settings;
  const ShrineScreenScaffold({
    super.key,
    this.background = const [],
    required this.child,
    this.rail,
    this.overlay,
    this.atmosphere,
    this.skip,
    this.back = true,
    this.settings = true,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ShrineSessionProvider>().state;
    final rm = s.reduceMotion || MediaQuery.of(context).disableAnimations;
    final top = MediaQuery.paddingOf(context).top;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: rm),
      child: Stack(children: [
        ...background,
        if (atmosphere != null)
          Positioned.fill(
              child: rm ? const ShrineAtmosphere(petals: 0, grain: false, reduceMotion: true) : atmosphere!),
        Positioned.fill(child: child),
        Positioned(
            top: top,
            left: 18,
            right: 18,
            child: Row(children: [
              SizedBox(
                  width: 38,
                  child: back
                      ? ShrineIconBtn(
                          semantic: '뒤로',
                          onTap: () => ShrineNav.pop(context),
                          child: Text('←', style: ShrineType.ui(1, size: 15)))
                      : null),
              Expanded(child: Center(child: rail ?? const SizedBox())),
              if (skip != null) ...[
                ShrinePill(height: 34, onTap: skip, child: const Text('SKIP ›')),
                const SizedBox(width: 8),
              ],
              if (settings)
                ShrineIconBtn(
                    semantic: '설정',
                    onTap: () => showShrineSettingsSheet(context),
                    child: const Text('⚙', style: TextStyle(color: ShrineColor.fg, fontSize: 15))),
            ])),
        if (overlay != null) Positioned.fill(child: IgnorePointer(child: overlay!)),
      ]),
    );
  }
}

class ShrineBottomFade extends StatelessWidget {
  final double h;
  const ShrineBottomFade(this.h, {super.key});
  @override
  Widget build(BuildContext context) => Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: MediaQuery.sizeOf(context).height * h,
      child: const IgnorePointer(
          child: DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00070404), Color(0xC7070404), ShrineColor.bg],
                      stops: [0, .45, .92])))));
}

/// 등장 — 1.2s 아래에서 10px 떠오름
class ShrineFadeRise extends StatelessWidget {
  final Widget child;
  final Duration delay;
  const ShrineFadeRise({super.key, required this.child, this.delay = Duration.zero});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200) + delay,
      curve: ShrineMotion.ease,
      builder: (_, v, c) {
        final d = delay.inMilliseconds / (1200 + delay.inMilliseconds);
        final q = ((v - d) / (1 - d)).clamp(0.0, 1.0);
        return Opacity(opacity: q, child: Transform.translate(offset: Offset(0, (1 - q) * 10), child: c));
      },
      child: child);
}

/// 먹번짐 — blur 18 → 0, scale 1.25 → 1, 2.4s
class ShrineInkBleed extends StatelessWidget {
  final Widget child;
  const ShrineInkBleed({super.key, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: ShrineMotion.revealHanja,
      curve: ShrineMotion.ease,
      builder: (_, v, c) => Opacity(
          opacity: (v / .6).clamp(0, 1),
          child: Transform.scale(
              scale: 1.25 - .25 * v,
              child: ImageFiltered(
                  enabled: v < .999,
                  imageFilter: ui.ImageFilter.blur(sigmaX: (1 - v) * 18, sigmaY: (1 - v) * 18),
                  child: c))),
      child: child);
}

/// 부적 맥동 — ember 글로우 3s
class ShrineEmberPulse extends StatefulWidget {
  final Widget child;
  final bool on;
  const ShrineEmberPulse({super.key, required this.child, required this.on});
  @override
  State<ShrineEmberPulse> createState() => _ShrineEmberPulseState();
}

class _ShrineEmberPulseState extends State<ShrineEmberPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _c,
      builder: (_, c) => DecoratedBox(
          decoration: BoxDecoration(
              boxShadow: widget.on
                  ? [BoxShadow(color: Color.fromRGBO(255, 150, 70, .25 + .3 * _c.value), blurRadius: 24 + 36 * _c.value)]
                  : null),
          child: c),
      child: widget.child);
}

/// 탭 유도 원 — 14px 점 + 90px 링 ×2 (2.4s, 1.2s 엇갈림)
class ShrineTapInvite extends StatefulWidget {
  final Alignment at;
  const ShrineTapInvite({super.key, this.at = Alignment.center});
  @override
  State<ShrineTapInvite> createState() => _ShrineTapInviteState();
}

class _ShrineTapInviteState extends State<ShrineTapInvite> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
      alignment: widget.at,
      child: SizedBox(
          width: 90,
          height: 90,
          child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                Widget ring(double ph) {
                  final v = (_c.value + ph) % 1;
                  return Transform.scale(
                      scale: .2 + .8 * v,
                      child: Opacity(
                          opacity: 1 - v,
                          child: Container(
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle, border: Border.all(color: const Color(0xB3EFE4D2))))));
                }

                return Stack(alignment: Alignment.center, children: [
                  ring(0),
                  ring(.5),
                  Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: ShrineColor.fg,
                          boxShadow: [BoxShadow(color: Color(0xE6FFC88C), blurRadius: 14)])),
                ]);
              })));
}
