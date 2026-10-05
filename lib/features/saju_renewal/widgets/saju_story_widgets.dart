import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import '../data/models/interpret_result.dart';
import '../data/models/topic_card.dart' show SajuRenewalScene;
import '../data/saju_visual_adapter.dart';
import '../theme/saju_dark_tokens.dart';
import 'saju_base_widgets.dart';
import 'saju_visual_widgets.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 핸드오프] 남은 공용 위젯 모음.
/// `design_files/saju/saju-components.jsx` 303~524행(TermText/Evidence/
/// SealedCard/SceneBg×5/GuidePlaceholder)을 Flutter로 1:1 포팅한다.
///
/// [Pouch 재사용 결정] 디자인 핸드오프의 `PouchComponents.jsx`는 wish_room
/// "복주머니" 적립 피처 전용 신규 컴포넌트이며 사주 화면에는 쓰이지 않는다
/// (사주 결과 접근은 기존 `result_access_gate_sheet.dart`가 이미 처리).
/// 따라서 사주 화면에서 파우치 아이콘이 필요하면 기존
/// `pouch_box/.../mini_pouch_icon.dart`를 그대로 재사용하고, 새 SVG Pouch는
/// 포팅하지 않는다(범위 밖 중복 방지).

// =====================================================================
// 공통: 점선(dash) 패스 유틸 — GuidePlaceholder/SealedCard 안쪽 테두리용.
// =====================================================================
Path _dashPath(Path source, {double dashLength = 4, double gapLength = 4}) {
  final dest = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    var draw = true;
    while (distance < metric.length) {
      final len = draw ? dashLength : gapLength;
      final next = math.min(distance + len, metric.length);
      if (draw) {
        dest.addPath(metric.extractPath(distance, next), Offset.zero);
      }
      distance = next;
      draw = !draw;
    }
  }
  return dest;
}

// =====================================================================
// 용어 텍스트 — [[key|쉬운 표현]] → 탭 시 1줄 보조설명(TermSheet) 오픈.
// =====================================================================

/// 용어 탭 콜백을 하위 트리에 전파하는 스코프.
/// 화면(STEP7+)에서 `SajuTermScope(onOpenTerm: (key) => showSajuTermSheet(...))`
/// 로 감싸면, 그 안의 모든 [SajuTermText]가 자동으로 연결된다.
class SajuTermScope extends InheritedWidget {
  const SajuTermScope({
    super.key,
    required this.onOpenTerm,
    required super.child,
  });

  final void Function(String termKey) onOpenTerm;

  static void Function(String termKey)? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<SajuTermScope>();
    return scope?.onOpenTerm;
  }

  @override
  bool updateShouldNotify(SajuTermScope oldWidget) =>
      oldWidget.onOpenTerm != onOpenTerm;
}

/// `[[termKey|쉬운 표현]]` 마크업을 파싱해 밑줄+물음표 뱃지가 달린 탭 가능
/// 텍스트로 렌더링한다. 매칭되지 않는 일반 텍스트는 [style] 그대로 출력.
class SajuTermText extends StatelessWidget {
  const SajuTermText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  static final RegExp _termPattern = RegExp(r'\[\[([^|\]]+)\|([^\]]+)\]\]');

  @override
  Widget build(BuildContext context) {
    final opener = SajuTermScope.maybeOf(context);
    final base = style ?? SajuType.body14;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _termPattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final key = m.group(1)!;
      final label = m.group(2)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: opener == null ? null : () => opener(key),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: SajuGold.g500, width: 1),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: RichText(
                    text: TextSpan(
                      style: base.copyWith(color: SajuGold.g100),
                      children: [
                        TextSpan(text: label),
                        TextSpan(
                          text: ' ?',
                          style: TextStyle(
                            fontSize: (base.fontSize ?? 14) * 0.6,
                            color: SajuGold.g500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      text: TextSpan(style: base, children: spans),
    );
  }
}

/// 용어 바텀시트("근거는 항상 1클릭" 원칙) — 쉬운 설명 1~2문장 + 닫기.
Future<void> showSajuTermSheet(
  BuildContext context, {
  required String termLabel,
  required String definition,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          decoration: BoxDecoration(
            color: SajuInk.i850,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SajuText.lineGold),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: SajuText.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('쉬운 설명', style: SajuType.mono9),
              const SizedBox(height: 8),
              Text(termLabel, style: SajuType.h2),
              const SizedBox(height: 10),
              Text(definition, style: SajuType.body14.copyWith(color: SajuText.fg2)),
              const SizedBox(height: 18),
              SajuButton(
                label: '확인',
                variant: SajuButtonVariant.secondary,
                height: 46,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// =====================================================================
// 근거 조각(Evidence) — type(grid|elements|luck)에 따라 시각화 위젯 전환.
// =====================================================================

/// 블록/미리보기 본문 하단에 붙는 "핵심 근거" 카드.
/// [profile]은 실제 사용자 사주로 계산된 [SajuVisualProfile](가짜 데모 데이터
/// 금지 원칙 — 어댑터를 통해서만 주입받는다).
class SajuEvidenceCard extends StatelessWidget {
  const SajuEvidenceCard({
    super.key,
    required this.evidence,
    required this.profile,
    this.label = '핵심 근거',
    this.compact = false,
  });

  final InterpretEvidence evidence;
  final SajuVisualProfile profile;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Widget visual;
    switch (evidence.type) {
      case 'grid':
        visual = SajuPillarGrid(
          pillars: profile.pillars,
          cell: compact ? 38 : 44,
          gap: 7,
          reveal: 8,
          highlightColumns: evidence.cols,
          showLabels: true,
        );
        break;
      case 'elements':
        visual = SizedBox(
          width: compact ? 220 : 260,
          child: SajuElementBars(
            weighted: profile.elementsWeighted,
            highlight: evidence.hl,
            compact: true,
          ),
        );
        break;
      case 'luck':
        visual = SajuLuckStream(
          luck: profile.luck,
          current: profile.luckCurrentIndex,
          highlight: int.tryParse(evidence.hl ?? ''),
          width: compact ? 250 : 270,
        );
        break;
      default:
        visual = const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 16,
        compact ? 14 : 16,
        compact ? 14 : 16,
        compact ? 16 : 18,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SajuText.lineGold),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SajuText.fg.withValues(alpha: 0.05),
            SajuViolet.v700.withValues(alpha: 0.35),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('◆', style: TextStyle(color: SajuGold.g300, fontSize: 10)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: SajuType.ui,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: SajuGold.g300,
                  letterSpacing: 0.06 * 11.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Container(height: 1, color: SajuText.line)),
            ],
          ),
          const SizedBox(height: 12),
          Center(child: visual),
          const SizedBox(height: 12),
          SajuTermText(
            text: evidence.text,
            style: const TextStyle(
              fontFamily: SajuType.ui,
              fontSize: 13.5,
              height: 1.6,
              color: SajuText.fg2,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// 봉인된 이야기 카드(SealedCard).
// =====================================================================

class SajuSealedCard extends StatelessWidget {
  const SajuSealedCard({
    super.key,
    this.width = 230,
    this.opening = false,
    this.tint = SajuGold.g300,
    this.small = false,
  });

  final double width;
  final bool opening;
  final Color tint;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final h = width * 1.36;
    final sealSize = small ? 40.0 : 54.0;
    return SizedBox(
      width: width,
      height: h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 카드 바탕.
          Container(
            width: width,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SajuText.lineGold),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [SajuViolet.v700, SajuViolet.v900],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 60,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(color: SajuGold.glow, blurRadius: 40),
              ],
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: RadialGradient(
                  center: const Alignment(0, -0.75),
                  radius: 1.0,
                  colors: [tint.withValues(alpha: 0.13), Colors.transparent],
                ),
              ),
            ),
          ),
          // 안쪽 실선 테두리.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: SajuGold.g500.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ),
          // 안쪽 점선 테두리.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: CustomPaint(
                painter: _DashedRRectPainter(
                  color: SajuGold.g500.withValues(alpha: 0.2),
                  radius: 8,
                ),
              ),
            ),
          ),
          // 모서리 다이아몬드 장식.
          const Positioned(
            left: 18,
            top: 16,
            child: Text('◆', style: TextStyle(color: SajuGold.g500, fontSize: 9)),
          ),
          const Positioned(
            right: 18,
            top: 16,
            child: Text('◆', style: TextStyle(color: SajuGold.g500, fontSize: 9)),
          ),
          const Positioned(
            left: 18,
            bottom: 16,
            child: Text('◆', style: TextStyle(color: SajuGold.g500, fontSize: 9)),
          ),
          const Positioned(
            right: 18,
            bottom: 16,
            child: Text('◆', style: TextStyle(color: SajuGold.g500, fontSize: 9)),
          ),
          Positioned(
            top: small ? 22 : 34,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'STORY · N°01',
                style: SajuType.mono9.copyWith(fontSize: small ? 8 : 9),
              ),
            ),
          ),
          // 중앙 팔괘 실루엣.
          Opacity(
            opacity: 0.55,
            child: IgnorePointer(
              child: SajuBagua(size: width * 0.7, speedSeconds: 200, intensity: 0.8),
            ),
          ),
          // 금빛 밀봉 라인 — 열림 시 좌우로 갈라짐.
          Positioned(
            left: 0,
            right: 0,
            top: h / 2 - 1,
            child: SizedBox(
              height: 2,
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: opening ? 0 : 1,
                      duration: SajuMotion.card,
                      curve: SajuMotion.easeSj,
                      child: AnimatedSlide(
                        offset: opening ? const Offset(-0.6, 0) : Offset.zero,
                        duration: SajuMotion.card,
                        curve: SajuMotion.easeSj,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, SajuGold.g300],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: opening ? 0 : 1,
                      duration: SajuMotion.card,
                      curve: SajuMotion.easeSj,
                      child: AnimatedSlide(
                        offset: opening ? const Offset(0.6, 0) : Offset.zero,
                        duration: SajuMotion.card,
                        curve: SajuMotion.easeSj,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [SajuGold.g300, Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 봉인 인장.
          AnimatedScale(
            scale: opening ? 1.6 : 1,
            duration: SajuMotion.card,
            curve: SajuMotion.easeSj,
            child: AnimatedOpacity(
              opacity: opening ? 0 : 1,
              duration: SajuMotion.card,
              curve: SajuMotion.easeSj,
              child: AnimatedRotation(
                turns: opening ? 20 / 360 : 0,
                duration: SajuMotion.card,
                curve: SajuMotion.easeSj,
                child: Container(
                  width: sealSize,
                  height: sealSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.4),
                      colors: [SajuGold.g100, SajuGold.g300, SajuGold.g500],
                      stops: [0.0, 0.45, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(color: SajuGold.g300.withValues(alpha: 0.6), blurRadius: 24),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '命',
                    style: TextStyle(
                      fontFamily: SajuType.serif,
                      fontWeight: FontWeight.w900,
                      fontSize: small ? 18 : 24,
                      color: const Color(0xFF3A2A12),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (opening)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: opening ? 1 : 0,
                  duration: SajuMotion.card,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: RadialGradient(
                        colors: [
                          SajuGold.g100.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.6],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = _dashPath(Path()..addRRect(rrect), dashLength: 4, gapLength: 4);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) => false;
}

// =====================================================================
// 주제군 장면 배경(SceneBg) — 5종.
// =====================================================================

/// 화면 안에서 `Stack`의 맨 아래 레이어로 깔리는 주제군 배경.
/// 그라데이션 조명 + 별 필드 + 주제별 고유 SVG 모티프(파형/상승곡선/
/// 달·심장박동/산 능선/촛불) 로 구성된다.
class SajuSceneBg extends StatefulWidget {
  const SajuSceneBg({super.key, required this.scene, this.strength = 1});

  final SajuRenewalScene scene;
  final double strength;

  @override
  State<SajuSceneBg> createState() => _SajuSceneBgState();
}

class _SajuSceneBgState extends State<SajuSceneBg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  SajuScene get _token {
    switch (widget.scene) {
      case SajuRenewalScene.money:
        return SajuScene.money;
      case SajuRenewalScene.talent:
        return SajuScene.talent;
      case SajuRenewalScene.love:
        return SajuScene.love;
      case SajuRenewalScene.life:
        return SajuScene.life;
      case SajuRenewalScene.guin:
        return SajuScene.guin;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = _token.tint;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [SajuInk.i850, SajuInk.i900, SajuInk.i900],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -1),
                radius: 1.1,
                colors: [tint.withValues(alpha: 0.15), Colors.transparent],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 1),
                radius: 0.9,
                colors: [tint.withValues(alpha: 0.08), Colors.transparent],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
          SajuStarField(count: 28, seed: widget.scene.index + 3, opacity: 0.5),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 300,
            child: Opacity(
              opacity: 0.9 * widget.strength,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _scenePainterFor(widget.scene, tint, _controller.value),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

CustomPainter _scenePainterFor(SajuRenewalScene scene, Color tint, double t) {
  switch (scene) {
    case SajuRenewalScene.money:
      return _SceneMoneyPainter(tint: tint, t: t);
    case SajuRenewalScene.talent:
      return _SceneTalentPainter(tint: tint, t: t);
    case SajuRenewalScene.love:
      return _SceneLovePainter(tint: tint, t: t);
    case SajuRenewalScene.life:
      return _SceneLifePainter(tint: tint, t: t);
    case SajuRenewalScene.guin:
      return _SceneGuinPainter(tint: tint, t: t);
  }
}

/// 공통 기준 캔버스 402×300(design handoff viewBox)에 맞춰 스케일.
class _SceneBasePainter extends CustomPainter {
  _SceneBasePainter(this.t);
  final double t;

  @override
  bool shouldRepaint(covariant _SceneBasePainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {}
}

/// 재물 — 우측 상단 달빛 웅덩이 + 잔물결 파형 + 반짝이는 윤슬.
class _SceneMoneyPainter extends _SceneBasePainter {
  _SceneMoneyPainter({required this.tint, required double t}) : super(t);
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 402, sy = size.height / 300;
    final cx = 290 * sx, cy = 150 * sy;
    final double r = 70.0 * math.min(sx, sy);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [tint.withValues(alpha: 0.55), tint.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, glow);

    for (var i = 0; i < 3; i++) {
      final y = (200 + i * 18) * sy;
      final phase = t * 2 * math.pi + i * 0.6;
      final path = Path();
      for (var k = 0; k <= 14; k++) {
        final x = k * (402 / 14) * sx;
        final wy = y + math.sin(k * 0.9 + phase) * 6 * sy;
        if (k == 0) {
          path.moveTo(x, wy);
        } else {
          path.lineTo(x, wy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = tint.withValues(alpha: 0.35 - i * 0.08),
      );
    }

    for (var i = 0; i < 22; i++) {
      final a = i * 2.4;
      final r2 = (6 + (i % 7) * 6) * math.min(sx, sy);
      final px = cx + math.cos(a) * r2;
      final py = cy + math.sin(a) * r2 * 0.8;
      final twinkle = 0.5 + 0.5 * math.sin(t * 2 * math.pi * (1 + i % 4) + i);
      canvas.drawCircle(
        Offset(px, py),
        (0.8 + (i % 3) * 0.6) * math.min(sx, sy),
        Paint()..color = tint.withValues(alpha: twinkle.clamp(0.0, 1.0)),
      );
    }
  }
}

/// 재능·직업 — 좌하단에서 우상단으로 상승하는 궤적선 + 빛나는 정상 점.
class _SceneTalentPainter extends _SceneBasePainter {
  _SceneTalentPainter({required this.tint, required double t}) : super(t);
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 402, sy = size.height / 300;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    final path = Path()
      ..moveTo(p(20, 250).dx, p(20, 250).dy)
      ..cubicTo(p(120, 240).dx, p(120, 240).dy, p(160, 150).dx, p(160, 150).dy, p(250, 130).dx, p(250, 130).dy)
      ..cubicTo(p(300, 120).dx, p(300, 120).dy, p(360, 110).dx, p(360, 110).dy, p(370, 70).dx, p(370, 70).dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [tint.withValues(alpha: 0), tint.withValues(alpha: 0.7), Colors.white],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final pulse = 0.6 + 0.4 * (0.5 - 0.5 * math.cos(t * 2 * math.pi * 2));
    final end = p(370, 70);
    canvas.drawCircle(
      end,
      4 * math.min(sx, sy) * (0.85 + pulse * 0.3),
      Paint()..color = Colors.white.withValues(alpha: pulse.clamp(0.0, 1.0)),
    );

    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = tint.withValues(alpha: 0.2);
    for (final pos in const [[80.0, 280.0], [200.0, 290.0], [320.0, 286.0]]) {
      canvas.drawLine(p(pos[0], pos[1]), p(pos[0] + 30, pos[1] - 4), tickPaint);
    }
  }
}

/// 연애·인연 — 두 개의 빛(달·별)을 잇는 곡선과 심장박동처럼 뛰는 점.
class _SceneLovePainter extends _SceneBasePainter {
  _SceneLovePainter({required this.tint, required double t}) : super(t);
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 402, sy = size.height / 300;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    final path = Path()
      ..moveTo(p(110, 110).dx, p(110, 110).dy)
      ..quadraticBezierTo(p(200, 190).dx, p(200, 190).dy, p(300, 90).dx, p(300, 90).dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = tint.withValues(alpha: 0.7),
    );

    for (final spec in const [[110.0, 110.0, 5.0, 3.0], [300.0, 90.0, 6.0, 4.0]]) {
      final c = p(spec[0], spec[1]);
      final baseR = spec[2] * math.min(sx, sy);
      canvas.drawCircle(
        c,
        baseR * 4,
        Paint()..color = tint.withValues(alpha: 0.08),
      );
      final pulse = 0.7 + 0.3 * (0.5 - 0.5 * math.cos(t * 2 * math.pi * spec[3]));
      canvas.drawCircle(
        c,
        baseR * pulse,
        Paint()..color = Colors.white.withValues(alpha: pulse.clamp(0.0, 1.0)),
      );
    }
  }
}

/// 인생 흐름 — 저무는 해/달과 겹겹이 이어진 산 능선, 길을 따라 걷는 점선.
class _SceneLifePainter extends _SceneBasePainter {
  _SceneLifePainter({required this.tint, required double t}) : super(t);
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 402, sy = size.height / 300;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    canvas.drawCircle(
      p(310, 70),
      22 * math.min(sx, sy),
      Paint()..color = tint.withValues(alpha: 0.85),
    );
    canvas.drawCircle(p(318, 64), 20 * math.min(sx, sy), Paint()..color = SajuInk.i850);

    Path ridge(List<List<double>> pts) {
      final path = Path()..moveTo(p(pts.first[0], pts.first[1]).dx, p(pts.first[0], pts.first[1]).dy);
      for (final pt in pts.skip(1)) {
        path.lineTo(p(pt[0], pt[1]).dx, p(pt[0], pt[1]).dy);
      }
      path.lineTo(p(402, 300).dx, p(402, 300).dy);
      path.lineTo(p(0, 300).dx, p(0, 300).dy);
      path.close();
      return path;
    }

    canvas.drawPath(
      ridge(const [[0, 230], [60, 190], [110, 215], [180, 160], [240, 205], [300, 175], [402, 225]]),
      Paint()..color = const Color(0xFF1D1C22),
    );
    canvas.drawPath(
      ridge(const [[0, 260], [80, 232], [150, 250], [230, 220], [320, 248], [402, 236]]),
      Paint()..color = const Color(0xFF17161B),
    );

    final trail = Path()
      ..moveTo(p(40, 300).dx, p(40, 300).dy)
      ..cubicTo(p(120, 270).dx, p(120, 270).dy, p(150, 248).dx, p(150, 248).dy, p(200, 240).dx, p(200, 240).dy)
      ..cubicTo(p(250, 234).dx, p(250, 234).dy, p(280, 226).dx, p(280, 226).dy, p(300, 214).dx, p(300, 214).dy);
    final dashed = _dashPath(trail, dashLength: 3, gapLength: 4);
    canvas.drawPath(
      dashed,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = tint.withValues(alpha: 0.5),
    );
    canvas.drawLine(p(300, 214), p(300, 200), Paint()..color = tint.withValues(alpha: 0.7));
    canvas.drawRect(Rect.fromLTWH(p(300, 200).dx, p(300, 200).dy, 12 * sx, 6 * sy), Paint()..color = tint.withValues(alpha: 0.7));
  }
}

/// 귀인 — 흔들리는 촛불과 번지는 안개(기댈 수 있는 인연의 온기).
class _SceneGuinPainter extends _SceneBasePainter {
  _SceneGuinPainter({required this.tint, required double t}) : super(t);
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 402, sy = size.height / 300;
    Offset p(double x, double y) => Offset(x * sx, y * sy);
    final flicker = 0.75 + 0.25 * math.sin(t * 2 * math.pi * 3.4);

    canvas.drawCircle(
      p(290, 140),
      90 * math.min(sx, sy) * flicker,
      Paint()..color = tint.withValues(alpha: 0.5 * flicker),
    );
    canvas.drawLine(p(290, 70), p(290, 112), Paint()..color = tint.withValues(alpha: 0.5));

    final body = Path()
      ..moveTo(p(276, 112).dx, p(276, 112).dy)
      ..lineTo(p(304, 112).dx, p(304, 112).dy)
      ..lineTo(p(308, 150).dx, p(308, 150).dy)
      ..quadraticBezierTo(p(290, 160).dx, p(290, 160).dy, p(272, 150).dx, p(272, 150).dy)
      ..close();
    canvas.drawPath(body, Paint()..color = tint.withValues(alpha: 0.25));
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = tint.withValues(alpha: 0.8),
    );

    canvas.drawOval(
      Rect.fromCenter(center: p(290, 134), width: 12 * sx * flicker, height: 18 * sy * flicker),
      Paint()..color = const Color(0xFFFFF8DD),
    );

    for (var i = 0; i < 3; i++) {
      final fog = 0.5 + 0.5 * math.sin(t * 2 * math.pi + i * 1.3);
      canvas.drawOval(
        Rect.fromCenter(
          center: p(200, 200 + i * 26 + fog * 6),
          width: 520 * sx,
          height: 28 * sy,
        ),
        Paint()..color = SajuGold.g100.withValues(alpha: (0.035 + i * 0.01) * (0.6 + 0.4 * fog)),
      );
    }
  }
}

// =====================================================================
// 안내자 캐릭터 자리(GuidePlaceholder) — 민세레나 실제 에셋 대체 플레이스홀더.
// =====================================================================

class SajuGuidePlaceholder extends StatelessWidget {
  const SajuGuidePlaceholder({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: SajuText.card,
              border: Border.all(color: SajuText.line),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomRight: Radius.circular(4),
                bottomLeft: Radius.circular(14),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: SajuType.ui,
                fontSize: 12,
                height: 1.5,
                color: SajuText.fg2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(56, 56),
                painter: _GuideAvatarPainter(),
              ),
              Text(
                '민세레나\n에셋',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: SajuType.mono,
                  fontSize: 7,
                  color: SajuGold.g500,
                  height: 1.3,
                  letterSpacing: 0.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideAvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final clipPath = Path()..addOval(rect);
    canvas.save();
    canvas.clipPath(clipPath);
    // 45도 해치 패턴.
    final hatchPaint = Paint()
      ..color = SajuText.fg.withValues(alpha: 0.04)
      ..strokeWidth = 4;
    for (double x = -size.height; x < size.width + size.height; x += 8) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), hatchPaint);
    }
    canvas.restore();

    final dashed = _dashPath(Path()..addOval(rect.deflate(0.5)), dashLength: 3, gapLength: 3);
    canvas.drawPath(
      dashed,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = SajuGold.g500,
    );
  }

  @override
  bool shouldRepaint(covariant _GuideAvatarPainter oldDelegate) => false;
}

/// 데스크톱 프리뷰 등에서 마우스 드래그로도 스크롤되도록 하는 스크롤 동작
/// (모바일 터치 전용 프로젝트지만 웹 프리뷰 QA 편의를 위해 포함).
class SajuWebScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
