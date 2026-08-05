import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../application/tarot_provider.dart';
import '../application/tarot_session_controller.dart';
import 'theme/tarot_perf_config.dart';
import 'theme/tarot_perf_monitor.dart';
import 'widgets/tarot_mystic_background.dart';

/// [AI 타로 리딩 UX/UI 개선] TarotLoadingScreen 전면 재구성.
///
/// §1 "리딩 시작 애니메이션"(카드 리비테이션 + 빛 확산 + 회전 + 마법진) →
/// §2/§3 "AI가 실제로 분석하는 느낌"(랜덤 단계 문구 + 살아있는 배경)의 2단계
/// 시네마틱 로딩을 구현한다. 실제 카드 정체(어떤 카드가 나왔는지)는 이 단계
/// 시점에는 아직 서버 응답이 도착하지 않았을 수 있으므로(비동기), 여기서는
/// "정체를 알 수 없는 신비로운 카드 뒷면"만 보여주고 실제 카드 공개는 결과
/// 화면(§4~6)의 전용 리빌 연출로 넘긴다 - 화면 간 역할을 명확히 분리해
/// 로딩 화면 로직이 결과 화면 로직과 뒤섞이지 않게 한다.
///
/// [체감 리추얼 보장] API가 즉시 응답하더라도 최소 [_minRitualDuration]만큼은
/// 반드시 연출을 재생한다("바로 결과를 보여주지 않습니다" 원칙, §1). API가
/// 느리면 문구 로테이션이 계속 이어지며 자연스럽게 대기 시간을 채운다.
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
    // [§11 P6] 이 화면은 [TarotThemeScope]를 사용하지 않는 유일한 타로
    // 화면(기존 라이트 Scaffold + AppColors.deepSpace 유지)이므로,
    // 프레임 성능 관측 진입/이탈을 여기서 직접 연결한다.
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
    // [타로 섹션 전면 개편 §7 P2] 카드선택 화면(⑤)에서 확정된 스프레드에
    // 맞춰 리비테이션 카드 매수를 맞춘다(1카드/YES·NO는 1장, 3카드는
    // 3장). 세션이 없는 레거시 경로(콘솔 진입 등)에서는 기존처럼 1장.
    final session = context.watch<TarotSessionController>();
    final cardCount = session.state.requiredCardCount.clamp(1, 3);

    return Scaffold(
      backgroundColor: AppColors.deepSpace,
      body: Stack(
        children: [
          TarotMysticBackground(
            intensity: TarotPerfConfig.backgroundIntensity(1.0),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                            // 빛이 퍼짐(§1) - 카드가 떠오르며 함께 확산되는 후광
                            Opacity(
                              opacity: (rise * 0.9).clamp(0.0, 0.9),
                              child: Container(
                                width: 170 + breathe * 10,
                                height: 170 + breathe * 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.secondary.withValues(
                                        alpha: 0.35,
                                      ),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // 은빛/골드 마법진(§1 "빛나는 원형 마법진")
                            Opacity(
                              opacity: rise.clamp(0.0, 1.0),
                              child: Transform.rotate(
                                angle: _circleController.value * 2 * pi,
                                child: CustomPaint(
                                  size: const Size(200, 200),
                                  painter: _MagicCirclePainter(),
                                ),
                              ),
                            ),
                            Transform.rotate(
                              angle: -_circleController.value * 2 * pi * 0.6,
                              child: Opacity(
                                opacity: (rise * 0.7).clamp(0.0, 0.7),
                                child: CustomPaint(
                                  size: const Size(150, 150),
                                  painter: _MagicCirclePainter(dashCount: 18),
                                ),
                              ),
                            ),
                            // 떠오르는 카드(§1 "카드가 천천히 떠오릅니다" +
                            // "카드가 살짝 회전합니다") - 3카드 스프레드는
                            // 카드 3장이 살짝 시차(stagger)를 두고 함께
                            // 떠오른다(등장 후 §3 "미세하게 흔들림" 유지).
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
                                      child: _CardBack(
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
                  const SizedBox(height: 40),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
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

/// 정체를 알 수 없는 신비로운 카드 뒷면(§1) - 실제 카드는 결과 화면에서 공개.
/// [width]/[height]는 3카드 스프레드에서 카드 3장이 나란히 들어갈 수
/// 있도록 축소된 크기를 전달받는다(1카드는 기존 크기 그대로 유지).
class _CardBack extends StatelessWidget {
  final double width;
  final double height;
  const _CardBack({this.width = 118, this.height = 178});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: AppColors.mysticGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.7),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: width * 0.71,
          height: height * 0.775,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.secondaryLight.withValues(alpha: 0.6),
            ),
          ),
          alignment: Alignment.center,
          child: Text('✨', style: TextStyle(fontSize: width * 0.29)),
        ),
      ),
    );
  }
}

/// 회전하는 마법진 - 원형 테두리 + 방사형 점(§1 "빛나는 원형 마법진").
class _MagicCirclePainter extends CustomPainter {
  final int dashCount;
  _MagicCirclePainter({this.dashCount = 24});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final ringPaint = Paint()
      ..color = AppColors.secondaryLight.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, ringPaint);

    final dotPaint = Paint()
      ..color = AppColors.secondaryLight.withValues(alpha: 0.8);
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
  bool shouldRepaint(covariant _MagicCirclePainter oldDelegate) => false;
}
