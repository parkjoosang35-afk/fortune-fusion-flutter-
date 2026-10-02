// <RoomScene> v2.6 — 9-레이어 Stack (§13.1) · prototype/app2/room2.jsx › Room() 1:1 이식 스타터
// 좌표계 390×844. 부모에서 FittedBox / Transform.scale(screenW/390) 로 감싸 쓰세요.
//
// 레이어 순서 (아래 → 위) — 웹과 동일하게 유지해야 미리보기·배경화면·앱 화면이 같아집니다.
//  L1–3  방 일러스트 (테마 방 rooms/room-{theme}.jpg, 자유 테마는 room-empty.jpg) · 밝기 필터 · drift 24s
//        └ 자유 테마만: 둥근 창 안 창밖 풍경(BACKGROUND 아이템 win 이미지) + 날씨(꽃잎/단풍/눈)
//  L2    광원 — 달 글로우(236,108) pulse 6s · Lv4+ 등불 글로우 2 · Lv7+ 천장 별 30 · Lv9+ 전체 광량 · Lv10 금빛 마법진
//  L4    꾸미기 — DECORATION ≤5 · SEAL ≤3 · THEME ≤5 (room_layout.dart › placeDecos) + FLOWER + Lv 해금 오브젝트(sacred 테마는 숨김)
//  L6    촛불 — 장착 촛불 PNG(기본 c_basic 은 방 그림의 연꽃 촛불 그대로) · 광원 300px(정성 중 470) flick 2.6s · Lv5+ 받침 링
//  L7    상시 파티클 — 빛먼지 16 · 꽃잎 7(Lv2+) · 반딧불 2(Lv4+) · SPECIAL fx · 저사양은 ×0.5
//  L5    캐릭터 — 의상(outfitNow) 이미지 · breathe 4.2s · 정성 중이면 동작 그림(poseImage) 크로스페이드 .7s
//  감쇠  비네트 opacity (1-brightness)×1.2 · 황금빛(gold) 오버레이
//  L8    인터랙션 FX — children 슬롯 (정성 버스트 · 응원 하트 · 선물 · 꾸미기 적용 연출 · 레벨업 리빌)
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import 'room_layout.dart';

class RoomScene extends StatefulWidget {
  final WishRoom room;
  final List<WrItem> items;
  final bool pray;          // 정성 머금는 중 → 동작 그림
  final double boost;       // 0 · 1 · 2  (정성 연출 중 광량)
  final double gold;        // 0~1 완료 연출 황금빛
  final bool lowFx, frozen, hideChar, charGlow;
  final List<Widget> fx;    // L8
  /// SCR-10 완료 연출 전용 — `Math.max(r.level, levelOverride)` (원본 `{...r, level: st>=3 ? Math.max(r.level,10) : r.level}`).
  /// Lv9+/Lv7+ 등 레벨 해금 연출을 완료 연출 중 강제로 끌어올릴 때만 사용.
  final int? levelOverride;
  const RoomScene({super.key, required this.room, required this.items, this.pray = false, this.boost = 0, this.gold = 0,
      this.lowFx = false, this.frozen = false, this.hideChar = false, this.charGlow = false, this.fx = const [], this.levelOverride});
  @override State<RoomScene> createState() => _RoomSceneState();
}

class _RoomSceneState extends State<RoomScene> with TickerProviderStateMixin {
  late final AnimationController drift = AnimationController(vsync: this, duration: const Duration(seconds: 24));
  late final AnimationController flick = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  late final AnimationController breathe = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  late final AnimationController loop = AnimationController(vsync: this, duration: const Duration(seconds: 20)); // 파티클 공용 시계

  @override void initState() { super.initState(); if (!widget.frozen) { for (final c in [drift, flick, breathe, pulse]) { c.repeat(reverse: true); } loop.repeat(); } }
  @override void dispose() { for (final c in [drift, flick, breathe, pulse, loop]) { c.dispose(); } super.dispose(); }

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
    final ritualPose = Pose.values.byName(cat.ritual(r.theme)['pose'] as String);
    final poseImg = cat.poseImage(r.char, r.outfitNow, ritualPose);

    return SizedBox(width: 390, height: 844, child: ClipRect(child: Stack(clipBehavior: Clip.hardEdge, children: [
      // ── L1–L3 방 ──
      AnimatedBuilder(animation: drift, builder: (_, c) => Transform.scale(scale: 1 + .025 * drift.value, child: c),
        child: AnimatedSwitcher(duration: const Duration(milliseconds: 2400), child: ColorFiltered(key: ValueKey('$roomImg$light'),
          colorFilter: ColorFilter.matrix(_brightness(.22 + .78 * math.min(1, light) + (light > 1 ? (light - 1) * .5 : 0))),
          child: Image.asset(roomImg, width: 390, height: 844, fit: BoxFit.cover, alignment: const Alignment(0, -.2))))),
      if (!sacred) _WindowView(bg: _item(r.equip.background), light: light),
      // ── L2 광원 ──
      _glow(236 + 75, 108 + 75, 75, const Color(0x73FFF5E6), pulse),
      if (lv >= 4) ...[_glow(-18 + 75, 80 + 75, 75, const Color(0x80FFA096), pulse), _glow(256 + 75, 196 + 75, 75, const Color(0x80FFA096), pulse)],
      if (lv >= 7) ..._ceilingStars(widget.lowFx ? 15 : 30),
      if (lv >= 9) Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -.24), radius: .7, colors: [const Color(0x52FFDC96), Colors.transparent]))))),
      // ── L4 꾸미기 ──
      for (final d in decos) _deco(d),
      if (flower?.img != null) _stand(flower!.asset!, r.layout[flower.id]?.x ?? RoomLayout.flower.x, r.layout[flower.id]?.y ?? RoomLayout.flower.y, r.layout[flower.id]?.s ?? RoomLayout.flower.s, sway: true),
      if (!sacred) for (final e in RoomLayout.unlocks.entries.where((e) => lv >= e.key)) for (final it in (e.value['items'] as List).cast<Map>()) _unlockObj(it),
      // ── L6 촛불 ──
      if (!sacred && candle != null && candle.id != 'c_basic' && candle.asset != null)
        _stand('assets/wishroom/items/${candle.id}.png', RoomLayout.candle.x, RoomLayout.candle.y, RoomLayout.candle.s),
      if (lv >= 5 && !sacred) Positioned(left: 204 - 125, top: 505 - 35, child: FadeTransition(opacity: Tween(begin: .55, end: 1.0).animate(pulse),
        child: Container(width: 250, height: 70, decoration: BoxDecoration(borderRadius: BorderRadius.circular(125), border: Border.all(color: const Color(0x8CFFDC96), width: 2), boxShadow: const [BoxShadow(color: Color(0x99FFC878), blurRadius: 24)])))),
      AnimatedBuilder(animation: flick, builder: (_, __) { final s = (widget.boost > 0 ? 470.0 : 300.0) * (1 + .03 * flick.value);
        return Positioned(left: 204 - s / 2, top: 330 - s / 2, child: IgnorePointer(child: Opacity(opacity: .4 + .6 * math.min(1, bright), child: Container(width: s, height: s,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [const Color(0xCCFFF0BE), glowC.withValues(alpha: .4), glowC.withValues(alpha: .08), Colors.transparent], stops: const [0, .22, .48, .66])))))); }),
      // ── L7 파티클 ── (CustomPainter 로 한 번에 그리면 성능 예산 §13.3 충족: 동시 ≤80, 저사양 ≤40)
      Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(animation: loop, builder: (_, __) => CustomPaint(painter: _AmbientPainter(t: loop.value * 20, lv: lv, density: widget.lowFx ? .5 : 1))))),
      // ── L5 캐릭터 ──
      if (!widget.hideChar) Positioned(left: -2, top: 468, width: 162, height: 226, child: AnimatedBuilder(animation: breathe,
        builder: (_, c) => Transform.scale(alignment: Alignment.bottomCenter, scaleY: 1 + .012 * breathe.value, child: c),
        child: ShaderMask(shaderCallback: (b) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black, Colors.black, Colors.transparent], stops: [0, .7, 1]).createShader(b), blendMode: BlendMode.dstIn,
          child: ColorFiltered(colorFilter: ColorFilter.matrix(_brightness(widget.charGlow ? 1.1 : .4 + .6 * math.min(1, bright))), child: Stack(fit: StackFit.expand, children: [
            AnimatedOpacity(opacity: widget.pray && poseImg != null ? 0 : 1, duration: const Duration(milliseconds: 700), child: Image.asset(cat.charImage(r.char, r.outfitNow), fit: BoxFit.contain, alignment: Alignment.bottomCenter)),
            if (poseImg != null) AnimatedOpacity(opacity: widget.pray ? 1 : 0, duration: const Duration(milliseconds: 700), child: Image.asset(poseImg, fit: BoxFit.contain, alignment: Alignment.bottomCenter)),
          ]))))),
      // ── 감쇠 비네트 · 황금빛 ──
      Positioned.fill(child: IgnorePointer(child: AnimatedOpacity(duration: const Duration(milliseconds: 1400), opacity: (math.max(0, 1 - bright) * 1.2).clamp(0, 1).toDouble(),
        child: const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.16), radius: .8, colors: [Colors.transparent, Color(0x99050208)])))))),
      if (widget.gold > 0) Positioned.fill(child: IgnorePointer(child: AnimatedOpacity(duration: const Duration(milliseconds: 1600), opacity: widget.gold,
        child: const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.1), radius: .9, colors: [Color(0xD9FFD778), Color(0x4DF5A050), Colors.transparent], stops: [0, .6, 1])))))),
      // ── L8 FX ──
      ...widget.fx,
    ])));
  }

  Widget _glow(double cx, double cy, double rad, Color c, Animation<double> a) => Positioned(left: cx - rad, top: cy - rad, child: IgnorePointer(child: FadeTransition(opacity: Tween(begin: .7, end: 1.0).animate(a),
      child: Container(width: rad * 2, height: rad * 2, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, Colors.transparent], stops: const [0, .64]))))));

  List<Widget> _ceilingStars(int n) { final rnd = math.Random(13); return List.generate(n, (i) { final s = 2.0 + (i % 3) * 1.5;
    return Positioned(left: 16 + rnd.nextDouble() * 356, top: 44.0 + (i * 29) % 110, child: FadeTransition(opacity: Tween(begin: .3, end: 1.0).animate(CurvedAnimation(parent: pulse, curve: Interval((i % 5) / 10, 1))),
      child: Container(width: s, height: s, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFF6D0), boxShadow: [BoxShadow(color: Color(0xFFFFD070), blurRadius: 8)])))); }); }

  Widget _stand(String asset, double x, double y, double s, {bool sway = false}) => Positioned(left: x - s / 2, top: y - s, width: s, height: s,
      child: Image.asset(asset, fit: BoxFit.contain, alignment: Alignment.bottomCenter));

  Widget _deco(PlacedDeco d) {
    if (d.item.slot == Slot.SEAL) return Positioned(left: d.x - d.s / 2, top: d.y - d.s, child: _Seal(text: d.item.hanja ?? '願', color: _hex(d.item.color ?? '#c94a3b'), size: d.s));
    final asset = d.item.asset;
    final child = asset != null ? Image.asset(asset, width: d.s, height: d.s, fit: BoxFit.contain) : Text(d.item.glyph ?? '✦', style: TextStyle(fontSize: d.s * .7));
    switch (d.kind) {
      case 'hang': return Positioned(left: d.x - d.s / 2, top: d.y, child: AnimatedBuilder(animation: breathe, builder: (_, c) => Transform.rotate(alignment: Alignment.topCenter, angle: .05 * (breathe.value - .5), child: c),
          child: Column(children: [Container(width: 1.5, height: d.len, color: const Color(0xCCFFD28C)), child])));
      case 'float': return Positioned(left: d.x - d.s / 2, top: d.y - d.s / 2, child: AnimatedBuilder(animation: breathe, builder: (_, c) => Transform.translate(offset: Offset(0, -6 * breathe.value), child: c), child: child));
      default: return Positioned(left: d.x - d.s / 2, top: d.y - d.s, child: child);
    }
  }

  Widget _unlockObj(Map it) {
    final s = (it['s'] as num).toDouble(), x = (it['x'] as num).toDouble(), y = (it['y'] as num).toDouble();
    final img = Image.asset('assets/wishroom/items/${it['img']}.png', width: s, height: s);
    if (it['kind'] == 'hang') return Positioned(left: x - s / 2, top: y, child: Column(children: [Container(width: 1.5, height: (it['len'] as num).toDouble(), color: const Color(0xCCFFD28C)), img]));
    if (it['kind'] == 'float') return Positioned(left: x - s / 2, top: y - s / 2, child: img);
    return Positioned(left: x - s / 2, top: y - s, child: img);
  }
}

/// 자유 테마의 둥근 창 — BACKGROUND 아이템의 창밖 그림(win) 또는 기본 밤하늘, tint 로 방 조명 색
class _WindowView extends StatelessWidget {
  final WrItem? bg; final double light; const _WindowView({required this.bg, required this.light});
  @override Widget build(BuildContext context) {
    final win = bg?.raw('win') as String?; final tint = bg?.raw('tint') as String?;
    return Stack(children: [
      if (win != null) Positioned(left: RoomLayout.windowCx - RoomLayout.windowR, top: RoomLayout.windowCy - RoomLayout.windowR,
        child: ClipOval(child: Image.asset('assets/wishroom/${win.replaceFirst('assets/', '')}', width: RoomLayout.windowR * 2, height: RoomLayout.windowR * 2, fit: BoxFit.cover))),
      if (tint != null) Positioned.fill(child: IgnorePointer(child: ColoredBox(color: _rgba(tint)))),
    ]);
  }
}

class _Seal extends StatelessWidget { final String text; final Color color; final double size; const _Seal({required this.text, required this.color, required this.size});
  @override Widget build(BuildContext c) => Transform.rotate(angle: -6 * math.pi / 180, child: Container(width: size, height: size, alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6), boxShadow: [BoxShadow(color: color.withValues(alpha: .55), blurRadius: 8)]),
      child: Text(text, style: TextStyle(fontFamily: 'Noto Serif KR', fontWeight: FontWeight.w900, fontSize: size * .55, color: const Color(0xFFFFF9E8))))); }

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

List<double> _brightness(double b) => [b, 0, 0, 0, 0, 0, b, 0, 0, 0, 0, 0, b, 0, 0, 0, 0, 0, 1, 0];
Color _hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));
Color _rgba(String s) { final m = RegExp(r'rgba?\(([^)]+)\)').firstMatch(s); if (m == null) return Colors.transparent; final p = m.group(1)!.split(',').map((e) => double.parse(e.trim())).toList();
  return Color.fromRGBO(p[0].round(), p[1].round(), p[2].round(), p.length > 3 ? p[3] : 1); }

extension on WrItem { Object? raw(String k) => WrCatalog.I.raw['ITEMS'].firstWhere((e) => e['id'] == id)[k]; }
