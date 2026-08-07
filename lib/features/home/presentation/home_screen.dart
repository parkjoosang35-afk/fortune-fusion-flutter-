import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/premium_card.dart';
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
import '../../../core/widgets/app_toast.dart';
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

  // 헤더 아래 gap(헤더 로우 → "전체보기" 섹션). 스펙 "SafeArea→헤더 14~18" 범위와
  // "세로 간격은 12/14/16/20만 사용" 원칙을 함께 만족시키는 값으로 확정.
  // [사용자 요청] "오늘의 운세보기" 검은색 CTA 버튼을 삭제하면서, 헤더 바로
  // 아래에 "전체보기" 섹션이 오도록 gap을 그대로 유지한다(버튼이 있던 자리의
  // 간격 값을 재사용해 레이아웃 흔들림 없이 자연스럽게 붙인다).
  static const double headerBottomGap = 20;

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
  // [사용자 요청 - 상단 메뉴 이동(탭) 기능] "전체보기" 타이틀과 "오늘의 운세"
  // 칩을 누르면 홈 화면에 실제로 존재하는 "오늘의 운세" 섹션(힐링 문구 카드 +
  // 운세/타로 카드)으로 자동 스크롤 이동한다. Scrollable.ensureVisible로 이
  // 키가 달린 위젯이 화면에 보이도록 스크롤한다(같은 ListView 안이라 별도
  // ScrollController offset 계산 없이 안전하게 동작). 사주/관상/손금/정통사주는
  // 기존처럼 각자의 입력 화면으로 바로 이동하고, 신년운세는 아직 홈에 전용
  // 섹션/상세화면이 없어 안내 토스트로 대체한다(key=null → _scrollToSection이
  // 자동으로 토스트 처리).
  final _todayFortuneSectionKey = GlobalKey();

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

  /// [상단 메뉴 이동(탭) 기능] 지정한 [key]가 달린 섹션이 화면에 보이도록
  /// 부드럽게 스크롤한다. 신년운세처럼 아직 홈 화면에 전용 콘텐츠 섹션이 없는
  /// 카테고리는 key가 null이라 대신 안내 토스트를 띄운다(전체 카테고리 화면
  /// 이동 없이 홈에 머무르는 사용자 경험 유지).
  void _scrollToSection(GlobalKey? key, String label) {
    if (key?.currentContext == null) {
      AppToast.show(context, '$label 섹션은 곧 홈에서 만나볼 수 있어요 🙏');
      return;
    }
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      alignment: 0.08,
    );
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

                // ② [사용자 요청] "전체보기" 타이틀(탭 시 "오늘의 운세" 섹션으로
                // 스크롤 이동) + 우측 블랙 원형 그리드 버튼(운세 전체보기
                // 카테고리 허브 화면으로 이동, 기존 동작 유지).
                FadeSlideIn(
                  delay: const Duration(milliseconds: 40),
                  child: _AllCategoriesHeader(
                    onTitleTap: () => _scrollToSection(
                      _todayFortuneSectionKey,
                      '오늘의 운세',
                    ),
                  ),
                ),
                const SizedBox(height: _Dims.tarotHeaderBottomGap),

                // ③ [사용자 요청] 칩 메뉴 구조 변경 - 오늘의 운세/사주/관상/손금/
                // 정통사주/신년운세. "오늘의 운세" 칩만 홈 내 섹션으로 스크롤
                // 이동하고, 사주/관상/손금/정통사주는 기존처럼 열림패스 게이트를
                // 거쳐 각자의 입력화면으로 바로 이동한다. 신년운세는 아직 상세
                // 화면이 없어 안내 토스트로 대체한다.
                FadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: _FortuneCategoryChips(
                    onScrollToToday: () => _scrollToSection(
                      _todayFortuneSectionKey,
                      '오늘의 운세',
                    ),
                  ),
                ),
                const SizedBox(height: _Dims.chipsBottomGap),

                // ④ [사용자 요청] "오늘의 운세" 섹션 - 힐링 문구 카드 + 운세/타로
                // 2분할 카드를 하나의 섹션으로 감싸 GlobalKey를 부여한다(상단
                // 메뉴/칩에서 이 섹션으로 스크롤 이동할 수 있게 하기 위함).
                // 콘텐츠 자체(힐링 문구 db 기반 자동 순환, 운세/타로 카드 이동
                // 동작)는 기존과 완전히 동일하게 유지한다.
                KeyedSubtree(
                  key: _todayFortuneSectionKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 120),
                        child: const _HealingQuoteCard(),
                      ),
                      const SizedBox(height: _Dims.heroCardBottomGap),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 140),
                        child: const _FortuneTarotRow(),
                      ),
                    ],
                  ),
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
        // [사용자 요청] 상단 '신통방통' 로고 크기를 '전체보기' 제목 정도의
        // 크기로 줄인다. 기존 22px(Type Scale 최대치인 titleLarge 17px보다도
        // 큰 예외값)에서 18px로 축소해, 아래에서 함께 줄인 '전체보기' 제목
        // (16px)과 비슷한 크기대에서 로고 쪽이 아주 살짝만 더 커 보이도록
        // 균형을 맞춘다(완전히 동일하면 워드마크로서의 존재감이 사라지므로
        // 최소한의 위계는 남긴다).
        Text(
          '신통방통',
          style: TextStyle(
            fontFamily: HomeText.family,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            height: 1.3,
            color: HomeColors.textPrimary,
          ),
        ),
        const Spacer(),
        // [인트로 전면 개편 - 인트로↔홈 연결] 인트로 2단계(복주머니)에서 소개한
        // "복주머니는 무료로 모으고, 자유롭게 써요"가 실제로 홈에서 잔액으로
        // 바로 확인 가능해야 한다는 요구사항 대응. 탭하면 복주머니 상세(적립
        // 내역/받기)로 이동한다. 마이페이지의 _WalletSummaryCard와는 별개로,
        // 여기서는 헤더에 붙는 작은 배지 형태로 최소한만 노출한다.
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
          child: Consumer<WalletProvider>(
            builder: (context, wallet, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: HomeColors.cardAllMenu,
                borderRadius: BorderRadius.circular(HomeTokens.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.card_giftcard_rounded,
                    size: 14,
                    color: HomeColors.textPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${wallet.balance}',
                    style: HomeText.chipLabel(),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: _Dims.headerIconGap),
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

/// ③ [사용자 요청] "전체보기" 섹션 헤더 + 우측 블랙 원형 그리드 아이콘 버튼.
///
/// - "전체보기" 텍스트를 누르면 페이지 이동 없이 "오늘의 운세" 섹션으로
///   스크롤 이동한다([onTitleTap]).
/// - 우측 원형 그리드 버튼은 기존 그대로 운세 전체보기(카테고리 허브,
///   `/home/all-categories`)로 이동한다(탭 동작만 텍스트와 분리해서 유지).
/// - [사용자 요청] "'전체보기' 제목도 현재보다 약간 작게 조정" — 기존
///   titleLarge(17px)에서 title(15px)로 축소해, 위에서 줄인 로고(18px)와
///   비슷한 크기대에서 자연스러운 균형을 이루도록 한다.
class _AllCategoriesHeader extends StatelessWidget {
  const _AllCategoriesHeader({required this.onTitleTap});

  final VoidCallback onTitleTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTitleTap,
            child: Row(
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
                  child: const Icon(
                    Icons.style_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text('전체보기', style: HomeText.title()),
              ],
            ),
          ),
        ),
        // 섹션 우상단 원형 아이콘 배경 28 / 내부 아이콘 14(28*0.5=14).
        // 블랙 CTA 색상을 스펙 정확값(#111111)으로 override.
        PremiumCircleButton(
          icon: Icons.grid_view_rounded,
          style: PremiumCircleButtonStyle.black,
          size: _Dims.tarotCircleSize,
          bgColor: HomeColors.black,
          fgColor: Colors.white,
          // [첨부 디자인 반영] 운세 전체보기(카테고리 허브) 화면으로 이동하는
          // 기존 동작을 그대로 유지한다(텍스트 탭 동작과는 별개).
          onTap: () => Navigator.of(context).pushNamed('/home/all-categories'),
        ),
      ],
    );
  }
}

/// ④ [사용자 요청] 운세 카테고리 칩(가로 스크롤) 구조 변경 - 기존
/// "전체보기/사주/관상/손금" 4개에서 "오늘의 운세/사주/관상/손금/정통사주/
/// 신년운세" 6개로 확장한다.
///
/// - "오늘의 운세" 칩: 페이지 이동 없이 홈의 "오늘의 운세" 섹션(힐링 문구
///   카드 + 운세/타로 카드)으로 스크롤 이동한다([onScrollToToday]).
/// - "사주"/"관상"/"손금"/"정통사주": 기존과 동일하게 열림패스 게이트를 거쳐
///   각자의 입력/촬영 화면으로 바로 이동한다(정통사주는 `all_categories_screen`
///   과 동일하게 사주 입력 화면 라우트를 재사용).
/// - "신년운세": 아직 전용 상세화면이 없어(all_categories_screen과 동일하게
///   route=null) 탭하면 안내 토스트만 표시한다.
class _FortuneCategoryChips extends StatefulWidget {
  const _FortuneCategoryChips({required this.onScrollToToday});

  /// "오늘의 운세" 칩을 눌렀을 때 홈 내 섹션으로 스크롤 이동시키는 콜백.
  final VoidCallback onScrollToToday;

  @override
  State<_FortuneCategoryChips> createState() => _FortuneCategoryChipsState();
}

class _FortuneCategoryChipsState extends State<_FortuneCategoryChips> {
  // [사용자 요청] 기본 선택 칩은 "오늘의 운세"(index 0)로 둔다(홈에 진입하면
  // 바로 아래에 보이는 섹션과 자연스럽게 연결되도록).
  int _selected = 0;
  bool _checking = false;

  // 기준 시안: 칩에는 아이콘 없이 텍스트만 표시.
  // route가 null이면 아직 상세화면이 없는 카테고리(신년운세)라는 뜻이다.
  static const _items = [
    ('오늘의 운세', null, false),
    ('사주', '/ai-fortune/saju/input', true),
    ('관상', '/ai-fortune/face/capture', true),
    ('손금', '/ai-fortune/palm/capture', true),
    ('정통사주', '/ai-fortune/saju/input', true),
    ('신년운세', null, false),
  ];

  Future<void> _handleTap(int index) async {
    setState(() => _selected = index);
    final (title, route, requiresPass) = _items[index];

    // "오늘의 운세"는 홈 내 섹션 스크롤로 처리한다(페이지 이동 없음).
    if (index == 0) {
      widget.onScrollToToday();
      return;
    }

    // route가 없는 카테고리(신년운세)는 아직 상세화면이 없으므로 안내
    // 토스트만 표시한다(all_categories_screen의 "준비중" 패턴과 동일).
    if (route == null) {
      AppToast.show(context, '$title · 준비 중이에요! 곧 만나볼 수 있어요 🙏');
      return;
    }

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

    // [사용자 요청] "힐링섹션에 그래픽 애니메이션 효과좀 넣어줘 빈공간에" —
    // 카드 우측 상단~하단의 빈 여백에 은은한 그라디언트 블롭 + 떠다니는 달 +
    // 반짝이는 별 애니메이션을 배치한다. 배경색이 30분마다 파스텔 팔레트에서
    // 랜덤 변경되므로, 장식 색상도 고정색이 아니라 [textColor](대비 자동
    // 계산값) 기반의 낮은 알파값을 써서 어떤 배경에서도 튀지 않고 은은하게
    // 어울리도록 한다. 실제 문구 텍스트는 Stack의 마지막 레이어(맨 위)에 두어
    // 장식이 절대 가독성을 해치지 않게 한다.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(_Dims.heroCardRadius),
      ),
      child: Stack(
        children: [
          // 배경 장식 레이어 ① - 우측 상단에 카드 밖으로 살짝 번지는 은은한
          // 그라디언트 블롭(정적, 부드러운 공기감 연출).
          Positioned(
            right: -34,
            top: -34,
            child: SoftGradientBlob(size: 150, color: textColor, opacity: 0.10),
          ),
          // 배경 장식 레이어 ② - 우측 상단 빈 공간에서 위아래로 은은하게
          // 떠다니는 달 아이콘("힐링/밤의 위안" 테마와 어울림).
          Positioned(
            top: 12,
            right: 16,
            child: FloatingMoon(size: 30, color: textColor.withValues(alpha: 0.3)),
          ),
          // 배경 장식 레이어 ③ - 반짝이는 별 2개(opacity pulse)를 우측/하단
          // 빈 공간에 흩뿌려 리듬감을 더한다.
          Positioned(
            top: 56,
            right: 44,
            child: SparkleDot(size: 14, color: textColor.withValues(alpha: 0.35)),
          ),
          Positioned(
            bottom: 18,
            right: 26,
            child: SparkleDot(size: 10, color: textColor.withValues(alpha: 0.28)),
          ),
          // 실제 콘텐츠 - 기존 패딩/레이아웃을 그대로 유지한 채 장식 레이어
          // 위(맨 앞)에 배치해 텍스트가 항상 선명하게 보이도록 한다.
          Padding(
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
                      quote?.content ??
                          '잠시 마음을 쉬어가도 괜찮아요.\n당신은 충분히 잘하고 있습니다.',
                      key: ValueKey(quote?.id ?? -1),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: HomeText.title(
                        color: textColor,
                      ).copyWith(height: 1.35),
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
          ),
        ],
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
              // [프리패스 전체잠금 통일] 게이트 없이 직접 이동하던 버그 수정.
              onTap: () => navigateWithPassGate(
                context,
                title: '오늘의 운세',
                route: '/home/daily-fortune-detail',
                requiresPass: true,
              ),
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
              // [프리패스 전체잠금 통일] 게이트 없이 직접 이동하던 버그 수정.
              onTap: () => navigateWithPassGate(
                context,
                title: '타로',
                route: '/tarot/home',
                requiresPass: true,
              ),
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
