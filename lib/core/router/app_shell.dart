import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/fortune/presentation/ai_fortune_hub_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/reward/presentation/reward_screen.dart';
import '../../features/mypage/presentation/mypage_screen.dart';

/// 03단계 §3.1 5탭 하단내비게이션 + IndexedStack 앱쉘
/// 홈 / 운세 / 커뮤니티 / 복주머니 / 마이
///
/// [Fortune Fusion UI 리뉴얼 프롬프트] §3 라우터 재구성.
/// 신규 화면(FortuneHubScreen/CommunityHubScreen/LuckyBagScreen/MyScreen)은
/// 이번 1~6번 작업 범위 밖(추후 7~11번 작업에서 신규 작성)이므로,
/// 탭에 연결되는 실제 화면은 기존 화면을 그대로 유지하고 하단내비게이션의
/// 라벨/아이콘/색상/높이 등 스타일만 우주 감성 팔레트로 갱신한다.
/// (추후 7~11번 작업 완료 시 아래 _tabs의 화면 인스턴스만 교체하면 됨)
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(), // 🏠 홈 → (추후) HomeScreen 신규 8섹션 버전으로 교체 예정
    AiFortuneHubScreen(), // 🔮 운세 → (추후) FortuneHubScreen으로 교체 예정
    CommunityScreen(), // 💬 커뮤니티 → (추후) CommunityHubScreen으로 교체 예정
    RewardScreen(), // 🍀 복주머니 → (추후) LuckyBagScreen으로 교체 예정
    MyPageScreen(), // 👤 마이 → (추후) MyScreen으로 교체 예정
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
