import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_button.dart';
import '../../../core/widgets/premium_chip.dart';
import '../../../core/widgets/premium_circle_button.dart';
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

/// [Fortune Fusion 서브 디자인 통일 마스터 프롬프트] 홈 화면 - 기준 시안 그대로 구현
///
/// 사용자가 제공한 홈 화면 목업(화이트 배경, 상단 로고+아이콘, 블랙 pill
/// "+오늘의 운세보기" 버튼, "타로이야기가기" 섹션, 전체운세/사주/궁합/손금 칩,
/// 인디고 그라디언트 히어로카드, 소원게시판/소원방 2단 라벤더 카드, 전체보기
/// 3버튼 로우, 하단 블랙 "열림패스" 바)를 기준 디자인으로 그대로 재구현한다.
///
/// [주의] Application/Data/Domain 레이어(Provider/Repository/Model)는 기존
/// 것을 그대로 재사용하며, 이 화면은 Presentation 레이어만 재작성한다.
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
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                96, // 하단 열림패스 고정바 높이만큼 여백 확보
              ),
              children: [
                // ① 상단 헤더 - 로고 + 클로버/벨 아이콘(배경 없는 bare 아이콘)
                const _TopHeader(),
                const SizedBox(height: AppSpacing.lg),

                // ② 블랙 pill CTA - "+ 오늘의 운세보기"
                const FadeSlideIn(
                  child: _TodayFortuneCta(),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ③ "타로이야기가기" 타이틀 + 우측 블랙 원형 그리드 버튼
                const FadeSlideIn(
                  delay: Duration(milliseconds: 40),
                  child: _TarotStoryHeader(),
                ),
                const SizedBox(height: AppSpacing.md),

                // ④ 칩 로우 - 전체운세(선택,네온라임)/사주/궁합/손금
                const FadeSlideIn(
                  delay: Duration(milliseconds: 80),
                  child: _FortuneCategoryChips(),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ⑤ 오늘의 운세 이야기 - 인디고 그라디언트 히어로카드
                const FadeSlideIn(
                  delay: Duration(milliseconds: 120),
                  child: _TodayStoryHeroCard(),
                ),
                const SizedBox(height: AppSpacing.md),

                // ⑥ 소원게시판 / 소원방 2단 라벤더 카드
                const FadeSlideIn(
                  delay: Duration(milliseconds: 160),
                  child: _WishBoardRoomRow(),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ⑦ 전체보기 타이틀 + 3버튼 로우
                Text('전체보기', style: AppTypography.sectionTitle.copyWith(fontSize: 17)),
                const SizedBox(height: AppSpacing.md),
                const FadeSlideIn(
                  delay: Duration(milliseconds: 200),
                  child: _AllMenuButtonsRow(),
                ),
                const SizedBox(height: AppSpacing.xl),

                const AdBannerWidget(position: 'home_bottom'),
              ],
            ),

            // ⑧ 하단 고정 블랙 pill 바 - "🔒 열림패스" + 네온라임 원형 화살표
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _OpenPassBottomBar(),
            ),
          ],
        ),
      ),
    );
  }
}

/// ① 상단 헤더 - 좌측 로고 텍스트 + 우측 클로버🍀/벨🔔 bare 아이콘
class _TopHeader extends StatelessWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context) {
    final notif = context.watch<NotificationProvider>();

    return Row(
      children: [
        Text(
          '신통방통',
          style: AppTypography.sectionTitle.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
          child: const Text('🍀', style: TextStyle(fontSize: 22)),
        ),
        const SizedBox(width: AppSpacing.md),
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/my/notifications'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                notif.unreadCount > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_none_rounded,
                size: 24,
                color: AppColors.premiumTextPrimary,
              ),
              if (notif.unreadCount > 0)
                Positioned(
                  right: -1,
                  top: -1,
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
        ),
      ],
    );
  }
}

/// ② "+ 오늘의 운세보기" 블랙 pill 버튼
class _TodayFortuneCta extends StatelessWidget {
  const _TodayFortuneCta();

  @override
  Widget build(BuildContext context) {
    return PremiumButton.black(
      label: '오늘의 운세보기',
      icon: Icons.add_rounded,
      height: 52,
      onPressed: () =>
          Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
    );
  }
}

/// ③ "타로이야기가기" 섹션 헤더 + 우측 블랙 원형 그리드 아이콘 버튼
class _TarotStoryHeader extends StatelessWidget {
  const _TarotStoryHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('타로이야기가기', style: AppTypography.cardTitle.copyWith(fontSize: 17)),
        const Spacer(),
        PremiumCircleButton(
          icon: Icons.grid_view_rounded,
          style: PremiumCircleButtonStyle.black,
          size: 32,
          onTap: () => Navigator.of(context).pushNamed('/ai-fortune/tarot/question'),
        ),
      ],
    );
  }
}

/// ④ 운세 카테고리 칩(가로 스크롤) - 전체운세/사주/궁합/손금
class _FortuneCategoryChips extends StatefulWidget {
  const _FortuneCategoryChips();

  @override
  State<_FortuneCategoryChips> createState() => _FortuneCategoryChipsState();
}

class _FortuneCategoryChipsState extends State<_FortuneCategoryChips> {
  int _selected = 0;
  bool _checking = false;

  // 기준 시안: 칩에는 아이콘 없이 텍스트만 표시
  static const _items = [
    ('전체운세', '/home/daily-fortune-detail', false),
    ('사주', '/ai-fortune/saju/input', true),
    ('궁합', '/ai-fortune/compatibility/input', true),
    ('손금', '/ai-fortune/palm/capture', true),
  ];

  Future<void> _handleTap(int index) async {
    setState(() => _selected = index);
    final (title, route, requiresPass) = _items[index];
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
          final (label, _, _) = _items[index];
          return PremiumChip(
            label: label,
            selected: _selected == index,
            onTap: _checking ? () {} : () => _handleTap(index),
          );
        },
      ),
    );
  }
}

/// ⑤ "오늘의 운세 이야기" 히어로카드 - 인디고 그라디언트 + 네온라임 원형 버튼
class _TodayStoryHeroCard extends StatelessWidget {
  const _TodayStoryHeroCard();

  @override
  Widget build(BuildContext context) {
    final today = context.watch<DailyFortuneProvider>().today;

    return PremiumCard(
      gradient: AppColors.premiumIndigoHeroGradient,
      borderColor: Colors.transparent,
      showShadow: false,
      onTap: () => Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Stack(
        children: [
          // 은은한 크레센트(초승달형) 글로우 장식 - 카드 하단에서 우상단으로 스윕
          Positioned(
            bottom: -30,
            left: 10,
            child: SoftGradientBlob(size: 150, color: Colors.white, opacity: 0.20),
          ),
          Positioned(
            bottom: -10,
            left: 70,
            child: SoftGradientBlob(size: 110, color: Colors.white, opacity: 0.16),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘의 운세 이야기',
                      style: AppTypography.cardTitle.copyWith(
                        color: Colors.white,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      today?.summaryText ?? '오늘은 당신의\n운명은 어떤 이야기가 펼쳐질까요?',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMain.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.5,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              PremiumCircleButton(
                icon: Icons.arrow_drop_up_rounded,
                style: PremiumCircleButtonStyle.neon,
                size: 34,
                onTap: () =>
                    Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ⑥ 소원게시판 / 소원방 2단 라벤더 카드
class _WishBoardRoomRow extends StatelessWidget {
  const _WishBoardRoomRow();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _LavenderMiniCard(
              title: '소원게시판',
              bottomLabel: '참여해보세요',
              circleIcon: Icons.arrow_drop_up_rounded,
              circleStyle: PremiumCircleButtonStyle.neon,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CommunityScreen()),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _LavenderMiniCard(
              title: '소원방',
              bottomLabel: '개인소원방',
              circleIcon: Icons.arrow_drop_down_rounded,
              circleStyle: PremiumCircleButtonStyle.black,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CommunityScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LavenderMiniCard extends StatelessWidget {
  const _LavenderMiniCard({
    required this.title,
    required this.bottomLabel,
    required this.circleIcon,
    required this.circleStyle,
    required this.onTap,
  });

  final String title;
  final String bottomLabel;
  final IconData circleIcon;
  final PremiumCircleButtonStyle circleStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: AppColors.premiumSoftLavender,
      borderColor: Colors.transparent,
      showShadow: false,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Stack(
        children: [
          // 은은한 원형 글로우 장식
          Positioned(
            bottom: -18,
            left: -10,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.cardTitle.copyWith(fontSize: 15),
                    ),
                  ),
                  PremiumCircleButton(
                    icon: circleIcon,
                    style: circleStyle,
                    size: 28,
                    onTap: onTap,
                  ),
                ],
              ),
              const SizedBox(height: 44),
              Text(bottomLabel, style: AppTypography.caption),
            ],
          ),
        ],
      ),
    );
  }
}

/// ⑦ 전체보기 - 부적만들기/궁합매칭/커뮤니티 3버튼 로우(가로 스크롤)
class _AllMenuButtonsRow extends StatelessWidget {
  const _AllMenuButtonsRow();

  static const _items = [
    ('부적만들기', '/reward/amulet/generate'),
    ('궁합매칭', '/ai-fortune/matching/discover'),
    ('커뮤니티', null),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final (label, route) = _items[index];
          return GestureDetector(
            onTap: () {
              if (route != null) {
                Navigator.of(context).pushNamed(route);
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CommunityScreen()),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.premiumSoftLavender,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(
                label,
                style: AppTypography.bodyStrong.copyWith(
                  color: AppColors.premiumDeepNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ⑧ 하단 고정 블랙 pill 바 - "🔒 열림패스" + 남은시간 + 네온라임 원형 화살표
class _OpenPassBottomBar extends StatelessWidget {
  const _OpenPassBottomBar();

  @override
  Widget build(BuildContext context) {
    final pass = context.watch<PassProvider>();
    final isActive = pass.isActive;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.premiumBlackCta,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  isActive ? '🔓' : '🔒',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '열림패스',
                  style: AppTypography.bodyStrong.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                PremiumCircleButton(
                  icon: Icons.chevron_right_rounded,
                  style: PremiumCircleButtonStyle.neon,
                  size: 34,
                  onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
