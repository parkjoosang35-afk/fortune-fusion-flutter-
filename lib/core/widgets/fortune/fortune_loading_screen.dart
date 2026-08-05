import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_unified_style.dart';

/// 재사용 위젯 ⑫ FortuneLoadingScreen — "문구 배열 주입형" 로딩 화면.
///
/// §3 로딩 애니메이션 스펙: 2.8~4초 고정, 스킵 불가, 화이트 배경, 원형 링 회전 +
/// 옅은 파티클 스파클(#C6F24E 20% + #6B6B75 라인), pulse(1.0→1.05→1.0),
/// 문구 3단계 순차 전환(fade 300ms). [messages]만 바꾸면 사주/타로 등
/// 다른 카테고리에서도 동일한 로딩 연출을 재사용할 수 있다.
///
/// [subCard]는 §3 "보조 카드 가능"에 대응하는 선택 항목이다. null이면(기본값)
/// 아무 카드도 표시하지 않는다.
///
/// [task]를 애니메이션과 병행 실행하고, 둘 다 끝나면 [onComplete](결과)를
/// 호출한다. task가 실패하면 [onError]를 호출한다(§7 상태처리 "로딩 실패").
class FortuneLoadingScreen<T> extends StatefulWidget {
  const FortuneLoadingScreen({
    super.key,
    required this.task,
    required this.onComplete,
    required this.onError,
    this.messages = const [
      '오늘의 기운을 읽는 중이에요',
      '연애, 금전, 관계 흐름을 정리하고 있어요',
      '당신만의 오늘 운세를 완성했어요',
    ],
    this.totalDuration = const Duration(milliseconds: 3500),
    this.subCard,
  });

  final Future<T> Function() task;
  final void Function(T result) onComplete;
  final void Function(Object error) onError;
  final List<String> messages;
  final Duration totalDuration;
  final String? subCard;

  @override
  State<FortuneLoadingScreen<T>> createState() =>
      _FortuneLoadingScreenState<T>();
}

class _FortuneLoadingScreenState<T> extends State<FortuneLoadingScreen<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _messageIndex = 0;
  bool _ran = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.totalDuration,
    )..repeat();

    final perMessage =
        widget.totalDuration.inMilliseconds ~/ widget.messages.length;
    for (var i = 1; i < widget.messages.length; i++) {
      Future.delayed(Duration(milliseconds: perMessage * i), () {
        if (mounted) setState(() => _messageIndex = i);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_ran) return;
    _ran = true;
    final minWait = Future.delayed(widget.totalDuration);
    try {
      final results = await Future.wait([
        widget.task().then<Object?>((v) => v),
        minWait.then<Object?>((_) => null),
      ]);
      if (!mounted) return;
      widget.onComplete(results.first as T);
    } catch (e) {
      await minWait;
      if (!mounted) return;
      widget.onError(e);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) =>
                    _LoadingRing(progress: _controller.value),
              ),
              const SizedBox(height: UnifiedTokens.spaceXxl),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  widget.messages[_messageIndex],
                  key: ValueKey(_messageIndex),
                  style: UnifiedText.body(color: UnifiedColors.textPrimary),
                ),
              ),
              if (widget.subCard != null) ...[
                const SizedBox(height: UnifiedTokens.spaceXl),
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: UnifiedTokens.spaceXxl,
                  ),
                  padding: const EdgeInsets.all(UnifiedTokens.spaceMd),
                  decoration: BoxDecoration(
                    color: UnifiedColors.cardBanner,
                    borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
                  ),
                  child: Text(
                    widget.subCard!,
                    textAlign: TextAlign.center,
                    style: UnifiedText.caption(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 원형 링 회전 + 옅은 파티클 스파클 + pulse 스케일 애니메이션.
class _LoadingRing extends StatelessWidget {
  const _LoadingRing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    // pulse: 0→0.5 구간에서 1.0→1.05, 0.5→1.0 구간에서 1.05→1.0
    final pulseT = (math.sin(progress * 2 * math.pi) + 1) / 2; // 0~1
    final scale = 1.0 + pulseT * 0.05;

    return SizedBox(
      width: 96,
      height: 96,
      child: Transform.scale(
        scale: scale,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 옅은 파티클 스파클(작은 점 6개, 회전 위치 + 옅은 opacity)
            for (int i = 0; i < 6; i++) _sparkle(i, progress),
            // 회전하는 원형 링
            Transform.rotate(
              angle: progress * 2 * math.pi,
              child: CustomPaint(
                size: const Size(72, 72),
                painter: _RingPainter(),
              ),
            ),
            Icon(
              Icons.auto_awesome_rounded,
              size: 26,
              color: UnifiedColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sparkle(int i, double progress) {
    final angle = (i / 6) * 2 * math.pi + progress * 2 * math.pi;
    final dx = math.cos(angle) * 42;
    final dy = math.sin(angle) * 42;
    final opacity = (math.sin(progress * 2 * math.pi + i) + 1) / 2 * 0.5 + 0.1;
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: UnifiedColors.neon,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 옅은 베이스 링(#6B6B75 라인)
    final basePaint = Paint()
      ..color = UnifiedColors.textSecondary.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, basePaint);

    // 진행 아크(#C6F24E 20%)
    final arcPaint = Paint()
      ..color = UnifiedColors.neon.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 0.9,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
