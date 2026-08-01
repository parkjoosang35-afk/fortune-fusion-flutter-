import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/app_shortcut_row.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/grade_model.dart';
import '../../pass/application/pass_provider.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../subscription/application/subscription_provider.dart';
import '../../community/presentation/community_hub_screen.dart';
import '../../fortune/presentation/fortune_hub_screen.dart';

/// [9단계 - 마이 탭 정리] MyScreen - 마이 탭
/// 프로필+등급뱃지 + [열림패스/행복머니/구독 요약(3축 정책 한눈에 보기)]
/// + 아카이브(사주/타로/관상/손금/궁합 히스토리) + 커뮤니티(내 글·소원) + 설정
///
/// [서브 디자인 통일 확산 프롬프트] §5 마이 탭 확산 규칙 적용. 기존 다크
/// "우주(Cosmic)" 톤(CosmicCard/AppColors.bgPrimary 등)을 홈 화면과 동일한
/// 화이트+라벤더 팔레트로 전면 전환한다. 화면 구조/섹션 순서는 그대로 유지.
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
    // [9단계] 마이 탭 진입 시 열림패스/행복머니/구독 요약을 최신화한다.
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
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('마이', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(UnifiedTokens.screenPadding),
          children: [
            // §1 프로필 카드
            PremiumCard(
              backgroundColor: UnifiedColors.cardSection,
              borderColor: Colors.transparent,
              showShadow: false,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
              padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
              child: Row(
                children: [
                  Container(
                    width: UnifiedTokens.iconCircleLg + 24,
                    height: UnifiedTokens.iconCircleLg + 24,
                    decoration: const BoxDecoration(
                      color: UnifiedColors.cardAllMenu,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: UnifiedColors.textPrimary,
                      size: UnifiedTokens.iconXl,
                    ),
                  ),
                  const SizedBox(width: UnifiedTokens.spaceLg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user?.nickname ?? '게스트',
                                style: UnifiedText.title(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (auth.currentGrade != null) ...[
                              const SizedBox(width: UnifiedTokens.spaceSm),
                              _GradeBadge(grade: auth.currentGrade!),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '로그인이 필요합니다',
                          style: UnifiedText.caption(),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      color: UnifiedColors.textCaption,
                      size: UnifiedTokens.iconLg,
                    ),
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed('/signup/profile-check'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            // [9단계] §1.5 열림패스/행복머니/구독 요약 - 3축 정책을 한 화면에서
            // 확인할 수 있도록 마이 탭에 요약 카드 3개를 배치한다.
            const _SectionTitle(title: '내 혜택 요약'),
            const SizedBox(height: UnifiedTokens.spaceMd),
            _PassSummaryCard(
              pass: pass,
              isLoading: pass.isLoading,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FortuneHubScreen()),
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            _WalletSummaryCard(
              balance: wallet.balance,
              isLoading: wallet.isLoading,
              onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            _SubscriptionSummaryCard(
              subscription: subscription,
              isLoading: subscription.isLoadingSubscription,
              onTap: () => Navigator.of(context).pushNamed('/my/subscription'),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            // §2 아카이브 섹션
            const _SectionTitle(title: '나의 운세 아카이브'),
            const SizedBox(height: UnifiedTokens.spaceMd),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: UnifiedTokens.spaceMd,
              crossAxisSpacing: UnifiedTokens.spaceMd,
              childAspectRatio: 2.2,
              children: [
                _ArchiveCard(
                  icon: Icons.auto_stories_outlined,
                  label: '사주 히스토리',
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/saju/history'),
                ),
                _ArchiveCard(
                  icon: Icons.style_outlined,
                  label: '타로 히스토리',
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/tarot/history'),
                ),
                _ArchiveCard(
                  icon: Icons.face_outlined,
                  label: '관상 히스토리',
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/face/history'),
                ),
                _ArchiveCard(
                  icon: Icons.back_hand_outlined,
                  label: '손금 히스토리',
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/palm/history'),
                ),
                _ArchiveCard(
                  icon: Icons.favorite_outline_rounded,
                  label: '궁합 히스토리',
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/compatibility/history'),
                ),
              ],
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            // [9단계] §2.5 커뮤니티(내 글·내 소원) - 전용 "내 글 목록" API는
            // 아직 백엔드에 없으므로(mock 상태), 커뮤니티 허브로 진입시켜
            // 소원/게시판에서 직접 확인하도록 연결한다. 다음 턴에 "내 활동만
            // 필터링하는" 전용 API/화면으로 고도화할 수 있다.
            const _SectionTitle(title: '나의 커뮤니티'),
            const SizedBox(height: UnifiedTokens.spaceMd),
            _MenuTile(
              icon: Icons.forum_outlined,
              title: '내 글 · 내 소원 보러가기',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CommunityHubScreen()),
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            // §3 설정 섹션
            const _SectionTitle(title: '설정'),
            const SizedBox(height: UnifiedTokens.spaceMd),
            PremiumCard(
              backgroundColor: UnifiedColors.bg,
              borderColor: UnifiedColors.border,
              showShadow: false,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _MenuRow(
                    icon: Icons.workspace_premium_outlined,
                    title: '프리미엄 구독',
                    onTap: () =>
                        Navigator.of(context).pushNamed('/my/subscription'),
                  ),
                  _MenuRow(
                    icon: Icons.notifications_none_rounded,
                    title: '알림',
                    onTap: () =>
                        Navigator.of(context).pushNamed('/my/notifications'),
                  ),
                  _MenuRow(
                    icon: Icons.settings_outlined,
                    title: '설정',
                    onTap: () =>
                        Navigator.of(context).pushNamed('/my/settings'),
                  ),
                  _MenuRow(
                    icon: Icons.info_outline_rounded,
                    title: '앱 정보',
                    onTap: () {},
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),
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
                foregroundColor: UnifiedColors.textSecondary,
                side: const BorderSide(color: UnifiedColors.border),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                ),
              ),
              child: Text('로그아웃', style: UnifiedText.bodyStrong()),
            ),
          ],
        ),
      ),
    );
  }
}

/// [9단계] §1.5 열림패스 요약 카드 - 활성 여부와 남은 시간을 한눈에 보여준다.
/// [서브 디자인 통일 확산 프롬프트] §5 "열림패스 요약은 잔여 시간만 담백하게".
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
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      onTap: onTap,
      child: AppShortcutRow(
        emoji: '🔔',
        accentColor: UnifiedColors.textPrimary,
        icon: Icons.lock_clock_outlined,
        iconColor: UnifiedColors.textPrimary,
        circleColor: UnifiedColors.bg,
        circleSize: UnifiedTokens.iconCircleLg,
        spacing: UnifiedTokens.spaceMd,
        titleStyle: UnifiedText.bodyStrong(),
        subtitleStyle: UnifiedText.caption(),
        arrowColor: UnifiedColors.textCaption,
        arrowSize: UnifiedTokens.iconMd,
        title: '열림패스',
        subtitle: isLoading
            ? '불러오는 중...'
            : status.isActive
            ? '남은 시간 ${_formatRemaining(status.remainingSec)}'
            : '보유한 열림패스가 없어요',
      ),
    );
  }
}

/// [9단계] §1.5 행복머니 요약 카드 - 현재 잔액을 한눈에 보여준다.
/// [서브 디자인 통일 확산 프롬프트] §5 "행복머니 요약은 잔액 + 짧은 안내".
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
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      onTap: onTap,
      child: AppShortcutRow(
        emoji: '🍀',
        accentColor: UnifiedColors.textPrimary,
        icon: Icons.eco_outlined,
        iconColor: UnifiedColors.textPrimary,
        circleColor: UnifiedColors.bg,
        circleSize: UnifiedTokens.iconCircleLg,
        spacing: UnifiedTokens.spaceMd,
        titleStyle: UnifiedText.bodyStrong(),
        subtitleStyle: UnifiedText.caption(),
        arrowColor: UnifiedColors.textCaption,
        arrowSize: UnifiedTokens.iconMd,
        title: '행복머니',
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
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      onTap: onTap,
      child: AppShortcutRow(
        emoji: '👑',
        accentColor: UnifiedColors.textPrimary,
        icon: Icons.workspace_premium_outlined,
        iconColor: UnifiedColors.textPrimary,
        circleColor: UnifiedColors.bg,
        circleSize: UnifiedTokens.iconCircleLg,
        spacing: UnifiedTokens.spaceMd,
        titleStyle: UnifiedText.bodyStrong(),
        subtitleStyle: UnifiedText.caption(),
        arrowColor: UnifiedColors.textCaption,
        arrowSize: UnifiedTokens.iconMd,
        title: '구독',
        subtitle: isLoading
            ? '불러오는 중...'
            : isActive
            ? '${my?.plan.name ?? '프리미엄'} 구독 중'
            : '구독하고 열림패스·행복머니 혜택 받기',
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: UnifiedText.titleLarge());
  }
}

/// Phase2-1: 04A §A-5 `user_grades` 등급 배지
class _GradeBadge extends StatelessWidget {
  final GradeModel grade;

  const _GradeBadge({required this.grade});

  @override
  Widget build(BuildContext context) {
    // [서브 디자인 통일 확산 프롬프트] §9 컬러 남용 금지 - 등급 색상 구분 대신
    // 블랙 텍스트 + 라벤더 배경 단일 톤으로 통일하고, 강조는 굵기로만 표현한다.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: UnifiedColors.cardAllMenu,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
      ),
      child: Text(grade.name, style: UnifiedText.chipLabel()),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.symmetric(
        horizontal: UnifiedTokens.spaceMd,
        vertical: UnifiedTokens.spaceSm,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: UnifiedTokens.iconCircleMd,
            height: UnifiedTokens.iconCircleMd,
            decoration: const BoxDecoration(
              color: UnifiedColors.bg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: UnifiedTokens.iconMd,
              color: UnifiedColors.textPrimary,
            ),
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          Expanded(
            child: Text(
              label,
              style: UnifiedText.bodyStrong(),
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
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: UnifiedColors.textPrimary,
            size: UnifiedTokens.iconLg,
          ),
          const SizedBox(width: UnifiedTokens.spaceMd),
          Expanded(child: Text(title, style: UnifiedText.bodyStrong())),
          Icon(
            Icons.chevron_right_rounded,
            color: UnifiedColors.textCaption,
            size: UnifiedTokens.iconMd,
          ),
        ],
      ),
    );
  }
}

/// [서브 디자인 통일 확산 프롬프트] §5 "리스트 아이템 높이 균일 48~56, 좌측
/// 아이콘 20(iconSize.lg), 우측 화살표 16(iconSize.md) 색상 #9A9AA2,
/// 라벨 BodyStrong14 SemiBold, 하단 구분선 #ECECEF" - 설정 리스트 전용 행.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: UnifiedTokens.spaceLg),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  bottom: BorderSide(color: UnifiedColors.border, width: 1),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: UnifiedColors.textPrimary,
              size: UnifiedTokens.iconLg,
            ),
            const SizedBox(width: UnifiedTokens.spaceMd),
            Expanded(child: Text(title, style: UnifiedText.bodyStrong())),
            Icon(
              Icons.chevron_right_rounded,
              color: UnifiedColors.textCaption,
              size: UnifiedTokens.iconMd,
            ),
          ],
        ),
      ),
    );
  }
}
