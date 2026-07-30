import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cosmic_card.dart';
import '../../../core/widgets/app_shortcut_row.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/grade_model.dart';
import '../../pass/application/pass_provider.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../subscription/application/subscription_provider.dart';
import '../../community/presentation/community_hub_screen.dart';
import '../../fortune/presentation/fortune_hub_screen.dart';

/// [9단계 - 마이 탭 정리] MyScreen - 마이 탭
/// 프로필+등급뱃지 + [알림패스/복주머니/구독 요약(3축 정책 한눈에 보기)]
/// + 아카이브(사주/타로/관상/손금/궁합 히스토리) + 커뮤니티(내 글·소원) + 설정
///
/// [주의] AuthProvider/GradeModel/UserModel/PassProvider/WalletProvider/
/// SubscriptionProvider는 기존 것을 그대로 재사용하며, 아카이브·설정 메뉴는
/// 모두 기존 app_router.dart에 등록된 라우트로 이동한다.
class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  @override
  void initState() {
    super.initState();
    // [9단계] 마이 탭 진입 시 알림패스/복주머니/구독 요약을 최신화한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PassProvider>().load();
      context.read<WalletProvider>().load();
      context.read<SubscriptionProvider>().loadMySubscription();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final pass = context.watch<PassProvider>();
    final wallet = context.watch<WalletProvider>();
    final subscription = context.watch<SubscriptionProvider>();

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

            // [9단계] §1.5 알림패스/복주머니/구독 요약 - 3축 정책을 한 화면에서
            // 확인할 수 있도록 마이 탭에 요약 카드 3개를 배치한다.
            const _SectionTitle(title: '📋 내 혜택 요약'),
            const SizedBox(height: AppSpacing.md),
            _PassSummaryCard(
              pass: pass,
              isLoading: pass.isLoading,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FortuneHubScreen()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _WalletSummaryCard(
              balance: wallet.balance,
              isLoading: wallet.isLoading,
              onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
            ),
            const SizedBox(height: AppSpacing.md),
            _SubscriptionSummaryCard(
              subscription: subscription,
              isLoading: subscription.isLoadingSubscription,
              onTap: () =>
                  Navigator.of(context).pushNamed('/my/subscription'),
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

            // [9단계] §2.5 커뮤니티(내 글·내 소원) - 전용 "내 글 목록" API는
            // 아직 백엔드에 없으므로(mock 상태), 커뮤니티 허브로 진입시켜
            // 소원/게시판에서 직접 확인하도록 연결한다. 다음 턴에 "내 활동만
            // 필터링하는" 전용 API/화면으로 고도화할 수 있다.
            const _SectionTitle(title: '💬 나의 커뮤니티'),
            const SizedBox(height: AppSpacing.md),
            _MenuTile(
              icon: Icons.forum_outlined,
              title: '내 글 · 내 소원 보러가기',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CommunityHubScreen()),
              ),
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

/// [9단계] §1.5 알림패스 요약 카드 - 활성 여부와 남은 시간을 한눈에 보여준다.
/// [10단계 - 로딩 상태 보강] initState의 최초 load() 완료 전까지는 스켈레톤을
/// 표시해, "보유한 알림패스가 없어요"가 실제 무패스 상태인지 로딩 중인지
/// 혼동되지 않게 한다.
class _PassSummaryCard extends StatelessWidget {
  const _PassSummaryCard({
    required this.pass,
    required this.isLoading,
    required this.onTap,
  });

  final PassProvider pass;
  final bool isLoading;
  final VoidCallback onTap;

  String _formatRemaining(int sec) {
    final m = sec ~/ 60;
    final h = m ~/ 60;
    if (h > 0) return '$h시간 ${m % 60}분';
    return '$m분';
  }

  @override
  Widget build(BuildContext context) {
    final status = pass.status;
    return CosmicCard(
      showGlow: false,
      onTap: onTap,
      child: AppShortcutRow(
        emoji: '🔔',
        accentColor: AppColors.accentBlue,
        title: '알림패스',
        subtitle: isLoading
            ? '불러오는 중...'
            : status.isActive
                ? '사용 중 · 남은 시간 ${_formatRemaining(status.remainingSec)}'
                : '보유한 알림패스가 없어요',
      ),
    );
  }
}

/// [9단계] §1.5 복주머니 요약 카드 - 현재 잔액을 한눈에 보여준다.
class _WalletSummaryCard extends StatelessWidget {
  const _WalletSummaryCard({
    required this.balance,
    required this.isLoading,
    required this.onTap,
  });

  final int balance;
  final bool isLoading;
  final VoidCallback onTap;

  String _formatBalance(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return CosmicCard(
      showGlow: false,
      onTap: onTap,
      child: AppShortcutRow(
        emoji: '🍀',
        accentColor: AppColors.accentGold,
        title: '복주머니',
        subtitle: isLoading ? '불러오는 중...' : '${_formatBalance(balance)} P 보유 중',
      ),
    );
  }
}

/// [9단계] §1.5 구독 요약 카드 - 구독 활성 여부를 한눈에 보여준다.
class _SubscriptionSummaryCard extends StatelessWidget {
  const _SubscriptionSummaryCard({
    required this.subscription,
    required this.isLoading,
    required this.onTap,
  });

  final SubscriptionProvider subscription;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final my = subscription.mySubscription;
    final isActive = subscription.isPremium;
    return CosmicCard(
      showGlow: false,
      onTap: onTap,
      child: AppShortcutRow(
        emoji: '👑',
        accentColor: AppColors.accentPurple,
        title: '구독',
        subtitle: isLoading
            ? '불러오는 중...'
            : isActive
                ? '${my?.plan.name ?? '프리미엄'} 구독 중'
                : '구독하고 알림패스·복주머니 혜택 받기',
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
