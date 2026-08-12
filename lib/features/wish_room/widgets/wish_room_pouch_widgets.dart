import 'package:flutter/material.dart';

import '../theme/wish_room_colors.dart';
import '../theme/wish_room_text_styles.dart';

/// 신통방통 · 복주머니(Lucky Pouch) 전용 컴포넌트
///
/// 출처: 디자인 핸드오프 `design_files/pouch/PouchComponents.jsx`.
/// 팔레트 기본값: Moonlit Crystal(달빛 크리스탈) — [WishRoomColors.crystal].
///
/// 절대 원칙 준수:
///  - 결제 유도 문구/버튼 없음
///  - 느낌표(!) 사용 금지
///  - 이모지는 아이콘 자리에만 사용(하단 네비게이션 등)

/// ─────────────────────────────────────────────────────────
/// <Shard> — 달빛 조각 (육각 크리스탈, facet 라인 + halo)
/// viewBox 0 0 40 46
/// ─────────────────────────────────────────────────────────
class WishRoomShard extends StatelessWidget {
  const WishRoomShard({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    final h = size * 46 / 40;
    return SizedBox(
      width: size,
      height: h,
      child: CustomPaint(painter: _ShardPainter()),
    );
  }
}

class _ShardPainter extends CustomPainter {
  static const _faceTop = Color(0xFFFFFFFF);
  static const _faceMid = Color(0xFFE8C8F5);
  static const _faceBottom = Color(0xFFA8D5E3);
  static const _sideTop = Color(0xFF7FB8D4);
  static const _sideBottom = Color(0xFF3D3568);
  static const _halo = Color(0xFFE8C8F5);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 40.0;
    canvas.save();
    canvas.scale(scale, scale);

    // halo
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [_halo.withValues(alpha: 0.35), _halo.withValues(alpha: 0)],
      ).createShader(const Rect.fromLTWH(0, 1, 40, 44));
    canvas.drawOval(const Rect.fromLTWH(0, 1, 40, 44), haloPaint);

    // main hexagonal body points
    const hex = [
      Offset(20, 3),
      Offset(33, 13),
      Offset(33, 33),
      Offset(20, 43),
      Offset(7, 33),
      Offset(7, 13),
    ];
    final bodyPath = Path()..addPolygon(hex, true);

    final facePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _faceTop.withValues(alpha: 0.95),
          _faceMid.withValues(alpha: 0.95),
          _faceBottom.withValues(alpha: 0.7),
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(const Rect.fromLTWH(7, 3, 26, 40));
    canvas.drawPath(bodyPath, facePaint);

    // right darker facet
    final sidePath = Path()
      ..moveTo(20, 3)
      ..lineTo(33, 13)
      ..lineTo(33, 33)
      ..lineTo(20, 23)
      ..close();
    final sidePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          _sideTop.withValues(alpha: 0.65),
          _sideBottom.withValues(alpha: 0.4),
        ],
      ).createShader(const Rect.fromLTWH(20, 3, 13, 30))
      ..color = _sideTop.withValues(alpha: 0.5);
    canvas.drawPath(sidePath, sidePaint..color = sidePaint.color.withValues(alpha: 1));

    // body outline
    canvas.drawPath(
      bodyPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = _halo.withValues(alpha: 0.7),
    );

    // facet lines
    final lp1 = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 0.6;
    canvas.drawLine(const Offset(20, 3), const Offset(20, 43), lp1);
    final lp2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 0.5;
    canvas.drawLine(const Offset(7, 13), const Offset(20, 23), lp2);
    canvas.drawLine(const Offset(33, 13), const Offset(20, 23), lp2);
    final lp3 = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 0.4;
    canvas.drawLine(const Offset(20, 23), const Offset(7, 33), lp3);
    canvas.drawLine(const Offset(20, 23), const Offset(33, 33), lp3);

    // top highlight
    final topHighlight = Path()
      ..addPolygon(const [
        Offset(20, 3),
        Offset(27, 8),
        Offset(20, 13),
        Offset(13, 8),
      ], true);
    canvas.drawPath(topHighlight, Paint()..color = Colors.white.withValues(alpha: 0.35));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShardPainter oldDelegate) => false;
}

/// ─────────────────────────────────────────────────────────
/// <Pouch> — 복주머니(드로우스트링 파우치)
/// viewBox 0 0 100 110
/// ─────────────────────────────────────────────────────────
class WishRoomPouch extends StatelessWidget {
  const WishRoomPouch({
    super.key,
    this.size = 96,
    this.color = const Color(0xFFA8B5E8),
    this.accentColor = const Color(0xFFE8C8F5),
  });

  final double size;
  final Color color;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.1,
      child: CustomPaint(painter: _PouchPainter(color: color, accentColor: accentColor)),
    );
  }
}

class _PouchPainter extends CustomPainter {
  _PouchPainter({required this.color, required this.accentColor});
  final Color color;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;
    canvas.save();
    canvas.scale(scale, scale);

    // halo
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [accentColor.withValues(alpha: 0.35), accentColor.withValues(alpha: 0)],
      ).createShader(const Rect.fromLTWH(0, 10, 100, 100));
    canvas.drawCircle(const Offset(50, 60), 50, glowPaint);

    final strokeColor = color;

    // drawstring loops (top)
    final loopPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = strokeColor.withValues(alpha: 0.85)
      ..strokeCap = StrokeCap.round;
    final loopLeft = Path()
      ..moveTo(32, 20)
      ..quadraticBezierTo(30, 10, 40, 10)
      ..quadraticBezierTo(45, 10, 45, 18);
    final loopRight = Path()
      ..moveTo(68, 20)
      ..quadraticBezierTo(70, 10, 60, 10)
      ..quadraticBezierTo(55, 10, 55, 18);
    canvas.drawPath(loopLeft, loopPaint);
    canvas.drawPath(loopRight, loopPaint);

    // drawstring cord
    final cordPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = accentColor.withValues(alpha: 0.9)
      ..strokeCap = StrokeCap.round;
    final cord = Path()
      ..moveTo(25, 26)
      ..quadraticBezierTo(50, 18, 75, 26);
    canvas.drawPath(cord, cordPaint);

    // neck / opening (gathered)
    final neckPath = Path()
      ..moveTo(28, 32)
      ..quadraticBezierTo(50, 26, 72, 32)
      ..lineTo(68, 40)
      ..quadraticBezierTo(50, 36, 32, 40)
      ..close();
    final neckPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [strokeColor.withValues(alpha: 0.7), strokeColor.withValues(alpha: 0.85)],
      ).createShader(const Rect.fromLTWH(28, 26, 44, 14));
    canvas.drawPath(neckPath, neckPaint);
    canvas.drawPath(
      neckPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = strokeColor.withValues(alpha: 0.7),
    );

    // vertical gathers on neck
    final gatherPaint = Paint()
      ..strokeWidth = 0.5
      ..color = Colors.black.withValues(alpha: 0.2);
    canvas.drawLine(const Offset(38, 30), const Offset(37, 40), gatherPaint);
    canvas.drawLine(const Offset(50, 28), const Offset(50, 40), gatherPaint);
    canvas.drawLine(const Offset(62, 30), const Offset(63, 40), gatherPaint);

    // main body — rounded bottom pouch
    final bodyPath = Path()
      ..moveTo(32, 40)
      ..quadraticBezierTo(50, 36, 68, 40)
      ..lineTo(78, 60)
      ..quadraticBezierTo(82, 90, 50, 100)
      ..quadraticBezierTo(18, 90, 22, 60)
      ..close();
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.4),
          color.withValues(alpha: 0.9),
          const Color(0xFF3D3568).withValues(alpha: 0.85),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(const Rect.fromLTWH(18, 36, 64, 64));
    canvas.drawPath(bodyPath, bodyPaint);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = strokeColor.withValues(alpha: 0.9),
    );

    // shine highlight
    final shinePath = Path()
      ..moveTo(30, 50)
      ..quadraticBezierTo(26, 68, 32, 84);
    canvas.drawPath(
      shinePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeCap = StrokeCap.round,
    );

    // center 福 character
    final tp = TextPainter(
      text: TextSpan(
        text: '福',
        style: TextStyle(
          fontFamily: 'NotoSerifKRWish',
          fontWeight: FontWeight.w900,
          fontSize: 16,
          color: accentColor.withValues(alpha: 0.85),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(50 - tp.width / 2, 72 - tp.height / 2));

    // tassel
    canvas.drawLine(
      const Offset(50, 100),
      const Offset(50, 108),
      Paint()
        ..strokeWidth = 1.2
        ..color = accentColor.withValues(alpha: 0.9),
    );
    canvas.drawCircle(const Offset(50, 108), 2, Paint()..color = accentColor.withValues(alpha: 0.9));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PouchPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accentColor != accentColor;
}

/// ─────────────────────────────────────────────────────────
/// <ShardCounter> — 현재 조각 잔액 표시 (sm/md/lg/xl)
/// ─────────────────────────────────────────────────────────
enum WishRoomShardCounterSize { sm, md, lg, xl }

class WishRoomShardCounter extends StatelessWidget {
  const WishRoomShardCounter({
    super.key,
    required this.count,
    this.sizeVariant = WishRoomShardCounterSize.md,
    this.textColor,
    this.glow = false,
  });

  final int count;
  final WishRoomShardCounterSize sizeVariant;
  final Color? textColor;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final spec = switch (sizeVariant) {
      WishRoomShardCounterSize.sm => const (shard: 16.0, num: 15.0, gap: 5.0),
      WishRoomShardCounterSize.md => const (shard: 22.0, num: 22.0, gap: 7.0),
      WishRoomShardCounterSize.lg => const (shard: 32.0, num: 42.0, gap: 10.0),
      WishRoomShardCounterSize.xl => const (shard: 40.0, num: 56.0, gap: 12.0),
    };
    final color = textColor ?? WishRoomColors.crystal.fg;
    final numberText = Text(
      _formatCount(count),
      style: TextStyle(
        fontFamily: WishRoomText.fontDisplay,
        fontWeight: FontWeight.w900,
        fontSize: spec.num,
        letterSpacing: -0.02 * spec.num,
        height: 1.0,
        color: color,
        shadows: glow
            ? [
                Shadow(
                  color: WishRoomColors.crystal.glowShadow,
                  blurRadius: 20,
                ),
              ]
            : null,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WishRoomShard(size: spec.shard),
        SizedBox(width: spec.gap),
        numberText,
      ],
    );
  }

  static String _formatCount(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }
}

/// ─────────────────────────────────────────────────────────
/// <MissionRow> — 오늘의 적립 미션 한 줄
/// ─────────────────────────────────────────────────────────
class WishRoomMissionRow extends StatelessWidget {
  const WishRoomMissionRow({
    super.key,
    required this.label,
    this.sub,
    required this.reward,
    this.done = false,
    this.palette = WishRoomColors.crystal,
    this.onTap,
  });

  final String label;
  final String? sub;
  final int reward;
  final bool done;
  final WishRoomPaletteTokens palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: done ? 0.6 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: palette.card,
              border: Border.all(color: palette.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  height: 30,
                  child: Center(
                    child: done
                        ? const WishRoomShard(size: 22)
                        : CustomPaint(
                            size: const Size(22, 25),
                            painter: _HollowHexPainter(color: palette.muted),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: WishRoomText.h3(palette.fg).copyWith(
                          decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
                          decorationColor: palette.muted,
                        ),
                      ),
                      if (sub != null) ...[
                        const SizedBox(height: 2),
                        Text(sub!.toUpperCase(), style: WishRoomText.monoSm(palette.muted)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: done ? Colors.transparent : palette.glow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: done ? palette.line : palette.glow,
                      style: done ? BorderStyle.solid : BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const WishRoomShard(size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '+$reward',
                        style: TextStyle(
                          fontFamily: WishRoomText.fontDisplay,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: done ? palette.muted : palette.glow,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HollowHexPainter extends CustomPainter {
  _HollowHexPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 40.0;
    canvas.save();
    canvas.scale(scale, scale);
    const hex = [
      Offset(20, 3),
      Offset(33, 13),
      Offset(33, 33),
      Offset(20, 43),
      Offset(7, 33),
      Offset(7, 13),
    ];
    final path = Path()..addPolygon(hex, true);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.6),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HollowHexPainter oldDelegate) => oldDelegate.color != color;
}

/// ─────────────────────────────────────────────────────────
/// <RewardTile> — 사용처 타일 (인장/촛불/테마/부적 상점 공용)
/// ─────────────────────────────────────────────────────────
class WishRoomRewardTile extends StatelessWidget {
  const WishRoomRewardTile({
    super.key,
    required this.icon,
    required this.name,
    this.sub,
    required this.cost,
    this.locked = false,
    this.owned = false,
    this.palette = WishRoomColors.crystal,
    this.onTap,
  });

  final Widget icon;
  final String name;
  final String? sub;
  final int cost;
  final bool locked;
  final bool owned;
  final WishRoomPaletteTokens palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.55 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: palette.card,
              border: Border.all(color: owned ? palette.glow : palette.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 44, child: Center(child: icon)),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: WishRoomText.h3(palette.fg),
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub!.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: WishRoomText.monoSm(palette.muted),
                      ),
                    ],
                    const SizedBox(height: 6),
                    owned
                        ? Text('담겨있음', style: WishRoomText.body(palette.glow).copyWith(fontSize: 11))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const WishRoomShard(size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '$cost',
                                style: TextStyle(
                                  fontFamily: WishRoomText.fontDisplay,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: palette.fg,
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
                if (owned)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.glow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'OWNED',
                        style: TextStyle(
                          fontFamily: WishRoomText.fontMono,
                          fontSize: 8,
                          letterSpacing: 0.2 * 8,
                          fontWeight: FontWeight.w600,
                          color: WishRoomColors.onGlowText,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// <LedgerRow> — 거래 내역(정성의 흔적 장부) 한 줄
/// ─────────────────────────────────────────────────────────
class WishRoomLedgerRow extends StatelessWidget {
  const WishRoomLedgerRow({
    super.key,
    required this.label,
    required this.sub,
    required this.amount,
    required this.date,
    this.palette = WishRoomColors.crystal,
  });

  final String label;
  final String sub;
  final int amount;
  final String date;
  final WishRoomPaletteTokens palette;

  @override
  Widget build(BuildContext context) {
    final gain = amount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: gain ? palette.glow.withValues(alpha: 0.15) : palette.crystal.withValues(alpha: 0.15),
              border: Border.all(color: palette.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              gain ? '＋' : '－',
              style: TextStyle(
                fontSize: 14,
                color: gain ? palette.glow : palette.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: WishRoomText.h3(palette.fg)),
                const SizedBox(height: 2),
                Text(
                  '${sub.toUpperCase()} · $date',
                  style: WishRoomText.monoSm(palette.muted),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const WishRoomShard(size: 12),
              const SizedBox(width: 4),
              Text(
                '${gain ? '+' : ''}$amount',
                style: TextStyle(
                  fontFamily: WishRoomText.fontDisplay,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: gain ? palette.glow : palette.fg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// <PouchBottomNav> — 4탭 하단 네비게이션
/// 나의 소원 / 모두의 소원 / 복주머니 / 기록
/// (이모지는 아이콘 자리에만 사용 — 절대원칙 준수)
/// ─────────────────────────────────────────────────────────
class WishRoomBottomNavItem {
  const WishRoomBottomNavItem({required this.id, required this.label, required this.icon});
  final String id;
  final String label;
  final String icon;
}

class WishRoomBottomNav extends StatelessWidget {
  const WishRoomBottomNav({
    super.key,
    required this.active,
    this.palette = WishRoomColors.crystal,
    this.onSelect,
  });

  static const items = [
    WishRoomBottomNavItem(id: 'home', label: '나의 소원', icon: '🕯'),
    WishRoomBottomNavItem(id: 'feed', label: '모두의 소원', icon: '☾'),
    WishRoomBottomNavItem(id: 'pouch', label: '복주머니', icon: '❖'),
    WishRoomBottomNavItem(id: 'me', label: '기록', icon: '◈'),
  ];

  final String active;
  final WishRoomPaletteTokens palette;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.bg2.withValues(alpha: 0), palette.bg2],
          stops: const [0.0, 0.45],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((it) {
          final on = it.id == active;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSelect == null ? null : () => onSelect!(it.id),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(it.icon, style: TextStyle(fontSize: 18, color: on ? palette.glow : palette.muted)),
                const SizedBox(height: 3),
                Text(
                  it.label,
                  style: TextStyle(
                    fontFamily: WishRoomText.fontBody,
                    fontSize: 10,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                    color: on ? palette.glow : palette.muted,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// <PouchButton> — 공용 버튼 스타일 (primary/ghost)
/// ─────────────────────────────────────────────────────────
class WishRoomPouchButton extends StatelessWidget {
  const WishRoomPouchButton({
    super.key,
    required this.label,
    this.onPressed,
    this.primary = true,
    this.palette = WishRoomColors.crystal,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final WishRoomPaletteTokens palette;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary ? palette.glow : Colors.transparent,
        border: primary ? null : Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(999),
        boxShadow: primary
            ? [BoxShadow(color: palette.glowShadow, blurRadius: 16, offset: const Offset(0, 4))]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: WishRoomText.fontBody,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: primary ? WishRoomColors.onGlowText : palette.fg,
        ),
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: expand ? SizedBox(width: double.infinity, child: child) : child,
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// <PouchIconButton> — 원형 아이콘 버튼(뒤로가기 등)
/// ─────────────────────────────────────────────────────────
class WishRoomPouchIconButton extends StatelessWidget {
  const WishRoomPouchIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.palette = WishRoomColors.crystal,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final WishRoomPaletteTokens palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.card,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: palette.line),
          ),
          child: Icon(icon, size: 18, color: palette.fg),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// <PouchBg> — 공통 배경(팔레트 그라디언트)
/// ─────────────────────────────────────────────────────────
class WishRoomPouchBg extends StatelessWidget {
  const WishRoomPouchBg({
    super.key,
    required this.child,
    this.palette = WishRoomColors.crystal,
  });

  final Widget child;
  final WishRoomPaletteTokens palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.bg1, palette.bg2],
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontFamily: WishRoomText.fontUi, color: palette.fg),
        child: child,
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// <PouchMonoLabel> — 모노스페이스 라벨(대문자 + 자간)
/// ─────────────────────────────────────────────────────────
class WishRoomPouchMonoLabel extends StatelessWidget {
  const WishRoomPouchMonoLabel({
    super.key,
    required this.text,
    this.palette = WishRoomColors.crystal,
  });

  final String text;
  final WishRoomPaletteTokens palette;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: WishRoomText.monoSm(palette.muted));
  }
}
