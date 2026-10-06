import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
// [신통방통 홈 v2 전면 교체] 사용자 두 번째 디자인 핸드오프
// (design_handoff_sintong_main.zip)로 전면 교체 — 기존 v1
// home_screen.dart(화이트 프리미엄 CMS 동적 섹션)는 더 이상 이 탭에
// 배선하지 않는다(파일 자체는 프로젝트 관례상 보존).
import '../../features/home/presentation/sintong_home_v2/sintong_home_v2_screen.dart';
import '../../features/wishroom/features/intro/wish_room_intro_screen.dart';
// [행운상자 - 복주머니 탭 신규 기능] 사용자 요청("복주머니 탭 자리에
// 첨부한 행운상자 기능을 넣어달라, 하단바 라벨은 그대로 복주머니")에 따라
// 이 탭이 보여주는 화면 내용을 LuckyBagScreen(잔액+광고카드+출석체크)에서
// PouchBoxTabScreen(그리드→광고→흔들림→폭발→결과 상태머신)으로 교체한다.
// LuckyBagScreen 파일 자체는 프로젝트 관례에 따라 삭제하지 않고 보존한다.
import '../../features/pouch_box/presentation/pouch_box_tab_screen.dart';
import '../../features/mypage/presentation/my_screen.dart';

/// 03단계 §3.1 4탭 하단내비게이션 + IndexedStack 앱쉘
/// 홈 / 소원방 / 복주머니 / 마이
///
/// [운세보기 섹션 삭제 — 사용자 요청] "그냥 운세보기 섹션을 삭제해버려
/// 없어도돼" — 기존 5탭(홈/운세/소원방/복주머니/마이) 중 "운세" 탭
/// (정통운세/이미지운세/카드운세/종합운세 카테고리 목록을 보여주던
/// FortuneHubScreen)을 완전히 제거하고 4탭으로 축소한다. 정통사주/타로/
/// 관상/손금/궁합 등 실제 기능 화면 자체는 전혀 건드리지 않는다 — 전부
/// 홈 화면의 카테고리 바로가기(히어로 캐러셀/대표카드/전체보기)로 이미
/// 동일하게 접근 가능하므로 기능 접근성 손실이 없다. "운세" 탭 전용
/// 화면이었던 `features/fortune/presentation/fortune_hub_screen.dart`는
/// 다른 곳에서 전혀 참조되지 않아(단일 소비자였음) 파일 자체를 삭제했다.
///
/// [Fortune Fusion 디자인 우선 리디자인 프롬프트] §7-9 하단 탭바를 화이트/연보라
/// 톤으로 통일한다(홈 화면만 화이트로 바뀌었으므로 탭바도 함께 맞춰야 이질감이 없음).
/// 다른 3개 탭(소원방/복주머니/마이)의 화면 내부는 아직 다크 우주 톤을
/// 유지하므로, 탭 전환 시 상단 배경색은 각 화면의 Scaffold.backgroundColor가
/// 그대로 담당한다(이 파일은 탭바 자체만 화이트로 변경).
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  /// [하단바 통일 작업] 정통사주/타로/소원방/귀인지도처럼 AppShell
  /// 바깥에서 push된 화면에서 [MainBottomNavBar]를 탭했을 때, 스택을
  /// 정리하고 이 특정 탭으로 곧장 진입시키기 위한 초기 탭 인덱스.
  /// 지정하지 않으면 기존과 동일하게 항상 0(홈)으로 시작한다.
  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index;

  // [소원방 v2.6 전면 재구축] 신규 [WishRoomShell]은 자체 5탭(🕯☾✉✿◈)과
  // 전용 하단바를 이미 갖고 있어, 구버전 WishRoomHomeScreen처럼 AppShell의
  // IndexedStack 안에 "내용만" 끼워 넣을 수 없다(하단바가 이중으로 겹침).
  // 그래서 소원방 탭은 IndexedStack 콘텐츠가 아니라 "탭을 누르면 전체화면으로
  // [WishRoomIntroScreen]을 push"하는 방식으로 바꾼다 — 홈 카드/마이페이지
  // 등 기존 다른 진입점들과 동일한 패턴(Navigator.push)으로 통일되는
  // 장점도 있다. 탭을 뒤로가기(pop)하면 직전 탭(기본 0=홈)으로 자동 복귀.
  //
  // [탭(nav) 인덱스 vs 콘텐츠(tab) 인덱스 분리] [운세보기 섹션 삭제] 이후
  // `_navItems`는 4개(홈/소원방/복주머니/마이)이고, `_tabs`(IndexedStack
  // 콘텐츠)는 소원방 자리가 빠져 3개뿐이다. 그래서 nav 인덱스 ↔ tab 인덱스를
  // 서로 변환하는 헬퍼가 필요하다: nav 1(소원방)은 콘텐츠가 없으므로 push만
  // 하고 `_index`(=선택 표시용 nav 인덱스)는 그대로 둔다.
  static const int _wishRoomNavIndex = 1;

  int _navToTab(int navIndex) {
    if (navIndex < _wishRoomNavIndex) return navIndex;
    if (navIndex == _wishRoomNavIndex) return 0; // 소원방은 콘텐츠가 없음(push 전용)
    return navIndex - 1; // 복주머니(3)->2, 마이(4)->3
  }

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _navItems.length - 1);
    if (_index == _wishRoomNavIndex) {
      // 홈 라우트에 arguments:2로 곧장 진입한 경우(예: MainBottomNavBar)에도
      // 동일하게 push 방식을 적용하기 위해 첫 프레임 이후 0(홈)으로
      // 되돌리고 소원방을 push한다.
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openWishRoom());
    }
  }

  void _onTapNav(int navIndex) {
    if (navIndex == _wishRoomNavIndex) {
      _openWishRoom();
      return;
    }
    setState(() => _index = navIndex);
  }

  Future<void> _openWishRoom() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WishRoomIntroScreen()),
    );
  }

  // [운세보기 섹션 삭제] FortuneHubScreen 탭 콘텐츠를 _tabs에서 제거.
  static const _tabs = [
    SintongHomeV2Screen(), // 🏠 홈 - 다크 히어로 캐러셀 v2(design_handoff_sintong_main)
    // 🎁 복주머니 - [행운상자 - 복주머니 탭 신규 기능] 광고 시청으로 여는
    // 행운상자 그리드(하단바 라벨/아이콘은 그대로 "복주머니" 유지, 화면
    // 내용만 신규 행운상자 인터랙션으로 전면 교체됨).
    PouchBoxTabScreen(),
    MyScreen(), // 👤 마이 - 프로필+등급뱃지+아카이브+설정
  ];

  // [운세보기 섹션 삭제] "운세" 탭 항목을 _navItems에서 제거. 4탭(홈/소원방/
  // 복주머니/마이)로 축소.
  static const _navItems = [
    (Icons.home_outlined, Icons.home_rounded, '홈'),
    (
      Icons.local_fire_department_outlined,
      Icons.local_fire_department_rounded,
      '소원방',
    ),
    // [2026-11 복주머니 아이콘 교체] main_bottom_nav_bar.dart와 동일하게,
    // 기본 Material 아이콘(선물상자 모양) 대신 실제 한국 전통 복주머니
    // 모양으로 생성한 커스텀 이미지 에셋을 쓴다. items 빌더에서 인덱스
    // 2번만 Image.asset으로 렌더링한다.
    (Icons.card_giftcard_outlined, Icons.card_giftcard_rounded, '복주머니'),
    (Icons.person_outline_rounded, Icons.person_rounded, '마이'),
  ];

  static const String _luckyBagIconAsset = 'assets/icons/luckybag_icon.png';

  Widget _luckyBagIcon({required bool selected}) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        selected ? const Color(0xFF111111) : const Color(0xFF9A9AA2),
        BlendMode.srcIn,
      ),
      child: Image.asset(_luckyBagIconAsset, width: 22, height: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _navToTab(_index), children: _tabs),
      // [홈 화면 최종 마감 정돈 프롬프트] 탭바 5개 완전 통일: 아이콘 22 고정,
      // 두께/라벨 크기·자간을 모두 동일 규칙으로 통일하고 활성(#111111)/
      // 비활성(#9A9AA2)은 색상 규칙으로만 구분한다(굵기/크기 차이 제거).
      // 여기 쓰이는 색상 리터럴은 이 위젯 내부에서만 쓰이는 값이라 전역
      // AppColors 상수를 바꾸지 않고 직접 지정해도 다른 화면에 영향이 없다.
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.premiumBgSection,
          border: Border(top: BorderSide(color: Color(0xFFECECEF), width: 1)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: BottomNavigationBar(
              currentIndex: _index,
              onTap: _onTapNav,
              backgroundColor: AppColors.premiumBgSection,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              selectedItemColor: const Color(0xFF111111),
              unselectedItemColor: const Color(0xFF9A9AA2),
              selectedLabelStyle: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              items: _navItems.asMap().entries.map((entry) {
                final index = entry.key;
                final e = entry.value;
                // 복주머니 탭(인덱스 2, 운세 삭제로 인덱스 변경됨)만 커스텀
                // 이미지 아이콘으로 교체.
                if (index == 2) {
                  return BottomNavigationBarItem(
                    icon: _luckyBagIcon(selected: false),
                    activeIcon: _luckyBagIcon(selected: true),
                    label: e.$3,
                  );
                }
                return BottomNavigationBarItem(
                  icon: Icon(e.$1, size: 22),
                  activeIcon: Icon(e.$2, size: 22),
                  label: e.$3,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
