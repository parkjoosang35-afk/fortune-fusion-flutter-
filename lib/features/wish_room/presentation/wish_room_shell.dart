import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_room_tab_controller.dart';
import '../theme/wish_room_colors.dart';
import 'home/wish_room_home_screen.dart';
import 'home/wish_room_feed_screen.dart';
import 'pouch/wish_room_pouch_home_screen.dart';
import 'pouch/wish_room_ledger_screen.dart';

/// 신통방통 소원방 · 4탭 메인 셸
///
/// 탭 구성(WishRoomBottomNav.items 순서와 동일):
///  - home(나의 소원) : 소원방 본체 홈([WishRoomHomeScreen])
///  - feed(모두의 소원): 익명 소원 피드([WishRoomFeedScreen])
///  - pouch(복주머니) : 완성된 복주머니 홈([WishRoomPouchHomeScreen])
///  - me(기록)        : 조용한 장부([WishRoomLedgerScreen])
///
/// 탭 전환은 [WishRoomTabController]가 담당한다(Provider로 셸 범위에 등록).
/// 각 탭 화면 내부에 이미 그려진 [WishRoomBottomNav]의 onSelect는
/// `context.read<WishRoomTabController>().go(id)`를 호출해 IndexedStack의
/// 인덱스만 바꾸며, Navigator push/pop은 전혀 사용하지 않는다.
class WishRoomShell extends StatelessWidget {
  const WishRoomShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WishRoomTabController>(
      create: (_) => WishRoomTabController(),
      child: const _WishRoomShellBody(),
    );
  }
}

class _WishRoomShellBody extends StatelessWidget {
  const _WishRoomShellBody();

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<WishRoomTabController>();

    return Scaffold(
      backgroundColor: WishRoomColors.crystal.bg2,
      body: IndexedStack(
        index: tab.index,
        children: const [
          WishRoomHomeScreen(),
          WishRoomFeedScreen(),
          WishRoomPouchHomeScreen(),
          WishRoomLedgerScreen(),
        ],
      ),
    );
  }
}
