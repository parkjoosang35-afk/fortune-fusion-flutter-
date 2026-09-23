import 'package:flutter/material.dart';

import '../oz_theme.dart';

/// [타로 카드뽑기 화면 디자인 핸드오프 매핑 · T1] 하단 프레임 안에 들어가는
/// 컴팩트 진행 오브 + 안내 메시지. CSS 대응: `<MysticOrbInline>`(TarotApp.jsx).
class OzMysticOrbInline extends StatelessWidget {
  final int pickedCount;
  final int target;
  final bool isShuffling;
  const OzMysticOrbInline({
    super.key,
    required this.pickedCount,
    required this.target,
    required this.isShuffling,
  });

  static const List<String> _messages = [
    '깊은 숨을 쉬고 마음을 여세요',
    '첫 카드가 열렸어요',
    '흐름이 보이기 시작해요',
    '카드가 이야기를 엮고 있어요',
    '한 걸음만 더 남았어요',
    '남은 카드들이 모습을 드러냈어요',
  ];

  @override
  Widget build(BuildContext context) {
    final progress = target == 0 ? 0.0 : pickedCount / target;
    final msg = isShuffling
        ? '카드를 섞고 있어요…'
        : _messages[pickedCount.clamp(0, _messages.length - 1)];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.4, -0.5),
                    colors: [
                      OzColors.gold.withValues(alpha: 0.5),
                      OzColors.bgMid,
                      OzColors.bgDeep,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: OzColors.gold.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 20,
                height: 20,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  builder: (context, value, _) => CustomPaint(
                    painter: _RingPainter(progress: value),
                  ),
                ),
              ),
              Text(
                '$pickedCount',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: OzColors.gold,
                  fontFamily: 'serif',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            msg,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontStyle: FontStyle.italic,
              color: OzColors.fg.withValues(alpha: 0.9),
              fontFamily: 'serif',
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '·',
          style: TextStyle(color: OzColors.goldDeep.withValues(alpha: 0.7)),
        ),
        const SizedBox(width: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$pickedCount',
                style: TextStyle(
                  color: OzColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: '/$target',
                style: TextStyle(color: OzColors.muted),
              ),
            ],
          ),
          style: const TextStyle(fontSize: 9.5),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    final paint = Paint()
      ..color = OzColors.gold
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // -90deg
      6.2832 * progress, // 2*pi * progress
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
