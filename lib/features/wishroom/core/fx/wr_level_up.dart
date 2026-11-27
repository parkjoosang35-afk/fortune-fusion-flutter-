// 레벨업 전체화면 시네마틱 — app2/fx2.jsx › LevelUp({level, onDone}) 93-126줄 1:1.
//
// [버그수정 — 전수감사] main_room_screen.dart의 _showLevelUp()은 텍스트 위주의
// 평범한 Dialog(제목+Lv.N+unlock문구+확인버튼)만 보여줬다. 원본은 전체화면을
// 덮는 시네마틱 오버레이로, 레벨마다 다른 fx 배경 효과(cinema/stars/lightup),
// 16방향 halo-rays 회전, 꽃잎비(PetalRain), 터짐(Burst), 해금 아이콘 이미지
// pop+bob 애니메이션, 자동 닫힘 타이머(레벨10만 5.6s, 그 외 3.8s), 화면 어디를
// 탭해도 닫히는 상호작용까지 포함한 훨씬 비중있는 연출이었다 — 완전 재구현.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/wr_catalog.dart';
import '../motion/wr_motion.dart';
import '../theme/wr_theme.dart';
import 'wr_fx.dart';

/// 레벨별 해금 메타 — app/room-layout.js › UNLOCKS 1:1(아이콘 자산 경로 포함).
class WrUnlocks {
  static const Map<int, (String say, String icon)> _m = {
    2: ('창가에 첫 꽃잎이 날리기 시작했어요', 'petal'),
    3: ('작은 향로에서 향이 피어올라요', 'incense'),
    4: ('양쪽 기둥에 등불이 켜졌어요', 'lantern'),
    5: ('촛불 받침이 은은하게 빛나요', 'chest'),
    6: ('창가에 연꽃등이 떠올랐어요', 'lotus'),
    7: ('천장에 별이 내려앉았어요', 'star'),
    8: ('기둥에 복주머니가 걸렸어요', 'pouch'),
    9: ('방 전체가 환하게 밝아졌어요', 'spark'),
    10: ('당신의 소원방이 완성되었어요', 'gift'),
  };
  static (String say, String icon)? of(int lv) => _m[lv];
}

/// LevelUp({level, onDone}) 1:1. 호출부는 Overlay/Stack 최상단(z-index 85 상당)에
/// Positioned.fill로 띄우고, onDone에서 제거하면 된다(Dialog 아님 — 원본은 일반 뷰).
class WrLevelUp extends StatefulWidget {
  const WrLevelUp({super.key, required this.level, required this.onDone, this.wallpaperNotice});
  final int level;
  final VoidCallback onDone;
  /// S-07 — me.wallpaper가 있고 이 방 배경화면을 쓰는 중이며 안내를 아직 못 본
  /// 경우에만 비어있지 않은 문구(플랫폼별 문구)를 전달한다. null이면 배너 생략.
  final String? wallpaperNotice;

  @override
  State<WrLevelUp> createState() => _WrLevelUpState();
}

class _WrLevelUpState extends State<WrLevelUp> with SingleTickerProviderStateMixin {
  late final AnimationController _halo = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
  Timer? _t;

  String get _fx {
    final levels = WrCatalog.I.levels;
    if (widget.level - 1 < levels.length && widget.level - 1 >= 0) {
      return levels[widget.level - 1]['fx'] as String? ?? 'intro';
    }
    return 'intro';
  }

  String get _name {
    final levels = WrCatalog.I.levels;
    if (widget.level - 1 < levels.length && widget.level - 1 >= 0) {
      return levels[widget.level - 1]['name'] as String? ?? '';
    }
    return '';
  }

  String get _change {
    final levels = WrCatalog.I.levels;
    if (widget.level - 1 < levels.length && widget.level - 1 >= 0) {
      return levels[widget.level - 1]['change'] as String? ?? '';
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    // setTimeout(onDone, level===10 ? 5600 : 3800) 1:1.
    _t = Timer(widget.level == 10 ? WrDur.levelUpLv10 : WrDur.levelUp, widget.onDone);
  }

  @override
  void dispose() { _halo.dispose(); _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final unlock = WrUnlocks.of(widget.level);
    final say = unlock?.$1 ?? _change;
    final icon = unlock?.$2 ?? 'chest';
    final fx = _fx;
    return GestureDetector(
      onTap: widget.onDone,
      child: Container(
        decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.1),
          radius: 1.1, colors: [Color(0x59280A1E), Color(0xD90A0308)])),
        child: ClipRect(child: Stack(alignment: Alignment.center, children: [
          // fx 배경 분기 — cinema: 상하 블랙바 rise-in / stars: 좌→우 라이트 스와이프 /
          // lightup: 화면 전체 금빛 스크린블렌드.
          if (fx == 'cinema') ...const [
            Positioned(left: 0, right: 0, top: 0, child: _RiseInBar(height: 80, fromTop: true)),
            Positioned(left: 0, right: 0, bottom: 0, child: _RiseInBar(height: 80, fromTop: false)),
          ],
          if (fx == 'stars') const Positioned(top: 135, left: 0, child: _SwipeLight()),
          if (fx == 'lightup') const Positioned.fill(child: _GoldScreen()),
          // 16방향 halo-rays — 24s linear infinite 회전.
          AnimatedBuilder(animation: _halo, builder: (_, __) => Opacity(opacity: .55,
            child: Transform.rotate(angle: _halo.value * 2 * math.pi, child: SizedBox(width: 520, height: 520,
              child: Stack(children: [for (var i = 0; i < 16; i++) _HaloRay(angleDeg: i * 22.5)]))))),
          WrPetalRain(n: (fx == 'cinema' || fx == 'lotus') ? 36 : 18, dur: const (3.4, 5.4), spread: 1.4),
          const WrBurst(x: 195, y: 338, n: 24, spread: 170, color: Color(0xFFFFE08A)),
          // 중앙 컨텐츠.
          _Content(level: widget.level, name: _name, say: say, icon: icon, wallpaperNotice: widget.wallpaperNotice),
        ])),
      ),
    );
  }
}

class _Content extends StatefulWidget {
  const _Content({required this.level, required this.name, required this.say, required this.icon, this.wallpaperNotice});
  final int level;
  final String name, say, icon;
  final String? wallpaperNotice;
  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  @override
  void dispose() { _bob.dispose(); _pop.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(animation: Listenable.merge([_pop, _bob]), builder: (_, __) {
        final popT = Curves.easeOutBack.transform(_pop.value);
        final bobDy = math.sin(_bob.value * math.pi) * 6;
        return Transform.scale(scale: .4 + .6 * popT, child: Transform.translate(offset: Offset(0, bobDy), child: Image.asset(
          'assets/wishroom/items/${widget.icon}.png', width: 130, height: 130, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome, size: 90, color: WrC.glow),
        )));
      }),
      const SizedBox(height: 10),
      Text('LEVEL UP', style: WrF.mono(size: 10, color: WrC.glow)),
      ShaderMask(shaderCallback: (b) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF6D8), Color(0xFFF5CF6A), Color(0xFFFF8FB1)], stops: [0, .55, 1]).createShader(b),
        child: Text('Lv.${widget.level}', style: WrF.display(64, color: Colors.white, height: 1))),
      const SizedBox(height: 10),
      Text(widget.name, style: WrF.display(24, color: WrC.fg)),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: const Color(0x1AFFDCEB),
          border: Border.all(color: const Color(0x59FFBED2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('UNLOCK', style: WrF.mono(size: 9.5, color: WrC.blossom2)),
          const SizedBox(width: 8),
          Text(widget.say, style: WrF.body(13.5, w: FontWeight.w700)),
        ]),
      ),
      if (widget.wallpaperNotice != null) Padding(padding: const EdgeInsets.only(top: 12), child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0x8C140810),
          border: Border.all(color: const Color(0x4DFFE6B4))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 14, height: 26, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xCCFFE6B4), width: 1.5)),
            child: Center(child: Container(width: 8, height: 20, decoration: BoxDecoration(borderRadius: BorderRadius.circular(1.5),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFD98A), Color(0xFFF2628F)]))))),
          const SizedBox(width: 8),
          Flexible(child: Text(widget.wallpaperNotice!, style: WrF.body(12.5, w: FontWeight.w700))),
        ]),
      )),
      const SizedBox(height: 14),
      Text('탭하면 방에서 확인해요', style: WrF.body(12, color: WrC.muted)),
    ]);
  }
}

class _HaloRay extends StatelessWidget {
  const _HaloRay({required this.angleDeg});
  final double angleDeg;
  @override
  Widget build(BuildContext context) {
    return Positioned(left: 260 - 1.5, top: 260, child: Transform.rotate(angle: angleDeg * math.pi / 180, alignment: Alignment.topCenter,
      child: Container(width: 3, height: 260, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter,
        end: Alignment.bottomCenter, colors: [Color(0xB3FFDC96), Colors.transparent])))));
  }
}

class _RiseInBar extends StatefulWidget {
  const _RiseInBar({required this.height, required this.fromTop});
  final double height;
  final bool fromTop;
  @override
  State<_RiseInBar> createState() => _RiseInBarState();
}
class _RiseInBarState extends State<_RiseInBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (_, __) {
    final t = Curves.easeOut.transform(_c.value);
    return Transform.translate(offset: Offset(0, widget.fromTop ? -widget.height * (1 - t) : widget.height * (1 - t)),
      child: Container(height: widget.height, color: Colors.black));
  });
}

class _SwipeLight extends StatefulWidget {
  const _SwipeLight();
  @override
  State<_SwipeLight> createState() => _SwipeLightState();
}
class _SwipeLightState extends State<_SwipeLight> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (_, __) {
    final d = Curves.easeInOut.transform(_c.value);
    return Opacity(opacity: _c.value < .05 || _c.value > .95 ? 0 : 1, child: Transform.translate(
      offset: Offset(-234 + d * (390 + 234), 0),
      child: Container(width: 234, height: 90, decoration: const BoxDecoration(gradient: LinearGradient(
        colors: [Colors.transparent, Color(0xD9FFF6D0), Colors.transparent]))),
    ));
  });
}

class _GoldScreen extends StatefulWidget {
  const _GoldScreen();
  @override
  State<_GoldScreen> createState() => _GoldScreenState();
}
class _GoldScreenState extends State<_GoldScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..forward();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (_, __) {
    final t = _c.value < .5 ? _c.value * 2 : (1 - _c.value) * 2;
    return Opacity(opacity: t.clamp(0.0, 1.0), child: const DecoratedBox(decoration: BoxDecoration(
      gradient: RadialGradient(colors: [Color(0xB3FFE6A0), Colors.transparent], radius: .7))));
  });
}
