// ═══════════════════════════════════════════════════════════════
// FILE: destiny_map.dart
// [궁합지도 「인연지도」 디자인 핸드오프 2차 반영] design_handoff_gunghap_map
// (1).zip `MAP_HOME_SPEC.md` + `flutter_starter/lib/gunghap/map/
// destiny_map.dart` 참고 구현을 이 프로젝트의 실제 서버 데이터 모델
// (`gunghap_map_models.dart`의 [MapPerson])에 맞춰 이식했다.
//
// [기존 StarMap(2인 전용)과의 역할 분리] `widgets/star_map.dart`는
// "두 사람" 전용 연출(초대/결과 화면)로 계속 쓰이고, 이 [DestinyMap]은
// "나 + 궁합을 본 모든 사람"을 보여주는 메인 홈 전용 위젯이다 — 서로
// 대체 관계가 아니다.
//
// [점수 → 거리 — 연속값, MAP_HOME_SPEC.md §8]
// "§1–2 의 궤도 구간 표기는 §8 연속 거리로 대체" — 디자인 문서 최신
// 확정에 따라 6단계 이산 궤도가 아니라 연속 공식
// `r = 46 + 105 × (100 − score) / 60`([ghScoreToRadius])로 별의 거리를
// 계산한다. 궤도선 6개는 시각적 눈금(90/82/74/66/58/40)으로만 남긴다.
//
// [빈 자리 별 8개] MAP_HOME_SPEC.md §9. 실제 서버에 "슬롯-인물 매핑"
// 데이터가 없으므로(이번 단계 범위 — 신규 DB 컬럼 추가 없이 구현),
// 실제 별이 늘어날 때마다 **뒤에서부터** 슬롯을 하나씩 숨기는 단순
// 규칙으로 "인연 수 + 슬롯 = 항상 8" 원칙을 근사 구현한다(디자인 문서
// "아니면 뒤에서부터 하나씩 사라짐" 폴백 규칙 그대로).
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../domain/gunghap_map_models.dart';
import '../theme/gh_tokens.dart';

/// [MAP_HOME_SPEC.md §9] 빈 자리 별(인연 슬롯) 8개 고정 명세.
class GhSlot {
  const GhSlot(this.id, this.label, this.majorId, this.recommend, this.virtualScore);
  final String id;
  final String label;
  final String majorId;
  final String recommend;
  final int virtualScore;
}

const List<GhSlot> ghSlots = [
  GhSlot('spouse', '배우자', 'marriage', '부부 · 결혼 · 생활', 92),
  GhSlot('mom', '엄마', 'family', '어머니·자녀 · 가족 생활', 88),
  GhSlot('lover', '연인', 'love', '연애 · 썸 · 애정표현', 80),
  GhSlot('bestfriend', '절친', 'friend', '절친 · 여행 · 취미', 76),
  GhSlot('dad', '아빠', 'family', '아버지·자녀', 70),
  GhSlot('colleague', '동료', 'business', '직장 동료 · 업무', 64),
  GhSlot('sibling', '형제·자매', 'family', '형제·자매', 58),
  GhSlot('crush', '썸', 'love', '썸 · 짝사랑', 52),
];

Color _ghElementColor(String element) =>
    Color(ghElementColorValue[element] ?? 0xFFE2C07F);

class DestinyMap extends StatefulWidget {
  const DestinyMap({
    super.key,
    required this.people,
    this.filterMajor,
    this.selectedPersonKey,
    required this.onTapPerson,
    this.onTapSlot,
    this.vivid = true,
    this.showSlots = true,
  });

  final List<MapPerson> people;
  final String? filterMajor; // null = 전체
  final String? selectedPersonKey;
  final ValueChanged<MapPerson> onTapPerson;
  final ValueChanged<GhSlot>? onTapSlot;
  final bool vivid;
  final bool showSlots;

  @override
  State<DestinyMap> createState() => _DestinyMapState();
}

class _DestinyMapState extends State<DestinyMap> with TickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
        ..forward();
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(hours: 1))..repeat();

  double get _speed => widget.vivid ? .55 : 1.0;

  double _orbitAngle(int orbit) {
    final period = (70 + orbit * 26) * _speed; // seconds / revolution
    final secs = _clock.lastElapsedDuration?.inMilliseconds ?? 0;
    return (secs / 1000.0) / period * 2 * pi;
  }

  @override
  void didUpdateWidget(DestinyMap old) {
    super.didUpdateWidget(old);
    if (widget.selectedPersonKey != null) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _clock.dispose();
    super.dispose();
  }

  /// [MAP_HOME_SPEC.md §9] 뒤에서부터 하나씩 숨기는 단순 규칙 —
  /// 실제 인물 수만큼 슬롯 목록 뒤쪽을 제거한다.
  List<GhSlot> get _visibleSlots {
    if (!widget.showSlots) return const [];
    final remain = ghSlots.length - widget.people.length;
    if (remain <= 0) return const [];
    return ghSlots.sublist(0, remain);
  }

  Offset _personPos(MapPerson p, double k) {
    final a = p.angleDeg * pi / 180 + _orbitAngle(p.orbit);
    final r = ghScoreToRadius(p.score);
    return Offset(180 + cos(a) * r, 180 + sin(a) * r) * k;
  }

  Offset _slotPos(GhSlot s, int idx, double k) {
    // 슬롯은 공전하지 않는다 — id 해시 기반 고정 각도만 사용.
    final hash = s.id.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);
    final a = (hash % 360) * pi / 180;
    final r = ghScoreToRadius(s.virtualScore);
    return Offset(180 + cos(a) * r, 180 + sin(a) * r) * k;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final size = min(c.maxWidth, 430.0);
        final k = size / 360;
        final slots = _visibleSlots;
        return SizedBox(
          width: size,
          height: size,
          child: AnimatedBuilder(
            animation: Listenable.merge([_intro, _clock]),
            builder: (_, __) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                for (final p in widget.people) {
                  if ((_personPos(p, k) - d.localPosition).distance < 16 * k) {
                    widget.onTapPerson(p);
                    return;
                  }
                }
                if (widget.onTapSlot == null) return;
                for (var i = 0; i < slots.length; i++) {
                  if ((_slotPos(slots[i], i, k) - d.localPosition).distance < 16 * k) {
                    widget.onTapSlot!(slots[i]);
                    return;
                  }
                }
              },
              child: CustomPaint(
                painter: _DestinyPainter(
                  people: widget.people,
                  slots: slots,
                  k: k,
                  intro: _intro.value,
                  personPosOf: (p) => _personPos(p, k),
                  slotPosOf: (s, i) => _slotPos(s, i, k),
                  filter: widget.filterMajor,
                  selectedPersonKey: widget.selectedPersonKey,
                  ringTurn:
                      (_clock.lastElapsedDuration?.inMilliseconds ?? 0) /
                      1000 /
                      (260 * _speed),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DestinyPainter extends CustomPainter {
  _DestinyPainter({
    required this.people,
    required this.slots,
    required this.k,
    required this.intro,
    required this.personPosOf,
    required this.slotPosOf,
    required this.ringTurn,
    this.filter,
    this.selectedPersonKey,
  });

  final List<MapPerson> people;
  final List<GhSlot> slots;
  final double k, intro, ringTurn;
  final Offset Function(MapPerson) personPosOf;
  final Offset Function(GhSlot, int) slotPosOf;
  final String? filter, selectedPersonKey;

  static const _ringScoreCuts = [90, 82, 74, 66, 58, 40];

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(180, 180) * k;

    // 바깥 링: 12지지 + 눈금 72개 — 회전.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(ringTurn * 2 * pi);
    canvas.drawCircle(
      Offset.zero,
      172 * k,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6 * k
        ..color = GHColors.gold.withValues(alpha: .22),
    );
    for (var i = 0; i < 72; i++) {
      final a = i / 72 * 2 * pi;
      final r1 = (i % 6 == 0 ? 164 : 168) * k;
      canvas.drawLine(
        Offset(cos(a) * r1, sin(a) * r1),
        Offset(cos(a) * 172 * k, sin(a) * 172 * k),
        Paint()
          ..strokeWidth = .5 * k
          ..color = GHColors.gold.withValues(alpha: .3),
      );
    }
    canvas.restore();

    // [MAP_HOME_SPEC.md §8] 점수 구간 눈금 6개 — 연속 거리 공식 기반 반지름.
    for (var t = 0; t < _ringScoreCuts.length; t++) {
      final prog = ((intro * 1.6) - t * .12).clamp(0.0, 1.0);
      final r = ghScoreToRadius(_ringScoreCuts[t]) * k;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6 * k
        ..color = (t == 0 ? const Color(0xFFF0D9A8) : GHColors.ivory)
            .withValues(alpha: t == 0 ? .3 : .1 + (5 - t) * .012);
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi * prog, false, paint);
      final tp = TextPainter(
        text: TextSpan(
          text: '${_ringScoreCuts[t]}',
          style: TextStyle(
            fontFamily: 'IBMPlexMono',
            fontSize: 6 * k,
            fontWeight: FontWeight.w700,
            color: GHColors.gold.withValues(alpha: .75 - t * .08),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c + Offset(r - tp.width - 2 * k, -3 * k - tp.height));
    }

    // 빈 자리 별(인연 슬롯) — 점선 원 + '+', 공전하지 않음.
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      final o = slotPosOf(s, i);
      _dashedCircle(canvas, o, 7 * k, GHColors.gray.withValues(alpha: .45));
      _text(canvas, '+', o, 9 * k, GHColors.gray.withValues(alpha: .7), w900: true);
      _text(canvas, s.label, o + Offset(0, 15 * k), 9.5 * k, GHColors.gray.withValues(alpha: .75));
    }

    // 연결선 + 실제 별.
    for (final p in people) {
      final o = personPosOf(p);
      final dim = filter != null && p.majorId != filter;
      final sel = p.personKey == selectedPersonKey;
      final col = _ghElementColor(p.element);
      final alpha = dim ? .18 : 1.0;
      canvas.drawLine(
        c,
        o,
        Paint()
          ..strokeWidth = (sel ? 1.4 : .6) * k
          ..shader = ui.Gradient.linear(c, o, [
            GHColors.gold.withValues(alpha: .9 * alpha),
            col.withValues(alpha: .9 * alpha),
          ]),
      );
      final r = (p.orbit <= 1 ? 4.4 : p.orbit <= 3 ? 3.6 : 3.2) * k;
      canvas.drawCircle(
        o,
        r * 4.2,
        Paint()
          ..shader = ui.Gradient.radial(o, r * 4.2, [
            col.withValues(alpha: .6 * alpha),
            col.withValues(alpha: 0),
          ]),
      );
      _star(canvas, o, r, col.withValues(alpha: .95 * alpha));
      _text(canvas, p.stem, o + Offset(0, -9 * k), 6.5 * k, col.withValues(alpha: alpha), w900: true);
      _text(
        canvas,
        p.name,
        o + Offset(0, 15 * k),
        10 * k,
        (sel ? col : GHColors.ivory).withValues(alpha: alpha),
      );
      _text(
        canvas,
        '${p.score}',
        o + Offset(0, 24 * k),
        7 * k,
        const Color(0xFFF0D9A8).withValues(alpha: alpha),
        mono: true,
      );
    }

    // 나(중심).
    canvas.drawCircle(c, 17 * k, Paint()..color = const Color(0xBF10172D));
    canvas.drawCircle(
      c,
      17 * k,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8 * k
        ..color = GHColors.gold.withValues(alpha: .7),
    );
    _star(canvas, c, 5.6 * k, GHColors.gold);
  }

  void _dashedCircle(Canvas cv, Offset o, double r, Color color) {
    const dashCount = 16;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    for (var i = 0; i < dashCount; i++) {
      final a0 = i / dashCount * 2 * pi;
      final a1 = a0 + (pi / dashCount) * .7;
      final p1 = o + Offset(cos(a0), sin(a0)) * r;
      final p2 = o + Offset(cos(a1), sin(a1)) * r;
      cv.drawLine(p1, p2, paint);
    }
  }

  void _star(Canvas cv, Offset o, double r, Color color) {
    final l = r * 2.5, w = r * .4;
    final path = Path()
      ..moveTo(o.dx, o.dy - l)
      ..lineTo(o.dx + w, o.dy - w)
      ..lineTo(o.dx + l, o.dy)
      ..lineTo(o.dx + w, o.dy + w)
      ..lineTo(o.dx, o.dy + l)
      ..lineTo(o.dx - w, o.dy + w)
      ..lineTo(o.dx - l, o.dy)
      ..lineTo(o.dx - w, o.dy - w)
      ..close();
    cv.drawPath(path, Paint()..color = color);
    cv.drawCircle(o, r * .6, Paint()..color = const Color(0xFFFFF8EA).withValues(alpha: color.a));
  }

  void _text(Canvas cv, String s, Offset at, double fs, Color color, {bool w900 = false, bool mono = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: mono ? 'IBMPlexMono' : (w900 ? 'NotoSerifKR' : 'Pretendard'),
          fontSize: fs,
          fontWeight: w900 ? FontWeight.w900 : FontWeight.w700,
          color: color,
          shadows: const [Shadow(color: Color(0xD910172D), blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(cv, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DestinyPainter old) => true;
}
