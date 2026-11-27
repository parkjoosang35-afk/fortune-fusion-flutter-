import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../oz_theme.dart';

/// [타로 "리딩 시작하기" 대기 연출 개선 - 2026-11 추가]
///
/// 기존에는 [TarotCardSelectScreen]에서 "리딩 시작하기" 버튼을 누르면
/// [TarotSessionStatus.revealing] 동안 버튼 안의 작은
/// [CircularProgressIndicator](일명 "새로고침 스피너")만 돌아가다가, API
/// 응답이 오면 [TarotLoadingScreen](마법진 애니메이션)으로 화면 전환되는
/// 구조였다. 이 전환 전까지의 몇 초가 "그냥 버튼이 멈춰 도는" 느낌으로
/// 보인다는 피드백에 따라, 같은 `revealing` 구간을 덮는 전체화면 리추얼
/// 오버레이를 추가한다.
///
/// [범위 - 다른 로직 변경 없음] 이 위젯은 순수 장식 레이어다.
/// [TarotCardSelectScreen._onRevealPressed]의 게이트 호출 순서, `reveal()`
/// 호출, 에러 분기(CATEGORY_LIMIT_REACHED/INVALID_QUESTION), 성공 시
/// `/ai-fortune/tarot/loading`으로의 네비게이션 타이밍은 전혀 건드리지
/// 않는다. 단지 그 호출이 끝나기를 기다리는 동안(`state.status ==
/// revealing`) 화면 위에 올라와 있다가, 호출부가 상태를 바꾸는 순간
/// 자연스럽게 사라질 뿐이다.
class OzRevealRitualOverlay extends StatefulWidget {
  const OzRevealRitualOverlay({super.key});

  @override
  State<OzRevealRitualOverlay> createState() => _OzRevealRitualOverlayState();
}

class _OzRevealRitualOverlayState extends State<OzRevealRitualOverlay>
    with TickerProviderStateMixin {
  static const _messages = [
    '카드의 기운을 읽는 중...',
    '당신의 에너지를 연결하는 중...',
    '운명의 흐름을 분석하는 중...',
  ];

  late final AnimationController _fadeController;
  late final AnimationController _circleController;
  late final AnimationController _breatheController;
  Timer? _messageTimer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _messageTimer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (!mounted) return;
      setState(() => _messageIndex = (_messageIndex + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _fadeController.dispose();
    _circleController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: FadeTransition(
        opacity: _fadeController,
        child: Container(
          color: OzColors.bgDeep.withValues(alpha: 0.94),
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: Listenable.merge([_circleController, _breatheController]),
            builder: (context, _) {
              final breathe = _breatheController.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 150 + breathe * 14,
                          height: 150 + breathe * 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                OzColors.gold.withValues(alpha: 0.32),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Transform.rotate(
                          angle: _circleController.value * 2 * pi,
                          child: CustomPaint(
                            size: const Size(150, 150),
                            painter: _RitualCirclePainter(dashCount: 24),
                          ),
                        ),
                        Transform.rotate(
                          angle: -_circleController.value * 2 * pi * 0.6,
                          child: CustomPaint(
                            size: const Size(112, 112),
                            painter: _RitualCirclePainter(dashCount: 16),
                          ),
                        ),
                        Transform.scale(
                          scale: 1.0 + breathe * 0.06,
                          child: Text(
                            '✨',
                            style: TextStyle(
                              fontSize: 36,
                              color: OzColors.gold.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'TAROT READING',
                    style: OzTypography.monoLabel(fontSize: 10, letterSpacing: 4),
                  ),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                    child: Text(
                      _messages[_messageIndex],
                      key: ValueKey(_messageIndex),
                      textAlign: TextAlign.center,
                      style: OzTypography.body(fontSize: 14, color: OzColors.fg),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final phase = (_breatheController.value + i * 0.33) % 1.0;
                      final opacity = 0.3 + (sin(phase * pi) * 0.6).abs();
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: OzColors.gold.withValues(
                              alpha: opacity.clamp(0.3, 0.95),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RitualCirclePainter extends CustomPainter {
  final int dashCount;
  _RitualCirclePainter({this.dashCount = 24});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final ringPaint = Paint()
      ..color = OzColors.gold.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, ringPaint);

    final dotPaint = Paint()..color = OzColors.gold.withValues(alpha: 0.85);
    for (var i = 0; i < dashCount; i++) {
      final angle = (i / dashCount) * 2 * pi;
      final dotRadius = i % 3 == 0 ? 2.2 : 1.2;
      canvas.drawCircle(
        Offset(
          center.dx + cos(angle) * radius,
          center.dy + sin(angle) * radius,
        ),
        dotRadius,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RitualCirclePainter oldDelegate) => false;
}
