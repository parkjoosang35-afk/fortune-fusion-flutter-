import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// 03단계 §2 Component 원자단위 - Skeleton Loader
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = AppRadius.cardSmall,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final opacity = 0.4 + 0.3 * (t < 0.5 ? t * 2 : (1 - t) * 2);
        final baseColor = Theme.of(context).dividerColor;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// 카드형 스켈레톤(리스트/결과화면 로딩용 조합)
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 120, height: 18),
          const SizedBox(height: AppSpacing.md),
          const SkeletonBox(height: 14),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonBox(height: 14, width: 220),
        ],
      ),
    );
  }
}
