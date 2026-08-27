import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_theme.dart';

/// 궤도(orbit) 반지름 — 안쪽(貴) → 바깥쪽(師), `GUINJI_SCREENS.md` 공통값.
const List<double> guinjiOrbitRadii = [55, 84, 108, 130, 148];

/// 사람 노드(person node) — 지도(S5)와 향후 관계상세(S6) 등에서 공용으로
/// 재사용하는 위젯. 원본 `GuinjiComponents.jsx` → `PersonNode` 이식.
class GuinjiPersonNode extends StatelessWidget {
  const GuinjiPersonNode({
    super.key,
    this.person,
    this.size = 44,
    this.onTap,
    this.isMe = false,
    this.showLabel = true,
  });

  final GuinjiPerson? person;
  final double size;
  final VoidCallback? onTap;
  final bool isMe;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final meta = person != null ? guinjiRelationTypes[person!.relation] : null;
    final ringColor = isMe
        ? GuinjiColors.lavender
        : (meta?.color ?? GuinjiColors.surfaceCardBorder);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMe
                  ? GuinjiColors.lavender
                  : ringColor.withValues(alpha: 0.22),
              border: Border.all(color: ringColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: ringColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: isMe
                ? const Text(
                    '我',
                    style: TextStyle(
                      fontFamily: GuinjiFonts.display,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: GuinjiColors.ink,
                    ),
                  )
                : Text(
                    meta?.hanja ?? '·',
                    style: TextStyle(
                      fontFamily: GuinjiFonts.mono,
                      fontWeight: FontWeight.w700,
                      fontSize: math.max(9, size * 0.32),
                      letterSpacing: 1.0,
                      color: ringColor,
                    ),
                  ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 2),
            Text(
              isMe ? '나' : (person?.name ?? ''),
              style: TextStyle(
                fontFamily: GuinjiFonts.body,
                fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                fontSize: isMe ? 10 : 9,
                color: isMe ? GuinjiColors.lavender : GuinjiColors.textPrimary,
                shadows: const [
                  Shadow(color: GuinjiColors.backgroundDeep, blurRadius: 6),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 동심원 궤도 지도 — 5개 관계 유형 링 + 참여자 노드 배치 + 중앙 '나' 노드.
/// 원본 `GuinjiComponents.jsx` → `OrbitMap` 이식.
///
/// [Phase G-3 범위] 원본의 `orbit-float 6s` bob 애니메이션·`ink-appear`
/// 마운트 연출은 이 Phase에서 생략한다(정적 배치 우선 확정 — 기존
/// Phase G-1/G-2와 동일한 "뼈대 먼저" 전략).
class GuinjiOrbitMap extends StatelessWidget {
  const GuinjiOrbitMap({
    super.key,
    required this.people,
    this.size = 300,
    this.onSelect,
  });

  final List<GuinjiPerson> people;
  final double size;
  final ValueChanged<GuinjiPerson>? onSelect;

  @override
  Widget build(BuildContext context) {
    final center = size / 2;

    // 관계 유형(orbit index)별로 그룹화.
    final grouped = <int, List<GuinjiPerson>>{};
    for (final p in people) {
      final orbit = guinjiRelationTypes[p.relation]?.orbit ?? 2;
      grouped.putIfAbsent(orbit, () => []).add(p);
    }

    final nodes = <Widget>[];
    grouped.forEach((orbitIdx, group) {
      final r = guinjiOrbitRadii[orbitIdx];
      final startAngle = -math.pi / 2 + (orbitIdx * 0.3);
      final angleStep = (2 * math.pi) / math.max(group.length, 1);
      for (var i = 0; i < group.length; i++) {
        final a = startAngle + angleStep * i;
        final x = center + math.cos(a) * r;
        final y = center + math.sin(a) * r;
        final p = group[i];
        nodes.add(
          Positioned(
            left: x - 18,
            top: y - 18,
            child: SizedBox(
              width: 36,
              child: GuinjiPersonNode(
                person: p,
                size: 30,
                onTap: () => onSelect?.call(p),
              ),
            ),
          ),
        );
      }
    });

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < guinjiOrbitRadii.length; i++)
            _DashedRing(
              radius: guinjiOrbitRadii[i],
              color: guinjiRelationTypes.values.elementAt(i).color,
            ),
          ...nodes,
          const GuinjiPersonNode(isMe: true, size: 48, showLabel: false),
        ],
      ),
    );
  }
}

class _DashedRing extends StatelessWidget {
  const _DashedRing({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: CustomPaint(
        painter: _DashedCirclePainter(color: color.withValues(alpha: 0.45)),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const dashLength = 4.0;
    const gapLength = 4.0;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();
    final anglePerDash = (2 * math.pi) / dashCount;
    for (var i = 0; i < dashCount; i++) {
      final startAngle = i * anglePerDash;
      final sweepAngle = anglePerDash * (dashLength / (dashLength + gapLength));
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
