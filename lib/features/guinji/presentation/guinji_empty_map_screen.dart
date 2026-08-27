import 'package:flutter/material.dart';

import '../../../core/widgets/app_toast.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_bg_atmosphere.dart';
import 'guinji_map_screen.dart';

/// 귀인지도(Guinji Map) — 04. 빈 지도 화면(🔴 바이럴의 첫 화면).
///
/// [Phase G-2] `GUINJI_SCREENS.md` "04 · 빈 지도" 스펙 재구현(원본
/// `GuinjiScreens.jsx` → `EmptyMapScreen`): 아직 아무도 참여하지 않은
/// 상태의 빈 궤도(5개 관계유형 링) + 신통도령 안내 + 초대 CTA 2단.
///
/// [Phase G-2 범위] 실제 "초대 링크 생성"·"카톡 공유" 기능(§공유 S8,
/// share_event 테이블)은 아직 구현하지 않는다 — 이 Phase에서는 화면
/// 뼈대와 정적 배치만 확정하고, CTA는 준비 중 토스트로 대체한다.
class GuinjiEmptyMapScreen extends StatelessWidget {
  const GuinjiEmptyMapScreen({super.key});

  /// 5유형(貴/同/緣/養/師) 링 반지름 순서 — RELATION_TYPES 정의 순서와
  /// 동일(orbit 0→4, 안쪽→바깥쪽): guin, oreunpal, inyeon, salrim, horang.
  static const List<double> _ringRadii = [55, 84, 108, 130, 148];
  static const List<Color> _ringColors = [
    GuinjiColors.relationGuin,
    GuinjiColors.relationOreunpal,
    GuinjiColors.relationInyeon,
    GuinjiColors.relationSalrim,
    GuinjiColors.relationHorang,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: GuinjiBgAtmosphere()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _IconButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const _MonoLabel('MY GUINJI · EMPTY'),
                      const SizedBox(width: 36),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 300,
                        height: 300,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            for (var i = 0; i < _ringRadii.length; i++)
                              _DashedRing(
                                radius: _ringRadii[i],
                                color: _ringColors[i],
                              ),
                            _MeNode(),
                            const Positioned(
                              top: 20,
                              child: _HintPill('WAITING FOR 貴'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const _DoryeongHint(),
                  const SizedBox(height: 12),
                  const Text(
                    '지도가 비어 있어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: GuinjiFonts.display,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      height: 1.2,
                      letterSpacing: -0.4,
                      color: GuinjiColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '지인 한 분만 초대해도\n어떤 결의 사람인지 바로 알 수 있어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: GuinjiFonts.body,
                      fontSize: 12,
                      height: 1.5,
                      color: GuinjiColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PrimaryCta(
                    label: '첫 지인 초대하기',
                    onPressed: () {
                      // [Phase G-2 범위] 초대 링크 생성(§공유 S8)은 후속
                      // Phase에서 구현한다.
                      AppToast.show(context, '곧 만나볼 수 있어요! 준비 중이에요 🙏');
                    },
                  ),
                  const SizedBox(height: 8),
                  _GhostCta(
                    label: '링크 복사해서 카톡으로 보내기',
                    onPressed: () {
                      AppToast.show(context, '곧 만나볼 수 있어요! 준비 중이에요 🙏');
                    },
                  ),
                  // [Phase G-3 임시] 실제 참여 플로우(§공유 S8 → 지인참여
                  // S9) 완성 전까지, 목데이터 기반 지도(S5) 화면을 검토할
                  // 수 있는 개발용 진입 링크. 후속 Phase에서 실제 참여
                  // 발생 시 자동 전환 로직으로 대체하고 이 버튼은 제거한다.
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GuinjiMapScreen(),
                      ),
                    ),
                    child: const Text(
                      '(개발용) 채워진 지도 미리보기 →',
                      style: TextStyle(
                        fontFamily: GuinjiFonts.mono,
                        fontSize: 10,
                        letterSpacing: 1.0,
                        color: GuinjiColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuinjiColors.surfaceCard,
      shape: const CircleBorder(
        side: BorderSide(color: GuinjiColors.surfaceCardBorder),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: GuinjiColors.textPrimary),
        ),
      ),
    );
  }
}

class _MonoLabel extends StatelessWidget {
  const _MonoLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: GuinjiFonts.mono,
        fontSize: 10,
        letterSpacing: 3.0,
        fontWeight: FontWeight.w500,
        color: GuinjiColors.textSecondary,
      ),
    );
  }
}

/// 5유형 관계 링 중 하나를 그리는 점선 원.
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
        painter: _DashedCirclePainter(color: color.withValues(alpha: 0.35)),
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
    final circumference = 2 * 3.14159265 * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();
    final anglePerDash = (2 * 3.14159265) / dashCount;
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

/// 중앙 "나" 노드.
class _MeNode extends StatelessWidget {
  const _MeNode();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: GuinjiColors.lavender,
        boxShadow: const [
          BoxShadow(color: GuinjiColors.glowShadow, blurRadius: 16),
        ],
      ),
      child: const Text(
        '나',
        style: TextStyle(
          fontFamily: GuinjiFonts.body,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: GuinjiColors.ink,
        ),
      ),
    );
  }
}

class _HintPill extends StatelessWidget {
  const _HintPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: GuinjiColors.backgroundDeep.withValues(alpha: 0.7),
        border: Border.all(
          color: GuinjiColors.surfaceCardBorder,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: GuinjiFonts.mono,
          fontSize: 10,
          letterSpacing: 2.0,
          color: GuinjiColors.textSecondary,
        ),
      ),
    );
  }
}

/// 신통도령(pointing) 미니 아이콘 + 말풍선.
class _DoryeongHint extends StatelessWidget {
  const _DoryeongHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/home/doryeong/pointing.png',
          width: 44,
          height: 44,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: GuinjiColors.surfaceCard,
              border: Border.all(color: GuinjiColors.surfaceCardBorder),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '소인, 아직 아무도\n못 만났사옵니다',
              style: TextStyle(
                fontFamily: GuinjiFonts.body,
                fontWeight: FontWeight.w500,
                fontSize: 12,
                height: 1.4,
                color: GuinjiColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: GuinjiColors.lavender,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: GuinjiColors.glowShadow,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '+ ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: GuinjiColors.ink,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: GuinjiFonts.body,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: GuinjiColors.ink,
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

class _GhostCta extends StatelessWidget {
  const _GhostCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: GuinjiColors.surfaceCardBorder),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: GuinjiFonts.ui,
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: GuinjiColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
