import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 앱 전역 5탭(홈/운세/소원방/복주머니/마이) 하단 네비게이션 바를
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
/// 이 위젯은 [AppShell]의 `BottomNavigationBar`와 완전히 동일한 스타일
/// (흰 배경, 선택 #111111/비선택 #9A9AA2, Pretendard 11px w600, 아이콘
/// 22px 고정)을 그대로 재사용하되, 탭을 누르면 [AppShell]로 돌아가면서
/// 해당 탭 인덱스를 열도록 라우팅한다.
///
/// [탭 이동 방식] 뒤로가기 스택을 계속 쌓지 않고
/// `pushNamedAndRemoveUntil('/home', (route) => false, arguments: index)`로
/// 스택을 정리한 뒤 새 [AppShell]을 `initialIndex`와 함께 생성한다(기존
/// `jeontong_eighty_result_screen.dart`/`luckybag_result_screen.dart`의
/// "홈으로 복귀" 선례와 동일한 패턴을 그대로 확장한 것).
class MainBottomNavBar extends StatelessWidget {
  const MainBottomNavBar({super.key, required this.currentIndex});

  /// 이 화면이 개념적으로 속한 탭 인덱스(0홈/1운세/2소원방/3복주머니/4마이).
  /// 정통사주·타로 화면은 1(운세), 소원방(push) 화면은 2, 귀인지도는
  /// 홈 배너에서 진입하므로 0을 사용한다.
  final int currentIndex;

  static const _navItems = [
    (Icons.home_outlined, Icons.home_rounded, '홈'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, '운세'),
    (
      Icons.local_fire_department_outlined,
      Icons.local_fire_department_rounded,
      '소원방',
    ),
    (Icons.card_giftcard_outlined, Icons.card_giftcard_rounded, '복주머니'),
    (Icons.person_outline_rounded, Icons.person_rounded, '마이'),
  ];

  void _onTap(BuildContext context, int index) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
      arguments: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.premiumBgSection,
        border: Border(top: BorderSide(color: Color(0xFFECECEF), width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (i) => _onTap(context, i),
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
            items: _navItems
                .map(
                  (e) => BottomNavigationBarItem(
                    icon: Icon(e.$1, size: 22),
                    activeIcon: Icon(e.$2, size: 22),
                    label: e.$3,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
