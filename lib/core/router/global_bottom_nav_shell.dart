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
