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
///
/// [화면 복제 정밀도 보정] 레퍼런스 이미지(390px 기준) 실측치를 그대로
/// 하드코딩 상수화한다. 좌우 패딩(16px) 통일 + 각 블록이 CTA 버튼과 동일한
/// 좌우 기준선(x=16 ~ x=374)에서 시작/종료하도록 폭을 맞추고, 세로 gap을
/// 레퍼런스처럼 촘촘하게 조정한다.
class _Dims {
  _Dims._();

  // 좌우 기준 페이지 패딩(모든 섹션 공통 시작선)
  static const double pagePadding = 16;

  // 헤더 아래 gap
  static const double headerBottomGap = 18;

  // CTA 버튼(+오늘의 운세보기) - radius는 PremiumButton이 height/2로 자동 계산(=22)
  static const double ctaHeight = 44;
  static const double ctaBottomGap = 22;

  // 타로이야기가기 헤더 아래 gap(칩 로우까지)
  static const double tarotHeaderBottomGap = 12;
  static const double tarotCircleSize = 30;

  // 카테고리 칩 - radius는 PremiumChip 내부에서 999(pill)로 고정
  // [검증] PremiumChip 내부 padding을 vertical:10→8로 축소하여(공용 컴포넌트 수정)
  // fontSize12/height1.3 텍스트(≈15.6px) + padding16 = 31.6px로 32px 타이트
  // 제약(SizedBox) 안에 여유 0.4px로 정확히 들어맞도록 보정함.
  static const double chipHeight = 32;
  static const double chipGap = 8;
  static const double chipsBottomGap = 16;

  // 헤더 row(아이콘 간격)
  static const double headerIconGap = 10;

  // 히어로 카드(오늘의 운세 이야기)
  static const double heroCardHeight = 136;
  static const double heroCardRadius = 20;
  static const double heroCardPadding = 18;
  static const double heroCardBottomGap = 13;
  static const double heroCircleSize = 30;

  // 소원게시판/소원방 2열 카드
  static const double wishCardGap = 8;
  static const double wishCardHeight = 120;
  static const double wishCardRadius = 18;
  static const double wishCardPadding = 14;
  static const double wishRowBottomGap = 18;
  static const double wishCircleSize = 27;

  // 전체보기 타이틀 + 3카드
  static const double allMenuTitleBottomGap = 12;
  static const double allMenuCardWidth = 108;
  static const double allMenuCardHeight = 80;
  static const double allMenuCardRadius = 16;
  static const double allMenuGap = 10;
  static const double allMenuBottomGap = 20;

  // 전체보기 아래 프로모 배너("AI 상담" 유도) - CMS 광고배너 없을 때 fallback
  static const double bannerHeight = 84;
  static const double bannerRadius = 20;
  static const double bannerPadding = 16;
  static const double bannerCircleSize = 30;

  // 하단 고정 열림패스 바
  static const double bottomBarHeight = 48;
  static const double bottomBarRadius = 24;
  static const double bottomBarTopGap = 20; // 열림패스 바 위 여백(콘텐츠와의 거리)
  static const double bottomBarBottomGap = 15; // 열림패스 바 아래 여백(탭바와의 거리)
  static const double bottomBarCircleSize = 32;

  // ListView 하단 예약 공간(= 바 위 여백 + 바 높이 + 바 아래 여백).
  // [배너 추가 세그먼트] 기존에는 +10 버퍼가 있어 배너~열림패스 사이 실제
  // 시각 gap이 30px(10 버퍼 + bottomBarTopGap 20)이 되어 사용자 스펙(16~20)을
  // 벗어났다. 버퍼를 제거해 마지막 콘텐츠(배너) 바로 아래가 열림패스 바의
  // bottomBarTopGap(20)과 정확히 맞물리도록 하여 gap을 스펙 범위(16~20)로 보정.
  // 열림패스 바 자체의 width/height/position(Positioned bottom:0 + 내부
  // padding 값)은 전혀 변경하지 않았다.
  static const double bottomBarReservedSpace =
      bottomBarTopGap + bottomBarHeight + bottomBarBottomGap;
}

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
                _Dims.pagePadding,
                _Dims.pagePadding,
                _Dims.pagePadding,
                _Dims.bottomBarReservedSpace, // 하단 열림패스 고정바(상단거리+높이+하단거리)만큼 여백 확보
              ),
              children: [
                // ① 상단 헤더 - 로고 + 클로버/벨 아이콘(배경 없는 bare 아이콘)
                const _TopHeader(),
                const SizedBox(height: _Dims.headerBottomGap),

                // ② 블랙 pill CTA - "+ 오늘의 운세보기"
                const FadeSlideIn(
                  child: _TodayFortuneCta(),
                ),
                const SizedBox(height: _Dims.ctaBottomGap),

                // ③ "타로이야기가기" 타이틀 + 우측 블랙 원형 그리드 버튼
                const FadeSlideIn(
                  delay: Duration(milliseconds: 40),
                  child: _TarotStoryHeader(),
                ),
                const SizedBox(height: _Dims.tarotHeaderBottomGap),

                // ④ 칩 로우 - 전체운세(선택,네온라임)/사주/궁합/손금
                const FadeSlideIn(
                  delay: Duration(milliseconds: 80),
                  child: _FortuneCategoryChips(),
                ),
                const SizedBox(height: _Dims.chipsBottomGap),

                // ⑤ 오늘의 운세 이야기 - 인디고 그라디언트 히어로카드
                const FadeSlideIn(
                  delay: Duration(milliseconds: 120),
                  child: _TodayStoryHeroCard(),
                ),
                const SizedBox(height: _Dims.heroCardBottomGap),

                // ⑥ 소원게시판 / 소원방 2단 라벤더 카드
                const FadeSlideIn(
                  delay: Duration(milliseconds: 160),
                  child: _WishBoardRoomRow(),
                ),
                const SizedBox(height: _Dims.wishRowBottomGap),

                // ⑦ 전체보기 타이틀 + 3버튼 로우
                Text('전체보기', style: AppTypography.sectionTitle.copyWith(fontSize: 17)),
                const SizedBox(height: _Dims.allMenuTitleBottomGap),
                const FadeSlideIn(
                  delay: Duration(milliseconds: 200),
                  child: _AllMenuButtonsRow(),
                ),
                const SizedBox(height: _Dims.allMenuBottomGap),

                // ⑧ 전체보기 아래 빈 공간 - 기존 AdBannerWidget(CMS 광고배너,
                // features/ad_banner)을 재사용. CMS에 활성 배너가 없을 때는
                // 완전히 사라지는 대신(fallback 없던 기존 동작) AI상담 유도
                // 프로모 카드(_ConsultationPromoBanner)를 대체 표시한다.
                AdBannerWidget(
                  position: 'home_bottom',
                  fallback: const _ConsultationPromoBanner(),
                ),
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
        const SizedBox(width: _Dims.headerIconGap),
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
      height: _Dims.ctaHeight,
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
          size: _Dims.tarotCircleSize,
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
      height: _Dims.chipHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: _Dims.chipGap),
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
      borderRadius: BorderRadius.circular(_Dims.heroCardRadius),
      showShadow: false,
      onTap: () => Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
      padding: const EdgeInsets.all(_Dims.heroCardPadding),
      child: SizedBox(
        height: _Dims.heroCardHeight - _Dims.heroCardPadding * 2,
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '오늘의 운세 이야기',
                        style: AppTypography.cardTitle.copyWith(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        today?.summaryText ?? '오늘은 당신의\n운명은 어떤 이야기가 펼쳐질까요?',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMain.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.5,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                PremiumCircleButton(
                  icon: Icons.arrow_drop_up_rounded,
                  style: PremiumCircleButtonStyle.neon,
                  size: _Dims.heroCircleSize,
                  onTap: () =>
                      Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ⑥ 소원게시판 / 소원방 2단 라벤더 카드
class _WishBoardRoomRow extends StatelessWidget {
  const _WishBoardRoomRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _Dims.wishCardHeight,
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
          const SizedBox(width: _Dims.wishCardGap),
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
      borderRadius: BorderRadius.circular(_Dims.wishCardRadius),
      showShadow: false,
      onTap: onTap,
      padding: const EdgeInsets.all(_Dims.wishCardPadding),
      child: Stack(
        children: [
          // 은은한 원형 글로우 장식 - 레퍼런스처럼 카드 대부분을 채우는 큰 사이즈
          Positioned(
            bottom: -30,
            right: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    size: _Dims.wishCircleSize,
                    onTap: onTap,
                  ),
                ],
              ),
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
    ('AI 상담', '/ai-fortune/consultation/type'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _Dims.allMenuCardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: _Dims.allMenuGap),
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
              width: _Dims.allMenuCardWidth,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.premiumSoftLavender,
                borderRadius: BorderRadius.circular(_Dims.allMenuCardRadius),
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

/// [배너 추가 세그먼트] 전체보기 아래 빈 공간을 메우는 보조 프로모 카드.
///
/// CMS 광고배너(`AdBannerWidget`)가 비어 있을 때(비활성/기간외/서버오류 등)
/// 표시되는 fallback으로, 새 배너 시스템을 만들지 않고 기존 `PremiumCard` +
/// `PremiumCircleButton` 디자인시스템 컴포넌트만 재사용해 구성한다. 톤은
/// 연라벤더 배경(`premiumSoftLavender`)으로 전체보기 카드/소원게시판 카드와
/// 통일하고, 시각적 무게는 열림패스 바(블랙 CTA)보다 가볍게 유지한다.
class _ConsultationPromoBanner extends StatelessWidget {
  const _ConsultationPromoBanner();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: AppColors.premiumSoftLavender,
      borderColor: Colors.transparent,
      borderRadius: BorderRadius.circular(_Dims.bannerRadius),
      showShadow: false,
      onTap: () => Navigator.of(context).pushNamed('/ai-fortune/consultation/type'),
      padding: const EdgeInsets.all(_Dims.bannerPadding),
      child: SizedBox(
        height: _Dims.bannerHeight - _Dims.bannerPadding * 2,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AI 상담으로 더 자세히 보기',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cardTitle.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '오늘의 운세를 기반으로 상담받아보세요',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            PremiumCircleButton(
              icon: Icons.chevron_right_rounded,
              style: PremiumCircleButtonStyle.black,
              size: _Dims.bannerCircleSize,
              onTap: () =>
                  Navigator.of(context).pushNamed('/ai-fortune/consultation/type'),
            ),
          ],
        ),
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
          _Dims.pagePadding,
          _Dims.bottomBarTopGap,
          _Dims.pagePadding,
          _Dims.bottomBarBottomGap,
        ),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
          child: Container(
            height: _Dims.bottomBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.premiumBlackCta,
              borderRadius: BorderRadius.circular(_Dims.bottomBarRadius),
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
                  size: _Dims.bottomBarCircleSize,
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
