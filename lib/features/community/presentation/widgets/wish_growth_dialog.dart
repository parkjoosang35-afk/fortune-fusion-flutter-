import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/wish_post_model.dart';

/// [소원성(Wish Castle) 확장] "성장 연출" - 행복머니를 보냈지만 레벨업은 아직 아닐 때
/// 재생되는 짧은(1.3초) 축하 애니메이션. 03단계 §10.2 "부적 획득"/`SendBokSuccessDialog`의
/// 스파클+스케일 패턴을 그대로 재사용하되, 골드 원형 대신 촛불 이모지를 사용해
/// "행복머니가 촛불에 스며드는" 느낌으로 테마만 교체한다(신규 애니메이션 로직 최소화).
class WishGrowthDialog extends StatefulWidget {
  final int bokjuAmount;
  final int candleLevel;
  final int bokjuCount;

  const WishGrowthDialog({
    super.key,
    required this.bokjuAmount,
    required this.candleLevel,
    required this.bokjuCount,
  });

  static Future<void> show(
    BuildContext context, {
    required int bokjuAmount,
    required int candleLevel,
    required int bokjuCount,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, __) => WishGrowthDialog(
        bokjuAmount: bokjuAmount,
        candleLevel: candleLevel,
        bokjuCount: bokjuCount,
      ),
    );
  }

  @override
  State<WishGrowthDialog> createState() => _WishGrowthDialogState();
}

class _WishGrowthDialogState extends State<WishGrowthDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Spark> _sparks;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();
    // 1초 뒤 자동으로 닫혀 "가벼운 성장" 느낌을 유지(레벨업 연출과의 무게감 차별화)
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) Navigator.of(context).maybePop();
    });

    final rand = Random(7);
    _sparks = List.generate(10, (i) {
      final angle = (i / 10) * 2 * pi + rand.nextDouble() * 0.3;
      return _Spark(
        angle: angle,
        distance: 55.0 + rand.nextDouble() * 30,
        size: 3.0 + rand.nextDouble() * 4,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = wishCandleLevelOf(widget.candleLevel);
    final scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );
    final fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    );
    final sparkFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.85, curve: Curves.easeOut),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final scaleValue = scale.value.clamp(0.0, 1.25);
          final fadeValue = fade.value.clamp(0.0, 1.0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ..._sparks.map((s) {
                      final t = _controller.value.clamp(0.0, 1.0);
                      final eased = Curves.easeOut.transform(t);
                      final opacity = (sparkFade.value * (1 - eased)).clamp(
                        0.0,
                        1.0,
                      );
                      final dx = cos(s.angle) * s.distance * eased;
                      final dy = sin(s.angle) * s.distance * eased;
                      return Transform.translate(
                        offset: Offset(dx, dy),
                        child: Opacity(
                          opacity: opacity,
                          child: Container(
                            width: s.size,
                            height: s.size,
                            decoration: const BoxDecoration(
                              color: AppColors.secondaryLight,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.secondary,
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    Transform.scale(
                      scale: scaleValue,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          gradient: AppColors.goldGradient,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          meta.emoji,
                          style: const TextStyle(fontSize: 42),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Opacity(
                opacity: fadeValue,
                child: Column(
                  children: [
                    Text(
                      '🧧 행복머니 +${widget.bokjuAmount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${meta.name} · 누적 ${widget.bokjuCount}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Spark {
  final double angle;
  final double distance;
  final double size;
  const _Spark({
    required this.angle,
    required this.distance,
    required this.size,
  });
}

/// [소원성(Wish Castle) 확장] "레벨업 특별 연출" - 촛불 레벨이 실제로 오를 때만
/// 재생되는 3초 전체화면 연출. 기존 촛불 이모지가 다음 단계 이모지로 전환되는
/// RotationTransition(기존 `_LuckyRouletteCard` 패턴 재사용)과 확장 스파클을 함께
/// 사용해 "성장 연출"보다 뚜렷하게 무게감을 준다.
class WishLevelUpDialog extends StatefulWidget {
  final int previousLevel;
  final int newLevel;
  final int bokjuCount;

  const WishLevelUpDialog({
    super.key,
    required this.previousLevel,
    required this.newLevel,
    required this.bokjuCount,
  });

  static Future<void> show(
    BuildContext context, {
    required int previousLevel,
    required int newLevel,
    required int bokjuCount,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, _, __) => WishLevelUpDialog(
        previousLevel: previousLevel,
        newLevel: newLevel,
        bokjuCount: bokjuCount,
      ),
    );
  }

  @override
  State<WishLevelUpDialog> createState() => _WishLevelUpDialogState();
}

class _WishLevelUpDialogState extends State<WishLevelUpDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Spark> _sparks;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..forward();

    final rand = Random(21);
    _sparks = List.generate(20, (i) {
      final angle = (i / 20) * 2 * pi + rand.nextDouble() * 0.3;
      return _Spark(
        angle: angle,
        distance: 90.0 + rand.nextDouble() * 60,
        size: 4.0 + rand.nextDouble() * 6,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prevMeta = wishCandleLevelOf(widget.previousLevel);
    final newMeta = wishCandleLevelOf(widget.newLevel);

    final rotate = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
    );
    final scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );
    final textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
    );
    final sparkFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.95, curve: Curves.easeOut),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final scaleValue = scale.value.clamp(0.0, 1.3);
          final textFadeValue = textFade.value.clamp(0.0, 1.0);
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.mysticGradient,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.goldGlowBorder, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '✨ 촛불이 자라났어요 ✨',
                  style: TextStyle(
                    color: AppColors.secondaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ..._sparks.map((s) {
                        final t = _controller.value.clamp(0.0, 1.0);
                        final eased = Curves.easeOut.transform(t);
                        final opacity = (sparkFade.value * (1 - eased * 0.7))
                            .clamp(0.0, 1.0);
                        final dx = cos(s.angle) * s.distance * eased;
                        final dy = sin(s.angle) * s.distance * eased;
                        return Transform.translate(
                          offset: Offset(dx, dy),
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              width: s.size,
                              height: s.size,
                              decoration: const BoxDecoration(
                                color: AppColors.secondaryLight,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.secondary,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      RotationTransition(
                        turns: Tween(begin: 0.0, end: 1.0).animate(rotate),
                        child: Transform.scale(
                          scale: scaleValue,
                          child: Container(
                            width: 128,
                            height: 128,
                            decoration: const BoxDecoration(
                              gradient: AppColors.goldGradient,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              newMeta.emoji,
                              style: const TextStyle(fontSize: 56),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Opacity(
                  opacity: textFadeValue,
                  child: Column(
                    children: [
                      Text(
                        '${prevMeta.name} → ${newMeta.name}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${newMeta.name}이 되었어요!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '누적 행복머니 ${widget.bokjuCount}개',
                        style: const TextStyle(
                          color: AppColors.secondaryLight,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: '확인',
                        fullWidth: false,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
