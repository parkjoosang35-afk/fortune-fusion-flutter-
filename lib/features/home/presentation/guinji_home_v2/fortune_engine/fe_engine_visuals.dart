// ═══════════════════════════════════════════════════════════════
// FILE: fe_engine_visuals.dart
// [운세 엔진 디자인 핸드오프] 엔진별 CustomPaint 시각화 + 히어로 오빗.
// 출처: design_files/engine-vis.jsx (SajuVis/GuiinVis/TarotVis/FaceVis/
// PalmVis/HeroOrbit)를 Flutter CustomPaint/Widget으로 포팅.
//
// [이미지/스톡사진 금지 원칙 준수] 전부 CustomPaint 또는 텍스트/Container
// 기반이며 외부 이미지 에셋을 전혀 사용하지 않는다(README 명시 원칙).
// 이 파일의 "예시 명식"(辛巳/庚辰/辛巳/庚午)과 각 측정값은 디자인
// 핸드오프에 포함된 데모용 고정 예시이며, 실제 사용자의 사주 계산
// 결과가 아니다 — 정통사주 엔진의 실제 계산 로직을 재구현하지 않는다.
// ═══════════════════════════════════════════════════════════════
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'fe_data.dart';
import 'fe_tokens.dart';
import 'fe_widgets.dart';

/// ---------------- 01 정통사주 시각화 ----------------
class FeSajuVis extends StatefulWidget {
  const FeSajuVis({super.key});
  @override
  State<FeSajuVis> createState() => _FeSajuVisState();
}

class _FeSajuVisState extends State<FeSajuVis> {
  bool _go = false;
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _go = true);
    });
  }

  static const _pillars = [
    ['時', '辛', '巳'],
    ['日', '庚', '辰'],
    ['月', '辛', '巳'],
    ['年', '庚', '午'],
  ];
  static const _el = {'辛': '金', '庚': '金', '巳': '火', '辰': '土', '午': '火'};
  static const _cnt = {'木': 0, '火': 3, '土': 1, '金': 4, '水': 0};
  static const _oh = [
    ['木', FeColors.wood],
    ['火', FeColors.fire],
    ['土', FeColors.earth],
    ['金', FeColors.metal],
    ['水', FeColors.water],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: _pillars.map((p) {
            final lab = p[0], g = p[1], j = p[2];
            final isMe = lab == '日';
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  children: [
                    Text(
                      '$lab柱',
                      style: const TextStyle(
                        fontFamily: FeFonts.mono,
                        fontSize: 9.5,
                        letterSpacing: 1.5,
                        color: FeColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _FePillarCell(char: g, element: _el[g]!, highlight: isMe),
                    const SizedBox(height: 5),
                    _FePillarCell(char: j, element: _el[j]!, highlight: isMe),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        const Text(
          '예시 명식 · 일간(日干) = 나',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: FeFonts.mono,
            fontSize: 9,
            color: FeColors.muted,
          ),
        ),
        const SizedBox(height: 14),
        ..._oh.map((e) {
          final k = e[0] as String;
          final c = e[1] as Color;
          final v = _cnt[k]!;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    k,
                    style: TextStyle(
                      fontFamily: FeFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: c,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutCubic,
                        width:
                            (_go ? (math.max(v, 0.08) / 4) : 0) *
                            (MediaQuery.of(context).size.width - 90),
                        height: 8,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [BoxShadow(color: c, blurRadius: 10)],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 20,
                  child: Text(
                    '$v',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: FeColors.muted),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _FePillarCell extends StatelessWidget {
  final String char, element;
  final bool highlight;
  const _FePillarCell({
    required this.char,
    required this.element,
    required this.highlight,
  });
  @override
  Widget build(BuildContext context) {
    final color = switch (element) {
      '木' => FeColors.wood,
      '火' => FeColors.fire,
      '土' => FeColors.earth,
      '金' => FeColors.metal,
      _ => FeColors.water,
    };
    return Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? FeColors.glow : FeColors.line,
          width: highlight ? 1.5 : 1,
        ),
        color: Colors.black.withValues(alpha: 0.25),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            char,
            style: TextStyle(
              fontFamily: FeFonts.display,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: color,
            ),
          ),
          Positioned(
            right: 4,
            bottom: 3,
            child: Text(
              element,
              style: TextStyle(
                fontSize: 9,
                color: color.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------- 02 귀인지도 시각화 ----------------
class FeGuiinVis extends StatelessWidget {
  const FeGuiinVis({super.key});
  static const _slots = [
    ['年', '사회', true],
    ['月', '직장', true],
    ['日', '나', false],
    ['時', '미래', true],
  ];
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const FeSigil(
            size: 190,
            color: FeColors.guiin,
            opacity: 0.5,
            period: Duration(seconds: 80),
          ),
          ..._slots.asMap().entries.map((entry) {
            final i = entry.key;
            final h = entry.value[0] as String;
            final s = entry.value[1] as String;
            final lit = entry.value[2] as bool;
            final a = -math.pi / 2 + i * math.pi / 2;
            const r = 74.0;
            return Positioned(
              left: 100 + math.cos(a) * r - 17,
              top: 100 + math.sin(a) * r - 17,
              child: Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: lit
                          ? FeColors.guiin.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.5),
                      border: Border.all(
                        color: lit ? FeColors.guiin : FeColors.line,
                      ),
                    ),
                    child: Text(
                      h,
                      style: TextStyle(
                        fontFamily: FeFonts.display,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: lit ? const Color(0xFFD8F0FA) : FeColors.fg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lit ? '$s ★' : s,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: FeColors.muted,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '貴人',
                style: TextStyle(
                  fontFamily: FeFonts.display,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Color(0xFFD8F0FA),
                ),
              ),
              SizedBox(height: 6),
              Text(
                '天乙·文昌',
                style: TextStyle(
                  fontFamily: FeFonts.mono,
                  fontSize: 8,
                  letterSpacing: 2,
                  color: FeColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ---------------- 03 타로 시각화 ----------------
class FeTarotVis extends StatelessWidget {
  const FeTarotVis({super.key});
  static const _cards = [
    ['過去', '♦', '펜타클 에이스', -8.0, 0.0],
    ['現在', '♥', '컵 2', 0.0, -8.0],
    ['未來', '⚔', '소드 나이트', 8.0, 0.0],
  ];
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _cards.map((c) {
          final pos = c[0] as String,
              sym = c[1] as String,
              name = c[2] as String;
          final rot = c[3] as double, ty = c[4] as double;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Transform.translate(
              offset: Offset(0, ty),
              child: Transform.rotate(
                angle: rot * math.pi / 180,
                child: Container(
                  width: 78,
                  height: 128,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: FeColors.tarot),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF2A2050), Color(0xFF150C2C)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: FeColors.tarot.withValues(alpha: 0.25),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pos,
                        style: const TextStyle(
                          fontFamily: FeFonts.mono,
                          fontSize: 8,
                          letterSpacing: 2,
                          color: FeColors.muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        sym,
                        style: TextStyle(
                          fontSize: 26,
                          color: FeColors.tarot,
                          shadows: [
                            Shadow(color: FeColors.tarot, blurRadius: 12),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: FeFonts.body,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// ---------------- 04 관상 시각화 ----------------
class FeFaceVis extends StatelessWidget {
  const FeFaceVis({super.key});
  static const _rows = [
    ['上停 · 이마', 32.4],
    ['中停 · 눈·코', 33.1],
    ['下停 · 입·턱', 34.5],
  ];
  @override
  Widget build(BuildContext context) {
    const c = FeColors.face;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          height: 144,
          child: CustomPaint(painter: _FeFacePainter(color: c)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._rows.map((r) {
                final label = r[0] as String, v = r[1] as double;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: FeColors.fg,
                            ),
                          ),
                          Text(
                            '$v%',
                            style: const TextStyle(
                              fontFamily: FeFonts.mono,
                              fontSize: 12,
                              color: c,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (v * 2.4 / 100).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: FeColors.muted,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: '재백궁(코) 폭 '),
                    const TextSpan(
                      text: '20%',
                      style: TextStyle(color: c, fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' · 인당 · 관록궁 측정'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeFacePainter extends CustomPainter {
  final Color color;
  _FeFacePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 130, sy = size.height / 170;
    Offset p(double x, double y) => Offset(x * sx, y * sy);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.6);
    final fill = Paint()..color = color.withValues(alpha: 0.08);
    canvas.drawOval(
      Rect.fromCenter(center: p(65, 88), width: 96 * sx, height: 136 * sy),
      fill,
    );
    canvas.drawOval(
      Rect.fromCenter(center: p(65, 88), width: 96 * sx, height: 136 * sy),
      outline,
    );
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.7);
    for (final y in [22.0, 62.0, 112.0, 156.0]) {
      _drawDashedLine(canvas, p(6, y), p(124, y), dash);
    }
    final feature = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = FeColors.fg.withValues(alpha: 0.7);
    canvas.drawCircle(p(65, 76), 3, feature);
    canvas.drawLine(p(52, 110), p(78, 110), feature..strokeWidth = 1.5);
    final dots = Paint()..color = FeColors.glowLight;
    for (final d in [
      [40.0, 72.0],
      [90.0, 72.0],
      [65.0, 104.0],
      [54.0, 128.0],
      [76.0, 128.0],
      [65.0, 64.0],
    ]) {
      canvas.drawCircle(p(d[0], d[1]), 1.8, dots);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashW = 3.0, gapW = 3.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var dist = 0.0;
    while (dist < total) {
      final next = math.min(dist + dashW, total);
      canvas.drawLine(a + dir * dist, a + dir * next, paint);
      dist = next + gapW;
    }
  }

  @override
  bool shouldRepaint(covariant _FeFacePainter oldDelegate) => false;
}

/// ---------------- 05 손금 시각화 ----------------
class FePalmVis extends StatelessWidget {
  const FePalmVis({super.key});
  static const _lines = [
    ['생명선', FeColors.wood, '휘어짐 0.071'],
    ['지혜선', FeColors.water, '길이·분지'],
    ['감정선', FeColors.fire, '끊김·곡률'],
    ['운명선', FeColors.glow, '손폭의 0.62배'],
  ];
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          width: 110,
          height: 144,
          child: CustomPaint(painter: _FePalmPainter()),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: _lines.map((l) {
              final name = l[0] as String,
                  c = l[1] as Color,
                  v = l[2] as String;
              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: FeColors.line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 2,
                          decoration: BoxDecoration(
                            color: c,
                            boxShadow: [BoxShadow(color: c, blurRadius: 6)],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: FeColors.fg,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      v,
                      style: const TextStyle(
                        fontFamily: FeFonts.mono,
                        fontSize: 10.5,
                        color: FeColors.muted,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _FePalmPainter extends CustomPainter {
  const _FePalmPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 140, sy = size.height / 180;
    final handPath = Path()
      ..moveTo(30 * sx, 170 * sy)
      ..lineTo(28 * sx, 90 * sy)
      ..quadraticBezierTo(26 * sx, 70 * sy, 34 * sx, 62 * sy)
      ..lineTo(36 * sx, 18 * sy)
      ..quadraticBezierTo(42 * sx, 10 * sy, 48 * sx, 18 * sy)
      ..lineTo(50 * sx, 56 * sy)
      ..lineTo(56 * sx, 10 * sy)
      ..quadraticBezierTo(62 * sx, 2 * sy, 68 * sx, 10 * sy)
      ..lineTo(70 * sx, 54 * sy)
      ..lineTo(78 * sx, 12 * sy)
      ..quadraticBezierTo(84 * sx, 4 * sy, 90 * sx, 12 * sy)
      ..lineTo(90 * sx, 58 * sy)
      ..lineTo(98 * sx, 26 * sy)
      ..quadraticBezierTo(104 * sx, 18 * sy, 110 * sx, 26 * sy)
      ..lineTo(108 * sx, 90 * sy)
      ..quadraticBezierTo(122 * sx, 80 * sy, 130 * sx, 92 * sy)
      ..quadraticBezierTo(120 * sx, 120 * sy, 104 * sx, 140 * sy)
      ..lineTo(100 * sx, 170 * sy)
      ..close();
    canvas.drawPath(
      handPath,
      Paint()..color = FeColors.wood.withValues(alpha: 0.08),
    );
    canvas.drawPath(
      handPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = FeColors.wood.withValues(alpha: 0.6),
    );
    void line(Color c, Path path) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..color = c,
      );
    }

    line(
      FeColors.wood,
      Path()
        ..moveTo(58 * sx, 150 * sy)
        ..quadraticBezierTo(30 * sx, 110 * sy, 46 * sx, 62 * sy),
    );
    line(
      FeColors.water,
      Path()
        ..moveTo(48 * sx, 92 * sy)
        ..quadraticBezierTo(80 * sx, 96 * sy, 104 * sx, 112 * sy),
    );
    line(
      FeColors.fire,
      Path()
        ..moveTo(44 * sx, 74 * sy)
        ..quadraticBezierTo(80 * sx, 60 * sy, 116 * sx, 70 * sy),
    );
    line(
      FeColors.glow,
      Path()
        ..moveTo(80 * sx, 158 * sy)
        ..quadraticBezierTo(78 * sx, 110 * sy, 74 * sx, 56 * sy),
    );
  }

  @override
  bool shouldRepaint(covariant _FePalmPainter oldDelegate) => false;
}

final Map<FeEngineId, Widget Function()> feEngineVis = {
  FeEngineId.s: () => const FeSajuVis(),
  FeEngineId.g: () => const FeGuiinVis(),
  FeEngineId.t: () => const FeTarotVis(),
  FeEngineId.f: () => const FeFaceVis(),
  FeEngineId.p: () => const FePalmVis(),
};

/// ---------------- 히어로 오빗: 5개 엔진이 1개의 對照를 둘러싼다 ----------------
class FeHeroOrbit extends StatefulWidget {
  const FeHeroOrbit({super.key});
  @override
  State<FeHeroOrbit> createState() => _FeHeroOrbitState();
}

class _FeHeroOrbitState extends State<FeHeroOrbit>
    with TickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: FeMotion.orbitRing,
  )..repeat();
  late final AnimationController _core = AnimationController(
    vsync: this,
    duration: FeMotion.corePulse,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ring.dispose();
    _core.dispose();
    super.dispose();
  }

  static const _r = 104.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const FeSigil(size: 280, color: FeColors.glow, opacity: 0.5),
          AnimatedBuilder(
            animation: _ring,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(280, 280),
                painter: _FeOrbitRingPainter(turns: _ring.value),
              );
            },
          ),
          ...feEngines.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final a = -math.pi / 2 + i * 2 * math.pi / 5;
            return AnimatedBuilder(
              animation: _ring,
              builder: (context, _) {
                final rot = _ring.value * 2 * math.pi;
                final x = math.cos(a + rot) * _r;
                final y = math.sin(a + rot) * _r;
                return Positioned(
                  left: 140 + x - 30,
                  top: 140 + y - 30,
                  child: Transform.rotate(
                    angle: -rot,
                    child: Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            e.color.withValues(alpha: 0.3),
                            FeColors.bg2,
                          ],
                          stops: const [0, 0.75],
                        ),
                        border: Border.all(color: e.color),
                        boxShadow: [
                          BoxShadow(
                            color: e.color.withValues(alpha: 0.5),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e.hanja,
                            style: TextStyle(
                              fontFamily: FeFonts.display,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: e.color,
                              shadows: [Shadow(color: e.color, blurRadius: 8)],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e.short,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: FeColors.fg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          AnimatedBuilder(
            animation: _core,
            builder: (context, _) {
              final glowA = 0.35 + _core.value * 0.2;
              return Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      FeColors.glow.withValues(alpha: 0.4),
                      FeColors.bg1.withValues(alpha: 0.95),
                    ],
                    stops: const [0, 0.7],
                  ),
                  border: Border.all(color: FeColors.glow),
                  boxShadow: [
                    BoxShadow(
                      color: FeColors.glow.withValues(alpha: glowA),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '對照',
                      style: TextStyle(
                        fontFamily: FeFonts.display,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: Color(0xFFFFF3CF),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'CROSS · CHECK',
                      style: TextStyle(
                        fontFamily: FeFonts.mono,
                        fontSize: 7,
                        letterSpacing: 1.4,
                        color: FeColors.glow,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeOrbitRingPainter extends CustomPainter {
  final double turns;
  _FeOrbitRingPainter({required this.turns});
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const r = _FeHeroOrbitState._r;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = FeColors.glow.withValues(alpha: 0.25);
    canvas.drawCircle(center, r, ring);
    final rot = turns * 2 * math.pi;
    final pts = List.generate(5, (i) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5 + rot;
      return center + Offset(math.cos(a), math.sin(a)) * r;
    });
    final colors = feEngines.map((e) => e.color).toList();
    for (var i = 0; i < 5; i++) {
      canvas.drawLine(
        center,
        pts[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = colors[i].withValues(alpha: 0.45),
      );
    }
    final pentaPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = FeColors.glow.withValues(alpha: 0.18);
    for (var i = 0; i < 5; i++) {
      canvas.drawLine(pts[i], pts[(i + 2) % 5], pentaPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FeOrbitRingPainter oldDelegate) =>
      oldDelegate.turns != turns;
}
