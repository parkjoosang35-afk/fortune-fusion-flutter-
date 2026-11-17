// 신통방통 소원방 v5 S2 · 내부 6탭(5탭+홈버튼) 셸.
// [v5 S2 — CHECKLIST.md "하단바 6칸: 神 · 내 소원 · 수호자 · 함께 빌기 · 상점 · 보관함
// (알림 → 상단 🔔)"] 기존 5탭(내소원방·소원방·알림·꾸미기·보관함)+별도 신통방통
// 홈버튼 구조를, 프로토타입 app3/shell.jsx의 TABS 배열 그대로(神 홈버튼 + home·
// guardians·together·shop·vault 5탭)로 재구성한다. 알림 탭은 하단바에서 빠지고
// (화면 자체는 유지, 상단 벨 진입은 main_room_screen.dart TopBar 작업에서 별도
// 연결 예정), 꾸미기 탭은 하단바에서 빠지고 "⋯ 소원방 돌보기" 메뉴의 시트로
// 들어간다(매핑표 46번 "사기=상점 1곳 · 놓기=꾸미기 시트") — 상점 탭 자리에는
// 정식 ShopScreen이 아직 없어 임시로 DecorScreen을 연결한다(Todo #5에서 교체).
//
// 매핑표 00-C UNLOCK SPEC · app3/shell.jsx TABS/goTab() 1:1:
//   TABS = [['home',🕯,'내 소원',null], ['guardians',👤,'수호자','guardian'],
//           ['together',☾,'함께 빌기','together'], ['shop',🛍,'상점','decor'],
//           ['vault',◈,'보관함',null]]
// lock key가 있는 탭은 room.isFeatureUnlocked(key)(=서버 unlocked[] 포함 여부)가
// false면 🔒 + 흐림(opacity .4)으로 표시하고, 탭을 눌러도 화면 이동을 막는다
// (매핑표 "하단바 탭: 🔒 + 흐림 · 누르면 안내 시트 … (화면 이동 안 함)").
// 안내 시트(C12, "🔒 N일째에 열려요 · N일 뒤" + 진행 막대 + [기다릴게요])의 정식
// GuideSheet3 포팅과 열림 카드(UnlockCard3)는 Todo #4에서 이어서 구현한다 —
// 여기서는 그 완성 전까지 화면 이동을 안전하게 막기 위한 최소 안내 시트만 둔다.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/wr_theme.dart';
import 'application/wishroom_provider.dart';
import 'data/wr_catalog.dart';
import 'core/wr_nav_pill.dart';
import 'features/room/main_room_screen.dart';
import 'features/explore/explore_screen.dart';
import 'features/decor/decor_screen.dart';
import 'features/characters/character_shop_screen.dart';
import 'features/vault/vault_screen.dart';

class WishRoomShell extends StatefulWidget {
  const WishRoomShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<WishRoomShell> createState() => _WishRoomShellState();
}

class _WishRoomShellState extends State<WishRoomShell> {
  late int _index;

  // [v5 S2] app3/shell.jsx TABS 배열 1:1 — home(잠금없음)·guardians('guardian')·
  // together('together')·shop('decor', 임시로 DecorScreen 연결 — Todo #5에서 정식
  // ShopScreen으로 교체)·vault(잠금없음). 알림/꾸미기는 하단바에서 제거.
  static const _tabs = [
    MainRoomScreen(),
    CharacterShopScreen(),
    ExploreScreen(),
    DecorScreen(),
    VaultScreen(),
  ];

  // (이모지, 라벨, lock key) — lock key가 null이면 항상 열림.
  static const _labels = [
    ('🕯', '내 소원', null),
    ('👤', '수호자', 'guardian'),
    ('☾', '함께 빌기', 'together'),
    ('🛍', '상점', 'decor'),
    ('◈', '보관함', null),
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
    // [전수검수 2026-10-12 — MINOR] 매 빌드마다 찍히던 디버그 로그 제거.
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
            // [v2.1 §14.3 "탭 숨김·재개"/"소원방이 화면 밖으로 나가면"] IndexedStack은
            // 비활성 탭도 트리에 계속 살려두므로, 브라우저 탭 전환(RoomScene의
            // didChangeAppLifecycleState)만으로는 "내 소원방"이 아닌 다른 탭(탐색·
            // 꾸미기 등)으로 전환됐을 때 RoomScene의 반복 애니메이션이 보이지 않는
            // 곳에서도 계속 틱(tick)하는 누락이 있었다. Flutter 표준 TickerMode로
            // 비활성 탭의 모든 AnimationController(TickerProviderStateMixin 기반,
            // RoomScene 포함)를 muted 처리한다 — stop()과 달리 값·위상이 보존되므로
            // 돌아왔을 때 순간이동 없이 그 자리에서 이어서 재생된다(§14.3 "긴 비활성
            // 시간 뒤 파티클 순간이동 방지"). 앱(Android/iOS) 빌드에도 동일하게
            // 적용되며 부작용 없이 배경 탭의 불필요한 렌더 비용만 줄어든다.
            child: IndexedStack(
              index: _index,
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  TickerMode(enabled: i == _index, child: _tabs[i]),
              ],
            ),
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
                      // [v5 S2] 매핑표 00-C "하단바 탭: 🔒 + 흐림 · 누르면 안내 시트
                      // … (화면 이동 안 함)" — lock key가 있고 room.isFeatureUnlocked()가
                      // false면 탭을 눌러도 _index를 바꾸지 않고 최소 안내 시트만 띄운다.
                      // (정식 GuideSheet3/진행 막대 포팅은 Todo #4에서 이어감)
                      Consumer<WishRoomProvider>(
                        builder: (context, p, __) {
                          final key = _labels[i].$3;
                          final locked =
                              key != null &&
                              (p.room == null ||
                                  !p.room!.isFeatureUnlocked(key));
                          return SizedBox(
                            width: WrSize.navItemW,
                            height: 48,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (locked) {
                                  _showLockHintSheet(context, key);
                                  return;
                                }
                                setState(() => _index = i);
                              },
                              child: Center(
                                child: AnimatedScale(
                                  scale: i == _index ? 1.1 : 1,
                                  duration: const Duration(milliseconds: 500),
                                  curve: const Cubic(.34, 1.56, .64, 1),
                                  child: Opacity(
                                    opacity: locked ? .4 : 1,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          locked ? '🔒' : _labels[i].$1,
                                          style: TextStyle(
                                            fontSize: 17,
                                            color: i == _index
                                                ? WrC.glow
                                                : WrC.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _labels[i].$2,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: i == _index
                                                ? WrC.fg
                                                : WrC.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
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
                              // [v5 S2] 매핑표 "神 신통방통" — app3/shell.jsx
                              // nav-home 버튼("神" 글리프)과 동일하게 교체.
                              Text(
                                '神',
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

  /// [v5 S2] 매핑표 00-C "잠긴 곳 표시 — 하단바 탭: 🔒 + 흐림 · 누르면 안내 시트
  /// '🔒 N일째에 열려요 · N일 뒤' + 진행 막대 + [기다릴게요] (화면 이동 안 함)"의
  /// 최소 구현. app3/shell.jsx goTab()의 `left = max(1, unlock[k] - dayN)` 계산을
  /// 그대로 따른다. 정식 GuideSheet3(그림·1·2·3 안내 카드 등)로의 교체는 Todo #4.
  void _showLockHintSheet(BuildContext context, String key) {
    final room = context.read<WishRoomProvider>().room;
    final unlockDay = (WrCatalog.I.raw['UNLOCK'] as Map)[key] as int? ?? 0;
    final dayN = room?.dayN ?? 1;
    final left = math.max(1, unlockDay - dayN);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: WrDeco.sheet,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔒', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 10),
              Text('$unlockDay일째에 열려요', style: WrF.display(18)),
              const SizedBox(height: 6),
              Text(
                '$left일 뒤에 만날 수 있어요',
                textAlign: TextAlign.center,
                style: WrF.body(13, color: WrC.muted, height: 1.6),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: WrSize.btnH,
                child: DecoratedBox(
                  decoration: WrDeco.btnPink,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(sheetCtx).pop(),
                      child: const Center(
                        child: Text(
                          '기다릴게요',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
