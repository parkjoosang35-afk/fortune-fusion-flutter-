import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/fortune/presentation/fortune_hub_screen.dart';
import '../../features/community/presentation/community_hub_screen.dart';
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
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(), // 🏠 홈 - 화이트 프리미엄 9섹션 리디자인
    FortuneHubScreen(), // 🔮 운세 - 7개 카테고리+비용뱃지
    CommunityHubScreen(), // 💬 커뮤니티 - 8개 서브탭(소원/자유/후기/고민상담/궁합이야기/부적/동행/랭킹)
    LuckyBagScreen(), // 🍀 복주머니 - 잔액 히어로+커뮤니티엔진 배너+적립방법/사용처/구독보너스/히스토리
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
          color: AppColors.premiumBgSection,
          border: Border(
            top: BorderSide(color: AppColors.premiumLightBorder, width: 1),
          ),
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
              selectedItemColor: AppColors.premiumDeepNavy,
              unselectedItemColor: AppColors.premiumTextTertiary,
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
