import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/grade_model.dart';

/// 03단계 §3.3 마이 탭 - MyPageScreen(프로필/히스토리/설정)
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('마이')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryContainer,
                    child: Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              user?.nickname ?? '게스트',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (auth.currentGrade != null) ...[
                              const SizedBox(width: AppSpacing.sm),
                              _GradeBadge(grade: auth.currentGrade!),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '로그인이 필요합니다',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.textHint,
                    ),
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed('/signup/profile-check'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _MenuTile(
              icon: Icons.auto_stories_outlined,
              title: '사주 히스토리',
              onTap: () =>
                  Navigator.of(context).pushNamed('/ai-fortune/saju/history'),
            ),
            _MenuTile(
              icon: Icons.receipt_long_outlined,
              title: '포인트 내역',
              onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
            ),
            _MenuTile(
              icon: Icons.notifications_none_rounded,
              title: '알림',
              onTap: () => Navigator.of(context).pushNamed('/my/notifications'),
            ),
            _MenuTile(
              icon: Icons.settings_outlined,
              title: '설정',
              onTap: () => Navigator.of(context).pushNamed('/my/settings'),
            ),
            _MenuTile(
              icon: Icons.info_outline_rounded,
              title: '앱 정보',
              onTap: () {},
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              onPressed: () async {
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              child: const Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Phase2-1: 04A §A-5 `user_grades` 등급 배지 - 마이페이지 프로필 카드에 노출
class _GradeBadge extends StatelessWidget {
  final GradeModel grade;

  const _GradeBadge({required this.grade});

  Color get _color {
    switch (grade.code) {
      case 'vip':
        return AppColors.secondaryDark;
      case 'gold':
        return AppColors.secondary;
      case 'silver':
        return AppColors.textSecondary;
      default:
        return AppColors.primaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        grade.name,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _color,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.cardSmall),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
