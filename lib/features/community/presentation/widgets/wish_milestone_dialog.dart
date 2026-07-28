import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../application/wish_post_provider.dart';
import '../../domain/wish_post_model.dart';

/// [소원성(Wish Castle) 확장] "최종단계 특별 연출" - 촛불이 최종 레벨(4, 가장 밝은
/// 불꽃)에 최초로 도달했을 때 단 1회만 재생되는 전체화면 연출.
///
/// [설계] `isMilestoneShown` 플래그로 1회 제한을 보장한다(마스터 기획 §최종단계
/// 특별 연출 - 매번 재생하면 화려함이 피로감이 된다는 원칙). 다이얼로그가 닫힐 때
/// [WishPostProvider.markMilestoneShown]을 호출해 서버에도 즉시 반영한다.
///
/// "소원이 실제로 이루어진다"는 확정적 표현은 사용하지 않고, "가장 밝은 불꽃"·
/// "많은 사람의 마음이 모였다"는 식으로 응원의 결실을 표현한다(마스터 기획 필수 원칙).
class WishMilestoneDialog extends StatefulWidget {
  final WishPostModel post;
  const WishMilestoneDialog({super.key, required this.post});

  /// 이미 노출된 적이 없는 경우에만 표시한다. 호출부는 조건 검사 없이 항상
  /// 이 메서드를 불러도 안전하다(내부에서 isMilestoneShown을 확인).
  static Future<void> showIfNeeded(
    BuildContext context,
    WishPostModel post,
  ) async {
    if (post.isMilestoneShown || !post.isMaxLevel) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, _, __) => WishMilestoneDialog(post: post),
    );
    if (context.mounted) {
      await context.read<WishPostProvider>().markMilestoneShown(post.id);
    }
  }

  @override
  State<WishMilestoneDialog> createState() => _WishMilestoneDialogState();
}

class _WishMilestoneDialogState extends State<WishMilestoneDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..forward();

    final rand = Random(88);
    _stars = List.generate(28, (i) {
      return _Star(
        dx: rand.nextDouble() * 2 - 1,
        dy: rand.nextDouble() * 2 - 1,
        size: 2.0 + rand.nextDouble() * 3,
        delay: rand.nextDouble() * 0.6,
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
    final scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.5, curve: Curves.elasticOut),
    );
    final textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
    );
    final buttonFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
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
                SizedBox(
                  width: 240,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ..._stars.map((s) {
                        final t =
                            ((_controller.value - s.delay) / (1 - s.delay))
                                .clamp(0.0, 1.0);
                        final opacity = (sin(t * pi) * 0.9).clamp(0.0, 1.0);
                        return Positioned(
                          left: 120 + s.dx * 110,
                          top: 100 + s.dy * 90,
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              width: s.size,
                              height: s.size,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      }),
                      Transform.scale(
                        scale: scale.value.clamp(0.0, 1.2),
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: const BoxDecoration(
                            gradient: AppColors.goldGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary,
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '🌟',
                            style: TextStyle(fontSize: 62),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Opacity(
                  opacity: textFade.value.clamp(0.0, 1.0),
                  child: Column(
                    children: [
                      Text(
                        '가장 밝은 불꽃',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '많은 사람의 마음이 모여\n이 소원의 불빛이 가장 밝게 빛나고 있어요',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.6,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Opacity(
                  opacity: buttonFade.value.clamp(0.0, 1.0),
                  child: AppButton(
                    label: '고마워요',
                    fullWidth: false,
                    onPressed: () => Navigator.of(context).pop(),
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

class _Star {
  final double dx;
  final double dy;
  final double size;
  final double delay;
  const _Star({
    required this.dx,
    required this.dy,
    required this.size,
    required this.delay,
  });
}
