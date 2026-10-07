import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../home/domain/saju_engine.dart'
    show ganElement, zhiElement, ganKr, zhiKr;
import '../theme/saju_dark_tokens.dart';
import '../data/saju_visual_adapter.dart';
import '../utils/saju_motion_prefs.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 핸드오프] 사주 시각화 컴포넌트.
/// `design_files/saju/saju-components.jsx`의 Bagua/PillarGrid/ElementShard/
/// ElementBars/BalanceGauge/LuckStream을 Flutter CustomPaint로 재현.

const Map<int, List<int>> _trigrams = {
  0: [1, 1, 1],
  1: [0, 1, 1],
  2: [1, 0, 1],
  3: [0, 0, 1],
  4: [1, 1, 0],
  5: [0, 1, 0],
  6: [1, 0, 0],
  7: [0, 0, 0],
};

String _elementKoToEn(String ko) {
  switch (ko) {
    case '목':
      return 'wood';
    case '화':
      return 'fire';
    case '토':
      return 'earth';
    case '금':
      return 'metal';
    case '수':
      return 'water';
    default:
      return 'wood';
  }
}

/// [E-Semantics] docs/01_디자인토큰.md §1-3 오행 한글 라벨은
/// "나무/불/흙/쇠/물"(순우리말)이다. 기존 데이터 소스(ganElement/
/// zhiElement)의 한자음 표기('목/화/토/금/수')는 시각적 라벨·색상
/// 매핑에 그대로 쓰되, 스크린리더 Semantics 라벨은 docs 08_QA_체크
/// 리스트.md 예시("천간 갑, 나무")와 동일하게 맞추기 위해 변환한다.
String _elementKoToSemantic(String ko) {
  switch (ko) {
    case '목':
      return '나무';
    case '화':
      return '불';
    case '토':
      return '흙';
    case '금':
      return '쇠';
    case '수':
      return '물';
    default:
      return ko;
  }
}

/// 음양·팔괘 오브제(01 상징 → 03 진행 인디케이터).
class SajuBagua extends StatefulWidget {
  const SajuBagua({
    super.key,
    this.size = 260,
    this.speedSeconds = 120,
    this.intensity = 1,
    this.collapse = 0,
    this.lit = -1,
    this.color = SajuGold.g300,
  });

  final double size;
  final double speedSeconds;
  final double intensity;
  final double collapse;
  final int lit; // -1 = 전부 점등
  final Color color;

  @override
  State<SajuBagua> createState() => _SajuBaguaState();
}

class _SajuBaguaState extends State<SajuBagua>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotionApplied = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.speedSeconds * 1000).round()),
    )..repeat();
  }

  // [E-Reduce Motion — docs/04_모션.md §2 "A-01 Bagua 팔괘 링 … 회전" /
  // "A-02 Bagua 음양 … 회전" / §5 "A-01~A-07 정지(정지 프레임 = 각 루프의
  // 0% 상태)"] 기존에는 disableAnimations를 전혀 조회하지 않아 Bagua
  // 회전이 Reduce Motion 설정과 무관하게 항상 돌았다.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = sajuReduceMotion(context);
    if (reduce && !_reduceMotionApplied) {
      _reduceMotionApplied = true;
      _controller.stop();
      _controller.value = 0;
    } else if (!reduce && _reduceMotionApplied) {
      _reduceMotionApplied = false;
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SajuBagua oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speedSeconds != widget.speedSeconds) {
      _controller.duration = Duration(
        milliseconds: (widget.speedSeconds * 1000).round(),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // [E-Semantics — docs/08_QA_체크리스트.md "장식(Bagua·별·장면
    // 오브제)은 접근성 트리에서 숨김"] Bagua는 03의 진행 인디케이터로도
    // 쓰이지만, 실제 진행 정보는 하단 "ANALYSIS · 0n/09" 상단바 타이틀과
    // 단계 라벨(Text)이 이미 전달하므로 이 오브제 자체는 순수 장식으로
    // 취급해 스크린 리더 트리에서 제외한다.
    return ExcludeSemantics(
      child: AnimatedScale(
        scale: 1 - widget.collapse * 0.4,
        duration: SajuMotion.card,
        child: AnimatedOpacity(
          opacity: 1 - widget.collapse,
          duration: SajuMotion.card,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _BaguaPainter(
                    t: _controller.value,
                    intensity: widget.intensity,
                    lit: widget.lit,
                    color: widget.color,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BaguaPainter extends CustomPainter {
  _BaguaPainter({
    required this.t,
    required this.intensity,
    required this.lit,
    required this.color,
  });

  final double t;
  final double intensity;
  final int lit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final scale = size.shortestSide / 240;
    final r = 100 * scale;

    // halo
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.18 * intensity),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r + 18 * scale));
    canvas.drawCircle(center, r + 18 * scale, halo);

    // 팔괘 링 (시계방향 회전)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(t * 2 * math.pi);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6 * scale
      ..color = color.withValues(alpha: 0.35 * intensity);
    canvas.drawCircle(Offset.zero, r + 12 * scale, ringPaint);
    canvas.drawCircle(
      Offset.zero,
      r - 16 * scale,
      ringPaint
        ..strokeWidth = 0.5 * scale
        ..color = color.withValues(alpha: 0.25 * intensity),
    );
    // 바깥 눈금
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5 * scale
      ..color = color.withValues(alpha: 0.4 * intensity);
    for (var i = 0; i < 64; i++) {
      final a = (i / 64) * 2 * math.pi;
      final r1 = r + 9 * scale;
      final r2 = r + (i % 8 == 0 ? 16 : 12) * scale;
      canvas.drawLine(
        Offset(math.cos(a) * r1, math.sin(a) * r1),
        Offset(math.cos(a) * r2, math.sin(a) * r2),
        tickPaint,
      );
    }
    // 8괘
    for (var i = 0; i < 8; i++) {
      final deg = i * 45 * math.pi / 180;
      final on = lit < 0 || i < lit;
      final opacity = on ? 1.0 : 0.22;
      final barPaint = Paint()
        ..color = color.withValues(alpha: 0.7 * intensity * opacity);
      canvas.save();
      canvas.rotate(deg);
      canvas.translate(0, -r + 2 * scale);
      final lines = _trigrams[i]!;
      for (var j = 0; j < 3; j++) {
        final y = (j * 5 - 6) * scale;
        final h = 2.4 * scale;
        if (lines[j] == 1) {
          final rect = Rect.fromLTWH(-11 * scale, y, 22 * scale, h);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(0.6 * scale)),
            barPaint,
          );
        } else {
          final rectL = Rect.fromLTWH(-11 * scale, y, 9 * scale, h);
          final rectR = Rect.fromLTWH(2 * scale, y, 9 * scale, h);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rectL, Radius.circular(0.6 * scale)),
            barPaint,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rectR, Radius.circular(0.6 * scale)),
            barPaint,
          );
        }
      }
      canvas.restore();
    }
    canvas.restore();

    // 음양 — 팔괘 링 대비 반시계·1/0.6배속(JSX: `sj-rotate-rev ${speed*0.6}s`,
    // 즉 팔괘가 speed초에 1회전할 때 음양은 speed*0.6초에 1회전 = 1/0.6배 빠름).
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-t * 2 * math.pi * (1 / 0.6));
    final yinYangScale = 0.5 * scale;
    canvas.scale(yinYangScale);
    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.7 * intensity);
    canvas.drawCircle(Offset.zero, 60, circlePaint);
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.16 * intensity);
    final path = Path()
      ..moveTo(0, -60)
      ..arcToPoint(
        const Offset(0, 60),
        radius: const Radius.circular(60),
        clockwise: true,
      )
      ..arcToPoint(
        const Offset(0, 0),
        radius: const Radius.circular(30),
        clockwise: true,
      )
      ..arcToPoint(
        const Offset(0, -60),
        radius: const Radius.circular(30),
        clockwise: false,
      )
      ..close();
    canvas.drawPath(path, fillPaint);
    canvas.drawCircle(const Offset(0, -30), 6, Paint()..color = SajuInk.i900);
    canvas.drawCircle(
      const Offset(0, -30),
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.7 * intensity),
    );
    canvas.drawCircle(
      const Offset(0, 30),
      6,
      Paint()..color = color.withValues(alpha: 0.7 * intensity),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BaguaPainter oldDelegate) => true;
}

/// 사주 원국 4×2 격자(시/일/월/년 × 천간/지지).
class SajuPillarGrid extends StatelessWidget {
  const SajuPillarGrid({
    super.key,
    required this.pillars,
    this.cell = 56,
    this.gap = 8,
    this.reveal = 8,
    this.highlightColumns,
    this.showLabels = true,
    this.showRelations = false,
    this.relations = const [],
    this.dimAll = false,
  });

  /// 길이 4, 화면 순서(0=時 1=日 2=月 3=年). null = 시간모름.
  final List<SajuVisualPillar?> pillars;
  final double cell;
  final double gap;
  final int reveal; // 0~8 새겨진 글자 수
  final List<int>? highlightColumns;
  final bool showLabels;
  final bool showRelations;
  final List<SajuVisualRelation> relations;
  final bool dimAll;

  static const _colLabels = ['時', '日', '月', '年'];
  static const _colLabelsKr = ['태어난 시', '태어난 날', '태어난 달', '태어난 해'];

  // 새김 순서: 年 → 月 → 日 → 時 (order index 3,2,1,0).
  int _revealIndex(int col, int row) {
    const order = [3, 2, 1, 0];
    return order.indexOf(col) * 2 + row;
  }

  @override
  Widget build(BuildContext context) {
    final width = cell * 4 + gap * 3;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLabels)
            Row(
              children: List.generate(4, (i) {
                final isHl = highlightColumns?.contains(i) ?? true;
                return SizedBox(
                  width: cell,
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 3 ? gap : 0),
                    child: Opacity(
                      opacity: (highlightColumns != null && !isHl) ? 0.4 : 1,
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _colLabels[i],
                              style: const TextStyle(
                                fontFamily: SajuType.serif,
                                fontSize: 10,
                                color: SajuText.muted,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' ${_colLabelsKr[i].replaceFirst('태어난 ', '')}',
                              style: const TextStyle(
                                fontFamily: SajuType.ui,
                                fontSize: 10,
                                color: SajuText.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          if (showLabels) const SizedBox(height: 6),
          SizedBox(
            width: width,
            height: cell * 2 + 6,
            child: Stack(
              children: [
                Column(
                  children: [
                    Row(
                      children: List.generate(4, (col) => _cell(col, 0, width)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(4, (col) => _cell(col, 1, width)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showRelations && relations.isNotEmpty)
            SizedBox(
              width: width,
              height: 36,
              child: CustomPaint(
                painter: _RelationPainter(
                  relations: relations,
                  cell: cell,
                  gap: gap,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(int col, int row, double totalWidth) {
    final pillar = pillars[col];
    final ch = pillar == null
        ? null
        : (row == 0 ? pillar.stemHanja : pillar.branchHanja);
    final elKo = ch == null
        ? null
        : (row == 0 ? ganElement[ch]?.$1 : zhiElement[ch]?.$1);
    final elColor = elKo == null
        ? null
        : SajuElementColor.of(_elementKoToEn(elKo));
    final shownIdx = _revealIndex(col, row);
    final shown = ch != null && shownIdx < reveal;
    final isHl = highlightColumns?.contains(col) ?? false;
    final dim = (highlightColumns != null && !isHl) || dimAll;

    // [E-Semantics — docs/08_QA_체크리스트.md "VoiceOver/TalkBack: 원국
    // 셀 '태어난 해, 천간 갑, 나무' 형식 라벨"] 열(col)은 화면 표시
    // 순서([0=時,1=日,2=月,3=年])를 그대로 "태어난 시/날/달/해"로
    // 치환하고, 행(row)은 "천간"(0)/"지지"(1)로, 글자는 한글 발음
    // (ganKr/zhiKr)으로, 오행은 한글 그대로 조합해 문장형 라벨을 만든다.
    // 아직 새겨지지 않은 칸(shown=false)은 "아직 비어 있음"으로,
    // 시간 모름(ch==null)은 "정보 없음"으로 안내한다.
    final colKo = _colLabelsKr[col]; // '태어난 시' 등.
    final rowKo = row == 0 ? '천간' : '지지';
    String semanticLabel;
    if (ch == null) {
      semanticLabel = '$colKo, $rowKo 정보 없음';
    } else if (!shown) {
      semanticLabel = '$colKo, $rowKo 아직 비어 있음';
    } else {
      final charKo = row == 0 ? (ganKr[ch] ?? ch) : (zhiKr[ch] ?? ch);
      semanticLabel = elKo == null
          ? '$colKo, $rowKo $charKo'
          : '$colKo, $rowKo $charKo, ${_elementKoToSemantic(elKo)}';
    }

    return Padding(
      padding: EdgeInsets.only(right: col < 3 ? gap : 0),
      child: Semantics(
        label: semanticLabel,
        excludeSemantics: true,
        child: AnimatedOpacity(
          duration: SajuMotion.card,
          opacity: dim ? 0.32 : 1,
          child: Container(
            width: cell,
            height: cell,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isHl
                    ? SajuText.fg.withValues(alpha: 0.7)
                    : SajuText.lineGold,
              ),
              color: isHl
                  ? SajuText.fg.withValues(alpha: 0.08)
                  : SajuText.fg.withValues(alpha: 0.025),
              boxShadow: isHl
                  ? [
                      BoxShadow(
                        color: SajuGold.g300.withValues(alpha: 0.28),
                        blurRadius: 22,
                      ),
                    ]
                  : null,
            ),
            child: ch == null
                ? const Text(
                    '—',
                    style: TextStyle(
                      fontFamily: SajuType.ui,
                      fontSize: 10,
                      color: SajuText.faint,
                    ),
                  )
                : shown
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        ch,
                        style: SajuType.hanja(cell * 0.5, highlight: isHl),
                      ),
                      if (elColor != null)
                        Positioned(
                          bottom: 5,
                          child: Container(
                            width: cell * 0.22,
                            height: 2,
                            decoration: BoxDecoration(
                              color: elColor.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  )
                : Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: SajuText.faint,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _RelationPainter extends CustomPainter {
  _RelationPainter({
    required this.relations,
    required this.cell,
    required this.gap,
  });
  final List<SajuVisualRelation> relations;
  final double cell;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in relations) {
      final x1 = r.columnA * (cell + gap) + cell / 2;
      final x2 = r.columnB * (cell + gap) + cell / 2;
      final depth = 12 + (r.columnB - r.columnA).abs() * 7;
      final path = Path()
        ..moveTo(x1, 0)
        ..cubicTo(x1, depth.toDouble(), x2, depth.toDouble(), x2, 0);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = r.isHap ? SajuRelationColor.hap : SajuRelationColor.chung;
      canvas.drawPath(path, paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: r.isHap ? '만남' : '부딪힘',
          style: TextStyle(
            fontFamily: SajuType.ui,
            fontSize: 9,
            color: r.isHap ? SajuGold.g300 : const Color(0xFFE08A7E),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset((x1 + x2) / 2 - textPainter.width / 2, depth - 1),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RelationPainter oldDelegate) => true;
}

/// 오행 조각(육각형).
class SajuElementShard extends StatelessWidget {
  const SajuElementShard({
    super.key,
    required this.element,
    this.size = 30,
    this.glow = false,
    this.label = true,
  });

  final String element; // wood/fire/earth/metal/water
  final double size;
  final bool glow;
  final bool label;

  @override
  Widget build(BuildContext context) {
    final color = SajuElementColor.of(element);
    return SizedBox(
      width: size,
      height: size * 1.15,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size * 1.15),
            painter: _ShardPainter(color: color, glow: glow),
          ),
          if (label && size >= 22)
            Opacity(
              opacity: 0.75,
              child: Text(
                SajuElementColor.hanjaOf(element),
                style: TextStyle(
                  fontFamily: SajuType.serif,
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.36,
                  color: SajuInk.i900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShardPainter extends CustomPainter {
  _ShardPainter({required this.color, required this.glow});
  final Color color;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 40;
    final sy = size.height / 46;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    final hex = Path()
      ..moveTo(p(20, 2).dx, p(20, 2).dy)
      ..lineTo(p(34, 13).dx, p(34, 13).dy)
      ..lineTo(p(34, 33).dx, p(34, 33).dy)
      ..lineTo(p(20, 44).dx, p(20, 44).dy)
      ..lineTo(p(6, 33).dx, p(6, 33).dy)
      ..lineTo(p(6, 13).dx, p(6, 13).dy)
      ..close();

    if (glow) {
      canvas.drawShadow(hex, color, 10, false);
    }

    final gradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.75),
          color.withValues(alpha: 0.9),
          color.withValues(alpha: 0.45),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(hex, gradient);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = color;
    canvas.drawPath(hex, strokePaint);

    final sidePath = Path()
      ..moveTo(p(20, 2).dx, p(20, 2).dy)
      ..lineTo(p(34, 13).dx, p(34, 13).dy)
      ..lineTo(p(34, 33).dx, p(34, 33).dy)
      ..lineTo(p(20, 23).dx, p(20, 23).dy)
      ..close();
    canvas.drawPath(
      sidePath,
      Paint()..color = Colors.black.withValues(alpha: 0.14),
    );

    canvas.drawLine(
      p(20, 2),
      p(20, 44),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ShardPainter oldDelegate) => false;
}

/// 오행 막대(근거 조각/상세 화면용 — 수치 미노출, 크기로만).
class SajuElementBars extends StatelessWidget {
  const SajuElementBars({
    super.key,
    required this.weighted,
    this.highlight,
    this.compact = false,
  });

  final Map<String, double> weighted;
  final String? highlight;
  final bool compact;

  static const _order = ['wood', 'fire', 'earth', 'metal', 'water'];

  @override
  Widget build(BuildContext context) {
    final max = weighted.values.isEmpty
        ? 1.0
        : weighted.values.reduce((a, b) => a > b ? a : b).clamp(0.0001, 1000);
    return SizedBox(
      height: compact ? 70 : 92,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _order.map((k) {
          final w = weighted[k] ?? 0;
          final isHl = highlight == k;
          return Expanded(
            child: Opacity(
              opacity: (highlight != null && !isHl) ? 0.45 : 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SajuElementShard(
                    element: k,
                    size: 14 + (w / max) * (compact ? 18 : 24),
                    glow: isHl,
                    label: false,
                  ),
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: SajuElementColor.hanjaOf(k),
                          style: TextStyle(
                            fontFamily: SajuType.serif,
                            fontSize: 12,
                            color: isHl ? SajuGold.g100 : SajuText.muted,
                          ),
                        ),
                        TextSpan(
                          text: ' ${SajuElementColor.koreanOf(k)}',
                          style: const TextStyle(
                            fontFamily: SajuType.ui,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 5단 음양 균형 게이지(사인 곡선 + 정착 점).
class SajuBalanceGauge extends StatelessWidget {
  const SajuBalanceGauge({super.key, required this.level, this.width = 240});

  final int level; // 0~4
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          SizedBox(
            width: width,
            height: 34,
            child: CustomPaint(
              painter: _BalanceCurvePainter(level: level, width: width),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (i) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= level ? SajuGold.g300 : SajuText.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 5),
          Row(
            children: const [
              Expanded(
                child: Text(
                  '약함',
                  style: SajuType.ui12,
                  textAlign: TextAlign.left,
                ),
              ),
              Expanded(child: SizedBox()),
              Expanded(
                child: Text(
                  '균형',
                  style: SajuType.ui12,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(child: SizedBox()),
              Expanded(
                child: Text(
                  '강함',
                  style: SajuType.ui12,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceCurvePainter extends CustomPainter {
  _BalanceCurvePainter({required this.level, required this.width});
  final int level;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i <= 40; i++) {
      final x = (i / 40) * width;
      final y = 17 + math.sin(i / 40 * 2 * math.pi) * 11;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final curvePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = SajuGold.g500.withValues(alpha: 0.6);
    canvas.drawPath(path, curvePaint);

    final dotX = (level / 4) * width;
    final dotPaint = Paint()..color = SajuGold.g100;
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: Offset(dotX, 17), radius: 5)),
      SajuGold.g300,
      6,
      false,
    );
    canvas.drawCircle(Offset(dotX, 17), 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _BalanceCurvePainter oldDelegate) =>
      oldDelegate.level != level;
}

/// 대운 별줄기(LuckStream).
class SajuLuckStream extends StatelessWidget {
  const SajuLuckStream({
    super.key,
    required this.luck,
    required this.current,
    this.highlight,
    this.width = 340,
  });

  final List<SajuVisualLuckEntry> luck;
  final int current;
  final int? highlight;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (luck.isEmpty) return SizedBox(width: width, height: 74);
    final step = luck.length > 1 ? width / (luck.length - 1) : width;
    return SizedBox(
      width: width,
      height: 74,
      child: Stack(
        children: [
          SizedBox(
            width: width,
            height: 40,
            child: CustomPaint(
              painter: _LuckLinePainter(
                luck: luck,
                current: current,
                highlight: highlight,
                step: step,
              ),
            ),
          ),
          ...List.generate(luck.length, (i) {
            final isCur = i == current;
            final isHl = i == highlight;
            return Positioned(
              top: 36,
              left: i * step - 26,
              width: 52,
              child: Column(
                children: [
                  Text(
                    luck[i].pillarHanja,
                    style: TextStyle(
                      fontFamily: SajuType.serif,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: (isCur || isHl) ? SajuGold.g100 : SajuText.muted,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isCur ? '지금' : luck[i].startYear.toString(),
                    style: TextStyle(
                      fontFamily: SajuType.ui,
                      fontSize: 9.5,
                      color: isCur ? SajuGold.g300 : SajuText.faint,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LuckLinePainter extends CustomPainter {
  _LuckLinePainter({
    required this.luck,
    required this.current,
    required this.highlight,
    required this.step,
  });
  final List<SajuVisualLuckEntry> luck;
  final int current;
  final int? highlight;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..strokeWidth = 1
      ..color = SajuText.line;
    canvas.drawLine(Offset(0, 20), Offset(size.width, 20), linePaint);

    final stopX = current * step;
    final goldPaint = Paint()
      ..strokeWidth = 1.4
      ..color = SajuGold.g300;
    canvas.drawLine(const Offset(0, 20), Offset(stopX, 20), goldPaint);

    for (var i = 0; i < luck.length; i++) {
      final x = i * step;
      final isCur = i == current;
      final isHl = i == highlight;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHl ? 1.4 : 1
        ..color = isHl ? SajuGold.g100 : SajuGold.g500;
      final fill = Paint()..color = isCur ? SajuGold.g100 : Colors.transparent;
      if (isCur) {
        canvas.drawShadow(
          Path()..addOval(Rect.fromCircle(center: Offset(x, 20), radius: 6)),
          SajuGold.g300,
          8,
          false,
        );
      }
      canvas.drawCircle(Offset(x, 20), isCur ? 6 : (isHl ? 5 : 3), fill);
      canvas.drawCircle(Offset(x, 20), isCur ? 6 : (isHl ? 5 : 3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LuckLinePainter oldDelegate) => true;
}
