import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/midnight_bottom_nav.dart';
// [신통방통 홈 v2 전면 교체] 사용자 두 번째 디자인 핸드오프
// (design_handoff_sintong_main.zip)로 전면 교체 — 기존 v1
// home_screen.dart(화이트 프리미엄 CMS 동적 섹션)는 더 이상 이 탭에
// 배선하지 않는다(파일 자체는 프로젝트 관례상 보존).
import '../../features/home/presentation/sintong_home_v2/sintong_home_v2_screen.dart';
// [신당(神堂) 통합 — A안] 하단바 1번 슬롯이 더 이상 소원방을 열지 않고
// 신당을 연다(아래 _openShrine 참고). WishRoomIntroScreen import와 소원방
// push 기능 자체는 홈 카드/마이페이지 등 다른 진입점이 계속 쓰므로 삭제하지
// 않는다 — 다만 이 파일에서는 더 이상 직접 참조하지 않는다.
// [신당(THE SHRINE) v3 전면 재구축 — 2026-11-06] 구버전(ShrineSessionProvider/
// ShrineNav, 어두운 공포 이야기 버전)은 비용 문제(영상 대역폭)로 전면
// 삭제되었다. design_handoff_shrine_v3 핸드오프 기준 신규 ShrineV3Provider/
// ShrineV3EntryScreen로 교체한다 — app.dart에 이미 ShrineV3Provider가
// 전역 등록되어 있다(아래 shrine_v3 모듈 신규 생성 예정, 아직 파일 없음).
import '../../features/shrine_v3/application/shrine_v3_provider.dart';
import '../../features/shrine_v3/presentation/screens/shrine_v3_entry_screen.dart';
import '../../features/auth/application/auth_provider.dart';
// [행운상자 - 복주머니 탭 신규 기능] 사용자 요청("복주머니 탭 자리에
// 첨부한 행운상자 기능을 넣어달라, 하단바 라벨은 그대로 복주머니")에 따라
// 이 탭이 보여주는 화면 내용을 LuckyBagScreen(잔액+광고카드+출석체크)에서
// PouchBoxTabScreen(그리드→광고→흔들림→폭발→결과 상태머신)으로 교체한다.
// LuckyBagScreen 파일 자체는 프로젝트 관례에 따라 삭제하지 않고 보존한다.
import '../../features/pouch_box/presentation/pouch_box_tab_screen.dart';
import '../../features/mypage/presentation/my_screen.dart';

/// 03단계 §3.1 4탭 하단내비게이션 + IndexedStack 앱쉘
/// 홈 / 신당부적 / 복주머니 / 마이
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
/// 인덱스, push 분기 등)은 전혀 건드리지 않고 겉모습만 교체한다.
///
/// [신당(神堂) 통합 — A안, 공식 지시서 `01_dev_spec_v1.4.pdf` §3.1~3.2,
/// 2026-11 확정] 1번 슬롯의 역할을 "소원방 push"에서 "신당 push"로
/// 교체한다 — 탭 개수(4개)·push 패턴(IndexedStack 밖, Navigator.push)
/// 자체는 그대로 유지하고 그 슬롯이 여는 대상만 바뀐다. 소원방은 폐지가
/// 아니라 하단바 라벨/아이콘만 제거된 것이며, 홈 화면 카드·마이페이지
/// 등 기존 다른 진입점(`WishRoomIntroScreen`)으로는 계속 동일하게 접근
/// 가능하다(검색 확인: all_categories_screen.dart,
/// sintong_home_v2_routing.dart, my_screen.dart에 각각 독립된 진입점
/// 보존됨 — 이 파일은 그 경로들을 전혀 건드리지 않는다).
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

  // [신당(神堂) 통합 — A안, 2026-11 확정] 이 슬롯은 여전히 IndexedStack
  // 콘텐츠를 갖지 않는 "push 전용" 자리다(신당은 자체 22-라우트 내부
  // Navigator 스택을 ShrineNav가 담당하므로, 소원방처럼 전체화면으로
  // push하는 패턴이 그대로 들어맞는다). 탭을 뒤로가기(pop)하면 직전 탭
  // (기본 0=홈)으로 자동 복귀.
  //
  // [탭(nav) 인덱스 vs 콘텐츠(tab) 인덱스 분리] [운세보기 섹션 삭제] 이후
  // `_navItems`는 4개(홈/신당부적/복주머니/마이)이고, `_tabs`(IndexedStack
  // 콘텐츠)는 이 슬롯이 빠져 3개뿐이다. 그래서 nav 인덱스 ↔ tab 인덱스를
  // 서로 변환하는 헬퍼가 필요하다: nav 1(신당부적)은 콘텐츠가 없으므로
  // push만 하고 `_index`(=선택 표시용 nav 인덱스)는 그대로 둔다.
  static const int _shrineNavIndex = 1;

  int _navToTab(int navIndex) {
    if (navIndex < _shrineNavIndex) return navIndex;
    if (navIndex == _shrineNavIndex) return 0; // 신당부적은 콘텐츠가 없음(push 전용)
    return navIndex - 1; // 복주머니(3)->2, 마이(4)->3
  }

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, kMidnightNavTabs.length - 1);
    if (_index == _shrineNavIndex) {
      // 홈 라우트에 arguments:1로 곧장 진입한 경우(예: MainBottomNavBar)에도
      // 동일하게 push 방식을 적용하기 위해 첫 프레임 이후 0(홈)으로
      // 되돌리고 신당을 push한다.
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openShrine());
    }
  }

  void _onTapNav(int navIndex) {
    if (navIndex == _shrineNavIndex) {
      _openShrine();
      return;
    }
    setState(() => _index = navIndex);
  }

  /// [신당(神堂) 통합 — A안 §3.2 "진입 지점"] "소지부 없으면 /entry(입장)로,
  /// 있으면 /more(다음 문)로 직행 — 재방문자에게 의식 반복 안 시킴."
  /// `ShrineSession.kept`(소지부 간직 여부)를 기준으로 분기한다. 신당
  /// 내부 화면은 ShrineNav가 담당하는 별도 Navigator 1.0 스택이므로,
  /// 여기서는 그 스택의 첫 화면만 push하면 된다(1.1초 크로스페이드
  /// 모션은 `ShrineNav.rootRoute`가 기존 `_fadeRoute`를 그대로 재사용).
  Future<void> _openShrine() async {
    // [신당 계정 격리 버그 수정 — 2026-10-27] 신당은 ConnectScreen에서
    // 연결한 회원의 memberId(= 실제 신통방통 로그인 유저 PK)를
    // ShrineSessionProvider.state.memberId에 저장한다. 그런데 이
    // 상태는 로그인 세션과 무관하게 기기(SharedPreferences
    // 'shrine.v2')에 영구 보관되므로, "로그아웃 콜백 등록"만으로는
    // 막지 못하는 경우가 남는다 — 로그아웃을 거치지 않고 앱을 지웠다
    // 설치하거나(데이터 미삭제), 같은 기기를 다른 사람이 이어서 쓰며
    // 처음으로 회원가입/로그인한 경우다. 이런 경우에도 신당에 이전
    // 사용자의 이름·생년월일·이야기 진행·부적함이 그대로 남아 있어
    // 신규 가입자 화면에 엉뚱한 이름(예: 이전 세션의 실명)이 나오고
    // 진행 흐름이 꼬이는 원인이 된다.
    //
    // 해결: 신당에 들어가는 매 순간(하단바 "신당부적" 탭을 누를 때마다)
    // "신당에 마지막으로 연결됐던 memberId"와 "지금 실제로 로그인한
    // 사용자 id"를 비교한다. 둘 다 존재하는데 서로 다르면, 다른
    // 계정의 흔적이 남아있는 것이 확실하므로 로그아웃 콜백과 동일하게
    // resetData()로 신당 개인화 데이터를 초기화한 뒤 입장시킨다.
    // (로그인조차 안 한 상태로 신당에 들어가는 "회원 연결 없이 직접
    // 적기" 경로는 currentUser가 null이므로 이 체크를 건드리지
    // 않는다 — 기존 동작 그대로 유지.)
    // [신당 v3 계정 격리] v3는 서버(admin_web ShrineOrder 등)가 userId
    // 기준으로 부적함을 관리하므로, 로그인 사용자가 바뀌면 app.dart의
    // 로그아웃 콜백(ShrineV3Provider.clearOnLogout)이 이미 캐시를 비워준다.
    // 여기서는 로그인 여부만 확인하고 곧장 입구 화면을 push한다 — v3는
    // 구버전처럼 22-라우트 내부 Navigator 스택(ShrineNav)을 쓰지 않고,
    // 10개 화면을 표준 Navigator.push 체인으로 연결한다(화면별로 각자
    // 다음 화면을 push).
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    debugPrint('[AppShell] 신당 진입 (userId=$currentUserId)');
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ShrineV3EntryScreen()));
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
    // [신당 v3 §3.2 "배지"] 보관 중인 부적이 있을 때만 신당부적 탭에
    // 금색 점을 표시한다. watch로 구독해 부적함에 새 항목이 생기는 즉시
    // 하단바가 재빌드되도록 한다. (ShrineV3Provider.hasOwnedTalismans는
    // shrine_v3 모듈 생성 시 함께 정의해야 한다 — 현재는 모듈 자체가
    // 없어 아래 참조가 임시로 컴파일 에러 상태다.)
    final kept = context.watch<ShrineV3Provider>().hasOwnedTalismans;
    return Scaffold(
      body: IndexedStack(index: _navToTab(_index), children: _tabs),
      bottomNavigationBar: MidnightBottomNavBar(
        currentIndex: _index,
        onTap: _onTapNav,
        badgedIndices: kept ? const {_shrineNavIndex} : const {},
        // README "같은 탭 다시 탭" 규칙: 현재 탭을 다시 누르면 스크롤을
        // 맨 위로. 현재 IndexedStack 탭 콘텐츠들은 전용 스크롤-투-탑 훅을
        // 노출하지 않아(화면별 ScrollController 비공개) 당장은 no-op으로
        // 남겨 둔다 — 각 탭 화면에 공개 컨트롤러가 추가되면 여기서 호출.
        onReselected: (_) {},
      ),
    );
  }
}
