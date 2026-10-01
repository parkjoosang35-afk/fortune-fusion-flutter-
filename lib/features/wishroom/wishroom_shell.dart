// 신통방통 소원방 v2.6 · 내부 5탭 셸 — 핸드오프 app_router.dart의
// StatefulShellRoute.indexedStack(5브랜치: 내 소원방·소원방(탐색)·알림·꾸미기·보관함)을
// 기존 앱 컨벤션(Navigator 1.0 + IndexedStack, go_router 미도입)으로 재구현.
// 바텀내비는 핸드오프 WrBottomNav 디자인(이모지 아이콘 🕯☾✉✿◈)을 그대로 따른다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/wr_theme.dart';
import 'application/wishroom_provider.dart';
import 'features/room/main_room_screen.dart';
import 'features/explore/explore_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/decor/decor_screen.dart';
import 'features/vault/vault_screen.dart';

class WishRoomShell extends StatefulWidget {
  const WishRoomShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<WishRoomShell> createState() => _WishRoomShellState();
}

class _WishRoomShellState extends State<WishRoomShell> {
  late int _index;

  static const _tabs = [
    MainRoomScreen(),
    ExploreScreen(),
    WrNotificationsScreen(),
    DecorScreen(),
    VaultScreen(),
  ];

  static const _labels = [('🕯', '내 소원방'), ('☾', '소원방'), ('✉', '알림'), ('✿', '꾸미기'), ('◈', '보관함')];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _tabs.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wr;
    return Theme(
      data: wrTheme(WrPalette.midnight),
      child: Scaffold(
        backgroundColor: c.bg2,
        body: SafeArea(
          top: false,
          child: IndexedStack(index: _index, children: _tabs),
        ),
        extendBody: true,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, c.bg2], stops: const [0, .45],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    GestureDetector(
                      onTap: () {
                        setState(() => _index = i);
                        if (i == 2) context.read<WishRoomProvider>().loadNotifications();
                      },
                      child: AnimatedScale(
                        scale: i == _index ? 1.1 : 1,
                        duration: const Duration(milliseconds: 500),
                        curve: const Cubic(.34, 1.56, .64, 1),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(clipBehavior: Clip.none, children: [
                              Text(_labels[i].$1, style: TextStyle(fontSize: 17, color: i == _index ? c.glow : c.muted)),
                              if (i == 2)
                                Consumer<WishRoomProvider>(builder: (_, p, __) => p.unreadCount > 0
                                    ? Positioned(right: -6, top: -3, child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(8)),
                                        child: Text('${p.unreadCount}', style: const TextStyle(fontSize: 9, color: Colors.white))))
                                    : const SizedBox.shrink()),
                            ]),
                            const SizedBox(height: 3),
                            Text(_labels[i].$2, style: TextStyle(fontSize: 10, color: i == _index ? c.fg : c.muted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
