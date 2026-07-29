import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cosmic_card.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/grade_model.dart';

/// [Fortune Fusion UI 리뉴얼 프롬프트] §8 MyScreen - 마이 탭
/// 프로필+등급뱃지 + 아카이브(사주/타로/관상/손금/궁합 히스토리) + 설정
///
/// [주의] AuthProvider/GradeModel/UserModel은 기존 것을 그대로 재사용하며,
/// 아카이브·설정 메뉴는 모두 기존 app_router.dart에 등록된 라우트로 이동한다.
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: const Text(
          '마이',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.cosmicTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // §1 프로필 카드
            CosmicCard(
              gradient: AppColors.gradientCosmic,
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.accentPurple,
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
                            Flexible(
                              child: Text(
                                user?.nickname ?? '게스트',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.cosmicTextPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.cosmicTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.cosmicTextTertiary,
                    ),
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed('/signup/profile-check'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // §2 아카이브 섹션
            const _SectionTitle(title: '📚 나의 운세 아카이브'),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 2.2,
              children: [
                _ArchiveCard(
                  emoji: '📜',
                  label: '사주 히스토리',
                  color: AppColors.accentGold,
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/saju/history'),
                ),
                _ArchiveCard(
                  emoji: '🔮',
                  label: '타로 히스토리',
                  color: AppColors.accentPurple,
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/tarot/history'),
                ),
                _ArchiveCard(
                  emoji: '🙂',
                  label: '관상 히스토리',
                  color: AppColors.accentBlue,
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/face/history'),
                ),
                _ArchiveCard(
                  emoji: '✋',
                  label: '손금 히스토리',
                  color: AppColors.accentMint,
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/palm/history'),
                ),
                _ArchiveCard(
                  emoji: '💞',
                  label: '궁합 히스토리',
                  color: AppColors.accentPink,
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/compatibility/history'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // §3 설정 섹션
            const _SectionTitle(title: '⚙️ 설정'),
            const SizedBox(height: AppSpacing.md),
            _MenuTile(
              icon: Icons.workspace_premium_outlined,
              title: '프리미엄 구독',
              onTap: () => Navigator.of(context).pushNamed('/my/subscription'),
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
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.cosmicTextPrimary,
      ),
    );
  }
}

/// Phase2-1: 04A §A-5 `user_grades` 등급 배지 - 우주 팔레트 톤으로 재구성
class _GradeBadge extends StatelessWidget {
  final GradeModel grade;

  const _GradeBadge({required this.grade});

  Color get _color {
    switch (grade.code) {
      case 'vip':
        return AppColors.accentGold;
      case 'gold':
        return AppColors.accentGold;
      case 'silver':
        return AppColors.cosmicTextSecondary;
      default:
        return AppColors.accentPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        grade.name,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CosmicCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      showGlow: false,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.cosmicTextPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
      child: CosmicCard(
        showGlow: false,
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: AppColors.cosmicTextSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.cosmicTextPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.cosmicTextTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
