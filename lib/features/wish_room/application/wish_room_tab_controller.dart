import 'package:flutter/foundation.dart';

/// 신통방통 소원방 · 4탭 셸의 활성 탭 상태.
///
/// [WishRoomShell] 내부에서 `ChangeNotifierProvider`로 등록되며,
/// 각 탭 화면(홈/피드/복주머니/장부)에 내장된 [WishRoomBottomNav]의
/// onSelect 콜백이 `context.read<WishRoomTabController>().go(id)`를
/// 호출해 탭을 전환한다(Navigator push/pop을 쓰지 않음 — IndexedStack 유지).
class WishRoomTabController extends ChangeNotifier {
  WishRoomTabController([this.index = 2]);

  static const tabIds = ['home', 'feed', 'pouch', 'me'];

  int index;

  String get activeId => tabIds[index];

  void go(String id) {
    final i = tabIds.indexOf(id);
    if (i >= 0 && i != index) {
      index = i;
      notifyListeners();
    }
  }
}
