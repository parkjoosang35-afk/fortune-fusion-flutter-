import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/cosmic_card.dart';
import '../../../core/widgets/point_badge.dart';
import '../../ad_banner/application/ad_banner_provider.dart';
import '../../ad_banner/presentation/ad_banner_widget.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../attendance/application/attendance_provider.dart';
import '../../fortune/daily/application/daily_fortune_provider.dart';
import '../../notification/notification_provider.dart';
import '../../luckybag/application/luckybag_provider.dart';
import '../../amulet/application/amulet_provider.dart';
import '../../community/application/wish_post_provider.dart';
import '../../community/presentation/community_screen.dart';
import '../../lucky_number/application/lucky_number_provider.dart';
import '../../lucky_number/presentation/lucky_number_widget.dart';
import '../../pass/application/pass_provider.dart';
import '../../pass/domain/pass_model.dart';
import '../../pass/presentation/pass_gate_helper.dart';
import '../../subscription/application/subscription_provider.dart';

/// [Fortune Fusion 3축 정책 반영] HomeScreen - 8개 섹션 신규 구성
/// ①상단상태(패스/복주머니/알림/마이) ②알림패스핵심(광고/제휴/구독/잔여시간)
/// ③운세카테고리(6종+패스검증) ④오늘의대표콘텐츠(요약운세/행운숫자, 무료미리보기)
/// ⑤커뮤니티미리보기(인기소원) ⑥복주머니적립(출석/미션/글쓰기/댓글 안내)
/// ⑦복주머니사용처(부적/동행) ⑧구독프로모션(추가혜택/광고배너)
///
/// [주의] Application/Data/Domain 레이어(Provider/Repository/Model)는 기존
/// 것을 그대로 재사용하며, 이 화면은 Presentation 레이어의 섹션 순서/구성만
/// 3축 정책(알림패스/복주머니/구독)에 맞춰 재배치한다.
class HomeScreenCosmic extends StatefulWidget {
  const HomeScreenCosmic({super.key});

  @override
  State<HomeScreenCosmic> createState() => _HomeScreenCosmicState();
}

class _HomeScreenCosmicState extends State<HomeScreenCosmic> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().load();
      context.read<AttendanceProvider>().load();
      context.read<DailyFortuneProvider>().loadToday();
      context.read<LuckyBagProvider>().load();
      context.read<AmuletProvider>().load();
      context.read<WishPostProvider>().loadFeed();
      context.read<LuckyNumberProvider>().load();
      context.read<PassProvider>().load();
      context.read<NotificationProvider>().load();
      context.read<SubscriptionProvider>().loadMySubscription();
      // [5단계] §8 구독프로모션 섹션의 광고 배너를 실제 AdBannerWidget으로
      // 연결하기 위해 관리자(admin_web CMS)가 등록한 배너를 미리 로드한다.
      context.read<AdBannerProvider>().loadPositions(const ['home_bottom']);
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final notif = context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: const Text(
          'Fortune Fusion',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.cosmicTextPrimary,
          ),
        ),
        // ①상단상태 — 알림패스 카운트다운(패스/복주머니 상태는 항상 상단에서 확인 가능)
        bottom: const _AlarmPassStatusBar(),
        actions: [
          PointBadge(
            balance: wallet.balance,
            onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
          ),
          const SizedBox(width: AppSpacing.sm),
          _CircleIconButton(
            icon: notif.unreadCount > 0
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
            showDot: notif.unreadCount > 0,
            onTap: () => Navigator.of(context).pushNamed('/my/notifications'),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // §2 알림패스 핵심 섹션(광고/제휴/구독 CTA) — 활성 상태면 자동 숨김
            const _AlarmPassSection(),
            const SizedBox(height: AppSpacing.xl),

            // §3 운세 카테고리(6종) — 각 카드는 공통 패스게이트(navigateWithPassGate)를 통과
            const _SectionTitle(title: '🔮 운세 카테고리'),
            const SizedBox(height: AppSpacing.md),
            const _FortuneCategoryGrid(),
            const SizedBox(height: AppSpacing.xl),

            // §4 오늘의 대표 콘텐츠 — 요약운세(무료 미리보기) + 행운숫자
            HeroFortuneSummaryCard(
              onCtaTap: () =>
                  Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
            ),
            const SizedBox(height: AppSpacing.md),
            const _SectionTitle(title: '🔢 오늘의 행운 숫자'),
            const SizedBox(height: AppSpacing.md),
            const _LuckyNumberSection(),
            const SizedBox(height: AppSpacing.xl),

            // §5 커뮤니티 미리보기 — 인기 소원 + 커뮤니티 안내
            const _SectionTitle(title: '🌠 지금 인기 있는 소원'),
            const SizedBox(height: AppSpacing.md),
            const _PopularWishSection(),
            const SizedBox(height: AppSpacing.md),
            const _CommunityBanner(),
            const SizedBox(height: AppSpacing.xl),

            // §6 복주머니 적립 — 출석/미션/글쓰기·댓글(커뮤니티 활동) 안내
            const _SectionTitle(title: '🍀 복주머니 적립하기'),
            const SizedBox(height: AppSpacing.md),
            const _LuckyBagEarnSection(),
            const SizedBox(height: AppSpacing.xl),

            // §7 복주머니 사용처 — 부적 만들기 / 운명의 동행
            const _SectionTitle(title: '✨ 복주머니 사용처'),
            const SizedBox(height: AppSpacing.md),
            const _AmuletMatchingRow(),
            const SizedBox(height: AppSpacing.xl),

            // §8 구독 프로모션 — 추가 혜택 배너 + 관리자 등록 광고 배너
            const _SectionTitle(title: '💎 구독으로 더 큰 혜택'),
            const SizedBox(height: AppSpacing.md),
            const _SubscriptionPromoBanner(),
            const SizedBox(height: AppSpacing.md),
            const AdBannerWidget(position: 'home_bottom'),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
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
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.bgTertiary,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.cosmicTextPrimary, size: 20),
          ),
          if (showDot)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.accentPink,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bgPrimary, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.onMore});

  final String title;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.cosmicTextPrimary,
          ),
        ),
        if (onMore != null)
          TextButton(
            onPressed: onMore,
            child: const Text(
              '더보기',
              style: TextStyle(
                color: AppColors.cosmicTextTertiary,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

/// §3 운세 카테고리 그리드 — 6종(사주/타로/궁합/전체운세/관상/손금).
/// [6단계] 각 카드는 FortuneHubScreen과 동일한 공통 패스게이트(navigateWithPassGate)를
/// 통과해야 상세 화면으로 진입한다(무료 콘텐츠인 "전체운세"는 예외).
class _FortuneCategoryGrid extends StatefulWidget {
  const _FortuneCategoryGrid();

  @override
  State<_FortuneCategoryGrid> createState() => _FortuneCategoryGridState();
}

class _FortuneCategoryGridState extends State<_FortuneCategoryGrid> {
  bool _checking = false;

  static const _items = [
    ('타로', Icons.style_rounded, AppColors.accentPurple, '/ai-fortune/tarot/question', true),
    ('사주', Icons.auto_stories_rounded, AppColors.accentGold, '/ai-fortune/saju/input', true),
    ('궁합', Icons.favorite_rounded, AppColors.accentPink, '/ai-fortune/compatibility/input', true),
    ('관상', Icons.face_retouching_natural_rounded, AppColors.accentPink, '/ai-fortune/face/capture', true),
    ('손금', Icons.back_hand_rounded, AppColors.accentMint, '/ai-fortune/palm/capture', true),
    ('전체운세', Icons.blur_circular_rounded, AppColors.accentBlue, '/home/daily-fortune-detail', false),
  ];

  Future<void> _handleTap(String title, String route, bool requiresPass) async {
    if (requiresPass) setState(() => _checking = true);
    await navigateWithPassGate(context, title: title, route: route, requiresPass: requiresPass);
    if (mounted && requiresPass) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final (label, icon, color, route, requiresPass) = _items[index];
        return CosmicCard(
          padding: const EdgeInsets.all(AppSpacing.sm),
          showGlow: false,
          onTap: _checking ? null : () => _handleTap(label, route, requiresPass),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cosmicTextPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// §4 오늘의 대표 콘텐츠 — 요약운세 카드(무료 미리보기, 상세는 daily-fortune-detail로 이동).
/// 기존 core/widgets/hero_fortune_card.dart(HeroFortuneCard)를 그대로 재사용한다.
class HeroFortuneSummaryCard extends StatelessWidget {
  const HeroFortuneSummaryCard({super.key, this.onCtaTap});

  final VoidCallback? onCtaTap;

  @override
  Widget build(BuildContext context) {
    final today = context.watch<DailyFortuneProvider>().today;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.gradientCosmic,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘의 대표 콘텐츠 · 무료 미리보기',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.cosmicTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            today?.summaryText ?? '오늘 당신에게 어떤 이야기가 펼쳐질까요?',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.cosmicTextPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerRight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onCtaTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientGold,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '자세히 보기',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.bgPrimary,
                          ),
                        ),
                        SizedBox(width: AppSpacing.xs),
                        Icon(Icons.arrow_forward, size: 16, color: AppColors.bgPrimary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// §4 행운숫자 영상/콘텐츠 섹션
class _LuckyNumberSection extends StatelessWidget {
  const _LuckyNumberSection();

  @override
  Widget build(BuildContext context) {
    final today = context.watch<DailyFortuneProvider>().today;
    return Consumer<LuckyNumberProvider>(
      builder: (context, luckyNumberProvider, _) {
        if (luckyNumberProvider.hasContent) {
          return SizedBox(
            height: 140,
            child: LuckyNumberWidget(
              height: 140,
              fallback: _LuckyNumberFallback(number: today?.luckyNumber),
            ),
          );
        }
        return _LuckyNumberFallback(number: today?.luckyNumber);
      },
    );
  }
}

class _LuckyNumberFallback extends StatelessWidget {
  const _LuckyNumberFallback({this.number});

  final int? number;

  @override
  Widget build(BuildContext context) {
    return CosmicCard(
      gradient: AppColors.gradientCosmic,
      onTap: () =>
          Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accentGold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number != null ? '$number' : '?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentGold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          const Expanded(
            child: Text(
              '오늘 당신의 행운을 부르는 숫자예요',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.cosmicTextSecondary,
              ),
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppColors.cosmicTextTertiary,
          ),
        ],
      ),
    );
  }
}

/// §5 인기 소원 섹션
class _PopularWishSection extends StatelessWidget {
  const _PopularWishSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishPostProvider>();
    final hot = provider.hotWishes.take(3).toList();

    if (provider.isLoading && hot.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accentPurple),
        ),
      );
    }

    if (hot.isEmpty) {
      return CosmicCard(
        showGlow: false,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CommunityScreen())),
        child: const Text(
          '아직 등록된 소원이 없어요. 첫 소원을 남겨보세요 🌠',
          style: TextStyle(color: AppColors.cosmicTextSecondary, fontSize: 13),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hot.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final wish = hot[index];
          return SizedBox(
            width: 220,
            child: CosmicCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              showGlow: false,
              onTap: () => Navigator.of(
                context,
              ).pushNamed('/community/wish/detail', arguments: wish),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wish.category,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentPink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      wish.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.cosmicTextPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        size: 12,
                        color: AppColors.accentPink,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${wish.supportCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.cosmicTextTertiary,
                        ),
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

/// §5 커뮤니티 안내 배너
class _CommunityBanner extends StatelessWidget {
  const _CommunityBanner();

  @override
  Widget build(BuildContext context) {
    return CosmicCard(
      gradient: AppColors.gradientWish,
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CommunityScreen())),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('💬', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '커뮤니티에 참여해보세요',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '소원을 나누고 함께 응원해요',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white,
            size: 16,
          ),
        ],
      ),
    );
  }
}

/// §6 복주머니 적립 섹션 — 출석체크 + 미션 + 커뮤니티 활동(글쓰기/댓글) 안내.
/// [3단계 복주머니 흐름 정리] 복주머니는 "커뮤니티 중심 재화"로, 적립 경로가
/// 여러 화면에 흩어져 있으므로 홈에서 한번에 안내한다.
class _LuckyBagEarnSection extends StatelessWidget {
  const _LuckyBagEarnSection();

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final luckyBag = context.watch<LuckyBagProvider>();
    final pending = luckyBag.summary?.pendingCount ?? 0;

    return Column(
      children: [
        CosmicCard(
          showGlow: false,
          onTap: () => Navigator.of(context).pushNamed('/reward/missions'),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentMint.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  color: AppColors.accentMint,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '오늘의 미션 완료하기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cosmicTextPrimary,
                      ),
                    ),
                    Text(
                      attendance.checkedToday
                          ? '출석 완료 · 연속 ${attendance.streak}일'
                          : '출석하고 복주머니 받기',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.cosmicTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.cosmicTextTertiary,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        CosmicCard(
          showGlow: false,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CommunityScreen())),
          child: const Row(
            children: [
              Text('✍️', style: TextStyle(fontSize: 20)),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '소원 글쓰기 · 댓글로 복주머니 받기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cosmicTextPrimary,
                      ),
                    ),
                    Text(
                      '커뮤니티 활동은 복주머니의 가장 큰 적립 경로예요',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.cosmicTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.cosmicTextTertiary,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        CosmicCard(
          showGlow: false,
          onTap: () => Navigator.of(context).pushNamed('/reward/luckybag'),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🍀', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '내 복주머니 전체보기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cosmicTextPrimary,
                      ),
                    ),
                    Text(
                      pending > 0
                          ? '받을 수 있는 복주머니 $pending개'
                          : '적립/사용 내역을 한눈에 확인해보세요',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.cosmicTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.cosmicTextTertiary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// §7 부적/동행 2단 카드 — 복주머니 사용처
class _AmuletMatchingRow extends StatelessWidget {
  const _AmuletMatchingRow();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CosmicCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              showGlow: false,
              onTap: () =>
                  Navigator.of(context).pushNamed('/reward/amulet/generate'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🧧 부적 만들기',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cosmicTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientGold,
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: AppColors.bgPrimary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    '나를 지켜주는 디지털 부적',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.cosmicTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: CosmicCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              showGlow: false,
              onTap: () => Navigator.of(
                context,
              ).pushNamed('/ai-fortune/matching/discover'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💫 운명의 동행',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cosmicTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientWish,
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    child: const Icon(
                      Icons.people_alt_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    '나와 인연이 될 사람 찾기',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.cosmicTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// §8 구독 프로모션 배너 — 미구독자에겐 가입 유도, 구독자에겐 혜택 요약을 보여준다.
class _SubscriptionPromoBanner extends StatelessWidget {
  const _SubscriptionPromoBanner();

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    final isPremium = sub.isPremium;

    return CosmicCard(
      gradient: AppColors.gradientGold,
      onTap: () => Navigator.of(context).pushNamed('/my/subscription/plans'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.workspace_premium_rounded, color: AppColors.bgPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? '구독 혜택을 받고 있어요' : '알림패스 + 복주머니 강화 상품',
                  style: const TextStyle(
                    color: AppColors.bgPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPremium
                      ? '정기 보너스와 광고 스트레스 완화를 계속 누려보세요'
                      : '알림패스 자동 지급 · 복주머니 정기 보너스 · 광고 완화',
                  style: const TextStyle(color: AppColors.bgPrimary, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.bgPrimary, size: 16),
        ],
      ),
    );
  }
}

/// 알림패스(AlarmPass) 상단 상태바 — AppBar.bottom에 장착되는 카운트다운.
/// 활성 상태가 아니면 높이 0(공간 차지 없음)으로 접혀 사라진다.
/// 서버 값(remainingSec)을 기준으로 1초 간격 로컬 타이머 없이 Provider 값을
/// 그대로 표시하고, 실제 만료 판정은 다음 PassProvider.load() 호출 시 서버가 갖는다.
class _AlarmPassStatusBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _AlarmPassStatusBar();

  @override
  Size get preferredSize => const Size.fromHeight(32);

  @override
  Widget build(BuildContext context) {
    final pass = context.watch<PassProvider>();
    if (!pass.isActive) return const SizedBox.shrink();

    final remaining = pass.status.remainingSec;
    final h = remaining ~/ 3600;
    final m = (remaining % 3600) ~/ 60;
    final s = remaining % 60;
    final label = h > 0
        ? '$h시간 $m분 남음'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} 남음';

    return Container(
      height: 32,
      color: AppColors.bgTertiary,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bolt_rounded, size: 14, color: AppColors.accentGold),
          const SizedBox(width: 4),
          Text(
            '알림패스 활성중 · ${pass.status.policyName ?? ''} · $label',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.accentGold,
            ),
          ),
        ],
      ),
    );
  }
}

/// §2 알림패스 핵심 섹션 — 광고 시청/파트너 방문 CTA 카드.
/// admin_web `GET /api/public/pass/policies` 정책 중 passType이 ad/partner인
/// 항목만 클라이언트에서 필터링해 노출한다(claim-ad/claim-partner API만 존재).
/// 이미 알림패스가 활성 상태면(상단 상태바로 충분히 안내되므로) 섹션을 숨긴다.
class _AlarmPassSection extends StatefulWidget {
  const _AlarmPassSection();

  @override
  State<_AlarmPassSection> createState() => _AlarmPassSectionState();
}

class _AlarmPassSectionState extends State<_AlarmPassSection> {
  bool _claiming = false;

  Future<void> _handleAdClaim(PassPolicyModel policy) async {
    final pass = context.read<PassProvider>();
    final confirmed = await showAppConfirmDialog(
      context,
      title: policy.name,
      message: policy.ctaText ?? '광고를 시청하고 알림패스를 받으시겠습니까?',
      confirmLabel: '시청하기',
    );
    if (!confirmed || !mounted) return;

    setState(() => _claiming = true);
    // [주의] AdMob 등 실제 광고 SDK가 아직 연동되지 않아, 확인 다이얼로그로
    // "시청 완료"를 대신한다(관리자 정책/보너스 로직은 서버가 실제로 처리).
    final ok = await pass.claimAd(policyId: policy.id);
    if (!mounted) return;
    setState(() => _claiming = false);

    if (ok) {
      await context.read<WalletProvider>().load();
      if (!mounted) return;
      AppToast.show(context, '알림패스가 발급되었습니다! (${policy.durationMin}분)');
    } else {
      AppToast.show(
        context,
        pass.lastError ?? '알림패스 발급에 실패했습니다.',
        isError: true,
      );
    }
  }

  Future<void> _handlePartnerClaim(PassPolicyModel policy) async {
    final pass = context.read<PassProvider>();
    final confirmed = await showAppConfirmDialog(
      context,
      title: policy.name,
      message: policy.ctaText ?? '파트너 페이지를 방문하고 알림패스를 받으시겠습니까?',
      confirmLabel: '방문하기',
    );
    if (!confirmed || !mounted) return;

    if (policy.linkUrl != null && policy.linkUrl!.isNotEmpty) {
      final uri = Uri.tryParse(policy.linkUrl!);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
    if (!mounted) return;

    setState(() => _claiming = true);
    final ok = await pass.claimPartner(policyId: policy.id);
    if (!mounted) return;
    setState(() => _claiming = false);

    if (ok) {
      await context.read<WalletProvider>().load();
      if (!mounted) return;
      AppToast.show(context, '알림패스가 발급되었습니다! (${policy.durationMin}분)');
    } else {
      AppToast.show(
        context,
        pass.lastError ?? '알림패스 발급에 실패했습니다.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pass = context.watch<PassProvider>();
    if (pass.isActive) return const SizedBox.shrink();

    final actionablePolicies = pass.policies
        .where(
          (p) => p.passType == PassType.ad || p.passType == PassType.partner,
        )
        .toList();
    if (actionablePolicies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⏱️ 알림패스 받기',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.cosmicTextPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...actionablePolicies.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _AlarmPassCard(
              policy: p,
              isBusy: _claiming,
              onTap: () => p.passType == PassType.ad
                  ? _handleAdClaim(p)
                  : _handlePartnerClaim(p),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlarmPassCard extends StatelessWidget {
  final PassPolicyModel policy;
  final bool isBusy;
  final VoidCallback onTap;

  const _AlarmPassCard({
    required this.policy,
    required this.isBusy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAd = policy.passType == PassType.ad;
    return CosmicCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      showGlow: false,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentGold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAd ? Icons.smart_display_rounded : Icons.storefront_rounded,
              color: AppColors.accentGold,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  policy.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cosmicTextPrimary,
                  ),
                ),
                Text(
                  '${policy.durationMin}분'
                  '${policy.bonusPoint > 0 ? ' · +${policy.bonusPoint}P' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.cosmicTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: isBusy ? null : onTap,
              child: Text(isAd ? '시청' : '방문'),
            ),
          ),
        ],
      ),
    );
  }
}
