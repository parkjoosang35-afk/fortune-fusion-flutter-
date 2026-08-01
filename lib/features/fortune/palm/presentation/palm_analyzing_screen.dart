import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../application/palm_provider.dart';

/// 07단계(추가) §3.3 - PalmAnalyzingScreen 로딩 애니메이션 고급화
/// - 회전 아이콘에 스케일/색상 변화(pulse) 추가
/// - 3개의 점이 순차적으로 나타났다 사라지는 Dot Loader 추가
/// - 분석 진행률(0% → 50% → 100%) 표시, Curves.easeInOutCubic 트랜지션 적용
class PalmAnalyzingScreen extends StatefulWidget {
  const PalmAnalyzingScreen({super.key});

  @override
  State<PalmAnalyzingScreen> createState() => _PalmAnalyzingScreenState();
}

class _PalmAnalyzingScreenState extends State<PalmAnalyzingScreen>
    with TickerProviderStateMixin {
  // 회전 + 스케일/색상 pulse 공용 컨트롤러
  late final AnimationController _iconController;
  // Dot Loader(●●●) 순차 점멸 컨트롤러
  late final AnimationController _dotController;

  bool _navigated = false;
  Timer? _stepTimer;

  // 3단계 메시지 ↔ 진행률(0% / 50% / 100%) 매핑 - 07단계(추가) §3.3
  static const _messages = [
    '손금의 선을 인식하고 있어요...',
    'AI가 주요 손금 라인을 분석하고 있어요...',
    '해석을 작성하고 있어요...',
  ];
  static const _progressValues = [0.0, 0.5, 1.0];

  int _step = 0;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // 실제 분석 완료(성공/실패) 전까지는 0%→50% 구간만 진행하고 대기,
    // 완료 시점에 _navigateOnResult에서 즉시 100%로 전환한다.
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1100), (timer) {
      if (!mounted) return;
      if (_step < 1) {
        setState(() => _step = 1);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _iconController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  void _navigateOnResult(PalmProvider provider) {
    if (_navigated) return;
    if (provider.state.isSuccess || provider.state.isError) {
      _navigated = true;
      _stepTimer?.cancel();
      setState(() => _step = 2); // 진행률 100% 표시
      // 사용자가 100% 완료를 눈으로 확인할 수 있도록 짧게 대기 후 전환
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '/ai-fortune/palm/result',
          arguments: provider.state.data?.id,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PalmProvider>();
    _navigateOnResult(provider);

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: UnifiedTokens.spaceXxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PulsingRotationIcon(controller: _iconController),
                SizedBox(height: UnifiedTokens.spaceXxl),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _messages[_step],
                    key: ValueKey(_step),
                    style: UnifiedText.body(color: UnifiedColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: UnifiedTokens.spaceXl),
                _DotLoader(controller: _dotController),
                SizedBox(height: UnifiedTokens.spaceXxl),
                _ProgressBar(value: _progressValues[_step]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 회전 + 스케일 + 색상 pulse가 결합된 아이콘
class _PulsingRotationIcon extends StatelessWidget {
  final AnimationController controller;
  const _PulsingRotationIcon({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // sin 곡선을 이용해 1.0 ↔ 1.18 스케일을 부드럽게 왕복
        final t = (math.sin(controller.value * 2 * math.pi) + 1) / 2;
        final scale = 1.0 + (0.18 * t);
        final color = Color.lerp(
          UnifiedColors.textSecondary,
          UnifiedColors.black,
          t,
        )!;
        return Transform.rotate(
          angle: controller.value * 2 * math.pi,
          child: Transform.scale(
            scale: scale,
            child: Icon(Icons.back_hand_rounded, color: color, size: 72),
          ),
        );
      },
    );
  }
}

/// 3개의 점이 순차적으로 나타났다 사라지는 Dot Loader (●●●)
class _DotLoader extends StatelessWidget {
  final AnimationController controller;
  const _DotLoader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // 각 점마다 위상을 1/3씩 어긋나게 하여 순차 점멸 연출
            final phase = (controller.value - (index * 0.2)) % 1.0;
            final curved = Curves.easeInOutCubic.transform(
              phase < 0.5 ? phase * 2 : (1 - phase) * 2,
            );
            final opacity = 0.25 + (0.75 * curved.clamp(0.0, 1.0));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: UnifiedColors.black,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// 분석 진행률 바 (0% → 50% → 100%), Curves.easeInOutCubic로 부드럽게 전환
class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
          child: SizedBox(
            width: 180,
            height: 6,
            child: Stack(
              children: [
                Container(color: UnifiedColors.border),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: value),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutCubic,
                  builder: (context, animatedValue, _) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: animatedValue,
                      child: Container(color: UnifiedColors.black),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: UnifiedTokens.spaceSm),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
          builder: (context, animatedValue, _) {
            return Text(
              '${(animatedValue * 100).round()}%',
              style: UnifiedText.caption(color: UnifiedColors.textCaption),
            );
          },
        ),
      ],
    );
  }
}
