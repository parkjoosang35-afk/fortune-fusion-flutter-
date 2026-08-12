import 'package:flutter/material.dart';

import '../../domain/wish_room_models.dart';
import '../../theme/wish_room_colors.dart';
import '../../theme/wish_room_text_styles.dart';
import '../../widgets/wish_room_sigils.dart';
import '../../widgets/wish_room_pouch_widgets.dart';

/// 08. 조각 획득 순간 (풀스크린 오버레이) — 출처: PouchScreens.jsx `ScreenEarnMoment`
///
/// 절대 원칙 5 예외: 이 화면의 획득 폭발 애니메이션은 1s 미만도 허용된다.
class WishRoomEarnMomentScreen extends StatefulWidget {
  const WishRoomEarnMomentScreen({super.key, required this.result});

  final WishRoomEarnResult result;

  @override
  State<WishRoomEarnMomentScreen> createState() => _WishRoomEarnMomentScreenState();
}

class _WishRoomEarnMomentScreenState extends State<WishRoomEarnMomentScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    final amount = widget.result.amount;

    return Scaffold(
      backgroundColor: palette.bg2,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 1.0,
                  colors: [palette.glow.withValues(alpha: 0.55), palette.bg1, palette.bg2],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          Center(child: WishRoomSigil(size: 340, color: palette.glow, opacity: 0.55)),
          Positioned.fill(child: WishRoomDust(count: 20, color: palette.glow)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('+ $amount · SEALED', style: WishRoomText.monoSm(palette.muted)),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _pulseCtrl,
                              builder: (context, _) => Opacity(
                                opacity: 0.6 + 0.25 * _pulseCtrl.value,
                                child: Container(
                                  width: 180,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [palette.glow, palette.glowShadow, palette.glow.withValues(alpha: 0)],
                                      stops: const [0.0, 0.3, 0.65],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            CustomPaint(
                              size: const Size(180, 180),
                              painter: _RayPainter(color: palette.glow),
                            ),
                            const WishRoomShard(size: 70),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        '달빛 조각\n${_koreanCount(amount)} 개가 담겼어요',
                        textAlign: TextAlign.center,
                        style: WishRoomText.h1(palette.fg).copyWith(
                          fontSize: 26,
                          shadows: [Shadow(color: palette.glowShadow, blurRadius: 24)],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${widget.result.label}\n고맙습니다',
                        textAlign: TextAlign.center,
                        style: WishRoomText.body(palette.muted).copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: palette.card,
                          border: Border.all(color: palette.glow),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('지금 담긴', style: WishRoomText.body(palette.muted).copyWith(fontSize: 11)),
                            const SizedBox(width: 8),
                            WishRoomShardCounter(
                              count: widget.result.newBalance,
                              sizeVariant: WishRoomShardCounterSize.sm,
                              textColor: palette.fg,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  WishRoomPouchButton(
                    label: '복주머니로 돌아가기',
                    primary: true,
                    palette: palette,
                    expand: true,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _koreanCount(int n) {
    const words = ['영', '한', '두', '세', '네', '다섯', '여섯', '일곱', '여덜', '아홉', '열'];
    if (n >= 0 && n < words.length) return words[n];
    return '$n';
  }
}

class _RayPainter extends CustomPainter {
  _RayPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    for (int i = 0; i < 16; i++) {
      final a = (i / 16) * 2 * 3.14159265;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(a);
      canvas.drawLine(Offset.zero, Offset(0, -size.height / 2 * 0.94), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RayPainter oldDelegate) => oldDelegate.color != color;
}
