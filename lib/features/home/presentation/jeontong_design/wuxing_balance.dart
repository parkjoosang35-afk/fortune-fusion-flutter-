// ============================================================
// 오행(五行) 밸런스 — 레이더 차트 + 막대 그래프. 정통사주 전용
// Dawn Hanji 디자인.
//
// [재계산 금지 원칙] 레거시 `saju_engine.dart`의
// `SajuResult.fiveElementsCount`(Map<String,int>, 키가 이미 한글
// '목'/'화'/'토'/'금'/'수')를 그대로 받는다 — 별도 카운팅 로직을 새로
// 만들지 않는다.
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'hanji_card.dart';
import 'hanji_design_tokens.dart';

const List<String> _kWuxingOrder = ['목', '화', '토', '금', '수'];

class WuxingBalance extends StatelessWidget {
  /// key: '목'|'화'|'토'|'금'|'수' — [SajuResult.fiveElementsCount]와 동일.
  final Map<String, int> counts;

  const WuxingBalance({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    final maxV = counts.values.fold<int>(0, math.max);

    return HanjiCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(painter: _PentagonPainter(counts: counts)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (final el in _kWuxingOrder) ...[
                      _WuxingBar(
                        el: el,
                        count: counts[el] ?? 0,
                        max: maxV == 0 ? 1 : maxV,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: HanjiColors.line, height: 24),
          Wrap(spacing: 6, runSpacing: 6, children: _chips(counts)),
        ],
      ),
    );
  }

  List<Widget> _chips(Map<String, int> c) {
    final chips = <Widget>[];
    final entries = c.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isNotEmpty && entries.first.value >= 3) {
      chips.add(
        _Chip('${entries.first.key} 과다 · ${entries.first.value}', tone: 'warn'),
      );
    }
    if (entries.isNotEmpty && entries.last.value == 0) {
      chips.add(_Chip('${entries.last.key} 부재 · 0', tone: 'muted'));
    }
    if (chips.isEmpty) chips.add(const _Chip('오행 균형'));
    return chips;
  }
}

class _WuxingBar extends StatelessWidget {
  final String el;
  final int count;
  final int max;
  const _WuxingBar({required this.el, required this.count, required this.max});

  static const Map<String, String> _labelKr = {
    '목': '나무',
    '화': '불',
    '토': '흙',
    '금': '쇠',
    '수': '물',
  };

  @override
  Widget build(BuildContext context) {
    final color = HanjiColors.wuxingColor(el);
    final label = _labelKr[el] ?? el;
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            el,
            style: HanjiTextStyles.display1(
              color: color,
            ).copyWith(fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: HanjiTextStyles.bodyTitle().copyWith(fontSize: 10),
                  ),
                  Text(
                    '$count개',
                    style: HanjiTextStyles.bodySmall().copyWith(fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: count / max,
                  minHeight: 4,
                  backgroundColor: const Color(
                    0xFF8B5A2B,
                  ).withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PentagonPainter extends CustomPainter {
  final Map<String, int> counts;
  _PentagonPainter({required this.counts});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide * 0.38;
    final maxV = counts.values.fold<int>(0, math.max).clamp(1, 999);

    Offset pt(int i, double radius) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      return center + Offset(math.cos(a), math.sin(a)) * radius;
    }

    for (final f in const [0.33, 0.66, 1.0]) {
      final path = Path();
      for (int i = 0; i < 5; i++) {
        final p = pt(i, r * f);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF8B5A2B).withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }
    for (int i = 0; i < 5; i++) {
      canvas.drawLine(
        center,
        pt(i, r),
        Paint()
          ..color = const Color(0xFF8B5A2B).withValues(alpha: 0.2)
          ..strokeWidth = 0.5,
      );
    }

    final path = Path();
    for (int i = 0; i < 5; i++) {
      final v = (counts[_kWuxingOrder[i]] ?? 0) / maxV * 0.95;
      final p = pt(i, r * v);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()..color = HanjiColors.glow.withValues(alpha: 0.25),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = HanjiColors.glow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    for (int i = 0; i < 5; i++) {
      final p = pt(i, r + 10);
      final tp = TextPainter(
        text: TextSpan(
          text: _kWuxingOrder[i],
          style: TextStyle(
            color: HanjiColors.wuxingColor(_kWuxingOrder[i]),
            fontWeight: FontWeight.w900,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _PentagonPainter oldDelegate) => false;
}

class _Chip extends StatelessWidget {
  final String text;
  final String tone; // 'default' | 'warn' | 'muted'
  const _Chip(this.text, {this.tone = 'default'});

  @override
  Widget build(BuildContext context) {
    Color color, bg, border;
    switch (tone) {
      case 'warn':
        color = HanjiColors.accent;
        bg = HanjiColors.accent.withValues(alpha: 0.08);
        border = HanjiColors.accent.withValues(alpha: 0.4);
        break;
      case 'muted':
        color = HanjiColors.muted;
        bg = Colors.transparent;
        border = HanjiColors.line;
        break;
      default:
        color = HanjiColors.fg;
        bg = HanjiColors.card;
        border = HanjiColors.line;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: HanjiTextStyles.bodyTitle(color: color).copyWith(fontSize: 10),
      ),
    );
  }
}
