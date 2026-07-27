import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../application/face_provider.dart';

/// 07단계(추가) §3.3 - FaceAnalyzingScreen 로딩 애니메이션 고급화
/// (손금 PalmAnalyzingScreen과 동일 패턴)
/// - 회전 아이콘에 스케일/색상 변화(pulse) 추가
/// - 3개의 점이 순차적으로 나타났다 사라지는 Dot Loader 추가
/// - 분석 진행률(0% → 50% → 100%) 표시, Curves.easeInOutCubic 트랜지션 적용
class FaceAnalyzingScreen extends StatefulWidget {
  const FaceAnalyzingScreen({super.key});

  @override
  State<FaceAnalyzingScreen> createState() => _FaceAnalyzingScreenState();
}

class _FaceAnalyzingScreenState extends State<FaceAnalyzingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _iconController;
  late final AnimationController _dotController;

  bool _navigated = false;
  Timer? _stepTimer;

  static const _messages = [
    '얼굴의 윤곽을 분석하고 있어요...',
    'AI가 부위별 특징을 읽고 있어요...',
    '관상 해석을 작성하고 있어요...',
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

  void _navigateOnResult(FaceProvider provider) {
    if (_navigated) return;
    if (provider.state.isSuccess || provider.state.isError) {
      _navigated = true;
      _stepTimer?.cancel();
      setState(() => _step = 2);
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '/ai-fortune/face/result',
          arguments: provider.state.data?.id,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FaceProvider>();
    _navigateOnResult(provider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.mysticGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PulsingRotationIcon(controller: _iconController),
                  const SizedBox(height: AppSpacing.xl),
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
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _DotLoader(controller: _dotController),
                  const SizedBox(height: AppSpacing.xxl),
                  _ProgressBar(value: _progressValues[_step]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingRotationIcon extends StatelessWidget {
  final AnimationController controller;
  const _PulsingRotationIcon({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = (math.sin(controller.value * 2 * math.pi) + 1) / 2;
        final scale = 1.0 + (0.18 * t);
        final color = Color.lerp(
          AppColors.secondary,
          AppColors.primaryLight,
          t,
        )!;
        return Transform.rotate(
          angle: controller.value * 2 * math.pi,
          child: Transform.scale(
            scale: scale,
            child: Icon(
              Icons.face_retouching_natural_rounded,
              color: color,
              size: 72,
            ),
          ),
        );
      },
    );
  }
}

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
                    color: AppColors.secondary,
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

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: SizedBox(
            width: 180,
            height: 6,
            child: Stack(
              children: [
                Container(color: Colors.white.withValues(alpha: 0.15)),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: value),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutCubic,
                  builder: (context, animatedValue, _) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: animatedValue,
                      child: Container(color: AppColors.secondary),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
          builder: (context, animatedValue, _) {
            return Text(
              '${(animatedValue * 100).round()}%',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
      ],
    );
  }
}
