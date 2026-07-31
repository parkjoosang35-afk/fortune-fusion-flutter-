import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_button.dart';
import '../../../core/widgets/premium_chip.dart';
import '../../../core/widgets/premium_badge.dart';
import '../../../core/widgets/premium_graphics.dart';
import '../../ad_banner/application/ad_banner_provider.dart';
import '../../ad_banner/presentation/ad_banner_widget.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../attendance/application/attendance_provider.dart';
import '../../fortune/daily/application/daily_fortune_provider.dart';
import '../../notification/notification_provider.dart';
import '../../community/application/wish_post_provider.dart';
import '../../community/presentation/community_screen.dart';
import '../../pass/application/pass_provider.dart';
import '../../pass/presentation/pass_gate_helper.dart';

/// [Fortune Fusion 디자인 우선 리디자인 프롬프트] §7 홈 화면 레이아웃 재설계
///
/// 화이트 베이스의 깨끗한 프리미엄 운세 앱 톤으로 9섹션 고정 순서 구성.
/// ①상단인사말 ②오늘의우주이야기히어로 ③운세카테고리칩 ④인기있는소원
/// ⑤커뮤니티미리보기 ⑥오늘의활동미션(행복머니) ⑦열림패스 ⑧부적/운명의동행
/// ⑨(하단탭바는 AppShell에서 별도 처리)
///
/// [주의] Application/Data/Domain 레이어(Provider/Repository/Model)는 기존
/// 것을 그대로 재사용하며, 이 화면은 Presentation 레이어만 신규 작성한다.
/// 기존 HomeScreenCosmic은 삭제하지 않고 보존한다(비교/롤백 대비).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().load();
      context.read<AttendanceProvider>().load();
      context.read<DailyFortuneProvider>().loadToday();
      context.read<WishPostProvider>().loadFeed();
      context.read<PassProvider>().load();
      context.read<NotificationProvider>().load();
      context.read<AdBannerProvider>().loadPositions(const ['home_bottom']);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.premiumBgMain,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            // ① 상단 인사말
            const _GreetingHeader(),
            const SizedBox(height: AppSpacing.xl),

            // ② 오늘의 우주 이야기 히어로 카드
            const FadeSlideIn(
              delay: Duration(milliseconds: 40),
              child: _CosmicStoryHero(),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ③ 운세 카테고리 칩
            const FadeSlideIn(
              delay: Duration(milliseconds: 90),
              child: _FortuneCategoryChips(),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ④ 지금 인기 있는 소원
            const _SectionHeader(title: '🌠 지금 인기 있는 소원'),
            const SizedBox(height: AppSpacing.md),
            const FadeSlideIn(
              delay: Duration(milliseconds: 130),
              child: _PopularWishSection(),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ⑤ 커뮤니티 미리보기
            const FadeSlideIn(
              delay: Duration(milliseconds: 170),
              child: _CommunityPreviewSection(),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ⑥ 오늘의 활동 미션(행복머니)
            const _SectionHeader(title: '🍀 오늘의 활동 미션'),
            const SizedBox(height: AppSpacing.md),
            const FadeSlideIn(
              delay: Duration(milliseconds: 210),
              child: _DailyMissionSection(),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ⑦ 열림패스
            const FadeSlideIn(
              delay: Duration(milliseconds: 250),
              child: _OpenPassSection(),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ⑧ 부적 / 운명의 동행
            const _SectionHeader(title: '✨ 부적 · 운명의 동행'),
            const SizedBox(height: AppSpacing.md),
            const FadeSlideIn(
              delay: Duration(milliseconds: 290),
              child: _AmuletCompanionRow(),
            ),
            const SizedBox(height: AppSpacing.xl),

            const AdBannerWidget(position: 'home_bottom'),
          ],
        ),
      ),
    );
  }
}

/// ① 상단 인사말 — 날짜/상태 문구 + 검색/알림/프로필 아이콘
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context) {
    final notif = context.watch<NotificationProvider>();
    final wallet = context.watch<WalletProvider>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('안녕하세요.', style: AppTypography.bodyStrong),
              const SizedBox(height: 2),
              Text(
                '오늘 당신의 운명은\n어떤 이야기를 들려줄까요?',
                style: AppTypography.heroTitle.copyWith(fontSize: 22),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _WalletPill(
          balance: wallet.balance,
          onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
        ),
        const SizedBox(width: AppSpacing.sm),
        _RoundIconButton(
          icon: notif.unreadCount > 0
              ? Icons.notifications_rounded
              : Icons.notifications_none_rounded,
          showDot: notif.unreadCount > 0,
          onTap: () => Navigator.of(context).pushNamed('/my/notifications'),
        ),
      ],
    );
  }
}

class _WalletPill extends StatelessWidget {
  const _WalletPill({required this.balance, required this.onTap});

  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.premiumSoftGold.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🍀', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              '$balance',
              style: AppTypography.smallLabel.copyWith(
                color: const Color(0xFFB07C0F),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.premiumBgSection,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.premiumLightBorder),
            ),
            child: Icon(icon, color: AppColors.premiumTextPrimary, size: 19),
          ),
          if (showDot)
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.premiumCoralAccent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.premiumBgMain,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 섹션 타이틀(더보기 없이 단순화) — 공통 스타일
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTypography.sectionTitle.copyWith(fontSize: 17));
  }
}

/// ② 오늘의 우주 이야기 히어로 카드
class _CosmicStoryHero extends StatelessWidget {
  const _CosmicStoryHero();

  @override
  Widget build(BuildContext context) {
    final today = context.watch<DailyFortuneProvider>().today;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 12),
          child: child,
        ),
      ),
      child: PremiumCard(
        gradient: AppColors.premiumHeroGradient,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Stack(
          children: [
            const Positioned(
              top: -6,
              right: -6,
              child: SoftGradientBlob(size: 120, opacity: 0.18),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: FloatingMoon(size: 30, color: AppColors.premiumSoftGold),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('오늘의 우주 이야기', style: AppTypography.cardTitle),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  today?.summaryText ??
                      '오늘 당신에게 어떤 이야기가 펼쳐질까요?\n조용히 마음을 열고 들어보세요.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMain.copyWith(height: 1.5),
                ),
                const SizedBox(height: AppSpacing.lg),
                PremiumButton(
                  label: '오늘의 운세 보기',
                  fullWidth: false,
                  height: 44,
                  icon: Icons.auto_awesome_rounded,
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed('/home/daily-fortune-detail'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ③ 운세 카테고리 칩(가로 스크롤)
class _FortuneCategoryChips extends StatefulWidget {
  const _FortuneCategoryChips();

  @override
  State<_FortuneCategoryChips> createState() => _FortuneCategoryChipsState();
}

class _FortuneCategoryChipsState extends State<_FortuneCategoryChips> {
  int _selected = 0;
  bool _checking = false;

  static const _items = [
    ('오늘의 추천 타로', Icons.style_rounded, '/ai-fortune/tarot/question', true),
    ('사주', Icons.auto_stories_rounded, '/ai-fortune/saju/input', true),
    ('궁합', Icons.favorite_rounded, '/ai-fortune/compatibility/input', true),
    ('전체 운세', Icons.blur_circular_rounded, '/home/daily-fortune-detail', false),
  ];

  Future<void> _handleTap(int index) async {
    setState(() => _selected = index);
    final (title, _, route, requiresPass) = _items[index];
    if (requiresPass) setState(() => _checking = true);
    await navigateWithPassGate(
      context,
      title: title,
      route: route,
      requiresPass: requiresPass,
    );
    if (mounted && requiresPass) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final (label, icon, _, _) = _items[index];
          return PremiumChip(
            label: label,
            icon: icon,
            selected: _selected == index,
            onTap: _checking ? () {} : () => _handleTap(index),
          );
        },
      ),
    );
  }
}

/// ④ 인기 있는 소원 섹션
class _PopularWishSection extends StatelessWidget {
  const _PopularWishSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishPostProvider>();
    final hot = provider.hotWishes.take(3).toList();

    if (provider.isLoading && hot.isEmpty) {
      return const SizedBox(
        height: 88,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.premiumMainPurple),
        ),
      );
    }

    if (hot.isEmpty) {
      return PremiumCard(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CommunityScreen())),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '아직 오늘의 소원이 없어요.\n첫 소원을 남겨보세요!',
              style: AppTypography.bodyMain.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: PremiumButton.secondary(
                    label: '소원 보러가기',
                    height: 44,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CommunityScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PremiumButton(
                    label: '지금 참여하기',
                    height: 44,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CommunityScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hot.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final wish = hot[index];
          return SizedBox(
            width: 220,
            child: PremiumCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              onTap: () => Navigator.of(
                context,
              ).pushNamed('/community/wish/detail', arguments: wish),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumBadge(
                    label: wish.category,
                    type: PremiumBadgeType.pass,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      wish.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong.copyWith(height: 1.35),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: 13,
                        color: AppColors.premiumCoralAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${wish.supportCount}',
                        style: AppTypography.smallLabel,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ⑤ 커뮤니티 미리보기 섹션
class _CommunityPreviewSection extends StatelessWidget {
  const _CommunityPreviewSection();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      gradient: AppColors.premiumHeroGradient,
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CommunityScreen())),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.premiumMainPurple.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('💬', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('커뮤니티에 참여해보세요', style: AppTypography.cardTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '자유게시판 · 후기 · 고민상담 · 궁합이야기',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppColors.premiumTextTertiary,
          ),
        ],
      ),
    );
  }
}

/// ⑥ 오늘의 활동 미션(행복머니)
class _DailyMissionSection extends StatelessWidget {
  const _DailyMissionSection();

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final wallet = context.watch<WalletProvider>();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.premiumGoldGradient,
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Text('🍀', style: TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('내 행복머니', style: AppTypography.caption),
                    Text(
                      '${wallet.balance}P',
                      style: AppTypography.cardTitle,
                    ),
                  ],
                ),
              ),
              PremiumBadge(
                label: attendance.checkedToday ? '출석 완료' : '출석 대기',
                type: attendance.checkedToday
                    ? PremiumBadgeType.done
                    : PremiumBadgeType.luckyBag,
                emoji: attendance.checkedToday ? '✅' : '📅',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '출석하고, 운세를 보고, 글을 쓰면 행복머니가 쌓여요.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: PremiumButton.secondary(
                  label: '오늘의 미션 보기',
                  height: 44,
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/reward/missions'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: PremiumButton.secondary(
                  label: '사용처 보기',
                  height: 44,
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/reward/luckybag'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ⑦ 열림패스 섹션 — "열어보는 키" 느낌, 판매 유도 배제
class _OpenPassSection extends StatelessWidget {
  const _OpenPassSection();

  @override
  Widget build(BuildContext context) {
    final pass = context.watch<PassProvider>();
    final isActive = pass.isActive;
    final remaining = pass.status.remainingSec;
    final h = remaining ~/ 3600;
    final m = (remaining % 3600) ~/ 60;

    return PremiumCard(
      backgroundColor: AppColors.premiumDeepNavy,
      borderColor: AppColors.premiumDeepNavy,
      child: Stack(
        children: [
          const Positioned(top: -10, right: -10, child: DottedOrbit(size: 100)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🔓', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Text(
                          '열림패스',
                          style: AppTypography.cardTitle.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 상태 배지: isActive 전환 시 fade+scale 애니메이션
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 320),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(scale: anim, child: child),
                          ),
                          child: isActive
                              ? const _MiniStatusPill(
                                  key: ValueKey('active'),
                                  label: '진행중',
                                  color: AppColors.premiumMintAccent,
                                  textColor: Color(0xFF1B8A6B),
                                )
                              : const _MiniStatusPill(
                                  key: ValueKey('inactive'),
                                  label: '충전 필요',
                                  color: AppColors.premiumSoftGold,
                                  textColor: Color(0xFFB07C0F),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // 남은 시간/안내 문구: 상태 전환 시 부드럽게 교체
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.15),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        isActive
                            ? '$h시간 $m분 남음 · 지금 더 깊게 살펴보세요'
                            : '남은 시간 동안 더 깊게 살펴보세요',
                        key: ValueKey('$isActive-$h-$m'),
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PremiumButton(
                      label: '충전소 가기',
                      fullWidth: false,
                      height: 40,
                      onPressed: () => Navigator.of(context).pushNamed('/reward/wallet'),
                    ),
                  ],
                ),
              ),
              const SparkleDot(size: 20, color: AppColors.premiumSoftGold),
            ],
          ),
        ],
      ),
    );
  }
}

/// 열림패스 상태 배지 (진행중/충전 필요) - AnimatedSwitcher와 함께 사용
class _MiniStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _MiniStatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: AppTypography.smallLabel.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// ⑧ 부적 만들기 / 운명의 동행 2단 카드
class _AmuletCompanionRow extends StatelessWidget {
  const _AmuletCompanionRow();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PremiumCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              onTap: () =>
                  Navigator.of(context).pushNamed('/reward/amulet/generate'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: AppColors.premiumGoldGradient,
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    child: const Center(child: Text('🧧', style: TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('부적 만들기', style: AppTypography.cardTitle.copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('소원과 연결된\n나만의 상징 아이템', style: AppTypography.caption),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: PremiumCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              onTap: () => Navigator.of(
                context,
              ).pushNamed('/ai-fortune/matching/discover'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.premiumMainPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    child: const Center(child: Text('💫', style: TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('운명의 동행', style: AppTypography.cardTitle.copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('같은 목표를 가진\n사람과 함께 응원', style: AppTypography.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
