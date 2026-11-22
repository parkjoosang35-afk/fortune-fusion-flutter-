// [C1-C11 신규] app3/guide3.jsx `GuideSheet3({k, onClose, lock})` 1:1 포팅.
// care_menu_info_sheet.dart `_CareMenuInfoSheet`와 거의 동일한 구조(히어로 +
// mono 라벨 + 제목 + 번호 스텝 카드 + 약속 문구 + CTA)를 그대로 재사용해
// 디자인 언어를 통일한다 — 다른 점은 이 시트는 "평생 1번"(GuidePrefs.seen/
// markSeen) 판정이고, 잠금 모드가 없는 한 항상 "알겠어요" 버튼 1개만 보여준다.
//
// [lock 파라미터] 원본은 잠긴 탭을 눌렀을 때도 같은 컴포넌트를 재사용한다
// (`lock={{day,left}}`). 이 포팅도 동일 구조를 지원해 두지만(향후
// wishroom_shell.dart의 placeholder `_showLockHintSheet` 교체 범위는 별도
// 확인 후 진행 — CHECKLIST.md 참고), 이번 C1-C11 작업 자체는 lock:null
// (처음 동작 안내) 호출만 실제로 연결한다.
import 'package:flutter/material.dart';
import '../../core/theme/wr_theme.dart';
import 'guide3_data.dart';
import 'guide_prefs.dart';

/// 잠금 모드 전용 부가 정보 — 원본 `lock={day,left}` 1:1.
class Guide3Lock {
  const Guide3Lock({required this.day, required this.left});
  final int day;
  final int left;
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
