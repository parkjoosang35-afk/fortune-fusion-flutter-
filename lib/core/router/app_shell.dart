import 'package:flutter/material.dart';
import '../widgets/midnight_bottom_nav.dart';
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
/// [하단바 리디자인 — design_handoff_bottom_nav.zip "심야의 신전" Variant A]
/// 기존에는 §7-9 지시로 하단 탭바를 화이트/연보라 톤(Material
/// BottomNavigationBar)으로 통일했었으나, 새 디자인 핸드오프가 어두운 바
/// 위에서 선택 탭만 금빛으로 켜지는 다크 테마로 전면 교체를 지시해
/// [MidnightBottomNavBar] 공용 위젯으로 바꾼다. 탭 전환 로직(IndexedStack
/// 인덱스, 소원방 push 분기 등)은 전혀 건드리지 않고 겉모습만 교체한다.
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
    _index = widget.initialIndex.clamp(0, kMidnightNavTabs.length - 1);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _navToTab(_index), children: _tabs),
      bottomNavigationBar: MidnightBottomNavBar(
        currentIndex: _index,
        onTap: _onTapNav,
        // README "같은 탭 다시 탭" 규칙: 현재 탭을 다시 누르면 스크롤을
        // 맨 위로. 현재 IndexedStack 탭 콘텐츠들은 전용 스크롤-투-탑 훅을
        // 노출하지 않아(화면별 ScrollController 비공개) 당장은 no-op으로
        // 남겨 둔다 — 각 탭 화면에 공개 컨트롤러가 추가되면 여기서 호출.
        onReselected: (_) {},
      ),
    );
  }
}
