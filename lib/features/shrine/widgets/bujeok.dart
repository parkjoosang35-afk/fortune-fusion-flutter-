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
import '../theme/tokens.dart';

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

// ═══════ U3 — 조각 조합 부적(bjCompose) : 웹 bujeok-combo.js 1:1 포팅 ═══════
// 부적 한 장을 통째로 그리지 않는다. 진짜 부적을 쓰는 순서대로 조각을
// 골라 쌓는다(12단계 — 머리 → 지붕+기둥 → 몸통 1·2 → 문구① → 지붕②
// → 몸통 3·4 → 문구② → 오행 줄 → 바닥 글자 → 꼬리 → 이음 → 이름 서명).
// 조각은 전부 shrine.json 의 bujeokLayout.pool(검수된 목록)에서만 고른다
// — 무작위 한자 금지. 씨앗 = 부적 조건키(종류|성향|이야기|결말) + 이름 +
// 일련번호 → fnv32 해시 → mulberry32 결정론적 난수. 같은 사람·같은 조건이면
// 같은 부적(재열람), 이름이나 조건이 다르면 다른 부적이 된다.

/// 32비트 부호 없는 정수 곱셈(JS Math.imul 과 동일 결과). 상위/하위 16비트로
/// 쪼개 계산해 중간값이 2^53(double 안전 정수 한계)을 넘지 않도록 한다 —
/// 그대로 곱하면 dart2js(웹 빌드)에서 정밀도가 깨져 웹 프로토타입과 다른
/// 난수가 나올 수 있다.
int _imul32(int a, int b) {
  final au = a & 0xFFFFFFFF, bu = b & 0xFFFFFFFF;
  final ah = (au >> 16) & 0xFFFF, al = au & 0xFFFF;
  final bh = (bu >> 16) & 0xFFFF, bl = bu & 0xFFFF;
  final low = al * bl;
  final cross = (ah * bl + al * bh) & 0xFFFFFFFF;
  return (low + cross * 0x10000) & 0xFFFFFFFF;
}

/// 웹 bujeok-combo.js 의 fnv(문자열 → 32비트 해시). shrine_engine.dart 의
/// 최상위 fnv()는 h*16777619 가 2^53 을 넘어설 수 있어(웹에서 정밀도 손실
/// 위험) bjCompose 전용으로 _imul32 기반의 안전한 버전을 별도로 둔다.
int _bjFnv(String s) {
  var h = 2166136261;
  for (final c in s.codeUnits) {
    h ^= c;
    h = _imul32(h, 16777619);
  }
  return h & 0xFFFFFFFF;
}

/// 웹 mulberry32(a) — 시드 1개로 0~1 사이 결정론적 난수를 계속 뽑는 클로저.
double Function() _mulberry32(int seed) {
  var a = seed & 0xFFFFFFFF;
  return () {
    a = (a + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _imul32(a ^ (a >> 15), 1 | a);
    t = ((t + _imul32(t ^ (t >> 7), 61 | t)) ^ t) & 0xFFFFFFFF;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0;
  };
}

T _bjPick<T>(double Function() r, List<T> arr) => arr[(r() * arr.length).floor() % arr.length];
double _bjJit(double Function() r, double a) => (r() * 2 - 1) * a;

/// 첫 · 둘째 지붕획 (inner 100×100, 3차 베지어)
List<List<double>> _bjRoofPath(String kind, double y, double x0, double x1, double Function() r) {
  final d = _bjJit(r, .8);
  switch (kind) {
    case 'dip':
      return [[x0, y + 1.2], [x0 + 20, y - .6 + d, x1 - 25, y + .8, x1, y - .4]];
    case 'hook':
      return [[x0, y], [x0 + 25, y - .8 + d, x1 - 15, y - .6, x1 - 3, y], [x1 + 1, y + .2, x1 + 1, y + 1.6, x1 - 2, y + 2.6]];
    case 'sweep':
      return [[x0 - 2, y + 2.2], [x0 + 10, y - .4, x1 - 30, y - 1.2 + d, x1 + 1, y + .6]];
    default:
      return [[x0, y + .3], [x0 + 30, y - .5 + d, x1 - 30, y + .4, x1, y]];
  }
}

/// 기둥 (직선 · 꺾임 · 겹획)
List<List<List<double>>> _bjPillarPaths(String kind, double x, double y0, double y1, double Function() r) {
  final out = <List<List<double>>>[
    [[x, y0], [x - 1.5, y0 + (y1 - y0) * .35, x + .5 + _bjJit(r, 1), y0 + (y1 - y0) * .7, x - 3, y1]],
  ];
  if (kind == 'bend') { out[0] = [[x, y0], [x + 1, y0 + (y1 - y0) * .5, x - 4, y1 - 3, x - 6, y1]]; }
  if (kind == 'double') { out.add([[x + 3.5, y0 + 2], [x + 3, y0 + (y1 - y0) * .5, x + 3.6, y1 - 4, x + 2, y1 - 1]]); }
  return out;
}

List<List<double>> _bjDot(double x, double y) => [[x - .8, y - .4], [x, y - .9, x + 1.2, y + .1, x + .4, y + .9]];

/// 꼬리 획 — 결말 A 두 갈래 실 · B 곧은 획+세 점 · C 고리 · D 물결 /
/// 추가 이야기 4종(fork·hook·zigzag·double)
List<List<List<double>>> _bjTailPaths(String kind, double y0, double Function() r) {
  final cx = 48 + _bjJit(r, 2), e = 99.0;
  switch (kind) {
    case 'twin':
      return [[[cx - 2, y0], [cx - 7, y0 + 3, cx + 4, y0 + 6, cx - 3, e]], [[cx + 2, y0], [cx + 7, y0 + 3, cx - 4, y0 + 6, cx + 4, e - 1]]];
    case 'dots':
      return [[[cx, y0], [cx + 1, y0 + 3, cx - 1, y0 + 6, cx, e - 3]], _bjDot(cx - 9, y0 + 3), _bjDot(cx + 9, y0 + 4.5), _bjDot(cx - 8, y0 + 7)];
    case 'loop':
      return [[[cx, y0], [cx + 12, y0 + 2, cx + 10, y0 + 6.5, cx, y0 + 6], [cx - 9, y0 + 5.6, cx - 6, y0 + 2.6, cx + 1, y0 + 3.4], [cx + 6, y0 + 4.4, cx + 2, y0 + 8, cx - 1, e]]];
    case 'wave':
      return [[[cx, y0], [cx - 8, y0 + 2, cx + 8, y0 + 4, cx, y0 + 5.5], [cx - 7, y0 + 7, cx + 6, y0 + 8.4, cx + 1, e]]];
    case 'fork':
      return [[[cx, y0], [cx, y0 + 3, cx, y0 + 5, cx, y0 + 6]], [[cx, y0 + 5], [cx - 4, y0 + 6.5, cx - 8, y0 + 8, cx - 10, e - 1]], [[cx, y0 + 5], [cx, y0 + 7, cx, y0 + 8, cx, e]], [[cx, y0 + 5], [cx + 4, y0 + 6.5, cx + 8, y0 + 8, cx + 10, e - 1]]];
    case 'hook':
      return [[[cx, y0], [cx + 1, y0 + 4, cx, y0 + 7, cx - 1, e - 1.5], [cx - 1.5, e, cx - 6, e, cx - 8, e - 2.5]]];
    case 'zigzag':
      return [[[cx, y0], [cx + 4, y0 + 1.5, cx + 6, y0 + 2.5, cx - 5, y0 + 4.5], [cx - 1, y0 + 5.5, cx + 7, y0 + 6.5, cx - 4, y0 + 8.5], [cx - 1, y0 + 9, cx + 2, y0 + 9.5, cx + 1, e]]];
    default:
      return [[[cx - 2, y0], [cx - 3, y0 + 4, cx - 1, y0 + 7, cx - 2, e]], [[cx + 2.5, y0 + .5], [cx + 3.5, y0 + 4, cx + 1.5, y0 + 7, cx + 2.5, e - 1]]];
  }
}

/// 조합 결과의 "요약표" — 설명서/부적 뒷면(U9 TalisBack)에 쓸 조합 ID 포함
class BjRecipe {
  final String head, phrase, element, base, tail, tailName, roofName, pillar, spine, id;
  final List<String> rows;
  final List<String> roof;
  const BjRecipe({
    required this.head, required this.rows, required this.phrase, required this.element,
    required this.base, required this.tail, required this.tailName, required this.roof,
    required this.roofName, required this.pillar, required this.spine, required this.id,
  });
}

class BjComposeResult {
  final List<_Item> items;
  final double steps;
  final BjRecipe recipe;
  const BjComposeResult(this.items, this.steps, this.recipe);
}

/// 웹 bjCompose(opts) 1:1 포팅. TalismanSpec 의 조건 필드(type·key·flavor·
/// story·ending·element·base·motif·phrase) + 부적을 받는 사람의 name·serial
/// 을 그대로 받는다 — 새로운 명리/난수 로직이 아니라 웹과 똑같은 알고리즘.
BjComposeResult bjCompose({
  required String type,
  String? phrase,
  String? key,
  String? flavor,
  String? story,
  String? ending,
  String? element,
  String? base,
  String? motif,
  String? name,
  String? serial,
}) {
  final L = BujeokLayout.L;
  final pool = L['pool'] as Map;
  final headPool = pool['head'] as Map;
  final rowsPool = pool['rows'] as Map;
  final roofPool = List<String>.from(pool['roof']);
  final pillarPool = List<String>.from(pool['pillar']);
  final spinePool = List<String>.from(pool['spine']);
  final tailPool = pool['tail'] as Map;
  final tailNamePool = Map<String, String>.from(pool['tailName']);
  final roofNamePool = Map<String, String>.from(pool['roofName']);
  final elementsPool = List<String>.from(pool['elements']);
  final simp = Map<String, String>.from(L['simp']);

  final resolvedType = headPool.containsKey(type) ? type : 'love';
  final ph = (phrase != null && phrase.characters.length == 2)
      ? phrase.characters.toList()
      : (List<String>.from(L['defaultPhrase']).join('')).characters.toList();
  final seedKey = [
    key ?? [resolvedType, flavor ?? '', story ?? '', ending ?? ''].join('|'),
    name ?? '',
    serial ?? '',
  ].join('#');
  final seedHash = _bjFnv(seedKey);
  final r = _mulberry32(seedHash);
  String s(String c) => simp[c] ?? c;

  final headChars = _bjPick<List<String>>(
      r, (headPool[resolvedType] as List).map((e) => List<String>.from(e as List)).toList());
  final rowsAll = List<String>.from(rowsPool[resolvedType] as List);
  for (var i = rowsAll.length - 1; i > 0; i--) {
    final j = (r() * (i + 1)).floor();
    final tmp = rowsAll[i]; rowsAll[i] = rowsAll[j]; rowsAll[j] = tmp;
  }
  final rows = rowsAll.sublist(0, 4);
  if (motif != null && motif.characters.length == 1) rows[3] = motif + motif;
  final roof1 = _bjPick(r, roofPool);
  final roof2 = _bjPick(r, roofPool);
  final pillar = _bjPick(r, pillarPool);
  final spine = _bjPick(r, spinePool);
  final el = elementsPool.contains(element) ? element! : _bjPick(r, elementsPool);
  final tailExtra = List<String>.from(tailPool['extra'] as List);
  final tail = (ending != null && tailPool.containsKey(ending) && (story == null || story == 'red-bell'))
      ? tailPool[ending] as String
      : _bjPick(r, tailExtra);
  final baseChar = base ?? '鬼';
  final cx = 46 + _bjJit(r, 1.5);

  final items = <_Item>[];
  var o = 0.0;
  void g(String c, double x, double y, double size, double sx, double sy, {String font = 'cur'}) {
    items.add(_Item.g(font == 'cur' ? s(c) : c, x, y, size, sx, sy, o, _bjJit(r, 2.6), sign: font == 'sign'));
  }
  void p(List<List<double>> pts, double w) => items.add(_Item.p(pts, w, o));
  void row(String str, double y, double size) {
    final cs = str.characters.toList();
    final n = cs.length;
    final sx = n >= 3 ? 1.12 : 1.4;
    final gw = size * sx * 2.4;
    final tot = gw * n * .86;
    final x0 = cx - tot / 2 + gw * .43;
    for (var i = 0; i < cs.length; i++) {
      g(cs[i], x0 + i * gw * .86 + _bjJit(r, .8), y + _bjJit(r, .5), size, sx, .8);
    }
  }

  // 1 머리 — 크게
  if (headChars.length == 1) {
    g(headChars[0], cx, 0, 13.5, 1.9, .8);
  } else {
    g(headChars[0], cx - 17, .4, 11.5, 1.45, .8);
    g(headChars[1], cx + 17, .4, 11.5, 1.45, .8);
  }
  o++;
  // 2 지붕 + 기둥 (굵게)
  p(_bjRoofPath(roof1, 11.4, 6, 95, r), 2.9);
  for (final pt in _bjPillarPaths(pillar, 8, 11.8, 40.5, r)) { p(pt, 2.6); }
  o++;
  // 3 몸통 1·2 — 폭을 꽉 채우게
  row(rows[0], 12.6, 9.4); o++;
  row(rows[1], 20.4, 9.4); o++;
  // 4 문구 첫 글자 — 틀 안을 가득
  g(ph[0], cx + 3, 28, 13.5, 2.0, .8); o++;
  // 5 둘째 지붕
  p(_bjRoofPath(roof2, 40.2, 10, 93, r), 2.8);
  for (final pt in _bjPillarPaths(pillar == 'double' ? 'straight' : pillar, 12, 40.6, 69, r)) { p(pt, 2.5); }
  o++;
  // 6 몸통 3·4
  row(rows[2], 41.4, 9.2); o++;
  row(rows[3], 49.0, 9.2); o++;
  // 7 문구 둘째 글자
  g(ph[1], cx + 3, 56.6, 13.5, 2.0, .8); o++;
  // 8 오행 줄
  row(el + el + el, 69.4, 6.6); o++;
  // 9 바닥 글자 — 가장 크게 눌러 씀
  g(baseChar, cx - 4, 75, 13, 2.0, .8); o++;
  // 10 꼬리
  for (final pt in _bjTailPaths(tail, 86.6, r)) { p(pt, tail == 'dots' ? 2.4 : 2.6); }
  o++;
  // 11 이음
  if (spine == 'line') p([[cx + 1, 26.4], [cx, 27, cx + 2, 27.6, cx + 1, 28.2]], 2);
  if (spine == 'dots') { p(_bjDot(cx - 36, 33), 2.2); p(_bjDot(cx + 38, 62), 2.2); }
  p(_bjDot(cx + 40, 2.5 + _bjJit(r, 1)), 2.2);
  o++;
  // 12 이름 서명 — 오른쪽 아래 세로
  final nm = (name ?? '').characters.take(4).toList();
  final nH = nm.isEmpty ? 0.0 : math.min(5.4, 16 / nm.length);
  for (var j = 0; j < nm.length; j++) {
    items.add(_Item.g(nm[j], 89, 72 + j * nH, nH * 1.05, 1, 1, o + j * .25, _bjJit(r, 2), sign: true));
  }
  o += 1;

  final base36 = seedHash.toRadixString(36).toUpperCase();
  final recipe = BjRecipe(
    head: headChars.join(''), rows: rows, phrase: ph.join(''), element: el + el + el, base: baseChar,
    tail: tail, tailName: tailNamePool[tail] ?? tail, roof: [roof1, roof2], roofName: roofNamePool[roof1] ?? roof1,
    pillar: pillar, spine: spine,
    id: 'BJ6-${base36.length > 7 ? base36.substring(0, 7) : base36}',
  );
  return BjComposeResult(items, o + .5, recipe);
}


TextStyle _font(bool sign, double fs, Color c) {
  final F = BujeokLayout.L['fonts'];
  return sign ? GoogleFonts.getFont(F['sign'], fontSize: fs, color: c, height: 1)
              : GoogleFonts.getFont(F['cursive'], fontSize: fs, color: c, height: 1);
}

/// 글자·획만 (종이 없이). 의식 화면에서 영상 위 종이 영역에 겹칠 때 사용.
/// U3: 단일 레이아웃(forms.glyphs)이 아니라 bjCompose 12단계 조각 조합을
/// 그대로 그린다 — steps 도 bjCompose 가 계산한 값(고정 inkSteps 아님).
void paintBujeokInk(Canvas c, Size sz, {required String name, required TalismanSpec spec, double ink = 1, String? serial}) {
  final L = BujeokLayout.L, I = L['inset']; final W = sz.width, H = sz.height;
  final ix = W * _d(I['side']), iy = H * _d(I['top']), iw = W * (1 - 2 * _d(I['side'])), ih = H * (1 - _d(I['top']) - _d(I['bottom']));
  final wk = _d(((L['weight'] as Map?)?[spec.type]) ?? 1);   // 유형별 굵기
  final comp = bjCompose(type: spec.type, phrase: spec.phrase, key: spec.key, flavor: spec.flavor, story: spec.story,
      ending: spec.ending, element: spec.element, base: spec.base, motif: spec.motif, name: name, serial: serial);
  final steps = comp.steps, strokeK = _d(L['stroke']) * wk, baseK = _d(L['baseline']);
  final inkC = _css(L['color']['ink']), signC = _css(L['color']['sign']), glowC = _css(L['color']['glow']); final glowB = W * _d(L['color']['glowBlur']);
  for (final it in comp.items) {
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
  paintBujeokInk(c, sz, name: name, spec: spec, ink: ink, serial: serial);
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
  final String name; final TalismanSpec spec; final double ink;
  _InkPainter(this.name, this.spec, this.ink);
  @override void paint(Canvas c, Size s) => paintBujeokInk(c, s, name: name, spec: spec, ink: ink);
  @override bool shouldRepaint(_InkPainter o) => o.ink != ink || o.name != name || o.spec.key != spec.key;
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
  Widget build(BuildContext context) => CustomPaint(size: Size.infinite, painter: _InkPainter(name, spec, ink));
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

/// U4 — 부적 옆 안내: 「이 세상에 하나뿐인 개인화 부적입니다」 + 조합 ID
/// (BJ6-XXXXXXX, bjCompose 가 계산한 실제 레시피에서 가져온다 — 지어낸
/// 표시 문구가 아니다). [onScroll]이 true면 결과 두루마리(한지 배경)
/// 안에 놓일 때처럼 먹색 글씨로 바뀐다(웹 shrine.css `.scroll .bj-one`).
class BjOneBadge extends StatelessWidget {
  final String? name;
  final TalismanSpec spec;
  final String? serial;
  final bool compact;
  final bool onScroll;
  const BjOneBadge({super.key, this.name, required this.spec, this.serial, this.compact = false, this.onScroll = false});
  @override
  Widget build(BuildContext context) {
    final rc = bjCompose(type: spec.type, phrase: spec.phrase, key: spec.key, flavor: spec.flavor, story: spec.story,
        ending: spec.ending, element: spec.element, base: spec.base, motif: spec.motif, name: name, serial: serial).recipe;
    final titleColor = onScroll ? const Color(0xFF3A1A0E) : C.fg;
    final smallColor = onScroll ? const Color(0xFF5A3A22) : C.muted;
    final codeColor = onScroll ? const Color(0xFFA11D19) : C.gold;
    final bg = onScroll ? const Color(0x12A11D19) : const Color(0x1EA11D19);
    final border = onScroll ? const Color(0x59A11D19) : const Color(0x73E0412F);
    final markSize = compact ? 26.0 : 34.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 7 : 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
      child: Row(crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
        Transform.rotate(angle: -4 * math.pi / 180, child: Container(
          width: markSize, height: markSize, alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB8241F), Color(0xFF6E0F0C)]),
            borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0x99D6AA64)),
            boxShadow: [BoxShadow(color: C.redGlow, blurRadius: 14)]),
          child: Text('唯\n一', textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifKr(fontSize: compact ? 9 : 11, fontWeight: FontWeight.w900, color: const Color(0xFFF8EAD6), height: 1.05, letterSpacing: .5)))),
        SizedBox(width: compact ? 8 : 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('이 세상에 하나뿐인 개인화 부적입니다',
            style: GoogleFonts.gowunBatang(fontSize: compact ? 12 : 13.5, fontWeight: FontWeight.w700, height: 1.4, color: titleColor)),
          if (!compact) ...[
            const SizedBox(height: 3),
            Text('${name != null && name!.isNotEmpty ? '$name님의 이름' : '당신의 이름'}과 고른 길, 닿은 결말로 조각을 골라 쓴 부적이라 같은 부적은 다시 나오지 않습니다.',
              style: TextStyle(fontFamily: 'Pretendard', fontSize: 11.5, height: 1.55, color: smallColor)),
          ],
          const SizedBox(height: 3),
          Text(rc.id, style: GoogleFonts.ibmPlexMono(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 1.2, color: codeColor)),
        ])),
      ]),
    );
  }
}
