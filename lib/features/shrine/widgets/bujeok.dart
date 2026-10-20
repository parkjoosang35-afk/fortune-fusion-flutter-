// 괴황지 부적 v4 — 초서 한 줄. 좌표는 assets/shrine/data/shrine.json 의 "bujeokLayout" 하나에서만 온다.
// 웹 bujeok-layout.js(window.BJ_LAYOUT)와 같은 객체 · 같은 수식 → 웹 화면 = 웹 PNG = 앱 화면 = 앱 PNG.
//
// 좌표 규칙 (웹 bjPaintInk / bjPaint 와 1:1)
//  종이 W × H (H = W × 41/22)
//  글자 영역: ix = W·side, iy = H·top, iw = W(1−2·side), ih = H(1−top−bottom)
//  글자: 원점 → (ix + iw·x/100, iy + ih·y/100) → scale(sx, sy) → rotate(rot°)
//        글자 크기 fs = ih·s/100, 가로 가운데 정렬, 기준선 = 원점 + baseline·fs   ← 폰트 ascent 와 무관하게 웹과 같은 자리
//        외곽선 폭 = stroke·ih (로컬 좌표) → 외곽선 먼저, 채움 나중 (서명은 채움만)
//  획:   inner 를 100×100 으로 scale 한 뒤 3차 베지어, 선폭 w (같은 100 단위)
//  진행: p = clamp(ink·inkSteps − o) — 글자는 위에서 높이 fs·1.1·p 만큼 클립, 획은 길이 × p
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../engine/shrine_engine.dart';

Color _css(String s) {
  s = s.trim();
  if (s.startsWith('#')) { final h = s.substring(1); return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16)); }
  final m = RegExp(r'rgba?\(([^)]+)\)').firstMatch(s)!; final v = m.group(1)!.split(',').map((e) => double.parse(e.trim())).toList();
  return Color.fromRGBO(v[0].round(), v[1].round(), v[2].round(), v.length > 3 ? v[3] : 1);
}
double _d(dynamic v) => (v as num).toDouble();

/// shrine.json "bujeokLayout" — main() 에서 Shrine.load() 후 BujeokLayout.init(json['bujeokLayout'])
class BujeokLayout {
  static late Map L;
  static void init(Map json) => L = json;
}

class _Item { final bool path; final String c; final double x, y, s, sx, sy, o, rot, w; final bool sign; final List pts;
  _Item.g(this.c, this.x, this.y, this.s, this.sx, this.sy, this.o, this.rot, {this.sign = false}) : path = false, w = 0, pts = const [];
  _Item.p(this.pts, this.w, this.o) : path = true, c = '', x = 0, y = 0, s = 0, sx = 1, sy = 1, rot = 0, sign = false; }

/// 웹 bjResolve 와 같은 해석 규칙
List<_Item> resolveBujeok({required String name, required String sig, required String base, String? phrase, String? motif, String? type}) {
  final L = BujeokLayout.L;
  // v5: 유형별 형(form) — 머리 글자 · 몸통 배치 · 꼬리가 부적마다 다르다
  final Map F = (L['forms'] as Map?)?[type] ?? (L['forms'] as Map?)?['love'] ?? L; final simp = Map<String, String>.from(L['simp']);
  String sv(String c) => simp[c] ?? c;
  final ph = (phrase != null && phrase.characters.length == 2) ? phrase.characters.toList() : List<String>.from(L['defaultPhrase']);
  final slot = {'phrase0': ph[0], 'phrase1': ph[1], 'sig': sig, 'motif': motif ?? L['defaultMotif'], 'base': base};
  final jit = (L['jitter'] as List).map(_d).toList(); final jm = _d(L['jitterMul']);
  double rot(int k) => jit[k % 10] * jm;
  final out = <_Item>[
    for (final g in F['glyphs'] as List) _Item.g(sv(g['slot'] != null ? slot[g['slot']]! : g['c']), _d(g['x']), _d(g['y']), _d(g['s']), _d(g['sx']), _d(g['sy']), _d(g['o']), rot(g['k'])),
    for (final p in F['paths'] as List) _Item.p(p['pts'], _d(p['w']), _d(p['o'])),
  ];
  final N = L['name']; final nm = name.characters.take(N['max']).toList();
  final nH = nm.isEmpty ? 0.0 : math.min(_d(N['maxH']), _d(N['total']) / nm.length);
  for (var j = 0; j < nm.length; j++) {
    out.add(_Item.g(nm[j], _d(N['x']), _d(N['y0']) + j * nH, nH * _d(N['sizeK']), _d(N['sx']), _d(N['sy']), _d(N['o0']) + j * _d(N['dO']), rot(N['k0'] + j), sign: true));
  }
  return out;
}

TextStyle _font(bool sign, double fs, Color c) {
  final F = BujeokLayout.L['fonts'];
  return sign ? GoogleFonts.getFont(F['sign'], fontSize: fs, color: c, height: 1)
              : GoogleFonts.getFont(F['cursive'], fontSize: fs, color: c, height: 1);
}

/// 글자·획만 (종이 없이). 의식 화면에서 영상 위 종이 영역에 겹칠 때 사용
void paintBujeokInk(Canvas c, Size sz, {required String name, required String sig, required String base, String? phrase, String? motif, String? type, double ink = 1}) {
  final L = BujeokLayout.L, I = L['inset']; final W = sz.width, H = sz.height;
  final ix = W * _d(I['side']), iy = H * _d(I['top']), iw = W * (1 - 2 * _d(I['side'])), ih = H * (1 - _d(I['top']) - _d(I['bottom']));
  final wk = _d(((L['weight'] as Map?)?[type]) ?? 1);   // 유형별 굵기
  final steps = _d(L['inkSteps']), strokeK = _d(L['stroke']) * wk, baseK = _d(L['baseline']);
  final inkC = _css(L['color']['ink']), signC = _css(L['color']['sign']), glowC = _css(L['color']['glow']); final glowB = W * _d(L['color']['glowBlur']);
  for (final it in resolveBujeok(name: name, sig: sig, base: base, phrase: phrase, motif: motif, type: type)) {
    final p = (ink * steps - it.o).clamp(0.0, 1.0); if (p <= 0) continue;
    if (it.path) {
      final path = Path(); final p0 = it.pts[0] as List; path.moveTo(_d(p0[0]), _d(p0[1]));
      for (final q in it.pts.skip(1)) { final b = (q as List).map(_d).toList(); path.cubicTo(b[0], b[1], b[2], b[3], b[4], b[5]); }
      Path drawn = path;
      if (p < 1) { final ms = path.computeMetrics().toList(); final total = ms.fold<double>(0, (a, m) => a + m.length); var left = total * p; drawn = Path();
        for (final m in ms) { if (left <= 0) break; drawn.addPath(m.extractPath(0, math.min(left, m.length)), Offset.zero); left -= m.length; } }
      c.save(); c.translate(ix, iy); c.scale(iw / 100, ih / 100);
      c.drawPath(drawn, Paint()..color = inkC..style = PaintingStyle.stroke..strokeWidth = it.w * wk..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
      c.restore(); continue;
    }
    final fs = ih * it.s / 100; final col = it.sign ? signC : inkC;
    final fill = TextPainter(text: TextSpan(text: it.c, style: _font(it.sign, fs, col).copyWith(shadows: [Shadow(color: glowC, blurRadius: glowB)])), textDirection: TextDirection.ltr)..layout();
    final asc = fill.computeDistanceToActualBaseline(TextBaseline.alphabetic);   // 이 폰트의 실제 기준선
    final dy = fs * baseK - asc;                                                // → 웹과 같은 기준선 위치로 이동
    c.save(); c.translate(ix + iw * it.x / 100, iy + ih * it.y / 100); c.scale(it.sx, it.sy); c.rotate(it.rot * math.pi / 180);
    if (p < 1) c.clipRect(Rect.fromLTWH(-fs * 1.5, -fs * .05, fs * 3, fs * 1.1 * p));
    if (!it.sign) {
      final st = TextPainter(text: TextSpan(text: it.c, style: _font(false, fs, col).copyWith(foreground: Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = strokeK * ih..strokeJoin = StrokeJoin.round)), textDirection: TextDirection.ltr)..layout();
      st.paint(c, Offset(-st.width / 2, dy));
    }
    fill.paint(c, Offset(-fill.width / 2, dy));
    c.restore();
  }
}

/// 종이 + 테두리 + 글자 + 인장 + 번호 (웹 bjPaint 와 1:1)
void paintBujeok(Canvas c, Size sz, {required String name, required TalismanSpec spec, double ink = 1, String? serial, bool shadow = false}) {
  final L = BujeokLayout.L, S = L['sheet']; final W = sz.width, H = sz.height; final rect = Offset.zero & sz;
  final pap = ((S['paper'][spec.paper] ?? S['paper']['gold']) as List).map((e) => _css(e)).toList();
  if (shadow) c.drawRect(rect.shift(Offset(0, W * .04)), Paint()..color = const Color(0x8C000000)..maskFilter = MaskFilter.blur(BlurStyle.normal, W * .045));
  c.save(); c.clipRect(rect);
  c.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: pap).createShader(rect));
  final gp = Paint()..color = _css(S['grain']['color']); final every = W * _d(S['grain']['every']);
  for (double x = 0; x < W; x += every) { c.drawRect(Rect.fromLTWH(x, 0, math.max(1, W / 700), H), gp); }
  final V = S['vignette']; final ctr = Offset(W * _d(V['cx']), H * _d(V['cy']));
  c.drawRect(rect, Paint()..shader = ui.Gradient.radial(ctr, H * _d(V['r']), [const Color(0x00000000), const Color(0x00000000), _css(V['color'])], [0, _d(V['from']), 1]));
  _border(c, W, H, spec.border);
  paintBujeokInk(c, sz, name: name, sig: spec.sig, base: spec.base, phrase: spec.phrase, motif: spec.motif, type: spec.type, ink: ink);
  // 인장
  final K = S['seal']; final s = W * _d(K['size']); final cx = W * (1 - _d(K['right'])) - s / 2, cy = H * (1 - _d(K['bottom'])) - s / 2;
  c.save(); c.translate(cx, cy); c.rotate(_d(K['rot']) * math.pi / 180);
  final sp = Paint()..color = _css(K['color'])..style = PaintingStyle.stroke..strokeWidth = math.max(1, W * _d(K['width']));
  switch (spec.seal) {
    case 'round': c.drawCircle(Offset.zero, s / 2, sp); break;
    case 'gourd': c.drawOval(Rect.fromCenter(center: Offset(0, -s * .2), width: s * .6, height: s * .56), sp); c.drawOval(Rect.fromCenter(center: Offset(0, s * .2), width: s * .84, height: s * .64), sp); break;
    default: c.drawRect(Rect.fromCenter(center: Offset.zero, width: s, height: s), sp);
  }
  final tp = TextPainter(text: TextSpan(text: spec.sig, style: GoogleFonts.getFont(L['fonts']['seal'], fontSize: s * _d(K['font']), fontWeight: FontWeight.w900, color: _css(K['text']))), textDirection: TextDirection.ltr)..layout();
  tp.paint(c, Offset(-tp.width / 2, -tp.height / 2 + (spec.seal == 'gourd' ? s * .16 : s * .04)));
  c.restore();
  // 번호
  if (serial != null) {
    final N = S['serial'];
    final t = TextPainter(text: TextSpan(text: serial, style: GoogleFonts.getFont(L['fonts']['serial'], fontSize: math.max(_d(N['minSize']), W * _d(N['size'])), fontWeight: FontWeight.w500, color: _css(N['color']))), textDirection: TextDirection.ltr)..layout();
    t.paint(c, Offset(W * _d(N['left']), H * _d(N['baseline']) - t.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
  }
  c.restore();
}

void _border(Canvas c, double W, double H, String kind) {
  final B = BujeokLayout.L['sheet']['border']; final m = W * _d(B['inset']);
  final pt = Paint()..color = _css(B['color'])..style = PaintingStyle.stroke..strokeWidth = math.max(_d(B['minWidth']), W * _d(B['width']));
  c.drawRect(Rect.fromLTWH(m, m, W - 2 * m, H - 2 * m), pt);
  if (kind == 'double') { final k = m * (1 + _d(B['inner'])); c.drawRect(Rect.fromLTWH(k, k, W - 2 * k, H - 2 * k), Paint()..color = pt.color..style = PaintingStyle.stroke..strokeWidth = math.max(1, W * _d(B['innerWidth']))); }
  if (kind == 'cloud') { final r = W * _d(B['cloudR']); for (double x = m + r; x < W - m; x += r * 2) {
    c.drawArc(Rect.fromCircle(center: Offset(x, m), radius: r), math.pi, math.pi, false, pt);
    c.drawArc(Rect.fromCircle(center: Offset(x, H - m), radius: r), 0, math.pi, false, pt); } }
  if (kind == 'thunder') { final t = W * _d(B['thunder']); final path = Path();
    for (double x = m; x < W - m - t; x += t * 2) { path..moveTo(x, m + t)..lineTo(x + t, m + t)..lineTo(x + t, m + t * .2)..moveTo(x, H - m - t)..lineTo(x + t, H - m - t)..lineTo(x + t, H - m - t * .2); }
    c.drawPath(path, pt); }
}

class _InkPainter extends CustomPainter {
  final String name, sig, base; final String? phrase, motif, type; final double ink;
  _InkPainter(this.name, this.sig, this.base, this.phrase, this.motif, this.ink, [this.type]);
  @override void paint(Canvas c, Size s) => paintBujeokInk(c, s, name: name, sig: sig, base: base, phrase: phrase, motif: motif, type: type, ink: ink);
  @override bool shouldRepaint(_InkPainter o) => o.ink != ink || o.name != name || o.phrase != phrase || o.sig != sig;
}
class _SheetPainter extends CustomPainter {
  final String name; final TalismanSpec spec; final double ink; final String? serial;
  _SheetPainter(this.name, this.spec, this.ink, this.serial);
  @override void paint(Canvas c, Size s) => paintBujeok(c, s, name: name, spec: spec, ink: ink, serial: serial);
  @override bool shouldRepaint(_SheetPainter o) => o.ink != ink || o.name != name || o.spec.key != spec.key || o.serial != serial;
}

/// 의식 화면: TalismanStage 의 종이 영역(부모 크기)에 글자만
class BujeokInk extends StatelessWidget {
  final String name; final TalismanSpec spec; final double ink;
  const BujeokInk({super.key, required this.name, required this.spec, this.ink = 1});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.infinite, painter: _InkPainter(name, spec.sig, spec.base, spec.phrase, spec.motif, ink, spec.type));
}

/// 소지부 한 장 (부적 받기 · 부적함 · 결과 · 선택의 의미)
class BujeokSheet extends StatelessWidget {
  final double w; final String name; final TalismanSpec spec; final double ink; final String? serial;
  const BujeokSheet({super.key, required this.w, required this.name, required this.spec, this.ink = 1, this.serial});
  @override
  Widget build(BuildContext context) {
    final r = BujeokLayout.L['ratio'] as List;
    return DecoratedBox(decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 14))]),
      child: CustomPaint(size: Size(w, w * _d(r[1]) / _d(r[0])), painter: _SheetPainter(name, spec, ink, serial)));
  }
}

/// 저장용 1080×1920 PNG — 웹 bjSavePNG 와 같은 배치. 생년월일 없음.
Future<Uint8List> renderBujeokPng({required String name, required TalismanSpec spec, required String serial, required String title, required String line, String? sub}) async {
  const W = 1080.0, H = 1920.0, sw = 620.0; final r = BujeokLayout.L['ratio'] as List; final sh = sw * _d(r[1]) / _d(r[0]);
  final rec = ui.PictureRecorder(); final c = Canvas(rec, const Rect.fromLTWH(0, 0, W, H));
  c.drawRect(const Rect.fromLTWH(0, 0, W, H), Paint()..shader = ui.Gradient.radial(const Offset(W / 2, H * .38), H * .8, const [Color(0xFF2A0D0B), Color(0xFF070404)]));
  c.save(); c.translate((W - sw) / 2, 130); paintBujeok(c, Size(sw, sh), name: name, spec: spec, serial: serial, shadow: true); c.restore();
  void txt(String s, TextStyle st, double baseline) { final tp = TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr)..layout(maxWidth: W - 120);
    tp.paint(c, Offset((W - tp.width) / 2, baseline - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic))); }
  final ty = 130 + sh;   // 웹과 같은 기준선 값 (ty+80 · +158 · +214 · +262)
  txt('${spec.phrase.characters.join(' ')}  ·  神 堂', GoogleFonts.ibmPlexMono(fontSize: 22, fontWeight: FontWeight.w500, color: const Color(0xFFC9A368)), ty + 80);
  txt(title, GoogleFonts.notoSerifKr(fontSize: 58, fontWeight: FontWeight.w900, color: const Color(0xFFEFE4D2)), ty + 158);
  txt(line, GoogleFonts.gowunBatang(fontSize: 30, color: const Color(0x9EEFE4D2)), ty + 214);
  if (sub != null) txt(sub, GoogleFonts.gowunBatang(fontSize: 24, color: const Color(0x66EFE4D2)), ty + 262);
  txt('신당', GoogleFonts.eastSeaDokdo(fontSize: 64, color: const Color(0xFFF4EBDE)), H - 60);
  final img = await rec.endRecording().toImage(W.toInt(), H.toInt());
  return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}
