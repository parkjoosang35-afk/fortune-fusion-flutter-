import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../domain/luckybag_product_model.dart';
import '../domain/luckybag_reward_model.dart';

/// 03단계 §10.2 "복주머니 열기" 결과화면 - 결과 카드 페이드인.
/// 등급별 반짝임 강도 차등(best > rare > common > none, 03§10.2 가이드).
class LuckyBagResultScreen extends StatefulWidget {
  final LuckyBagOpenResult result;
  final LuckyBagProductModel product;

  const LuckyBagResultScreen({
    super.key,
    required this.result,
    required this.product,
  });

  @override
  State<LuckyBagResultScreen> createState() => _LuckyBagResultScreenState();
}

class _LuckyBagResultScreenState extends State<LuckyBagResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  int get _sparkleCount {
    switch (widget.result.grade.code) {
      case 'best':
        return 16;
      case 'rare':
        return 10;
      case 'common':
        return 5;
      default:
        return 0;
    }
  }

  Color get _gradeColor {
    switch (widget.result.grade.code) {
      case 'best':
        return AppColors.secondaryDark;
      case 'rare':
        return AppColors.info;
      case 'common':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  String get _resultEmoji {
    switch (widget.result.rewardType) {
      case 'point':
        return '🪙';
      case 'amulet':
        return '🧿';
      case 'giftcard_fragment':
        return '🎟️';
      default:
        return '📭';
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWin = widget.result.grade.code != 'none';

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.mysticGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final fade = CurvedAnimation(
                    parent: _controller,
                    curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
                  ).value.clamp(0.0, 1.0);
                  final scale = CurvedAnimation(
                    parent: _controller,
                    curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
                  ).value.clamp(0.0, 1.3);
                  final sparkleT = _controller.value;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_sparkleCount > 0) ..._buildSparkles(sparkleT),
                            Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 120,
                                height: 120,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: isWin
                                      ? AppColors.goldGradient
                                      : null,
                                  color: isWin
                                      ? null
                                      : Colors.white.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  _resultEmoji,
                                  style: const TextStyle(fontSize: 52),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Opacity(
                        opacity: fade,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _gradeColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full,
                                ),
                              ),
                              child: Text(
                                widget.result.grade.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _gradeColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              isWin ? '축하해요! 좋은 행운을 발견했어요' : '다음 기회에 만나요',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              widget.result.rewardLabel,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: AppColors.secondary),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              '남은 복주머니 ${widget.result.remainingBalance}개',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            SizedBox(
                              width: 200,
                              child: AppButton(
                                label: '확인',
                                onPressed: () => Navigator.of(
                                  context,
                                ).popUntil((r) => r.settings.name == '/home'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSparkles(double t) {
    return List.generate(_sparkleCount, (i) {
      final angle = (2 * pi / _sparkleCount) * i;
      final distance = 55 + t * 45;
      final dx = cos(angle) * distance;
      final dy = sin(angle) * distance;
      final opacity = sin((t.clamp(0.0, 1.0)) * pi).clamp(0.0, 1.0);
      return Transform.translate(
        offset: Offset(dx, dy),
        child: Opacity(
          opacity: opacity,
          child: Icon(
            Icons.star_rounded,
            size: 12 + (i % 3) * 4,
            color: _gradeColor,
          ),
        ),
      );
    });
  }
}
