import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/fortune/presentation/ai_fortune_hub_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/reward/presentation/reward_screen.dart';
import '../../features/mypage/presentation/mypage_screen.dart';

/// 03단계 §3.1 5탭 하단내비게이션 + IndexedStack 앱쉘
/// 홈 / AI운세 / 커뮤니티 / 리워드 / 마이
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(),
    AiFortuneHubScreen(),
    CommunityScreen(),
    RewardScreen(),
    MyPageScreen(),
  ];

  static const _navItems = [
    (Icons.home_outlined, Icons.home_rounded, '홈'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'AI운세'),
    (Icons.favorite_border_rounded, Icons.favorite_rounded, '커뮤니티'),
    (Icons.card_giftcard_outlined, Icons.card_giftcard_rounded, '리워드'),
    (Icons.person_outline_rounded, Icons.person_rounded, '마이'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: _navItems
            .map(
              (e) => BottomNavigationBarItem(
                icon: Icon(e.$1),
                activeIcon: Icon(e.$2, color: AppColors.primary),
                label: e.$3,
              ),
            )
            .toList(),
      ),
    );
  }
}
