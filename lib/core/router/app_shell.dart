import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/fortune/presentation/fortune_hub_screen.dart';
import '../../features/wish_room/presentation/wish_room_home_screen.dart';
import '../../features/luckybag/presentation/luckybag_hub_screen.dart';
import '../../features/mypage/presentation/my_screen.dart';

/// 03단계 §3.1 5탭 하단내비게이션 + IndexedStack 앱쉘
/// 홈 / 운세 / 커뮤니티 / 복주머니 / 마이
///
/// [Fortune Fusion 디자인 우선 리디자인 프롬프트] §7-9 하단 탭바를 화이트/연보라
/// 톤으로 통일한다(홈 화면만 화이트로 바뀌었으므로 탭바도 함께 맞춰야 이질감이 없음).
/// 다른 4개 탭(운세/커뮤니티/복주머니/마이)의 화면 내부는 아직 다크 우주 톤을
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

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _tabs.length - 1);
  }

  static const _tabs = [
    HomeScreen(), // 🏠 홈 - 화이트 프리미엄 9섹션 리디자인
    FortuneHubScreen(), // 🔮 운세 - 7개 카테고리+비용뱃지
    // 🕯 신통방통 소원방 - "마법진이 소환되는 신전"(V2 Moonlit Crystal) 디자인
    // 핸드오프의 ScreenHome을 pixel-perfect 재현한 화면. 탭 아이콘/라벨/위치
    // (하단바 자체 UI)는 그대로 유지하고 이 탭이 보여주는 화면 내용만 교체.
    WishRoomHomeScreen(),
    LuckyBagScreen(), // 🍀 복주머니 - 잔액 히어로+커뮤니티엔진 배너+적립방법/사용처/구독보너스/히스토리
    MyScreen(), // 👤 마이 - 프로필+등급뱃지+아카이브+설정
  ];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
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
              onTap: (i) => setState(() => _index = i),
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
      ),
    );
  }
}
