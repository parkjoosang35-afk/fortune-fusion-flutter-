// [C1-C11 신규] app3/guide3.jsx `GuideSheet3({k, onClose, lock})` 1:1 포팅.
// care_menu_info_sheet.dart `_CareMenuInfoSheet`와 거의 동일한 구조(히어로 +
// mono 라벨 + 제목 + 번호 스텝 카드 + 약속 문구 + CTA)를 그대로 재사용해
// 디자인 언어를 통일한다 — 다른 점은 이 시트는 "평생 1번"(GuidePrefs.seen/
// markSeen) 판정이고, 잠금 모드가 없는 한 항상 "알겠어요" 버튼 1개만 보여준다.
//
// [lock 파라미터] 원본은 잠긴 탭을 눌렀을 때도 같은 컴포넌트를 재사용한다
// (`lock={{day,left}}`). [대표님 판정 — "잠김 안내는 한 가지 모양으로"]
// 이 구조를 그대로 살려 `showGuide3LockSheet()`(아래)를 추가했고, 하단 탭
// (wishroom_shell.dart/wr_bottom_nav.dart) · ⋯ 메뉴(care_menu_info_sheet.dart
// 경유) · 상점(shop_screen.dart) 세 곳 모두 이 함수로 교체 완료했다
// (CHECKLIST.md "대표님 판정② — Guide3Lock 통일" 참고).
import 'package:flutter/material.dart';
import '../../core/theme/wr_theme.dart';
import 'guide3_data.dart';
import 'guide_prefs.dart';

/// 잠금 모드 전용 부가 정보 — 원본 `lock={day,left}` 1:1 + 진행 막대 계산용
/// `dayN`(오늘 며칠째인지) 추가. [대표님 판정 — "잠김 안내는 한 가지 모양으로"]
/// 하단 탭 · ⋯ 메뉴 · 상점 세 곳이 모두 같은 모양(그림 + "🔒 N일째에 열려요" +
/// 오늘 며칠째인지 보여주는 진행 막대 + [기다릴게요])으로 보이도록, 호출부가
/// dayN까지 함께 넘긴다.
class Guide3Lock {
  const Guide3Lock({required this.day, required this.left, required this.dayN});
  final int day;
  final int left;
  final int dayN;
}

/// [C1-C11] 처음 동작 안내 — `!GuidePrefs.I.seen(key)`일 때만 호출부가 열고,
/// 닫힐 때(배경 탭 포함) `GuidePrefs.I.markSeen(key)`를 호출해 "평생 1번"을 보장한다.
/// lock이 주어지면(향후 확장용) 「기다릴게요」 버튼 + 잠금 라벨로 바뀐다.
Future<void> showGuide3Sheet(
  BuildContext context,
  String key, {
  Guide3Lock? lock,
  VoidCallback? onClose,
}) {
  final item = kGuide3[key];
  if (item == null) return Future.value();
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _Guide3Sheet(item: item, lock: lock),
  ).then((_) {
    if (lock == null) GuidePrefs.I.markSeen(key);
    onClose?.call();
  });
}

/// [C1-C11] 각 화면 `initState()`의 postFrameCallback에서 호출하는 공용
/// 진입점 — app3/shell.jsx `want && !(v.seenHints||[]).includes(want) && !hint`
/// 1:1. GuidePrefs 로딩이 아직 끝나지 않았을 수 있으므로(여러 탭이
/// IndexedStack으로 동시에 initState되는 WishRoomShell 구조 — 셸/메인화면
/// 쪽에서 이미 load()를 걸어 두지만 경합 가능) 먼저 await로 한 번 더
/// 보장한 뒤(멱등) seen 여부를 확인한다.
Future<void> maybeShowGuide3(BuildContext context, String key) async {
  await GuidePrefs.I.load();
  if (GuidePrefs.I.seen(key)) return;
  if (!context.mounted) return;
  await showGuide3Sheet(context, key);
}

/// [대표님 판정 — "잠김 안내는 한 가지 모양으로"] 앱 전체의 유일한 잠금 안내
/// 시트. 하단 탭(wishroom_shell.dart/wr_bottom_nav.dart) · ⋯ 메뉴
/// (care_menu_info_sheet.dart, CareMenuInfo→Guide3Item 변환 경유) · 상점
/// (shop_screen.dart) 세 곳 모두 이 함수 하나만 호출한다 — 서로 다른 모양의
/// 잠금 시트가 섞이지 않도록. `showGuide3Sheet`와 달리 "평생 1번" 판정이
/// 없다(잠긴 동안은 누를 때마다 매번 보여줘야 하므로 GuidePrefs.seen/markSeen을
/// 건드리지 않는다).
Future<void> showGuide3LockSheet(
  BuildContext context, {
  required Guide3Item item,
  required Guide3Lock lock,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _Guide3Sheet(item: item, lock: lock),
  );
}

class _Guide3Sheet extends StatelessWidget {
  const _Guide3Sheet({required this.item, this.lock});
  final Guide3Item item;
  final Guide3Lock? lock;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 22),
      padding: const EdgeInsets.only(bottom: 24),
      decoration: WrDeco.sheet,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              child: Container(
                height: 132,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, .8),
                    radius: 1.3,
                    colors: [Color(0x59FFC896), Colors.transparent],
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.isBg)
                      Opacity(
                        opacity: .8,
                        child: Image.asset(
                          'assets/wishroom/${item.img}',
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Image.asset(
                            'assets/wishroom/${item.img}',
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Text(
                      lock != null ? '🔒 ${lock!.day}일째에 열려요' : '처음이라면 · HOW TO',
                      style: WrF.mono(size: 10, color: WrC.glow),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      item.title,
                      style: WrF.display(21, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < item.steps.length; i++) ...[
                    if (i > 0) const SizedBox(height: 6),
                    _Guide3StepCard(step: item.steps[i], index: i + 1),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    item.promise,
                    textAlign: TextAlign.center,
                    style: WrF.body(12.5, color: WrC.muted, height: 1.6),
                  ),
                  if (lock != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: WrDeco.hanji,
                      child: Text.rich(
                        TextSpan(
                          style: WrF.body(13.5, color: WrC.fg, height: 1.6),
                          children: [
                            TextSpan(
                              text: '${lock!.left}일 뒤',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const TextSpan(text: '에 열려요 · 하루 한 번 기도하면 하나씩 찾아와요'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // [대표님 판정 — "잠김 안내는 한 가지 모양으로"] care_menu_info_sheet.dart
                    // 와 동일한 "오늘 N일째" + 진행 막대 — 하단 탭 · ⋯ 메뉴 · 상점 모두
                    // 이 한 가지 모양만 쓰도록 통일한다.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('오늘 ${lock!.dayN}일째', style: WrF.body(12, w: FontWeight.w700, color: WrC.muted)),
                        Text('${lock!.left}일 뒤 열려요', style: WrF.body(12, w: FontWeight.w700, color: WrC.glow)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: 7,
                        child: Stack(
                          children: [
                            Container(color: Colors.white.withValues(alpha: .08)),
                            FractionallySizedBox(
                              widthFactor: (lock!.day > 0 ? lock!.dayN / lock!.day : 1.0).clamp(0, 1),
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(colors: [Color(0xFFFF9CBC), Color(0xFFF5CF6A)]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // [QA 테스트 보조 — 대표 지시, 기본 규칙화] care_info_* 와 동일한
                  // 네이밍 규칙으로 좌표 클릭 대신 이름표로 누를 수 있게 한다.
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: Semantics(
                      identifier: 'guide3_close',
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WrC.blossom,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          lock != null ? '기다릴게요' : '알겠어요',
                          style: WrF.body(14, w: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Guide3StepCard extends StatelessWidget {
  const _Guide3StepCard({required this.step, required this.index});
  final Guide3Step step;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: WrDeco.card,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x29F2628F),
              border: Border.all(color: const Color(0x59FFBED2)),
            ),
            child: Text(step.icon, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STEP $index',
                  style: WrF.mono(size: 9, color: WrC.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  step.text,
                  style: WrF.body(12, w: FontWeight.w700, color: Colors.white, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
