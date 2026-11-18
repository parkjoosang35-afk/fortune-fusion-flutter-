// [v5 S2 — 사용자 지시 "캐릭터 상점 하단바 → 5탭 하단바를 지우고 공용 6탭
// 하단바로 통일해 주세요"] wishroom_shell.dart의 IndexedStack 바텀탭(神 홈버튼 +
// 내 소원·수호자·함께 빌기·상점·보관함)을 공용 위젯으로 뽑아, 셸 안이 아니라
// Navigator.push로 별도 진입하는 화면(character_shop_screen.dart 등)에서도
// 완전히 동일한 모양·잠금 로직·안내 시트를 보여주기 위한 공유 모듈이다.
//
// 디자인/로직은 wishroom_shell.dart 원본과 1바이트도 다르지 않게 유지한다 —
// 이 파일은 "코드 위치"만 옮긴 것이고 시각적 변경은 없다.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/wr_theme.dart';
import '../application/wishroom_provider.dart';
import '../data/wr_catalog.dart';
import '../features/guide/guide_prefs.dart';
import 'wr_nav_pill.dart';

/// (이모지, 라벨, lock key, 탭 id) — wishroom_shell.dart의 탭 순서 그대로.
/// lock key가 null이면 항상 열림. 탭 id는 GuidePrefs N 배지(fresh) 판정에 쓰인다.
const wrShellTabLabels = [
  ('🕯', '내 소원', null, 'home'),
  ('👤', '수호자', 'guardian', 'guardians'),
  ('☾', '함께 빌기', 'together', 'together'),
  ('🛍', '상점', 'decor', 'shop'),
  ('◈', '보관함', null, 'vault'),
];

/// 공용 6탭(5탭+神 홈버튼) 바텀 네비게이션 바.
/// - [currentIndex]: 현재 화면에 해당하는 탭 인덱스(하이라이트 표시용).
/// - [onTabTap]: 잠기지 않은 탭을 눌렀을 때 호출(전환 방식은 호출부가 결정 —
///   IndexedStack 안이면 setState, 독립 push 화면이면 wrReturnToTab()).
Widget wrBottomNavBar(
  BuildContext context, {
  required int currentIndex,
  required void Function(int index) onTabTap,
}) {
  return DecoratedBox(
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
            for (var i = 0; i < wrShellTabLabels.length; i++)
              // [v5 S2] 매핑표 00-C "하단바 탭: 🔒 + 흐림 · 누르면 안내 시트
              // … (화면 이동 안 함)" — lock key가 있고 room.isFeatureUnlocked()가
              // false면 탭을 눌러도 전환하지 않고 최소 안내 시트만 띄운다.
              Consumer<WishRoomProvider>(
                builder: (context, p, __) {
                  final key = wrShellTabLabels[i].$3;
                  final tabId = wrShellTabLabels[i].$4;
                  final unlocked =
                      key == null ||
                      (p.room != null && p.room!.isFeatureUnlocked(key));
                  final locked = !unlocked;
                  // [v5 S2] 매핑표 "새로 열린 표시 — 열린 탭에 N 배지 → 그 탭을
                  // 처음 들어가면 사라짐" — app3/shell.jsx
                  // `fresh = k && v.open(k) && !(v.visited||[]).includes(id)` 1:1.
                  final fresh =
                      key != null && unlocked && !GuidePrefs.I.visitedTab(tabId);
                  return SizedBox(
                    width: WrSize.navItemW,
                    height: 48,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (locked) {
                          wrShowLockHintSheet(context, key!);
                          return;
                        }
                        GuidePrefs.I.markTabVisited(tabId);
                        onTabTap(i);
                      },
                      child: Center(
                        child: AnimatedScale(
                          scale: i == currentIndex ? 1.1 : 1,
                          duration: const Duration(milliseconds: 500),
                          curve: const Cubic(.34, 1.56, .64, 1),
                          child: Opacity(
                            opacity: locked ? .4 : 1,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Text(
                                      locked ? '🔒' : wrShellTabLabels[i].$1,
                                      style: TextStyle(
                                        fontSize: 17,
                                        color: i == currentIndex
                                            ? WrC.glow
                                            : WrC.muted,
                                      ),
                                    ),
                                    if (fresh)
                                      Positioned(
                                        right: -6,
                                        top: -3,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: WrC.blossom,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'N',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  wrShellTabLabels[i].$2,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: i == currentIndex
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
            // 들어가는 홈바가없고"] 다른 탭과 동일한 터치 영역/스타일로
            // "신통방통" 홈 탭을 추가해 wrExitHome()으로 앱 루트까지 pop한다.
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
                      // nav-home 버튼("神" 글리프)과 동일.
                      const Text('神', style: TextStyle(fontSize: 17, color: WrC.muted)),
                      const SizedBox(height: 3),
                      const Text(
                        '신통방통',
                        style: TextStyle(fontSize: 10, color: WrC.muted),
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
  );
}

/// [v5 S2] 매핑표 00-C "잠긴 곳 표시 — 하단바 탭: 🔒 + 흐림 · 누르면 안내 시트
/// '🔒 N일째에 열려요 · N일 뒤' + 진행 막대 + [기다릴게요] (화면 이동 안 함)"의
/// 공용 구현. app3/shell.jsx goTab()의 `left = max(1, unlock[k] - dayN)` 그대로.
void wrShowLockHintSheet(BuildContext context, String key) {
  final room = context.read<WishRoomProvider>().room;
  // [버그수정 — S2 실사용 검증] app3/shell.jsx goTab() 1:1 — 상점 탭의 lock
  // key 자체는 'decor'(오픈 판정은 UNLOCK.decor=3일째 기준)지만, 안내시트에
  // 보여주는 "N일째에 열려요"는 반드시 'shop'(=14) 키로 리매핑해서 계산한다.
  final unlockKey = key == 'decor' ? 'shop' : key;
  final unlockDay = (WrCatalog.I.raw['UNLOCK'] as Map)[unlockKey] as int? ?? 0;
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
