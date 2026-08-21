import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../application/tarot_provider.dart';
import '../application/tarot_session_controller.dart';
import 'oz/oz_theme.dart';
import 'oz/widgets/oz_background.dart';
import 'theme/tarot_perf_monitor.dart';

/// [타로 오즈 리스킨 · 화면06 LOADING] AI 리딩 로딩 화면.
///
/// 순수 리스킨: [_tryNavigate] 로직, `_minRitualDuration`(4400ms)/
/// `_messageInterval`(1700ms) 타이밍, `cardCount` 계산 로직,
/// [TarotPerfMonitor.enter]/[exit] 호출은 그대로 유지하고, 배경/카드/
/// 마법진의 색상 팔레트만 오즈 톤(딥퍼플+골드)으로 교체한다. 이 화면은
/// 기존에도 [TarotMysticBackground]를 직접 썼을 뿐 다른 화면과 달리
/// [TarotThemeScope]를 사용하지 않는 특수성이 있었는데, 오즈 리스킨에서는
/// 다른 6화면과 시각적 일관성을 위해 [OzBackground]를 사용한다(로직
/// 특수성은 변경하지 않되, 배경 위젯 자체는 리스킨 대상이므로 교체).
class TarotLoadingScreen extends StatefulWidget {
  const TarotLoadingScreen({super.key});

  @override
  State<TarotLoadingScreen> createState() => _TarotLoadingScreenState();
}

class _TarotLoadingScreenState extends State<TarotLoadingScreen>
    with TickerProviderStateMixin {
  static const _minRitualDuration = Duration(milliseconds: 4400);
  static const _riseDuration = Duration(milliseconds: 2200);
  static const _messageInterval = Duration(milliseconds: 1700);

  static const _allMessages = [
    ('✨', '카드의 기운을 읽는 중...'),
    ('🔮', '운명의 흐름을 분석하는 중...'),
    ('🌙', '당신의 에너지를 연결하는 중...'),
    ('⭐', '미래의 가능성을 살펴보는 중...'),
    ('📜', '최종 리딩을 준비하는 중...'),
  ];

  late final AnimationController _riseController;
  late final AnimationController _circleController;
  late final AnimationController _breatheController;

  late List<(String, String)> _messages;
  int _messageIndex = 0;
  Timer? _messageTimer;

  bool _minTimeElapsed = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    TarotPerfMonitor.enter();
    _riseController = AnimationController(vsync: this, duration: _riseDuration)
      ..forward();
    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _messages = List.of(_allMessages)..shuffle(Random());
    _messageTimer = Timer.periodic(_messageInterval, (_) {
      if (!mounted) return;
      setState(() {
        _messageIndex++;
        if (_messageIndex >= _messages.length) {
          _messageIndex = 0;
          _messages.shuffle(Random());
        }
      });
    });

    Future.delayed(_minRitualDuration, () {
      if (!mounted) return;
      _minTimeElapsed = true;
      _tryNavigate(context.read<TarotProvider>());
    });
  }

  @override
  void dispose() {
    TarotPerfMonitor.exit();
    _messageTimer?.cancel();
    _riseController.dispose();
    _circleController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  void _tryNavigate(TarotProvider provider) {
    if (_navigated || !_minTimeElapsed) return;
    if (provider.state.isSuccess || provider.state.isError) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '/ai-fortune/tarot/result',
          arguments: provider.state.data?.id,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TarotProvider>();
    _tryNavigate(provider);

    final isRising = _riseController.value < 1.0;
    final session = context.watch<TarotSessionController>();
    final cardCount = session.state.requiredCardCount.clamp(1, 3);

    return Scaffold(
      backgroundColor: OzColors.bgDeep,
      body: Stack(
        children: [
          const OzBackground(),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '☽',
                    style: TextStyle(color: OzColors.gold, fontSize: 1),
                  ), // (레이아웃 안정용, 실제 달 장식은 하단 Stack에서 그림)
                  SizedBox(
                    width: cardCount > 1 ? 300 : 220,
                    height: 260,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _riseController,
                        _circleController,
                        _breatheController,
                      ]),
                      builder: (context, _) {
                        final rise = CurvedAnimation(
                          parent: _riseController,
                          curve: Curves.easeOutCubic,
                        ).value;
                        final settle = CurvedAnimation(
                          parent: _riseController,
                          curve: Curves.elasticOut,
                        ).value;
                        final breathe = _breatheController.value;

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // 은은한 골드 후광(§1 빛이 퍼짐)
                            Opacity(
                              opacity: (rise * 0.9).clamp(0.0, 0.9),
                              child: Container(
                                width: 170 + breathe * 10,
                                height: 170 + breathe * 10,
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
                            ),
                            // 골드 마법진
                            Opacity(
                              opacity: rise.clamp(0.0, 1.0),
                              child: Transform.rotate(
                                angle: _circleController.value * 2 * pi,
                                child: CustomPaint(
                                  size: const Size(200, 200),
                                  painter: _OzMagicCirclePainter(),
                                ),
                              ),
                            ),
                            Transform.rotate(
                              angle: -_circleController.value * 2 * pi * 0.6,
                              child: Opacity(
                                opacity: (rise * 0.7).clamp(0.0, 0.7),
                                child: CustomPaint(
                                  size: const Size(150, 150),
                                  painter: _OzMagicCirclePainter(dashCount: 18),
                                ),
                              ),
                            ),
                            for (var i = 0; i < cardCount; i++)
                              () {
                                final stagger = cardCount > 1 ? i * 0.12 : 0.0;
                                final localRise =
                                    ((rise - stagger) / (1 - stagger)).clamp(
                                      0.0,
                                      1.0,
                                    );
                                final localSettle =
                                    ((settle - stagger) / (1 - stagger)).clamp(
                                      0.0,
                                      1.0,
                                    );
                                final dx = cardCount > 1
                                    ? (i - (cardCount - 1) / 2) * 84.0
                                    : 0.0;
                                return Transform.translate(
                                  offset: Offset(dx, (1 - localRise) * 60),
                                  child: Transform.rotate(
                                    angle: isRising
                                        ? (1 - localSettle) * -0.25
                                        : sin((breathe + i * 0.3) * pi) * 0.02,
                                    child: Opacity(
                                      opacity: localRise.clamp(0.0, 1.0),
                                      child: _OzMoonCard(
                                        width: cardCount > 1 ? 92 : 118,
                                        height: cardCount > 1 ? 140 : 178,
                                      ),
                                    ),
                                  ),
                                );
                              }(),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI TAROT READING',
                    style: OzTypography.monoLabel(fontSize: 10, letterSpacing: 4),
                  ),
                  const SizedBox(height: 32),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.15),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      key: ValueKey(_messageIndex),
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        '${_messages[_messageIndex].$1} ${_messages[_messageIndex].$2}',
                        textAlign: TextAlign.center,
                        style: OzTypography.body(fontSize: 14, color: OzColors.fg),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _OzLoadingDots(controller: _breatheController),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 신비로운 카드 뒷면(오즈 골드 톤). 실제 카드는 결과 화면에서 공개된다.
class _OzMoonCard extends StatelessWidget {
  final double width;
  final double height;
  const _OzMoonCard({this.width = 118, this.height = 178});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3D2A6B), Color(0xFF1A0F3D)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: OzColors.gold.withValues(alpha: 0.7),
          width: 1.5,
        ),
        boxShadow: OzColors.goldGlow(alpha: 0.35, blur: 26),
      ),
      child: Center(
        child: Container(
          width: width * 0.71,
          height: height * 0.775,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: OzColors.gold.withValues(alpha: 0.45)),
          ),
          alignment: Alignment.center,
          child: Text('✨', style: TextStyle(fontSize: width * 0.29, color: OzColors.gold)),
        ),
      ),
    );
  }
}

/// 회전하는 골드 마법진.
class _OzMagicCirclePainter extends CustomPainter {
  final int dashCount;
  _OzMagicCirclePainter({this.dashCount = 24});

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
      final dotRadius = i % 3 == 0 ? 2.4 : 1.3;
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
  bool shouldRepaint(covariant _OzMagicCirclePainter oldDelegate) => false;
}

/// 하단 로딩 점 3개(순차 반짝임). CSS 대응: .oz-loading-dots / .oz-loading-dot.
class _OzLoadingDots extends StatelessWidget {
  final AnimationController controller;
  const _OzLoadingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = (controller.value + i * 0.33) % 1.0;
            final opacity = 0.3 + (sin(phase * pi) * 0.6).abs();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: OzColors.gold.withValues(alpha: opacity.clamp(0.3, 0.95)),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
