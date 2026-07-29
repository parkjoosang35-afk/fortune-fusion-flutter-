import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../features/home/presentation/home_screen_cosmic.dart';
import '../../features/fortune/presentation/fortune_hub_screen.dart';
import '../../features/community/presentation/community_hub_screen.dart';
import '../../features/luckybag/presentation/luckybag_hub_screen.dart';
import '../../features/mypage/presentation/my_screen.dart';

/// 03단계 §3.1 5탭 하단내비게이션 + IndexedStack 앱쉘
/// 홈 / 운세 / 커뮤니티 / 복주머니 / 마이
///
/// [Fortune Fusion UI 리뉴얼 프롬프트] §3 라우터 재구성.
/// 7~11번 작업으로 신규 화면(HomeScreenCosmic/FortuneHubScreen/
/// CommunityHubScreen/LuckyBagScreen/MyScreen)이 모두 완성되어 탭을 교체한다.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = [
    HomeScreenCosmic(), // 🏠 홈 - 8섹션 신규 구성
    FortuneHubScreen(), // 🔮 운세 - 7개 카테고리+비용뱃지
    CommunityHubScreen(), // 💬 커뮤니티 - 5개 서브탭
    LuckyBagScreen(), // 🍀 복주머니 - 잔액 히어로+획득처/사용처/VIP/히스토리
    MyScreen(), // 👤 마이 - 프로필+등급뱃지+아카이브+설정
  ];

  static const _navItems = [
    (Icons.home_outlined, Icons.home_rounded, '홈'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, '운세'),
    (Icons.forum_outlined, Icons.forum_rounded, '커뮤니티'),
    (Icons.card_giftcard_outlined, Icons.card_giftcard_rounded, '복주머니'),
    (Icons.person_outline_rounded, Icons.person_rounded, '마이'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgSecondary,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: BottomNavigationBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
              backgroundColor: AppColors.bgSecondary,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              selectedItemColor: AppColors.accentPurple,
              unselectedItemColor: AppColors.cosmicTextTertiary,
              selectedLabelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              items: _navItems
                  .map(
                    (e) => BottomNavigationBarItem(
                      icon: Icon(e.$1),
                      activeIcon: Icon(e.$2),
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
