import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_button.dart';
import '../../../core/widgets/premium_chip.dart';
import '../../../core/widgets/premium_circle_button.dart';
import '../../../core/widgets/premium_graphics.dart';
import '../../healing_quote/application/healing_quote_provider.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../attendance/application/attendance_provider.dart';
import '../../fortune/daily/application/daily_fortune_provider.dart';
import '../../notification/notification_provider.dart';
import '../../community/application/wish_post_provider.dart';
import '../../community/presentation/community_screen.dart';
import '../../pass/application/pass_provider.dart';
import '../../pass/presentation/pass_gate_helper.dart';
import '../../pass/presentation/pass_time_format.dart';
import '../../../core/domain/access/access_checker.dart';
import '../../auth/application/auth_provider.dart';
import '../../wish_room/presentation/screens/wish_room_riverpod_entry.dart';
import 'home_style_tokens.dart';

/// [Fortune Fusion 서브 디자인 통일 마스터 프롬프트] 홈 화면 - 기준 시안 그대로 구현
///
/// 사용자가 제공한 홈 화면 목업(화이트 배경, 상단 로고+아이콘, 블랙 pill
/// "오늘의 운세보기" 버튼, "타로이야기가기" 섹션, 전체보기/사주/궁합/손금 칩,
/// 인디고 그라디언트 히어로카드, 소원게시판/소원방 2단 라벤더 카드, 전체보기
/// 3카드 로우, 하단 블랙 "열림패스" 바)를 기준 디자인으로 그대로 재구현한다.
///
/// [UI 정리 세그먼트] 상단 CTA는 "+" 아이콘 없이 텍스트만 정중앙 정렬하고,
/// 전체보기는 처음부터 3개 카드용으로 설계된 균등분배 레이아웃을 사용하며,
/// AI 상담 배너 아래에는 일반상담을 재사용하는 보조 카드("고민상담")를 둔다.
///
/// [홈 화면 최종 마감 정돈 프롬프트] 화면 구조/카드 배치/섹션 순서는 절대
/// 바꾸지 않고, 색상·폰트·카드 크기·간격·정렬·아이콘 크기만 사용자가 제시한
/// 정밀 스펙(390px 기준)으로 전면 재조정한다. 색/폰트는 `home_style_tokens.dart`
/// (HomeColors/HomeText/HomeTokens, 이 화면 전용)를 단일 소스로 사용하고,
/// 기존 하드코딩 값(그라디언트/장식 원/그림자 등)은 "그림자·외곽선·그라데이션
/// 추가 금지" 원칙에 따라 제거한다. 다른 화면이 공유하는 `AppColors`/
/// `AppTypography`/`PremiumChip`·`PremiumCircleButton`의 기존 기본값은 그대로
/// 유지하고(회귀 방지), override 파라미터로만 이 화면에 스펙 색상을 주입한다.
///
/// [주의] Application/Data/Domain 레이어(Provider/Repository/Model)는 기존
/// 것을 그대로 재사용하며, 이 화면은 Presentation 레이어만 재작성한다.
class _Dims {
  _Dims._();

  // 좌우 기준 페이지 패딩(모든 섹션 공통 시작선, x=16 좌우 기준선과 동일)
  static const double pagePadding = 16;

  // 헤더 아래 gap(헤더 로우 → CTA 버튼). 스펙 "SafeArea→헤더 14~18" 범위와
  // "세로 간격은 12/14/16/20만 사용" 원칙을 함께 만족시키는 값으로 확정.
  static const double headerBottomGap = 16;

  // CTA 버튼(+오늘의 운세보기) - radius는 PremiumButton이 height/2로 자동 계산(=22).
  // 이 버튼은 스펙의 카드 크기 표에 명시되지 않은 요소라 크기 자체는 손대지 않았다.
  static const double ctaHeight = 44;
  // CTA 버튼 → "타로이야기가기" 헤더 gap.
  static const double ctaBottomGap = 16;

  // "타로이야기가기" 헤더 아래 gap(칩 로우까지) = 스펙 "섹션 제목 → 칩 라인: 12"
  static const double tarotHeaderBottomGap = 12;
  // 섹션 우상단 원형 아이콘 배경 28 / 내부 아이콘 14(28*0.5=14, override 불필요)
  static const double tarotCircleSize = 28;

  // 카테고리 칩 - 스펙: height30 / 좌우padding12 / radius15 / gap8
  static const double chipHeight = 30;
  static const double chipGap = 8;
  // 칩 라인 → 메인 카드 gap = 스펙 14
  static const double chipsBottomGap = 14;

  // 헤더 row(아이콘 간격) - 스펙에 명시되지 않은 아이콘 내부 미세 간격이라 유지.
  static const double headerIconGap = 10;

  // 히어로 카드(→ 힐링 문구 카드) - 스펙: width358(자동)/height108~116/radius16/padding14
  static const double heroCardHeight = 112;
  static const double heroCardRadius = 16;
  static const double heroCardPadding = 14;
  // 메인 카드 → 소원게시판/소원방 2열 gap = 스펙 12
  static const double heroCardBottomGap = 12;

  // [사용자 요청] "오늘의 운세 이야기" 박스를 삭제하고, 쿠팡 광고 배너(AdBannerWidget,
  // position=home_middle, height=96) 영역까지 포함해 힐링 문구 카드를 아래로 확장한다.
  // 기존 배너(96) + 배너-히어로 사이 gap이 없었으므로(연속 배치), 순수 배너 높이만큼만
  // 히어로 카드 높이에 더한다: heroCardHeight(112) + adBannerHeight(96) = 208.
  static const double healingCardHeight = heroCardHeight + 96;

  // 소원게시판/소원방 2열 카드 - 스펙: gap8/각width175(자동)/height96~104/radius16/padding14
  static const double wishCardGap = 8;
  static const double wishCardHeight = 100;
  static const double wishCardRadius = 16;
  static const double wishCardPadding = 14;
  // 카드 우상단 원형 CTA 배경 26~28 → 27(중앙값), 내부 아이콘 14로 override
  static const double wishCircleSize = 27;

  // 하단 고정 열림패스 바 - 스펙: width358(자동)/height48/radius24/좌우padding16
  static const double bottomBarHeight = 48;
  static const double bottomBarRadius = 24;
  // 소원게시판/소원방 카드 → 열림패스 바 gap = 스펙 "카드→열림패스바 14" 적용
  static const double bottomBarTopGap = 14;
  // 열림패스 바 → 탭바 gap = 스펙 14
  static const double bottomBarBottomGap = 14;
  static const double bottomBarCircleSize = 32;

  // ListView 하단 예약 공간(= 바 위 여백 + 바 높이 + 바 아래 여백).
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
      // [사용자 요청] "오늘의 운세 이야기"를 완전히 삭제하고 데이터베이스 기반 힐링
      // 문구로 대체 — admin_web `/api/public/healing-quotes`에서 활성 문구 목록을
      // 불러와 1분마다 자동 순환한다(AdBannerProvider.loadPositions 호출은 제거).
      context.read<HealingQuoteProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                _Dims.pagePadding,
                _Dims.pagePadding,
                _Dims.pagePadding,
                _Dims
                    .bottomBarReservedSpace, // 하단 열림패스 고정바(상단거리+높이+하단거리)만큼 여백 확보
              ),
              children: [
                // ① 상단 헤더 - 로고 + 클로버/벨 아이콘(배경 없는 bare 아이콘)
                const _TopHeader(),
                const SizedBox(height: _Dims.headerBottomGap),

                // ② 블랙 pill CTA - "+ 오늘의 운세보기"
                const FadeSlideIn(child: _TodayFortuneCta()),
                const SizedBox(height: _Dims.ctaBottomGap),

                // ③ [첨부 디자인 반영] "전체보기" 타이틀 + 우측 블랙 원형
                // 그리드 버튼 - 탭 시 운세 전체보기(카테고리 허브) 화면으로 이동한다.
                const FadeSlideIn(
                  delay: Duration(milliseconds: 40),
                  child: _AllCategoriesHeader(),
                ),
                const SizedBox(height: _Dims.tarotHeaderBottomGap),

                // ④ 칩 로우 - 전체보기(선택,네온라임)/사주/궁합/손금
                const FadeSlideIn(
                  delay: Duration(milliseconds: 80),
                  child: _FortuneCategoryChips(),
                ),
                const SizedBox(height: _Dims.chipsBottomGap),

                // ⑤ [사용자 요청] "오늘의 운세 이야기"(운세 기능) + 쿠팡 광고
                // 배너(AdBannerWidget, position=home_middle)를 완전히 삭제하고,
                // 그 자리(광고 영역까지 포함)를 힐링 문구 카드로 크게 확장한다.
                // 운세와 무관하며, db 기반 문구를 1분마다 자동 순환하고 배경색은
                // 30분마다 자동 변경된다(대비를 고려해 텍스트 색도 자동 조정).
                const FadeSlideIn(
                  delay: Duration(milliseconds: 120),
                  child: _HealingQuoteCard(),
                ),
                const SizedBox(height: _Dims.heroCardBottomGap),

                // ⑤-1 [첨부 디자인 반영] "운세"/"타로" 2분할 카드 - 연보라/
                // 파스텔블루 톤. 각각 오늘의 운세 상세, 타로 메인 홈으로 이동한다.
                const FadeSlideIn(
                  delay: Duration(milliseconds: 140),
                  child: _FortuneTarotRow(),
                ),
                const SizedBox(height: _Dims.heroCardBottomGap),

                // ⑥ 소원게시판 / 소원방 2단 카드(#F5F3FB, 완전 동일)
                // [첨부 디자인 반영] 목업에는 이 2단 카드까지만 존재하고 그
                // 아래(전체보기 3버튼/AI상담 배너/고민상담 카드)는 없으므로,
                // 여기서 화면을 마무리한다("나머지는 안보여도 됨").
                const FadeSlideIn(
                  delay: Duration(milliseconds: 160),
                  child: _WishBoardRoomRow(),
                ),
              ],
            ),

            // ⑧ 하단 고정 블랙 pill 바 - "열림패스" + 네온라임 원형 화살표
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

/// ① 상단 헤더 - 좌측 로고 텍스트 + 우측 클로버🍀/벨 bare 아이콘
class _TopHeader extends StatelessWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context) {
    final notif = context.watch<NotificationProvider>();
    final auth = context.watch<AuthProvider>();

    return Row(
      children: [
        // [예외] 브랜드 로고타입은 Type Scale(최대 17px) 범위를 벗어나는
        // 유일한 예외 요소다(앱 전체에서 1회만 등장하는 워드마크). 크기(22)는
        // 유지하고 컬러만 스펙 텍스트 기본색(#111111)으로 정확히 맞춘다.
        Text(
          '신통방통',
          style: TextStyle(
            fontFamily: HomeText.family,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            height: 1.3,
            color: HomeColors.textPrimary,
          ),
        ),
        const Spacer(),
        // 벨 아이콘 - 스펙 "상단 우측 알림/클로버 아이콘: 20~22" 범위 상단값(22),
        // 컬러는 기본 텍스트 아이콘 규칙(#111111) 적용.
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/my/notifications'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                notif.unreadCount > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_none_rounded,
                size: HomeTokens.iconXl,
                color: HomeColors.textPrimary,
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
                      border: Border.all(color: HomeColors.bg, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: _Dims.headerIconGap),
        // [첨부 디자인 반영] 우측 끝 원형 프로필 아바타 - 로그인 상태면
        // 마이페이지(설정)로, 비로그인 상태면 로그인 화면으로 이동한다.
        GestureDetector(
          onTap: () => Navigator.of(
            context,
          ).pushNamed(auth.isLoggedIn ? '/my/settings' : '/login'),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HomeColors.cardAllMenu,
              border: Border.all(color: HomeColors.border, width: 1),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.person_rounded,
              size: 18,
              color: HomeColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// ② "+ 오늘의 운세보기" 블랙 pill 버튼
///
/// [범위 외] PremiumButton.black은 CommunityHubScreen/LuckyBagScreen에서도
/// 그대로 쓰이는 공유 컴포넌트라 색상(#121212, 스펙 #111111과 1px 차이로
/// 육안상 동일)은 건드리지 않았다. 스펙의 카드 크기 표에도 이 CTA는 명시되지
/// 않은 요소다.
class _TodayFortuneCta extends StatelessWidget {
  const _TodayFortuneCta();

  @override
  Widget build(BuildContext context) {
    return PremiumButton.black(
      label: '오늘의 운세보기',
      height: _Dims.ctaHeight,
      onPressed: () =>
          Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
    );
  }
}

/// ③ [첨부 디자인 반영] "전체보기" 섹션 헤더 + 우측 블랙 원형 그리드 아이콘
/// 버튼 - 탭 시 운세 전체보기(카테고리 허브, `/home/all-categories`)로 이동한다.
class _AllCategoriesHeader extends StatelessWidget {
  const _AllCategoriesHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // [범위 외] 이 20x20 블랙 배지는 스펙의 아이콘 크기표(헤더/섹션원형/
        // 카드CTA/AI배너CTA/열림패스 등)에 명시되지 않은 장식 마커라 크기는
        // 유지했다. 컬러만 블랙 포인트(#111111)로 통일한다.
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HomeColors.black,
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(Icons.style_rounded, size: 12, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text('전체보기', style: HomeText.titleLarge()),
        const Spacer(),
        // 섹션 우상단 원형 아이콘 배경 28 / 내부 아이콘 14(28*0.5=14).
        // 블랙 CTA 색상을 스펙 정확값(#111111)으로 override.
        PremiumCircleButton(
          icon: Icons.grid_view_rounded,
          style: PremiumCircleButtonStyle.black,
          size: _Dims.tarotCircleSize,
          bgColor: HomeColors.black,
          fgColor: Colors.white,
          // [첨부 디자인 반영] "오늘의 운세보기" CTA 바로 아래 "전체보기"
          // 섹션은 운세 전체보기(카테고리 허브) 화면으로 이동하는 것이
          // 사용자 의도이므로, 타로 메인 홈이 아니라 이 라우트로 연결한다.
          onTap: () => Navigator.of(context).pushNamed('/home/all-categories'),
        ),
      ],
    );
  }
}

/// ④ 운세 카테고리 칩(가로 스크롤) - 전체보기/사주/이름 운세/손금
class _FortuneCategoryChips extends StatefulWidget {
  const _FortuneCategoryChips();

  @override
  State<_FortuneCategoryChips> createState() => _FortuneCategoryChipsState();
}

class _FortuneCategoryChipsState extends State<_FortuneCategoryChips> {
  // [첨부 디자인 반영] 첨부 목업은 "사주" 칩이 기본 선택(네온라임 강조)된
  // 상태를 보여준다. 목업의 "궁합" 칩은 앱에서 이미 삭제된 기능이라, 실제
  // 존재하는 기능 중 시각적으로 가장 가까운 "관상"으로 대체했다.
  int _selected = 1;
  bool _checking = false;

  // 기준 시안: 칩에는 아이콘 없이 텍스트만 표시
  static const _items = [
    ('전체보기', '/home/all-categories', false),
    ('사주', '/ai-fortune/saju/input', true),
    ('관상', '/ai-fortune/face/capture', true),
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
          final selected = _selected == index;
          // 스펙: height30/좌우padding12/radius15/활성 칩만 형광(#C6F24E) 배경.
          return PremiumChip(
            label: label,
            selected: selected,
            onTap: _checking ? () {} : () => _handleTap(index),
            height: _Dims.chipHeight,
            horizontalPadding: 12,
            radius: 15,
            activeBg: HomeColors.neon,
            activeFg: HomeColors.textPrimary,
            inactiveBg: HomeColors.chipInactiveBg,
            inactiveFg: HomeColors.textSecondary,
            labelStyle: HomeText.chipLabel(),
          );
        },
      ),
    );
  }
}

/// ⑤ [사용자 요청] "오늘의 운세 이야기"를 완전히 삭제하고 대체한 힐링 문구 카드.
///
/// - 운세 기능(DailyFortuneProvider 참조, 상세화면 이동)은 완전히 제거했다 —
///   이 카드는 탭 액션이 없는 순수 콘텐츠 카드다.
/// - 좋은 글귀/힐링 문구/긍정 명언/응원의 한마디를 admin_web DB에서 불러와
///   [HealingQuoteProvider]가 1분마다 자동으로 다음 문구로 순환시킨다(24시간 반복).
/// - 카드 배경색은 30분마다 부드럽고 감성적인 파스텔 팔레트에서 랜덤 선택되어
///   자동 변경되고, 텍스트 색은 배경 밝기에 따라 항상 잘 보이도록 자동 대비
///   조정된다(luminance 기반 흑/백 판정).
/// - 기존 "오늘의 운세 이야기" 히어로카드 + 그 위 쿠팡 광고 배너(96px) 영역을
///   합친 만큼 높이를 확장했다([_Dims.healingCardHeight]).
class _HealingQuoteCard extends StatefulWidget {
  const _HealingQuoteCard();

  @override
  State<_HealingQuoteCard> createState() => _HealingQuoteCardState();
}

class _HealingQuoteCardState extends State<_HealingQuoteCard> {
  static const Duration _bgRotationInterval = Duration(minutes: 30);

  // 부드럽고 감성적인 파스텔 계열 배경색 팔레트. 30분마다 이 중 하나를
  // 랜덤으로 선택해 카드 배경을 자동 변경한다.
  static const List<Color> _palette = [
    Color(0xFFEDE7F6), // 라벤더
    Color(0xFFE1F5FE), // 스카이블루
    Color(0xFFFFF3E0), // 피치
    Color(0xFFE8F5E9), // 민트그린
    Color(0xFFFCE4EC), // 로즈핑크
    Color(0xFFFFF9C4), // 크림옐로
    Color(0xFFE0F2F1), // 아쿠아
    Color(0xFFF3E5F5), // 라일락
    Color(0xFFECEFF1), // 그레이블루
    Color(0xFFFFEBEE), // 소프트코럴
  ];

  final Random _random = Random();
  late Color _bgColor;
  Timer? _bgTimer;

  @override
  void initState() {
    super.initState();
    _bgColor = _pickRandomColor();
    // [사용자 요청] "배경색을 30분마다 자동으로 변경... 부드럽고 감성적인
    // 색상을 랜덤으로 적용"
    _bgTimer = Timer.periodic(_bgRotationInterval, (_) {
      if (!mounted) return;
      setState(() => _bgColor = _pickRandomColor());
    });
  }

  Color _pickRandomColor() => _palette[_random.nextInt(_palette.length)];

  /// 배경색 밝기(luminance)를 기준으로 항상 잘 보이는 텍스트 색을 계산한다.
  /// 팔레트가 전부 밝은 파스텔이라 기본은 짙은 텍스트지만, 향후 팔레트가
  /// 어두운 색을 포함하게 되어도 자동으로 대비가 유지되도록 일반화했다.
  Color _contrastTextColor(Color background) {
    return background.computeLuminance() > 0.5
        ? const Color(0xFF1A1A1A)
        : Colors.white;
  }

  @override
  void dispose() {
    _bgTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final healing = context.watch<HealingQuoteProvider>();
    final quote = healing.current;
    final textColor = _contrastTextColor(_bgColor);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(_Dims.heroCardRadius),
      ),
      padding: const EdgeInsets.all(_Dims.heroCardPadding),
      child: SizedBox(
        height: _Dims.healingCardHeight - _Dims.heroCardPadding * 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(
                  Icons.self_improvement_rounded,
                  size: 18,
                  color: textColor.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 6),
                Text(
                  '오늘의 힐링 한마디',
                  style: HomeText.body(
                    color: textColor.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                quote?.content ?? '잠시 마음을 쉬어가도 괜찮아요.\n당신은 충분히 잘하고 있습니다.',
                key: ValueKey(quote?.id ?? -1),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: HomeText.title(color: textColor).copyWith(height: 1.35),
              ),
            ),
            if (quote?.author != null && quote!.author!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '- ${quote.author}',
                style: HomeText.caption(
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ⑤-1 [첨부 디자인 반영] "운세"/"타로" 2분할 카드
///
/// 좌측 "운세" 카드는 연보라(#F0EEFB 계열) 배경 + 네온라임 원형(위쪽 화살표)
/// 버튼으로 오늘의 운세 상세로 이동하고, 우측 "타로" 카드는 더 밝은 파스텔
/// 블루-라벤더 배경 + 블랙 원형(아래쪽 화살표) 버튼으로 타로 메인 홈으로
/// 이동한다. 각 카드 하단에는 작은 부제(운세이야기/타로이야기)를 배치해
/// 첨부 목업의 레이아웃을 그대로 재현한다.
class _FortuneTarotRow extends StatelessWidget {
  const _FortuneTarotRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _Dims.wishCardHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _FortuneTarotMiniCard(
              title: '운세',
              bottomLabel: '운세이야기',
              backgroundColor: HomeColors.cardMain,
              circleIcon: Icons.arrow_drop_up_rounded,
              circleStyle: PremiumCircleButtonStyle.neon,
              onTap: () =>
                  Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
            ),
          ),
          const SizedBox(width: _Dims.wishCardGap),
          Expanded(
            child: _FortuneTarotMiniCard(
              title: '타로',
              bottomLabel: '타로이야기',
              backgroundColor: HomeColors.cardWish,
              circleIcon: Icons.arrow_drop_down_rounded,
              circleStyle: PremiumCircleButtonStyle.black,
              onTap: () => Navigator.of(context).pushNamed('/tarot/home'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FortuneTarotMiniCard extends StatelessWidget {
  const _FortuneTarotMiniCard({
    required this.title,
    required this.bottomLabel,
    required this.backgroundColor,
    required this.circleIcon,
    required this.circleStyle,
    required this.onTap,
  });

  final String title;
  final String bottomLabel;
  final Color backgroundColor;
  final IconData circleIcon;
  final PremiumCircleButtonStyle circleStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overrideBg = circleStyle == PremiumCircleButtonStyle.neon
        ? HomeColors.neon
        : HomeColors.black;
    final overrideFg = circleStyle == PremiumCircleButtonStyle.neon
        ? HomeColors.textPrimary
        : Colors.white;

    return PremiumCard(
      backgroundColor: backgroundColor,
      borderColor: Colors.transparent,
      borderRadius: BorderRadius.circular(_Dims.wishCardRadius),
      showShadow: false,
      onTap: onTap,
      padding: const EdgeInsets.all(_Dims.wishCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(title, style: HomeText.title())),
              PremiumCircleButton(
                icon: circleIcon,
                style: circleStyle,
                size: _Dims.wishCircleSize,
                iconSize: 14,
                bgColor: overrideBg,
                fgColor: overrideFg,
                onTap: onTap,
              ),
            ],
          ),
          Text(bottomLabel, style: HomeText.caption()),
        ],
      ),
    );
  }
}

/// ⑥ 소원게시판 / 소원방 2단 카드 - #F5F3FB 완전 동일 배경/크기/구조
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
                MaterialPageRoute(
                  builder: (_) => const WishRoomRiverpodEntry(),
                ),
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
    // 네온 스타일 CTA만 정확한 스펙 hex(#C6F24E/#111111)로 override. 블랙
    // 스타일(소원방)은 기존 premiumBlackCta(#121212)를 유지해도 스펙 #111111과
    // 시각적으로 동일하지만, 완전한 hex 일치를 위해 이 화면에서는 두 카드 모두
    // override로 정확히 맞춘다(두 카드 완전 대칭 유지가 최우선이기 때문).
    final overrideBg = circleStyle == PremiumCircleButtonStyle.neon
        ? HomeColors.neon
        : HomeColors.black;
    final overrideFg = circleStyle == PremiumCircleButtonStyle.neon
        ? HomeColors.textPrimary
        : Colors.white;

    return PremiumCard(
      backgroundColor: HomeColors.cardWish,
      borderColor: Colors.transparent,
      borderRadius: BorderRadius.circular(_Dims.wishCardRadius),
      showShadow: false,
      onTap: onTap,
      padding: const EdgeInsets.all(_Dims.wishCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(title, style: HomeText.title())),
              // 카드 우상단 원형 CTA 배경 26~28→27, 내부 아이콘 14로 override.
              PremiumCircleButton(
                icon: circleIcon,
                style: circleStyle,
                size: _Dims.wishCircleSize,
                iconSize: 14,
                bgColor: overrideBg,
                fgColor: overrideFg,
                onTap: onTap,
              ),
            ],
          ),
          Text(bottomLabel, style: HomeText.caption()),
        ],
      ),
    );
  }
}

/// ⑦ 하단 고정 블랙 pill 바 - "열림패스" + 남은시간 + 네온라임 원형 화살표
///
/// [색상/아이콘 통일] 배경을 정확히 #111111로, 자물쇠 이모지를 라인 아이콘
/// (lock_outline_rounded/lock_open_rounded, 두께감 있는 rounded 세트)으로
/// 교체해 "라인 아이콘 기본" 원칙에 맞췄다. "그림자 사용 금지" 원칙에 따라
/// 기존 BoxShadow도 제거했다.
///
/// [열림패스/복주머니/복주머니 통합정책 §3] "홈 화면은 운세 진입과 열림패스
/// 중심으로 설계한다. ... 열림패스 남은 시간 노출이 우선"에 대응해, 활성 시
/// 남은 시간을 라벨로 함께 노출한다(구매 유도 문구는 추가하지 않음).
class _OpenPassBottomBar extends StatefulWidget {
  const _OpenPassBottomBar();

  @override
  State<_OpenPassBottomBar> createState() => _OpenPassBottomBarState();
}

class _OpenPassBottomBarState extends State<_OpenPassBottomBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // [프리패스 테스트 인프라] §6/§7/§13 — 남은 시간은 [OpenPassState.fromModel]이
    // expiresAt 기준으로 매번 실시간 재계산하므로, 여기서는 1초마다 단순
    // rebuild만 트리거해주면 만료 순간 자동으로 잠금 아이콘/문구로 전환된다
    // (서버 재호출 없이 "자동 재잠금"이 화면에 실시간 반영됨).
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessChecker>();
    final isActive = access.canAccessFortuneScope();
    // [프리패스 단순화 - 쿠팡파트너스 전용] §6 — HH:MM:SS 형식으로 통일.
    final remainingLabel = isActive
        ? formatPassHms(access.openPassState.remaining)
        : null;

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
              color: HomeColors.passBar,
              borderRadius: BorderRadius.circular(_Dims.bottomBarRadius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 열림패스 좌측 자물쇠 아이콘 16(스펙 고정값).
                Icon(
                  isActive
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                  size: HomeTokens.iconMd,
                  color: Colors.white,
                ),
                // 자물쇠-텍스트 gap 10(스펙 고정값).
                const SizedBox(width: 10),
                Text('프리패스', style: HomeText.bodyStrong(color: Colors.white)),
                if (isActive && remainingLabel != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '· $remainingLabel',
                    style: HomeText.bodyStrong(color: HomeColors.neon),
                  ),
                ],
                const Spacer(),
                // 열림패스 우측 원형 버튼 32 / 내부 아이콘 16(32*0.5=16).
                PremiumCircleButton(
                  icon: Icons.chevron_right_rounded,
                  style: PremiumCircleButtonStyle.neon,
                  size: _Dims.bottomBarCircleSize,
                  bgColor: HomeColors.neon,
                  fgColor: HomeColors.textPrimary,
                  onTap: () =>
                      Navigator.of(context).pushNamed('/reward/wallet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
