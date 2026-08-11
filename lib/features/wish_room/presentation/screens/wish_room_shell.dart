import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_bottom_nav.dart';
import 'wish_room_feed_screen.dart';
import 'wish_room_screen.dart';
import 'wish_room_temple_management_screen.dart';

/// [대형 작업 — Shell 재편] 소원방 메인 진입 이후의 탭 구조.
///
/// 사용자 지시("있는 기능은 페이지 한칸을 더 만들어서 구현 다시 구현")에
/// 따라 3개 탭으로 구성한다:
/// - index 0 "나의 소원"(🕯): 디자인 핸드오프 Home 화면(현재는 기존
///   [WishRoomScreen]을 그대로 담고 있으며, 다음 작업(Home 전면 재구현)에서
///   `wish-screens.jsx`의 `ScreenHome` 스펙으로 교체될 예정이다).
/// - index 1 "모두의 소원"(☾): Feed 화면([WishRoomFeedScreen], 아직
///   placeholder — 별도 작업에서 community 연동과 함께 구현).
/// - index 2 "신전관리"(◈): 기존 게임성 기능(성장/슬롯/치성/꾸미기)을 모아둔
///   허브([WishRoomTempleManagementScreen]) — 기존 기능을 삭제하지 않고
///   이곳으로 옮겨 계속 접근 가능하게 한다.
///
/// [탭 전환 시 상태 보존] IndexedStack을 사용해 탭을 전환해도 각 탭의
/// 위젯 트리(및 그 안의 스크롤 위치 등)가 dispose되지 않고 유지된다.
///
/// [Navigator 재사용] 이 위젯은 [WishRoomRiverpodEntry]의 중첩 Navigator
/// 서브트리 안에서 push되므로, 각 탭 내부에서 발생하는 추가 화면 전환
/// (소원 작성/기록/꾸미기/슬롯 확장 등)은 모두 그 동일한 Navigator를 그대로
/// 사용한다 — 별도의 Navigator를 새로 만들지 않는다.
class WishRoomShell extends StatefulWidget {
  const WishRoomShell({super.key});

  @override
  State<WishRoomShell> createState() => _WishRoomShellState();
}

class _WishRoomShellState extends State<WishRoomShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          WishRoomScreen(),
          WishRoomFeedScreen(),
          WishRoomTempleManagementScreen(),
        ],
      ),
      bottomNavigationBar: WishRoomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex) return;
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}
