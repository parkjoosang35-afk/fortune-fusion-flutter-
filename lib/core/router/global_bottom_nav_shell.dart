import 'package:flutter/material.dart';
import 'main_bottom_nav_bar.dart';

/// [전역 하단바 자동 부착 — 사용자 요청 2026-10-14]
/// "소원방만 빼고 모든 화면에 하단바(홈/소원방/복주머니/마이)를 넣어달라.
/// 결과페이지든 어디든 중간에 나오기가 힘들다."
///
/// [구조] AppShell 밖에서 named route로 열리는 화면을 라우터 헬퍼
/// (_pageNamed/_guinjiNamed)가 이 셸로 한 번에 감싼다. 화면마다 수동으로
/// 하단바를 넣던 방식의 누락(화면 113개 중 극소수만 있었음)을 원천 제거하고,
/// 앞으로 추가되는 라우트에도 자동으로 따라온다.
///
/// [제외] 소원방(자체 5탭 바 보유 — 이중 바 방지), 스플래시/인트로/온보딩/
/// 로그인/회원가입/정책(가입 전 화면), 홈 셸 자체(/home — 이미 바 보유).
/// 이름 없이 직접 MaterialPageRoute로 push되는 화면은 감싸지 않는다(기존
/// 수동 하단바 유지 — 타로 결과·귀인지도 게스트 참여).
///
/// [신당(神堂) 통합 — A안 확정 이후에도 유지] `/shrine`이 이 목록에서 누락되어 있어
/// 신당 콘텐츠(ShrineScreenScaffold, 자체 어두운 전체화면 연출) 전체가
/// 전역 하단바(MainBottomNavBar)로 다시 감싸지고 있었다. 신당은 소원방과
/// 동일하게 "자체 전체화면 몰입형 UI"(뒤로/레일/SKIP/설정을 직접 그림)를
/// 가지고 있어 이중 바 방지 원칙이 똑같이 적용되어야 한다. 이 누락이
/// Scaffold의 body 영역을 하단바 높이(~contentReserve+safeArea)만큼
/// 줄여, ShrineScreenScaffold 내부의 Positioned.fill/Align 좌표 기준이
/// 어긋나고 — 특히 shrine_inside_screen.dart의 전체화면 GestureDetector가
/// 실제로 그려지는 영역과 사용자가 탭하는 좌표가 서로 다른 캔버스로
/// 분리되어 onTap이 전혀 호출되지 않는 것처럼 보이는 문제로 이어졌다.
const Set<String> _bottomNavExcludedRoutes = {
  '/splash',
  '/intro',
  '/login',
  '/signup',
  '/policy/notice',
  '/onboarding',
  '/home',
  '/wish-room',
  '/wish-wall',
  '/shrine',
};

Widget wrapWithGlobalBottomNav(String? routeName, Widget child) {
  if (routeName == null || _bottomNavExcludedRoutes.contains(routeName)) {
    return child;
  }
  return Scaffold(
    backgroundColor: routeName.startsWith('/guinji') ? const Color(0xFF0B0B0D) : null,
    body: child,
    bottomNavigationBar: const MainBottomNavBar(currentIndex: 0),
  );
}
