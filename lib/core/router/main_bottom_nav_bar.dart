import 'package:flutter/material.dart';
import '../widgets/midnight_bottom_nav.dart';

/// 앱 전역 4탭(홈/소원방/복주머니/마이) 하단 네비게이션 바를
/// [AppShell] 바깥에서 push된 화면들(정통사주/타로/귀인지도/소원방 push
/// 인스턴스)에도 동일하게 노출하기 위한 공유 위젯.
///
/// [배경 — 사용자 리포트] "우리 신통방통에 모든 정통사주 타로 소원방
/// 귀인지도 관련 화면에 하단 메뉴가 없어" → "메인에 하단바을 다 넣어줘".
/// 이 화면들은 `AppShell`의 `IndexedStack` 밖에서 별도 Navigator 라우트로
/// 열리기 때문에(`Navigator.push`/`pushNamed`) AppShell 자체의
/// `BottomNavigationBar`를 전혀 모른다(별개의 Scaffold 트리) — 이것이
/// 하단바가 사라져 보이는 근본 원인이다.
///
/// [하단바 리디자인 — design_handoff_bottom_nav.zip "심야의 신전" Variant A]
/// 기존에는 [AppShell]의 흰 배경 BottomNavigationBar와 완전히 동일한
/// 스타일을 그대로 재사용했으나, 새 디자인 핸드오프가 다크 테마로 전면
/// 교체를 지시해 [AppShell]과 동일하게 [MidnightBottomNavBar] 공용
/// 위젯으로 바꾼다. 탭을 누르면 [AppShell]로 돌아가면서 해당 탭 인덱스를
/// 열도록 라우팅하는 동작 자체는 전혀 건드리지 않는다.
///
/// [탭 이동 방식] 뒤로가기 스택을 계속 쌓지 않고
/// `pushNamedAndRemoveUntil('/home', (route) => false, arguments: index)`로
/// 스택을 정리한 뒤 새 [AppShell]을 `initialIndex`와 함께 생성한다(기존
/// `jeontong_eighty_result_screen.dart`/`luckybag_result_screen.dart`의
/// "홈으로 복귀" 선례와 동일한 패턴을 그대로 확장한 것).
///
/// [운세보기 섹션 삭제 — 사용자 요청] "그냥 운세보기 섹션을 삭제해버려
/// 없어도돼" — 4탭(홈/소원방/복주머니/마이) 체제. [currentIndex] 의미:
/// 0홈/1소원방/2복주머니/3마이. 정통사주·타로처럼 운세 탭에서 push되던
/// 화면도 이제 0(홈)을 가리킨다.
class MainBottomNavBar extends StatelessWidget {
  const MainBottomNavBar({super.key, required this.currentIndex});

  /// 이 화면이 개념적으로 속한 탭 인덱스(0홈/1소원방/2복주머니/3마이).
  /// 정통사주·타로 화면은 0(홈), 소원방(push) 화면은 1, 귀인지도는
  /// 홈 배너에서 진입하므로 0을 사용한다.
  final int currentIndex;

  void _onTap(BuildContext context, int index) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
      arguments: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MidnightBottomNavBar(
      currentIndex: currentIndex,
      onTap: (i) => _onTap(context, i),
    );
  }
}
