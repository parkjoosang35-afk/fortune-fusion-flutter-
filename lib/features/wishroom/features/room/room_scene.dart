// <RoomScene> v2.6 — docs/screens/G_방_장면_RoomScene.md · app2/room2.jsx › Room() 1:1 이식
// 좌표계 390×844. 부모에서 FittedBox / Transform.scale(screenW/390) 로 감싸 쓰세요.
//
// [2차 전수 감사 — docs/screens/G 전체 재대조] 1차 구현은 L1-3/L2/L4/L6/L7/L5/감쇠/gold/L8
// 뼈대만 있었고 G-3 레이어 순서 12단계 중 다음이 전부 누락되어 있었다(= "개판"의 근본 원인):
//  · ThemeLayer (테마 분위기: 자유 보케4 · 하나님 빛줄기3+제단후광 · 부처님 불상후광+연등5 · 무속인 촛불빛5)
//  · WeatherFx  (BACKGROUND 아이템의 wx: stars/snow/maple/sakura — 창 안에서 낙하)
//  · PoseFx     (정성 동작별: pray=머리위 빛살5 · bow=바닥파문3+🪷 · rub=손끝불씨8)
//  · 레벨업 리빌(reveal) 스포트라이트 → 링 → 버스트 → 라벨, Lv9 전체밝아짐 wash, Lv10 마법진(sigil)
//  · entering(카메라인 2.2s) · shake(정성 흔들림)
//  · 촛불 뒤 흐림판(backdrop blur) · 촛불광원 sacred 배율((sacred&&!boost?.35:1))
// 전부 이번에 원본 1:1로 추가했다.
//
// 레이어 순서 (아래 → 위) — 웹과 동일하게 유지해야 미리보기·배경화면·앱 화면이 같아집니다.
//  L1–3  방 일러스트 · 밝기필터 · drift24s(또는 entering=cam-in 2.2s)
//        └ 자유 테마만: 둥근 창 안 창밖 풍경 + WeatherFx
//  테마  ThemeLayer — 테마별 분위기(모두 screen 블렌드, pulse 루프)
//  L2    광원 — 달글로우 pulse6s · Lv4+ 등불글로우2 · Lv7+ 천장별30 · Lv9+ 전체광량(+reveal wash) · Lv10 금빛마법진
//  L4    꾸미기 — DECORATION≤5·SEAL≤3·THEME≤5 + FLOWER + Lv해금오브젝트(sacred 숨김, glow/smoke)
//  L6    촛불 — 뒤 흐림판 + 장착 촛불PNG · 광원(sacred 배율) · Lv5+ 받침링 · boost 불꽃모양
//  L7    상시 파티클 — 빛먼지16·꽃잎7(Lv2+)·반딧불2(Lv4+)·SpecialFx 9종·WeatherFx
//  L5    캐릭터 — breathe4.2s · 정성중 포즈 크로스페이드.7s · PoseFx
//  감쇠  비네트 opacity(1-brightness)×1.2 · 황금빛(gold) 오버레이
//  리빌  레벨업 스포트라이트·링·버스트·라벨 (reveal)
//  L8    인터랙션 FX — children 슬롯
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/fx/wr_fx.dart';
import 'room_layout.dart';

class RoomScene extends StatefulWidget {
  final WishRoom room;
  final List<WrItem> items;
  final bool pray;          // 정성 머금는 중 → 동작 그림
  final double boost;       // 0 · 1 · 2  (정성 연출 중 광량)
  final double gold;        // 0~1 완료 연출 황금빛
  final bool lowFx, frozen, hideChar, charGlow;
  /// G-1 `entering` — 입장 연출(카메라인 2.2s). 타인의 방 입장 시 사용.
  final bool entering;
  /// G-1 `shake` — 정성 들이는 순간 화면 흔들림(DevotionTimeline.shake 단계).
  final bool shake;
  /// G-1 `reveal` — 방금 해금된 레벨(2~10). 스포트라이트→드롭인→버스트→라벨 1회 연출.
  final int? reveal;
  final List<Widget> fx;    // L8
  /// SCR-10 완료 연출 전용 — `Math.max(r.level, levelOverride)` (원본 `{...r, level: st>=3 ? Math.max(r.level,10) : r.level}`).
  /// Lv9+/Lv7+ 등 레벨 해금 연출을 완료 연출 중 강제로 끌어올릴 때만 사용.
  final int? levelOverride;
  const RoomScene({super.key, required this.room, required this.items, this.pray = false, this.boost = 0, this.gold = 0,
      this.lowFx = false, this.frozen = false, this.hideChar = false, this.charGlow = false, this.entering = false,
      this.shake = false, this.reveal, this.fx = const [], this.levelOverride});
  @override State<RoomScene> createState() => _RoomSceneState();
}

class _RoomSceneState extends State<RoomScene> with TickerProviderStateMixin {
  late final AnimationController drift = AnimationController(vsync: this, duration: const Duration(seconds: 24));
  late final AnimationController flick = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  late final AnimationController breathe = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  late final AnimationController loop = AnimationController(vsync: this, duration: const Duration(seconds: 20)); // 파티클 공용 시계
  late final AnimationController sigilSpin = AnimationController(vsync: this, duration: const Duration(seconds: 60));
  late final AnimationController cameraIn = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  AnimationController? _revealCtrl;
  int? _revealedFor;
  late final AnimationController shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override void initState() {
    super.initState();
    if (!widget.frozen) { for (final c in [drift, flick, breathe, pulse, sigilSpin]) { c.repeat(reverse: c != sigilSpin); } loop.repeat(); }
    if (widget.entering) { cameraIn.forward(); } else { cameraIn.value = 1; }
    if (widget.shake) { shakeCtrl.forward(from: 0); }
    _maybeStartReveal();
  }

  @override void didUpdateWidget(RoomScene old) {
    super.didUpdateWidget(old);
    if (widget.shake && !old.shake) { shakeCtrl.forward(from: 0); }
    _maybeStartReveal();
  }

  void _maybeStartReveal() {
    if (widget.reveal != null && widget.reveal != _revealedFor) {
      _revealedFor = widget.reveal;
      _revealCtrl?.dispose();
      _revealCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4600))..forward();
    }
  }

  @override void dispose() { for (final c in [drift, flick, breathe, pulse, loop, sigilSpin, cameraIn, shakeCtrl]) { c.dispose(); } _revealCtrl?.dispose(); super.dispose(); }

  WrItem? _item(String? id) => id == null ? null : widget.items.where((i) => i.id == id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final r = widget.room, cat = WrCatalog.I;
    final lv = widget.levelOverride != null ? math.max(r.level, widget.levelOverride!) : r.level;
    final sacred = r.sacred;
    final bright = r.brightness;
    final light = math.min(1.6, bright + (lv >= 9 ? .3 : 0) + (widget.boost >= 2 ? .32 : widget.boost >= 1 ? .15 : 0));
    final roomImg = sacred ? cat.roomImage(r.theme) : RoomLayout.roomImg;
    final candle = _item(r.equip.candle);
    final glowC = _hex((candle?.raw('glow') as String?) ?? '#ffd98a');
    final decos = placeDecos(r.equip, widget.items, r.layout);
    final flower = _item(r.equip.flower);
    final bgItem = _item(r.equip.background);
    final specialFx = _item(r.equip.special)?.fx;
    final ritualPose = Pose.values.byName(cat.ritual(r.theme)['pose'] as String);
    final poseImg = cat.poseImage(r.char, r.outfitNow, ritualPose);
    final hasArt = true; // THEMES[].room 은 4종 모두 존재(assets/wishroom/rooms/room-*.jpg) — §G-2 roomFor() 항상 그림 반환

    Widget scene = ClipRect(child: Stack(clipBehavior: Clip.hardEdge, children: [
      // ── L1–L3 방 ──
      AnimatedBuilder(animation: Listenable.merge([drift, cameraIn]), builder: (_, c) {
        final camT = Curves.easeOutCubic.transform(cameraIn.value);
        final camScale = widget.entering ? (1.14 - .14 * camT) : 1.0;
        return Transform.scale(scale: camScale * (1 + .025 * drift.value), child: Opacity(opacity: widget.entering ? (.4 + .6 * camT) : 1, child: c));
      },
        child: AnimatedSwitcher(duration: const Duration(milliseconds: 2400), child: ColorFiltered(key: ValueKey('$roomImg$light'),
          colorFilter: ColorFilter.matrix(_brightSat(.22 + .78 * math.min(1, light) + (light > 1 ? (light - 1) * .5 : 0), .6 + .4 * math.min(1, light))),
          child: Image.asset(roomImg, width: 390, height: 844, fit: BoxFit.cover, alignment: const Alignment(0, -.2))))),
      if (!sacred) _WindowView(bg: bgItem, light: light),
      if (!sacred && (bgItem?.raw('wx') as String?) != null)
        _WeatherFx(wx: bgItem!.raw('wx') as String, density: widget.lowFx ? .5 : 1, clock: loop),
      // ── 테마 분위기 ──
      _ThemeLayer(theme: r.theme, hasArt: hasArt, clock: pulse),
      // ── L2 광원 ──
      _glow(236 + 75, 108 + 75, 75, const Color(0x73FFF5E6), pulse),
      if (lv >= 4) ...[_glow(-18 + 75, 80 + 75, 75, const Color(0x80FFA096), pulse), _glow(256 + 75, 196 + 75, 75, const Color(0x80FFA096), pulse)],
      if (lv >= 7) ..._ceilingStars(widget.lowFx ? 15 : 30),
      if (lv >= 9)
        AnimatedBuilder(animation: _revealCtrl ?? pulse, builder: (_, __) {
          final revealing9 = widget.reveal == 9 && _revealCtrl != null;
          final op = revealing9 ? _revealCtrl!.value.clamp(0.0, 1.0) : null;
          return Positioned.fill(child: IgnorePointer(child: op != null
            ? Opacity(opacity: op, child: const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.24), radius: .7, colors: [Color(0x52FFDC96), Colors.transparent]))))
            : FadeTransition(opacity: Tween(begin: .7, end: 1.0).animate(pulse),
                child: const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.24), radius: .7, colors: [Color(0x52FFDC96), Colors.transparent])))),
          ));
        }),
      if (lv >= 10) _Lv10Sigil(spin: sigilSpin, revealing: widget.reveal == 10 ? _revealCtrl : null),
      // ── L4 꾸미기 ──
      for (final d in decos) _deco(d),
      if (flower?.img != null) _stand(flower!.asset!, r.layout[flower.id]?.x ?? RoomLayout.flower.x, r.layout[flower.id]?.y ?? RoomLayout.flower.y, r.layout[flower.id]?.s ?? RoomLayout.flower.s, sway: true, swayClock: breathe),
      if (!sacred) for (final e in RoomLayout.unlocks.entries.where((e) => lv >= e.key))
        for (final it in (e.value['items'] as List).cast<Map>())
          _unlockObj(it, isNew: widget.reveal == e.key, delayIdx: (e.value['items'] as List).indexOf(it)),
      // ── L6 촛불 ──
      if (!sacred && candle != null && candle.id != 'c_basic' && candle.asset != null) ...[
        // 촛불 뒤 흐림판 — G-2 "촛불 뒤 흐림판 숨김"은 sacred 전용, 자유 테마에서는 항시 표시.
        Positioned(left: 90, top: 250, child: IgnorePointer(child: ImageFiltered(imageFilter: _blurFilter(6), child: Container(
          width: 228, height: 280,
          decoration: BoxDecoration(borderRadius: const BorderRadius.all(Radius.elliptical(114, 130)),
            gradient: RadialGradient(colors: [const Color(0xEB3C1C14), const Color(0x003C1C14)], stops: const [.4, .72])),
        )))),
        _stand('assets/wishroom/items/${candle.id}.png', RoomLayout.candle.x, RoomLayout.candle.y, RoomLayout.candle.s),
      ],
      if (lv >= 5 && !sacred) Positioned(left: 204 - 125, top: 505 - 35, child: FadeTransition(opacity: Tween(begin: .55, end: 1.0).animate(pulse),
        child: Container(width: 250, height: 70, decoration: BoxDecoration(borderRadius: BorderRadius.circular(125), border: Border.all(color: const Color(0x8CFFDC96), width: 2), boxShadow: const [BoxShadow(color: Color(0x99FFC878), blurRadius: 24)])))),
      AnimatedBuilder(animation: flick, builder: (_, __) { final s = (widget.boost > 0 ? 470.0 : 300.0) * (1 + .03 * flick.value);
        final sacredMul = sacred && widget.boost <= 0 ? .35 : 1.0;
        return Positioned(left: 204 - s / 2, top: 330 - s / 2, child: IgnorePointer(child: Opacity(opacity: sacredMul * (.4 + .6 * math.min(1, bright)), child: Container(width: s, height: s,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [const Color(0xCCFFF0BE), glowC.withValues(alpha: .4), glowC.withValues(alpha: .08), Colors.transparent], stops: const [0, .22, .48, .66])))))); }),
      if (widget.boost > 0 && !sacred) _boostFlame(glowC),
      // ── L7 파티클 ── (CustomPainter 로 한 번에 그리면 성능 예산 §13.3 충족: 동시 ≤80, 저사양 ≤40)
      Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(animation: loop, builder: (_, __) => CustomPaint(painter: _AmbientPainter(t: loop.value * 20, lv: lv, density: widget.lowFx ? .5 : 1))))),
      // ── 꾸미기 SPECIAL 슬롯 9종 — app2/room2.jsx › SpecialFx()/special==='starrain'|
      // 'butterfly'|'aura' 1:1.
      if (specialFx != null && specialFx.isNotEmpty)
        Positioned.fill(child: WrSpecialFx(fx: specialFx, density: widget.lowFx ? .5 : 1)),
      // ── L5 캐릭터 ──
      if (!widget.hideChar) Positioned(left: -2, top: 468, width: 162, height: 226, child: AnimatedBuilder(animation: breathe,
        builder: (_, c) => Transform.scale(alignment: Alignment.bottomCenter, scaleY: 1 + .012 * breathe.value, child: c),
        child: ShaderMask(shaderCallback: (b) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black, Colors.black, Colors.transparent], stops: [0, .7, 1]).createShader(b), blendMode: BlendMode.dstIn,
          child: ColorFiltered(colorFilter: ColorFilter.matrix(_brightness(widget.charGlow ? 1.1 : .4 + .6 * math.min(1, bright))), child: Stack(fit: StackFit.expand, children: [
            AnimatedOpacity(opacity: widget.pray && poseImg != null ? 0 : 1, duration: const Duration(milliseconds: 700), child: Image.asset(cat.charImage(r.char, r.outfitNow), fit: BoxFit.contain, alignment: Alignment.bottomCenter)),
            if (poseImg != null) AnimatedOpacity(opacity: widget.pray ? 1 : 0, duration: const Duration(milliseconds: 700), child: Image.asset(poseImg, fit: BoxFit.contain, alignment: Alignment.bottomCenter)),
            if (widget.pray) Positioned(left: 162 * .64 - 50, top: 226 * .40 - 50, child: IgnorePointer(child: FadeTransition(opacity: Tween(begin: .6, end: 1.0).animate(pulse),
              child: Container(width: 100, height: 100, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0x80FFE1A0), Colors.transparent], stops: [0, .65])))))),
            if (widget.pray) _PoseFx(pose: ritualPose, clock: pulse),
          ]))))),
      // ── 감쇠 비네트 · 황금빛 ──
      Positioned.fill(child: IgnorePointer(child: AnimatedOpacity(duration: const Duration(milliseconds: 1400), opacity: (math.max(0, 1 - bright) * 1.2).clamp(0, 1).toDouble(),
        child: const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.16), radius: .8, colors: [Colors.transparent, Color(0x99050208)])))))),
      if (widget.gold > 0) Positioned.fill(child: IgnorePointer(child: AnimatedOpacity(duration: const Duration(milliseconds: 1600), opacity: widget.gold,
        child: const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.1), radius: .9, colors: [Color(0xD9FFD778), Color(0x4DF5A050), Colors.transparent], stops: [0, .6, 1])))))),
      // ── 레벨업 리빌: 스포트라이트 → 드롭인(오브젝트는 위에서 이미 애니메이션) → 버스트 → 라벨 ──
      if (widget.reveal != null && _revealCtrl != null && RoomLayout.unlocks[widget.reveal] != null)
        _RevealOverlay(ctrl: _revealCtrl!, unlock: RoomLayout.unlocks[widget.reveal]!, isLv9: widget.reveal == 9),
      // ── L8 FX ──
      ...widget.fx,
    ]));

    if (widget.shake) {
      scene = AnimatedBuilder(animation: shakeCtrl, builder: (_, c) {
        final t = shakeCtrl.value;
        final amp = (1 - t) * 6 * math.sin(t * math.pi * 8);
        return Transform.translate(offset: Offset(amp, 0), child: c);
      }, child: scene);
    }
    return SizedBox(width: 390, height: 844, child: scene);
  }

  Widget _boostFlame(Color glowC) => Positioned(left: 204 - 17, top: 300, child: AnimatedBuilder(animation: flick, builder: (_, __) {
    return Transform.scale(scale: 1.5, alignment: Alignment.bottomCenter, child: IgnorePointer(child: CustomPaint(
      size: const Size(34, 62),
      painter: _FlamePainter(color: glowC),
    )));
  }));

  Widget _glow(double cx, double cy, double rad, Color c, Animation<double> a) => Positioned(left: cx - rad, top: cy - rad, child: IgnorePointer(child: FadeTransition(opacity: Tween(begin: .7, end: 1.0).animate(a),
      child: Container(width: rad * 2, height: rad * 2, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, Colors.transparent], stops: const [0, .64]))))));

  List<Widget> _ceilingStars(int n) { final rnd = math.Random(13); return List.generate(n, (i) { final s = 2.0 + (i % 3) * 1.5;
    return Positioned(left: 16 + rnd.nextDouble() * 356, top: 44.0 + (i * 29) % 110, child: FadeTransition(opacity: Tween(begin: .3, end: 1.0).animate(CurvedAnimation(parent: pulse, curve: Interval((i % 5) / 10, 1))),
      child: Container(width: s, height: s, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFF6D0), boxShadow: [BoxShadow(color: Color(0xFFFFD070), blurRadius: 8)])))); }); }

  Widget _stand(String asset, double x, double y, double s, {bool sway = false, Animation<double>? swayClock}) {
    final img = Image.asset(asset, fit: BoxFit.contain, alignment: Alignment.bottomCenter);
    if (!sway || swayClock == null) return Positioned(left: x - s / 2, top: y - s, width: s, height: s, child: img);
    return Positioned(left: x - s / 2, top: y - s, width: s, height: s, child: AnimatedBuilder(animation: swayClock,
      builder: (_, c) => Transform.rotate(angle: .035 * math.sin(swayClock.value * math.pi * 2), alignment: Alignment.topCenter, child: c), child: img));
  }

  Widget _deco(PlacedDeco d) {
    if (d.item.slot == Slot.SEAL) return Positioned(left: d.x - d.s / 2, top: d.y - d.s, child: _Seal(text: d.item.hanja ?? '願', color: _hex(d.item.color ?? '#c94a3b'), size: d.s, clock: pulse));
    final asset = d.item.asset;
    final child = asset != null ? Image.asset(asset, width: d.s, height: d.s, fit: BoxFit.contain) : _Glyph(glyph: d.item.glyph ?? '✦', tier: d.item.tier, size: d.s);
    switch (d.kind) {
      case 'hang': return Positioned(left: d.x - d.s / 2, top: d.y, child: AnimatedBuilder(animation: breathe, builder: (_, c) => Transform.rotate(alignment: Alignment.topCenter, angle: .05 * (breathe.value - .5), child: c),
          child: Column(children: [Container(width: 1.5, height: d.len, color: const Color(0xCCFFD28C)), child])));
      case 'float': return Positioned(left: d.x - d.s / 2, top: d.y - d.s / 2, child: AnimatedBuilder(animation: breathe, builder: (_, c) => Transform.translate(offset: Offset(0, -6 * breathe.value), child: c), child: child));
      default: return Positioned(left: d.x - d.s / 2, top: d.y - d.s, child: child);
    }
  }

  Widget _unlockObj(Map it, {bool isNew = false, int delayIdx = 0}) {
    final s = (it['s'] as num).toDouble(), x = (it['x'] as num).toDouble(), y = (it['y'] as num).toDouble();
    final img = Image.asset('assets/wishroom/items/${it['img']}.png', width: s, height: s,
        errorBuilder: (_, __, ___) => SizedBox(width: s, height: s, child: Icon(Icons.auto_awesome, size: s * .6, color: const Color(0xFFFFD28C))));
    Widget wrapped;
    final glowRing = (it['glow'] == true) ? Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xB3FFDC96), width: 2), boxShadow: const [BoxShadow(color: Color(0xCCFFC878), blurRadius: 20)]))) : null;
    final pulseHalo = AnimatedBuilder(animation: pulse, builder: (_, __) => Opacity(opacity: .42 + .2 * pulse.value, child: Container(
      width: s * 2.2, height: s * 2.2, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0x6BFFC8A0), Colors.transparent], stops: [0, .65])))));
    final content = Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
      Positioned(left: s * -.6, top: s * -.6, child: pulseHalo),
      img,
      if (glowRing != null) glowRing,
    ]);
    if (it['kind'] == 'hang') { wrapped = Column(children: [Container(width: 1.5, height: (it['len'] as num).toDouble(), color: const Color(0xCCFFD28C)), content]); }
    else { wrapped = content; }
    final isFloat = it['kind'] == 'float';
    wrapped = AnimatedBuilder(animation: breathe, builder: (_, c) {
      if (it['kind'] == 'hang') return Transform.rotate(alignment: Alignment.topCenter, angle: .04 * (breathe.value - .5), child: c);
      if (isFloat) return Transform.translate(offset: Offset(0, -5 * breathe.value), child: c);
      return c!;
    }, child: wrapped);
    Widget positioned;
    if (it['kind'] == 'hang') positioned = Positioned(left: x - s / 2, top: y, child: wrapped);
    else if (isFloat) positioned = Positioned(left: x - s / 2, top: y - s / 2, child: wrapped);
    else positioned = Positioned(left: x - s / 2, top: y - s, child: wrapped);
    if (!isNew) return positioned;
    // reveal 드롭인: unlock-drop 1.3s overshoot, 아이템마다 .25s 지연(j*.25+.5s)
    return positioned.let((p) => TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 1300 + (delayIdx * 250)),
      curve: const Interval(0, 1, curve: Cubic(.34, 1.56, .64, 1)),
      tween: Tween(begin: 0, end: 1),
      builder: (_, v, __) => Transform.scale(scale: v.clamp(0, 1.2), alignment: Alignment.bottomCenter, child: p),
    ));
  }
}

extension _Let<T> on T { R let<R>(R Function(T) f) => f(this); }

/// ── ThemeLayer — app2/room2.jsx › ThemeLayer() 1:1. 테마별 빛만 얹음(모두 screen 블렌드, pulse 루프).
class _ThemeLayer extends StatelessWidget {
  final WrTheme theme; final bool hasArt; final Animation<double> clock;
  const _ThemeLayer({required this.theme, required this.hasArt, required this.clock});
  @override Widget build(BuildContext context) {
    switch (theme) {
      case WrTheme.free:
        const spots = [(60.0, 140.0, 60.0, Color(0x59FFAAD2)), (330.0, 120.0, 50.0, Color(0x4DB4C8FF)), (300.0, 420.0, 70.0, Color(0x40FFDCA0)), (90.0, 380.0, 46.0, Color(0x38C8FFDC))];
        return Positioned.fill(child: IgnorePointer(child: Stack(children: [
          for (final (x, y, s, c) in spots) AnimatedBuilder(animation: clock, builder: (_, __) => Positioned(left: x - s, top: y - s, child: Opacity(opacity: .6 + .4 * clock.value,
            child: _screenCircle(s * 2, c)))),
        ])));
      case WrTheme.god:
        if (!hasArt) return _godFallback(clock);
        const beams = [(195.0, 150.0, 0.0, Color(0x4DFFF5D2)), (90.0, 190.0, -14.0, Color(0x38FFC896)), (300.0, 190.0, 14.0, Color(0x38B4D2FF))];
        return Positioned.fill(child: IgnorePointer(child: Stack(children: [
          for (final beam in beams) _godBeam(beam, clock),
          AnimatedBuilder(animation: clock, builder: (_, __) => Positioned(left: 204 - 60, top: 330 - 60, child: Opacity(opacity: .6 + .4 * clock.value, child: _screenCircle(120, const Color(0x73FFF0C8))))),
        ])));
      case WrTheme.buddha:
        if (!hasArt) return _buddhaFallback(clock);
        const lanterns = [(60.0, 150.0, Color(0x66FF8CB4)), (120.0, 150.0, Color(0x66FF786E)), (200.0, 150.0, Color(0x6678B4FF)), (280.0, 150.0, Color(0x66FFDC6E)), (340.0, 150.0, Color(0x66FF8CB4))];
        return Positioned.fill(child: IgnorePointer(child: Stack(children: [
          AnimatedBuilder(animation: clock, builder: (_, __) => Positioned(left: 195 - 150, top: 360 - 150, child: Opacity(opacity: .7 + .3 * clock.value, child: _screenCircle(300, const Color(0x59FFD782))))),
          for (final (x, y, c) in lanterns) AnimatedBuilder(animation: clock, builder: (_, __) => Positioned(left: x - 40, top: y - 40, child: Opacity(opacity: .55 + .45 * clock.value, child: _screenCircle(80, c)))),
        ])));
      case WrTheme.shaman:
        if (!hasArt) return _shamanFallback(clock);
        const candles = [(118.0, 330.0), (206.0, 280.0), (340.0, 290.0), (340.0, 430.0), (120.0, 480.0)];
        return Positioned.fill(child: IgnorePointer(child: Stack(children: [
          for (final (x, y) in candles) AnimatedBuilder(animation: clock, builder: (_, __) => Positioned(left: x - 36, top: y - 36, child: Opacity(opacity: .5 + .5 * clock.value, child: _screenCircle(72, const Color(0x80FF9650))))),
        ])));
    }
  }

  static Widget _screenCircle(double d, Color c) => DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, Colors.transparent], stops: const [0, .65])), child: SizedBox(width: d, height: d));

  static Widget _godBeam((double, double, double, Color) beam, Animation<double> clock) {
    final (x, y, rot, c) = beam;
    final blurred = ImageFiltered(imageFilter: _blurFilter(10), child: Container(width: 60, height: 560,
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c, Colors.transparent]))));
    return AnimatedBuilder(animation: clock, builder: (_, __) => Positioned(left: x - 30, top: y,
      child: Transform.rotate(angle: rot * math.pi / 180, child: Opacity(opacity: .55 + .45 * clock.value, child: blurred))));
  }

  static Widget _godFallback(Animation<double> clock) => Positioned.fill(child: IgnorePointer(child: Stack(children: [
    const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x1AFFF5DC), Colors.transparent]))),
    Positioned(left: 195 - 131, top: 214 - 131, child: Opacity(opacity: .55, child: ClipOval(child: SizedBox(width: 262, height: 262, child: Stack(children: [
      const DecoratedBox(decoration: BoxDecoration(gradient: SweepGradient(colors: [Color(0xFFFF5A5A), Color(0xFFFFB84A), Color(0xFFFFE66A), Color(0xFF6AD08A), Color(0xFF4AA8FF), Color(0xFF8A6AFF), Color(0xFFFF6AD0), Color(0xFFFF5A5A)]))),
      Positioned(left: 128, top: 46, child: Container(width: 10, height: 168, color: const Color(0xF2FFF8E1))),
      Positioned(left: 73, top: 94, child: Container(width: 115, height: 10, color: const Color(0xF2FFF8E1))),
    ]))))),
  ])));
  static Widget _buddhaFallback(Animation<double> clock) => Positioned.fill(child: IgnorePointer(child: Stack(children: [
    const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.4), radius: .9, colors: [Color(0x33FFC86E), Colors.transparent]))),
    AnimatedBuilder(animation: clock, builder: (_, __) => Positioned(left: 195 - 70, top: 214 - 70, child: Opacity(opacity: .35, child: Transform.rotate(angle: clock.value * math.pi * 2,
      child: CustomPaint(size: const Size(140, 140), painter: _MandalaPainter())))))
  ])));
  static Widget _shamanFallback(Animation<double> clock) => Positioned.fill(child: IgnorePointer(child: Stack(children: [
    const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.1), radius: .85, colors: [Color(0x24FF5A5A), Color(0x2E280A14)]))),
    const Positioned(left: 0, right: 0, top: 44, child: _ObangFlags()),
  ])));
}

class _ObangFlags extends StatelessWidget {
  const _ObangFlags();
  static const _colors = [Color(0xD12A6AD8), Color(0xD1E8E0D0), Color(0xD1D82A2A), Color(0xD11A1A1A), Color(0xD1F5C02A)];
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [for (int i = 0; i < 10; i++) Container(width: 14, height: 70.0 + (i % 3) * 22, color: _colors[i % 5], margin: const EdgeInsets.only(right: 2))]));
}

class _MandalaPainter extends CustomPainter {
  @override void paint(Canvas c, Size s) {
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFFFFD98A);
    final center = Offset(s.width / 2, s.height / 2);
    c.drawCircle(center, s.width / 2 - 4, p);
    c.drawCircle(center, 10, p);
    for (var i = 0; i < 8; i++) { final a = i * math.pi / 4; c.drawLine(center, center + Offset(math.cos(a), math.sin(a)) * (s.width / 2 - 4), p); }
  }
  @override bool shouldRepaint(covariant CustomPainter o) => false;
}

/// ── WeatherFx — 창밖 날씨(배경 아이템 부가효과). app2/room2.jsx › WeatherFx() 1:1.
class _WeatherFx extends StatelessWidget {
  final String wx; final double density; final Animation<double> clock;
  const _WeatherFx({required this.wx, required this.density, required this.clock});
  @override Widget build(BuildContext context) {
    return Positioned(left: RoomLayout.windowCx - RoomLayout.windowR, top: RoomLayout.windowCy - RoomLayout.windowR, child: ClipOval(child: SizedBox(
      width: RoomLayout.windowR * 2, height: RoomLayout.windowR * 2,
      child: IgnorePointer(child: AnimatedBuilder(animation: clock, builder: (_, __) => CustomPaint(painter: _WeatherPainter(wx: wx, density: density, t: clock.value * 20)))),
    )));
  }
}

class _WeatherPainter extends CustomPainter {
  final String wx; final double density, t; _WeatherPainter({required this.wx, required this.density, required this.t});
  @override void paint(Canvas c, Size s) {
    final n = (14 * density).round();
    for (var i = 0; i < n; i++) {
      final q = _seedFrac(i, 31);
      if (wx == 'stars') {
        final dur = 1.4 + q * 2, delay = q * 3, ph = ((t - delay) % dur) / dur;
        if (ph < 0) continue;
        final op = (math.sin(ph * math.pi * 2) * .5 + .5);
        final paint = Paint()..color = Colors.white.withValues(alpha: op)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        c.drawCircle(Offset(q * s.width, ((i * 37) % 70) / 100 * s.height), 2.5, paint);
      } else {
        final dur = 5 + q * 4, delay = q * 6, raw = ((t - delay) % dur) / dur;
        if (raw < 0) continue;
        final dx = (q - .5) * 60 * raw;
        final x = q * s.width + dx, y = -12 + (s.height + 24) * raw;
        final op = raw < .08 ? raw / .08 : (raw > .85 ? (1 - raw) / .15 : 1.0);
        final paint = Paint()..color = (wx == 'snow' ? Colors.white : wx == 'maple' ? const Color(0xFFD8401A) : const Color(0xFFF58FB2)).withValues(alpha: op.clamp(0, 1));
        if (wx == 'snow') { c.drawCircle(Offset(x, y), 2, paint); } else { c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 9, height: 7), paint); }
      }
    }
  }
  @override bool shouldRepaint(covariant _WeatherPainter o) => o.t != t;
}

/// ── PoseFx — 테마별 정성 동작 이펙트. app2/room2.jsx › PoseFx() 1:1.
/// pray=머리위 빛120+빛살5줄(±24°) · bow=바닥연꽃파문3겹+🪷 · rub=손끝불씨8개
class _PoseFx extends StatelessWidget {
  final Pose pose; final Animation<double> clock;
  const _PoseFx({required this.pose, required this.clock});

  @override Widget build(BuildContext context) {
    switch (pose) {
      case Pose.bow: return _bow();
      case Pose.rub: return _rub();
      case Pose.pray: return _pray();
    }
  }

  Widget _bow() {
    final ripples = <Widget>[];
    for (final d in const [0.0, 1.07, 2.13]) {
      ripples.add(AnimatedBuilder(animation: clock, builder: (_, __) {
        final ph = ((clock.value * 6 + d) % 3.2) / 3.2;
        final deco = BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: const Color(0xCCFFD282), width: 2),
          boxShadow: const [BoxShadow(color: Color(0xB3FFBE64), blurRadius: 14)]);
        final box = Container(width: 140 * (1 + ph * .4), height: 36 * (1 + ph * .4), decoration: deco);
        return Positioned(left: -70, top: -18 - 20 * ph, child: Opacity(opacity: (1 - ph).clamp(0.0, 1.0), child: box));
      }));
    }
    const lotus = Positioned(left: -14, top: -40, child: Text('🪷',
      style: TextStyle(fontSize: 22, shadows: [Shadow(color: Color(0xFFFFC870), blurRadius: 8)])));
    return Positioned(left: 81, bottom: 6, child: IgnorePointer(child: Stack(clipBehavior: Clip.none, children: [...ripples, lotus])));
  }

  Widget _rub() {
    final sparks = <Widget>[];
    for (var i = 0; i < 8; i++) {
      sparks.add(AnimatedBuilder(animation: clock, builder: (_, __) {
        final dl = i * .17, dur = 1.4, raw = (((clock.value * 6) - dl) % dur) / dur;
        final dx = (i - 3.5) * 9.0;
        final color = i.isEven ? const Color(0xFFFFB070) : const Color(0xFFFFF0B0);
        final deco = BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: const [BoxShadow(color: Color(0xFFFF9A40), blurRadius: 8)]);
        final box = Container(width: 5, height: 5, decoration: deco);
        return Positioned(left: dx * raw - 2.5, top: -14 * raw - 2.5, child: Opacity(opacity: (1 - raw).clamp(0.0, 1.0), child: box));
      }));
    }
    return Positioned(left: 100, top: 131, child: IgnorePointer(child: Stack(clipBehavior: Clip.none, children: sparks)));
  }

  Widget _pray() {
    final haloDeco = const BoxDecoration(shape: BoxShape.circle,
      gradient: RadialGradient(colors: [Color(0xB3FFFADC), Colors.transparent], stops: [0, .65]));
    final halo = AnimatedBuilder(animation: clock, builder: (_, __) {
      final box = Container(width: 120, height: 120, decoration: haloDeco);
      return Positioned(left: -60, top: -60, child: Opacity(opacity: .5 + .5 * clock.value, child: box));
    });
    final rays = <Widget>[];
    for (var i = 0; i < 5; i++) {
      rays.add(AnimatedBuilder(animation: clock, builder: (_, __) {
        final op = (.5 + .5 * math.sin(clock.value * math.pi * 2 + i)).clamp(0.0, 1.0);
        final rayDeco = const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xB3FFF5C8)]));
        final ray = Container(width: 4, height: 110, decoration: rayDeco);
        return Positioned(left: -2, top: -120, child: Transform.rotate(angle: (i - 2) * 12 * math.pi / 180, child: Opacity(opacity: op, child: ray)));
      }));
    }
    return Positioned(left: 81, top: 9, child: IgnorePointer(child: Stack(clipBehavior: Clip.none, children: [halo, ...rays])));
  }
}

/// ── Lv10 금빛 마법진(sigil) — app2/room2.jsx 177~230행 svg 1:1 근사(CustomPaint).
class _Lv10Sigil extends StatelessWidget {
  final Animation<double> spin; final AnimationController? revealing;
  const _Lv10Sigil({required this.spin, this.revealing});
  @override Widget build(BuildContext context) {
    final core = AnimatedBuilder(animation: spin, builder: (_, __) => Transform.rotate(angle: spin.value * math.pi * 2,
        child: CustomPaint(size: const Size(240, 240), painter: _SigilPainter())));
    Widget w = Opacity(opacity: .75, child: core);
    if (revealing != null) {
      w = AnimatedBuilder(animation: revealing!, builder: (_, __) {
        final t = Curves.easeOutBack.transform((revealing!.value.clamp(0, 1)));
        return Opacity(opacity: t.clamp(0, 1), child: Transform.scale(scale: .4 + .6 * t, child: core));
      });
    }
    return Positioned(left: 204 - 120, top: 225 - 120, child: IgnorePointer(child: SizedBox(width: 240, height: 240, child: w)));
  }
}

class _SigilPainter extends CustomPainter {
  @override void paint(Canvas c, Size s) {
    final center = Offset(s.width / 2, s.height / 2);
    final gold = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = const Color(0xFFFFD98A);
    final pink = Paint()..style = PaintingStyle.stroke..strokeWidth = .9..color = const Color(0xFFFFC8DC);
    c.drawCircle(center, 92, gold);
    final dashed = Paint()..style = PaintingStyle.stroke..strokeWidth = .5..color = const Color(0xFFFFD98A);
    _dashedCircle(c, center, 84, dashed);
    _triangle(c, center, 70, 0, pink); _triangle(c, center, 70, math.pi, pink);
    c.drawCircle(center, 40, gold..strokeWidth = .8);
    final dot = Paint()..color = const Color(0xFFFFF4C0);
    for (var i = 0; i < 12; i++) { final a = i / 12 * math.pi * 2; c.drawCircle(center + Offset(math.cos(a), math.sin(a)) * 78, 2.2, dot); }
  }
  void _triangle(Canvas c, Offset center, double r, double rot, Paint p) {
    final path = Path();
    for (var i = 0; i < 3; i++) { final a = rot + i * math.pi * 2 / 3 - math.pi / 2; final pt = center + Offset(math.cos(a), math.sin(a)) * r;
      if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy); }
    path.close(); c.drawPath(path, p);
  }
  void _dashedCircle(Canvas c, Offset center, double r, Paint p) {
    const dashLen = 2.0, gapLen = 4.0; final circumference = 2 * math.pi * r; final count = (circumference / (dashLen + gapLen)).floor();
    for (var i = 0; i < count; i++) { final a0 = i * (dashLen + gapLen) / r, a1 = a0 + dashLen / r;
      c.drawArc(Rect.fromCircle(center: center, radius: r), a0, a1 - a0, false, p); }
  }
  @override bool shouldRepaint(covariant CustomPainter o) => false;
}

/// ── 레벨업 리빌 오버레이 — app2/room2.jsx 279~287행 1:1. 스포트라이트→링→버스트→라벨.
class _RevealOverlay extends StatelessWidget {
  final AnimationController ctrl; final Map<String, Object> unlock; final bool isLv9;
  const _RevealOverlay({required this.ctrl, required this.unlock, required this.isLv9});
  @override Widget build(BuildContext context) {
    final focus = (unlock['focus'] as List).cast<num>();
    final fx = focus[0].toDouble(), fy = focus[1].toDouble();
    final say = unlock['say'] as String;
    return AnimatedBuilder(animation: ctrl, builder: (_, __) {
      final t = ctrl.value; // 0~1, 총 4.6s
      final spotOp = (1 - t).clamp(0.0, 1.0) * (t < .92 ? 1.0 : (1 - t) / .08);
      final ringProg = ((t - .24) / .3).clamp(0.0, 1.0);
      final ringOp = (1 - (ringProg - 1).abs()).clamp(0.0, 1.0);
      final ringSize = 180 * (.6 + .4 * ringProg);
      final labelIn = ((t - .2) / .1).clamp(0.0, 1.0);
      final labelOut = (1 - ((t - .78) / .22).clamp(0.0, 1.0));
      final labelOp = (labelIn * labelOut).clamp(0.0, 1.0);
      final washOp = isLv9 ? (1 - ((t - .13) / .5 - 1).abs() * 2).clamp(0.0, 1.0) : 0.0;

      final spotGradient = BoxDecoration(gradient: RadialGradient(
        center: Alignment((fx - 195) / 195, (fy - 422) / 422), radius: 1.1,
        colors: const [Colors.transparent, Colors.transparent, Color(0xC7080305)], stops: const [0, .17, .46]));
      final ringDecoration = BoxDecoration(shape: BoxShape.circle,
        border: Border.all(color: const Color(0xE6FFDCA0), width: 2),
        boxShadow: const [BoxShadow(color: Color(0xE6FFC878), blurRadius: 30)]);
      final labelDecoration = BoxDecoration(borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF8FB1), Color(0xFFF2628F)]),
        boxShadow: const [BoxShadow(color: Color(0x99F2628F), blurRadius: 20)]);
      final washGradient = const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.2), radius: .7, colors: [Color(0xE6FFEBB4), Colors.transparent]));

      final labelBox = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: labelDecoration,
        child: Text('✦ NEW · $say', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
      );

      return Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(child: IgnorePointer(child: Opacity(opacity: spotOp,
          child: DecoratedBox(decoration: spotGradient)))),
        if (t > .24) Positioned(left: fx - ringSize / 2, top: fy - ringSize / 2, child: IgnorePointer(child: Opacity(opacity: ringOp,
          child: Container(width: ringSize, height: ringSize, decoration: ringDecoration)))),
        if (t > .25 && t < .7) WrBurst(x: fx, y: fy, n: 22, spread: 140, color: const Color(0xFFFFE08A), dur: 1500),
        if (t > .2) Positioned(
          left: math.max(14, math.min(390 - 230, fx - 110)), top: fy + (fy > 420 ? -150 : 80), width: 220,
          child: IgnorePointer(child: Opacity(opacity: labelOp, child: Center(child: labelBox))),
        ),
        if (isLv9 && t > .13) Positioned.fill(child: IgnorePointer(child: Opacity(opacity: washOp,
          child: DecoratedBox(decoration: washGradient)))),
      ]);
    });
  }
}

/// 자유 테마의 둥근 창 — BACKGROUND 아이템의 창밖 그림(win) 또는 기본 밤하늘, tint 로 방 조명 색
class _WindowView extends StatelessWidget {
  final WrItem? bg; final double light; const _WindowView({required this.bg, required this.light});
  @override Widget build(BuildContext context) {
    final win = bg?.raw('win') as String?; final tint = bg?.raw('tint') as String?;
    return Stack(children: [
      Positioned(left: RoomLayout.windowCx - RoomLayout.windowR, top: RoomLayout.windowCy - RoomLayout.windowR, child: ClipOval(child: SizedBox(
        width: RoomLayout.windowR * 2, height: RoomLayout.windowR * 2,
        child: Stack(children: [
          if (win != null) ColorFiltered(colorFilter: ColorFilter.matrix(_brightness(.3 + .7 * math.min(1, light))),
            child: Image.asset('assets/wishroom/${win.replaceFirst('assets/', '')}', width: RoomLayout.windowR * 2, height: RoomLayout.windowR * 2, fit: BoxFit.cover)),
          const DecoratedBox(decoration: BoxDecoration(boxShadow: [BoxShadow(color: Color(0xBF281208), blurRadius: 18, spreadRadius: -12, offset: Offset(0, 0))])),
        ]),
      ))),
      if (tint != null) Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -.4), radius: .9, colors: [_rgba(tint), Colors.transparent]))))),
    ]);
  }
}

class _Seal extends StatelessWidget { final String text; final Color color; final double size; final Animation<double> clock; const _Seal({required this.text, required this.color, required this.size, required this.clock});
  @override Widget build(BuildContext c) => Transform.rotate(angle: -6 * math.pi / 180, child: Stack(clipBehavior: Clip.none, children: [
      Positioned(left: -size * .35, top: size * (1.12 - .1), child: AnimatedBuilder(animation: clock, builder: (_, __) => Opacity(opacity: .5 + .3 * clock.value, child: ImageFiltered(imageFilter: _blurFilter(4),
        child: Container(width: size * 1.7, height: size * .5, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .4))))))),
      Container(width: size, height: size, alignment: Alignment.center,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6), boxShadow: [BoxShadow(color: color.withValues(alpha: .55), blurRadius: 8)]),
        child: Text(text, style: TextStyle(fontFamily: 'Noto Serif KR', fontWeight: FontWeight.w900, fontSize: size * .55, color: const Color(0xFFFFF9E8)))),
    ])); }

class _Glyph extends StatelessWidget { final String glyph; final String? tier; final double size; const _Glyph({required this.glyph, required this.tier, required this.size});
  @override Widget build(BuildContext context) {
    final c = {'free': const Color(0xFFC8F5D4), 'normal': const Color(0xFFFFE08A), 'special': const Color(0xFFE8C8FF)}[tier] ?? const Color(0xFFFFE08A);
    return Container(width: size, height: size, alignment: Alignment.center,
      decoration: BoxDecoration(boxShadow: [BoxShadow(color: c.withValues(alpha: .45), blurRadius: 12)]),
      child: Text(glyph, style: TextStyle(fontSize: size * .7)));
  }
}

/// 빛먼지 16 (rise 7–12s) · 꽃잎 7 (Lv2+, fall 12–20s) · 반딧불 2 (Lv4+)
class _AmbientPainter extends CustomPainter {
  final double t, density; final int lv; _AmbientPainter({required this.t, required this.lv, required this.density});
  @override void paint(Canvas c, Size s) {
    final rnd = math.Random(5); final mote = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (var i = 0; i < (16 * density).round(); i++) { final d = 7 + i % 5, ph = ((t + rnd.nextDouble() * 10) % d) / d;
      mote.color = const Color(0xFFFFF6D0).withValues(alpha: math.sin(ph * math.pi) * .9);
      c.drawCircle(Offset(s.width * (.08 + rnd.nextDouble() * .84) + (i.isOdd ? 1 : -1) * 20 * ph, 360 + (i * 37) % 280 - 260 * ph), 1.4 + (i % 3) * .7, mote); }
    if (lv >= 2) { final p = Paint()..color = const Color(0xFFF7A9C4);
      for (var i = 0; i < ((lv >= 2 ? 7 : 2) * density).round(); i++) { final d = 12 + (i % 4) * 2.4, ph = ((t + rnd.nextDouble() * 16) % d) / d;
        c.save(); c.translate(s.width * rnd.nextDouble() + (rnd.nextDouble() - .5) * 120 * ph, -20 + (s.height + 40) * ph); c.rotate(ph * 6.28 * 1.5);
        c.drawOval(const Rect.fromLTWH(-5.5, -4, 11, 8), p..color = p.color.withValues(alpha: math.sin(ph * math.pi))); c.restore(); } }
    if (lv >= 4) { final f = Paint()..color = const Color(0xFFFFF4B0)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      for (final (x, y, d) in [(300.0, 420.0, 11.0), (70.0, 250.0, 14.0)]) { final ph = (t % d) / d * 6.28; c.drawCircle(Offset(x + 30 * math.sin(ph), y + 20 * math.cos(ph * 1.3)), 3, f); } }
  }
  @override bool shouldRepaint(covariant _AmbientPainter o) => o.t != t || o.lv != lv;
}

class _FlamePainter extends CustomPainter {
  final Color color; _FlamePainter({required this.color});
  @override void paint(Canvas c, Size s) {
    final path = Path()
      ..moveTo(10, 1)
      ..cubicTo(15, 10, 17, 17, 15, 23)
      ..cubicTo(14, 28, 12, 30, 10, 30)
      ..cubicTo(8, 30, 6, 28, 5, 23)
      ..cubicTo(3, 17, 5, 10, 10, 1)
      ..close();
    final rect = Rect.fromLTWH(0, 0, 20, 32);
    final shader = ui.Gradient.radial(const Offset(10, 23), 18.56,
        [const Color(0xFFFFFDF0), const Color(0xFFFFF0B0), color.withValues(alpha: .8), color.withValues(alpha: 0)], const [0, .4, .75, 1]);
    final paint = Paint()..shader = shader;
    final scaleX = s.width / 20, scaleY = s.height / 32;
    c.save(); c.scale(scaleX, scaleY); c.drawPath(path, paint); c.restore();
    rect.toString();
  }
  @override bool shouldRepaint(covariant _FlamePainter o) => o.color != color;
}

ui.ImageFilter _blurFilter(double px) => ui.ImageFilter.blur(sigmaX: px / 2, sigmaY: px / 2);
double _seedFrac(int i, int salt) => ((math.sin(i * 12.9898 + salt * 78.233) * 43758.5453) % 1).abs();
List<double> _brightness(double b) => [b, 0, 0, 0, 0, 0, b, 0, 0, 0, 0, 0, b, 0, 0, 0, 0, 0, 1, 0];
List<double> _brightSat(double b, double sat) {
  // brightness(b) ∘ saturate(sat) 근사 행렬(순서는 CSS와 동일하게 밝기 먼저 적용 후 채도).
  const lr = .2126, lg = .7152, lb = .0722;
  final sr = (1 - sat) * lr, sg = (1 - sat) * lg, sb = (1 - sat) * lb;
  return [
    (sr + sat) * b, sg * b, sb * b, 0, 0,
    sr * b, (sg + sat) * b, sb * b, 0, 0,
    sr * b, sg * b, (sb + sat) * b, 0, 0,
    0, 0, 0, 1, 0,
  ];
}
Color _hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));
Color _rgba(String s) { final m = RegExp(r'rgba?\(([^)]+)\)').firstMatch(s); if (m == null) return Colors.transparent; final p = m.group(1)!.split(',').map((e) => double.parse(e.trim())).toList();
  return Color.fromRGBO(p[0].round(), p[1].round(), p[2].round(), p.length > 3 ? p[3] : 1); }

extension on WrItem { Object? raw(String k) => WrCatalog.I.raw['ITEMS'].firstWhere((e) => e['id'] == id)[k]; }

/// ── G-4 RoomThumb({room,w,h,focus=.5,zoom=1.25}) — 탐색·기록관·배경화면 목록 공용 썸네일.
/// `Room(scale=w/390*zoom, frozen=true, lowFx)`를 w×h 박스에 넣고 세로 focus 지점이 가운데 오게 이동.
class RoomThumb extends StatelessWidget {
  const RoomThumb({super.key, required this.room, required this.w, required this.h, this.items = const [], this.focus = .5, this.zoom = 1.25});
  final WishRoom room; final List<WrItem> items; final double w, h, focus, zoom;
  @override Widget build(BuildContext context) {
    final s = w / 390 * zoom;
    final top = -(844 * s * focus - h / 2);
    final left = -(390 * s - w) / 2;
    return ClipRect(child: SizedBox(width: w, height: h, child: Stack(children: [
      Positioned(left: left, top: top, child: Transform.scale(scale: s, alignment: Alignment.topLeft,
        child: RoomScene(room: room, items: items, frozen: true, lowFx: true))),
    ])));
  }
}
