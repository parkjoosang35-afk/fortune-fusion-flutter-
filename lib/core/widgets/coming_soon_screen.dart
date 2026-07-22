import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 10단계(A안) 임시 화면 - 아직 구현되지 않은 AI 기능(타로/관상/손금/궁합/AI상담)의
/// 진입 지점을 미리 라우팅에 연결해두기 위한 공용 Placeholder.
/// 각 기능은 07단계 설계서에 따라 순차적으로 실제 화면으로 교체될 예정.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const ComingSoonScreen({
    super.key,
    required this.title,
    this.icon = Icons.auto_awesome_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 48, color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  '$title 기능은 곧 만나보실 수 있어요',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '더 완벽한 AI 분석을 위해 준비 중입니다.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
