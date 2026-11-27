// ═══════════════════════════════════════════════════════════════
// FILE: destiny_map.dart
// [궁합지도 전면 리디자인 v4] design_handoff_gunghap_map_v4
// `00_DEV_MAPPING.md` §6(DestinyBurst) + `flutter_starter/lib/gunghap/
// map/destiny_map.dart`(v3 참고 구현) 완전 포팅.
//
// [과거 DestinyMap(궤도 공전 방식)에서 DestinyBurst(정지 배치 방식)로
// 전면 교체] 이전 구현은 viewBox 360×360에 "분야별 궤도 공전" 연출을
// 썼지만, v4 디자인은 viewBox 360×512(중심 C=180,250)에 "분야순→점수
// 내림차순 정렬 후 (n+빈자리) 칸 균등 분할·정지" 배치로 완전히
// 바뀌었다(§6-2~6-4). 공개 위젯 이름을 [DestinyBurst]로 바꾸고,
// 기존 [GhSlot]/[ghSlots] 로컬 정의는 제거해 `gunghap_data.dart`의
// v4 [Slot]/[ghSlots]/[ghVisibleSlots]를 그대로 쓴다(단일 출처 원칙).
//
// 규칙 요약(§6)
//  · 캔버스 360×512(비율 고정, 폭 100% · 최대 430) · 중심 C(180,250)=「나」
//  · 거리 r = ghBurstRadius(score) = 88 + 40×(100−clamp(score,40,100))/60
//    (100점 88 · 40점 128) · n>8 & score≥75 & 홀수 i → +16(지그재그)
//  · 좌표 x = cosθ·r·0.88, y = sinθ·r·1.32 (C 기준 상대 오프셋)
//  · 각도 = 정렬(분야순→점수 내림차순) 후 (n+빈자리) 칸 균등분할·정지
//    (공전 없음 — 과거 DestinyMap과의 핵심 차이)
//  · 노드 크기 NR = clamp(15−(max(2,n)−2)·0.45, 8, 15) · 이름 FS = max(7.5, NR·0.82)
//  · 레이어 9개(§6-5): 성운 → 코어 → 연결선 → 파동 → 「나」링 → 빈자리 →
//    인연노드 → 「나」 → 분야 네모 8
import 'dart:math';
import 'package:flutter/material.dart';
import '../domain/gunghap_data.dart' show Slot, ghMajorById;
import '../domain/gunghap_map_models.dart' show MapPerson, MapMe, ghBurstRadius;
import '../theme/gh_tokens.dart';
import 'cat_icon.dart';

const _cx = 180.0, _cy = 250.0, _sx = 0.88, _sy = 1.32, _sealR = 176.0, _slotR = 104.0;
const _canvas = Size(360, 512);

class BurstNode {
  BurstNode(this.person, this.offset, this.order);
  final MapPerson person;
  final Offset offset;

  /// 점수 순위(등장 지연 계산용) — 0이 가장 높은 점수.
  final int order;
}

class BurstSlot {
  BurstSlot(this.slot, this.offset, this.index);
  final Slot slot;
  final Offset offset;
  final int index;
}

/// §6-2~6-4 배치 계산(순수 함수 — 테스트 가능).
({List<BurstNode> nodes, List<BurstSlot> slots, double nr, double fs}) ghBurstLayout(
  List<MapPerson> people,
  List<Slot> slots,
) {
  int catIdx(String? id) => id == null ? -1 : GHCategory.order.indexOf(id);
  final seq = [...people]
    ..sort((a, b) {
      final c = catIdx(a.majorId).compareTo(catIdx(b.majorId));
      return c != 0 ? c : b.score.compareTo(a.score);
    });
  final n = seq.length, total = n + slots.length;
  final base = -90 - (total > 1 ? 180 / total : 0) + 12;
  final pIdx = [for (var i = 0; i < n; i++) (i * total / max(1, n)).round()];
  final sIdx = [for (var i = 0; i < total; i++) if (!pIdx.contains(i)) i];

  Offset at(double deg, double r) {
    final a = deg * pi / 180;
    return Offset(cos(a) * r * _sx, sin(a) * r * _sy);
  }

  final byScore = [...seq]..sort((a, b) => b.score.compareTo(a.score));
  final nodes = <BurstNode>[
    for (var i = 0; i < n; i++)
      BurstNode(
        seq[i],
        at(
          base + pIdx[i] * 360 / max(1, total),
          ghBurstRadius(seq[i].score) + (n > 8 && seq[i].score >= 75 && i.isOdd ? 16 : 0),
        ),
        byScore.indexOf(seq[i]),
      ),
  ];
  final sl = <BurstSlot>[
    for (var i = 0; i < slots.length; i++)
      BurstSlot(
        slots[i],
        at(base + (i < sIdx.length ? sIdx[i] : i) * 360 / max(1, total), _slotR),
        i,
      ),
  ];
  final nr = (15 - (max(2, n) - 2) * 0.45).clamp(8.0, 15.0).toDouble();
  return (nodes: nodes, slots: sl, nr: nr, fs: max(7.5, nr * .82));
}

class DestinyBurst extends StatefulWidget {
  const DestinyBurst({
    super.key,
    required this.people,
    required this.slots,
    required this.me,
    this.focusMajor,
    this.selectedKey,
    required this.onSelect,
    required this.onSlot,
    required this.onFocus,
    this.paused = false,
  });

  final List<MapPerson> people;

  /// 호출부가 `ghVisibleSlots(people)`로 미리 계산해 전달한다.
  final List<Slot> slots;
  final MapMe me;

  /// 분야 네모 하이라이트(null = 전체).
  final String? focusMajor;
  final String? selectedKey;

  /// 인연 노드 탭 → RelationSheet(S05).
  final ValueChanged<MapPerson> onSelect;

  /// 빈 자리 탭 → SlotSheet(S03).
  final ValueChanged<Slot> onSlot;

  /// 분야 네모 탭(토글 — 이미 선택된 분야를 다시 탭하면 null).
  final ValueChanged<String?> onFocus;

  /// 시트가 열려 있거나 앱이 백그라운드일 때 루프 애니메이션 정지.
  final bool paused;

  @override
  State<DestinyBurst> createState() => _DestinyBurstState();
}

class _DestinyBurstState extends State<DestinyBurst> with TickerProviderStateMixin {
  // 등장(0→4.5s), 상시 루프(파동 10s · 성운 부유 · 할로 2.4s · 링 맥동 3s).
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4500),
  )..forward();
  late final AnimationController _loop = AnimationController(vsync: this, duration: GHMotion.ripple)
    ..repeat();

  @override
  void didUpdateWidget(covariant DestinyBurst old) {
    super.didUpdateWidget(old);
    if (widget.paused) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lay = ghBurstLayout(widget.people, widget.slots);
    final counts = {
      for (final k in GHCategory.order)
        k: widget.people.where((p) => (p.majorId ?? 'love') == k).length,
    };
    return LayoutBuilder(
      builder: (ctx, c) {
        final w = min(c.maxWidth, 430.0), s = w / _canvas.width;
        Offset toLocal(Offset o) => Offset((_cx + o.dx) * s, (_cy + o.dy) * s);
        return SizedBox(
          width: w,
          height: _canvas.height * s,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final p = d.localPosition;
              for (final n in lay.nodes) {
                if ((toLocal(n.offset) - p).distance <= 24 * s) {
                  widget.onSelect(n.person);
                  return;
                }
              }
              for (final sl in lay.slots) {
                if ((toLocal(sl.offset) - p).distance <= 20 * s) {
                  widget.onSlot(sl.slot);
                  return;
                }
              }
              for (var i = 0; i < 8; i++) {
                final k = GHCategory.order[i];
                final a = (-90 + i * 45) * pi / 180;
                final o = Offset(cos(a) * (_sealR - 22), sin(a) * _sealR * _sy);
                if ((toLocal(o) - p).distance <= 22 * s) {
                  widget.onFocus(widget.focusMajor == k ? null : k);
                  return;
                }
              }
            },
            child: AnimatedBuilder(
              animation: Listenable.merge([_intro, _loop]),
              builder: (_, _) => CustomPaint(
                size: Size(w, _canvas.height * s),
                painter: _BurstPainter(
                  lay: lay,
                  counts: counts,
                  focus: widget.focusMajor,
                  selected: widget.selectedKey,
                  intro: _intro.value * 4.5,
                  loop: _loop.value,
                  scale: s,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.lay,
    required this.counts,
    this.focus,
    this.selected,
    required this.intro,
    required this.loop,
    required this.scale,
  });
  final ({List<BurstNode> nodes, List<BurstSlot> slots, double nr, double fs}) lay;
  final Map<String, int> counts;
  final String? focus, selected;

  /// 마운트 이후 경과 초(0~4.5).
  final double intro;

  /// 0~1(10초 1주기).
  final double loop;
  final double scale;

  double _t(double start, double dur, [Curve curve = Curves.easeOut]) =>
      curve.transform(((intro - start) / dur).clamp(0.0, 1.0));
  Color _cat(String? id) =>
      (GHCategory.colors[id ?? 'love'] ?? GHCategory.colors['love']!).$1;

  void _text(
    Canvas c,
    String s,
    Offset at,
    double size,
    Color color, {
    FontWeight w = FontWeight.w800,
    bool outline = true,
  }) {
    final style = TextStyle(fontFamily: 'Pretendard', fontSize: size, fontWeight: w, color: color, height: 1);
    if (outline) {
      final tpO = TextPainter(
        text: TextSpan(
          text: s,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpO.paint(c, at - Offset(tpO.width / 2, tpO.height / 2));
    }
    final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  void _avatar(Canvas c, Offset o, double r, Color fill, Color ring, String ch, {bool me = false}) {
    c.drawCircle(
      o,
      r + 3.2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = ring.withValues(alpha: .95),
    );
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: .95), fill, fill.withValues(alpha: .75)],
          stops: const [0, .28, 1],
        ).createShader(Rect.fromCircle(center: o, radius: r)),
    );
    c.drawCircle(o, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = Colors.white);
    _text(c, ch, o, r * (me ? .78 : .82), Colors.white, outline: false);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);
    const c = Offset(_cx, _cy);

    // 1. 성운(10~12s 부유).
    final f1 = sin(loop * 2 * pi), f2 = sin(loop * 2 * pi + 2);
    void neb(Offset o, double r, Color col, double op) => canvas.drawCircle(
      o,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [col.withValues(alpha: op), col.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: o, radius: r)),
    );
    neb(Offset(70 + f1 * 10, 140 - f1 * 8), 170, const Color(0xFFFFB3CF), .55);
    neb(Offset(300 + f2 * 10, 350 - f2 * 8), 180, const Color(0xFFC4B5FD), .55);
    neb(c, 150, const Color(0xFFFFE7A3), .6);

    // 2. 코어.
    canvas.drawCircle(
      c,
      70,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, Color(0xE6FFE1EC), Color(0x00FFD1E1)],
          stops: [0, .35, 1],
        ).createShader(Rect.fromCircle(center: c, radius: 70)),
    );

    // 4. 연결선(lineDraw).
    for (final n in lay.nodes) {
      final d = 1.25 + n.order * .16 - .1, k = _t(d, .7);
      if (k <= 0) continue;
      final dim = focus != null && focus != (n.person.majorId ?? 'love');
      final sel = selected == n.person.personKey;
      canvas.drawLine(
        c,
        c + n.offset * k,
        Paint()
          ..strokeWidth = sel ? 1.6 : .8
          ..strokeCap = StrokeCap.round
          ..color = _cat(n.person.majorId).withValues(alpha: (sel ? .9 : .35) * (dim ? .12 : 1)),
      );
    }

    // 3. 파동(6겹 · 10s · r34 기준 scale .25→5.2, opacity 0→.22(10%)→0).
    for (var k = 0; k < 6; k++) {
      final ph = (loop + k / 6) % 1.0;
      final sc = .25 + (5.2 - .25) * Curves.easeOut.transform(ph);
      final op = ph < .1 ? ph / .1 * .22 : .22 * (1 - (ph - .1) / .9);
      canvas.drawCircle(
        c,
        34 * sc,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = (k.isOdd ? const Color(0xFFC4B5FD) : const Color(0xFFFF9EC0)).withValues(alpha: op),
      );
    }

    // 5. 「나」 링 r40(ringIn .35s + 맥동 3s).
    final ringK = _t(.35, 1, const Cubic(.3, 1.4, .5, 1));
    if (ringK > 0) {
      final pulse = 1 + .04 * sin(loop * 2 * pi * (10 / 3));
      canvas.drawCircle(
        c,
        40 * ringK * pulse,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = GHColors.meInk.withValues(alpha: .9),
      );
      canvas.drawCircle(
        c,
        40 * ringK,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xE6B794F6),
      );
    }

    // 6. 빈 자리.
    for (final s in lay.slots) {
      final k = _t(1.2 + s.index * .1, .6);
      if (k <= 0) continue;
      final o = c + s.offset;
      final halo = .55 + .45 * (.5 + .5 * sin(loop * 2 * pi * (10 / 2.2) + s.index * .7));
      canvas.drawCircle(o, 13, Paint()..color = Colors.white.withValues(alpha: k));
      _dashedCircle(
        canvas,
        o,
        13,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = GHColors.accent.withValues(alpha: .8 * halo * k),
      );
      _text(canvas, '+', o, 13, GHColors.accent.withValues(alpha: k), w: FontWeight.w700, outline: false);
      _text(canvas, s.slot.label, o + const Offset(0, 25), 9.5, GHColors.muted.withValues(alpha: k), w: FontWeight.w700);
    }

    // 7. 인연 노드(flyIn 1.25s + 순위×.16s, .9s).
    for (final n in lay.nodes) {
      final k = _t(1.25 + n.order * .16, .9, GHMotion.flyCurve);
      if (k <= 0) continue;
      final o = c + n.offset * k;
      final p = n.person;
      final cat = _cat(p.majorId);
      final dim = focus != null && focus != (p.majorId ?? 'love');
      final sel = selected == p.personKey;
      canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: (dim ? .25 : 1) * min(1, k * 1.4)));
      canvas.translate(o.dx, o.dy);
      canvas.scale(.15 + .85 * k);
      canvas.translate(-o.dx, -o.dy);
      if (sel) {
        canvas.drawCircle(
          o,
          lay.nr + 8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = cat.withValues(alpha: 1 - (loop * 5.5) % 1),
        );
      }
      _avatar(canvas, o, lay.nr, GHElement.of(p.element), cat, p.name.characters.first);
      final lo = o + Offset(0, lay.nr + 12);
      _text(canvas, p.name, lo, lay.fs, GHColors.fg);
      final badge = RRect.fromRectAndRadius(
        Rect.fromCenter(center: lo + const Offset(0, 11), width: 17, height: 9.5),
        const Radius.circular(4.75),
      );
      canvas.drawRRect(badge, Paint()..color = cat);
      _text(canvas, '${p.score}', badge.center, 7.5, Colors.white, w: FontWeight.w900, outline: false);
      canvas.restore();
    }

    // 8. 「나」(ringIn .1s).
    final meK = _t(.1, .9, const Cubic(.3, 1.4, .5, 1));
    if (meK > 0) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(meK);
      canvas.translate(-c.dx, -c.dy);
      final halo = .55 + .45 * (.5 + .5 * sin(loop * 2 * pi * (10 / 2.4)));
      canvas.drawCircle(c, 30, Paint()..color = GHColors.meInk.withValues(alpha: .25 * halo));
      _avatar(canvas, c, 21, const Color(0xFFFF6FA8), GHColors.meInk, '나', me: true);
      final b = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(0, 33.5), width: 22, height: 13),
        const Radius.circular(6.5),
      );
      canvas.drawRRect(b, Paint()..color = GHColors.meInk);
      _text(canvas, '나', b.center, 8.5, Colors.white, w: FontWeight.w900, outline: false);
      canvas.restore();
    }

    // 9. 분야 네모 8(sealIn .6s + i×.07s) · 선택 시 c1 채움 + 흰 아이콘.
    for (var i = 0; i < 8; i++) {
      final k = _t(.6 + i * .07, .6, const Cubic(.3, 1.5, .5, 1));
      if (k <= 0) continue;
      final id = GHCategory.order[i];
      final col = GHCategory.colors[id]!.$1;
      final on = focus == id;
      final cnt = counts[id] ?? 0;
      final a = (-90 + i * 45) * pi / 180;
      final o = c + Offset(cos(a) * (_sealR - 22), sin(a) * _sealR * _sy);
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.scale(.4 + .6 * k);
      canvas.translate(-o.dx, -o.dy);
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 28, height: 28), const Radius.circular(8));
      canvas.drawRRect(
        r.shift(const Offset(0, 2)),
        Paint()
          ..color = col.withValues(alpha: .25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawRRect(r, Paint()..color = on ? col : Colors.white);
      canvas.drawRRect(r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = col);
      canvas.save();
      canvas.translate(o.dx - 10, o.dy - 10);
      CatIconPainter(ghMajorById(id).icon, white: on).paint(canvas, const Size(20, 20));
      canvas.restore();
      if (cnt > 0) {
        final bc = o + const Offset(13, -13);
        canvas.drawCircle(bc, 6, Paint()..color = col);
        canvas.drawCircle(bc, 6, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = Colors.white);
        _text(canvas, '$cnt', bc, 7, Colors.white, w: FontWeight.w900, outline: false);
      }
      _text(canvas, ghMajorById(id).short, o + const Offset(0, 26), 9, on ? col : GHColors.muted);
      canvas.restore();
    }

    canvas.restore();
  }

  void _dashedCircle(Canvas c, Offset o, double r, Paint p) {
    const dash = 3.0, gap = 3.0;
    final circ = 2 * pi * r;
    final n = (circ / (dash + gap)).floor();
    for (var i = 0; i < n; i++) {
      final a0 = i * (dash + gap) / r;
      c.drawArc(Rect.fromCircle(center: o, radius: r), a0, dash / r, false, p);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter o) => true;
}
