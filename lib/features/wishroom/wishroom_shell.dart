// 신통방통 소원방 v2.6 · 내부 5탭 셸 — 핸드오프 app_router.dart의
// StatefulShellRoute.indexedStack(5브랜치: 내 소원방·소원방(탐색)·알림·꾸미기·보관함)을
// 기존 앱 컨벤션(Navigator 1.0 + IndexedStack, go_router 미도입)으로 재구현.
// 바텀내비는 핸드오프 WrBottomNav 디자인(이모지 아이콘 🕯☾✉✿◈)을 그대로 따른다.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/wr_theme.dart';
import 'application/wishroom_provider.dart';
import 'core/wr_nav_pill.dart';
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

  static const _labels = [
    ('🕯', '내 소원방'),
    ('☾', '소원방'),
    ('✉', '알림'),
    ('✿', '꾸미기'),
    ('◈', '보관함'),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _tabs.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    // app2/guide2.jsx › GuideBook "✦ 소원방 한 바퀴 둘러보기"는 app.room && 조건만으로
    // 어느 화면(꾸미기/보관함 등)에서 열었어도 항상 보이고, 누르면 app.go('home') 후
    // startTour(). IndexedStack 구조라 탭 전환은 이 Shell만 할 수 있으므로, Provider의
    // tourRequested 플래그를 감지해 0번 탭(내 소원방)으로 전환한다. 실제 투어 시작은
    // MainRoomScreen이 같은 플래그를 소비하며 수행한다.
    final tourRequested = context.select<WishRoomProvider, bool>(
      (p) => p.tourRequested,
    );
    if (tourRequested && _index != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = 0);
      });
    }
    // wallet_sheet.dart "소원방에서 쓰는 곳" 카드(꾸미기/선물하기) · "전체 내역 보기"가
    // requestTab()으로 남긴 바텀탭 전환 요청을 소비한다(tourRequested와 동일 패턴).
    final requestedTab = context.select<WishRoomProvider, int?>(
      (p) => p.requestedTabIndex,
    );
    debugPrint(
      'WR_PHASE shell.build requestedTab=$requestedTab _index=$_index',
    );
    if (requestedTab != null && requestedTab != _index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        debugPrint('WR_PHASE shell.applyTab -> $requestedTab');
        setState(() => _index = requestedTab);
        context.read<WishRoomProvider>().consumeTabRequest();
      });
    } else if (requestedTab != null && requestedTab == _index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<WishRoomProvider>().consumeTabRequest();
      });
    }
    // [F섹션 접근성 — "나머지 빨리 진행해" 중 신규 구현] CHECKLIST.md "버튼 최소
    // 44pt · 텍스트 스케일 1.3배까지 레이아웃 유지". 이 모듈은 390×844 절대좌표
    // Stack+Positioned 레이아웃(픽셀 매칭 3원칙)이라 시스템 텍스트 스케일이
    // 과도하게 커지면(안드로이드는 최대 2.0까지 허용) 고정폭 카드 안의 텍스트가
    // 잘리거나 겹칠 수 있다. Apple/Google이 권장하는 "Dynamic Type 상한" 패턴과
    // 동일하게, 소원방 모듈 전체(바텀탭 5개 화면)에서만 textScaler를 최대
    // 1.3배로 clamp한다 — 요구사항 문구 그대로 "1.3배까지는 레이아웃을 유지"하고
    // 그 이상은 시각적으로 더 키우지 않아 레이아웃 붕괴를 막는다. 앱의 다른
    // 모듈(사주 등)에는 영향 없음(MediaQuery는 이 서브트리에만 적용).
    final mq = MediaQuery.of(context);
    final clampedScale = math.min(
      mq.textScaler.scale(1.0),
      1.3,
    ); // 축소(<1.0)는 그대로 허용, 확대만 1.3배 상한
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(clampedScale)),
      child: Theme(
        data: wrThemeData(),
        child: Scaffold(
          backgroundColor: WrC.bg2,
          body: SafeArea(
            top: false,
            child: IndexedStack(index: _index, children: _tabs),
          ),
          extendBody: true,
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, WrC.bg2],
                stops: const [0, .45],
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
                      // [버그수정 — 사용자 리포트: "하단바 터치가 잘안됨"] 기존
                      // GestureDetector가 Column(mainAxisSize: min)을 감싸고
                      // 있어 히트박스가 텍스트 글자 크기(17px 이모지 +
                      // 10px 라벨)만큼만 아주 작게 잡혔다. WrSize.navItemW
                      // (디자인 토큰에 정의돼 있었지만 이 화면에서 전혀
                      // 쓰이지 않았다)로 가로 58px, 세로도 패딩을 포함한
                      // 고정 터치 영역을 명시하고 behavior: opaque로 탭
                      // 아이템 전체(투명한 여백 포함)가 반응하도록 한다.
                      SizedBox(
                        width: WrSize.navItemW,
                        height: 48,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() => _index = i);
                            if (i == 2) {
                              context
                                  .read<WishRoomProvider>()
                                  .loadNotifications();
                            }
                          },
                          child: Center(
                            child: AnimatedScale(
                              scale: i == _index ? 1.1 : 1,
                              duration: const Duration(milliseconds: 500),
                              curve: const Cubic(.34, 1.56, .64, 1),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Text(
                                        _labels[i].$1,
                                        style: TextStyle(
                                          fontSize: 17,
                                          color: i == _index
                                              ? WrC.glow
                                              : WrC.muted,
                                        ),
                                      ),
                                      if (i == 2)
                                        Consumer<WishRoomProvider>(
                                          builder: (_, p, __) =>
                                              p.unreadCount > 0
                                              ? Positioned(
                                                  right: -6,
                                                  top: -3,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 4,
                                                          vertical: 1,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: WrC.blossom,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '${p.unreadCount}',
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _labels[i].$2,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: i == _index ? WrC.fg : WrC.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    // [버그수정 — 사용자 리포트: "하단바에 신통방통 메인으로
                    // 들어가는 홈바가없고"] 소원방 모듈 5탭 어디에도 앱의
                    // 메인 화면(신통방통 홈)으로 돌아가는 진입점이 바텀탭에
                    // 없었다(각 화면 상단 WrNavPill의 홈 아이콘만 있었는데,
                    // 스크롤하면 가려지거나 사용자가 찾지 못했다). 다른 탭과
                    // 동일한 터치 영역/스타일로 "신통방통" 홈 탭을 추가해
                    // wrExitHome()으로 앱 루트까지 pop한다.
                    SizedBox(
                      width: WrSize.navItemW,
                      height: 48,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => wrExitHome(context),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '⌂',
                                style: TextStyle(
                                  fontSize: 17,
                                  color: WrC.muted,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '신통방통',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: WrC.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
