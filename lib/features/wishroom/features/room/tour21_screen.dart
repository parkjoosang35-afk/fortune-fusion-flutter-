// J6 "Tour21" — app3/tour.jsx Tour21 1:1 이식(A안: 원본 그대로 "21일 미리보기
// 투어" 전체 구현). 생애 첫 기도(prayedN==1) 직후 한 번만 떠서, 실제 상태를
// 전혀 조작하지 않고(원본 previewStart/previewEnd의 localStorage 스냅샷-복구는
// 서버-백엔드 구조에 대응 개념이 없어 이식하지 않는다 — 대신 실제 탭
// 네비게이션(WishRoomProvider.requestTab)으로 각 기능을 "진짜로" 미리 보여준다)
// 7단계 코치마크(가디언/장식/함께빌기/옷장/테마/상점/목표일) + 마지막 "이루어짐
// 미리보기" 연출을 보여준 뒤, "진짜 첫 기도 올리러 가기" 안내로 끝맺는다.
//
// 기존 WrTour(guide_sheet.dart, "한 바퀴 둘러보기" 6단계)와는 완전히 별개의
// 기능이다 — 이름·상태·트리거 지점이 모두 다르다. 혼동 금지.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/wr_toast.dart';
import '../../core/fx/wr_fx.dart';
import '../guide/guide_prefs.dart';
import 'room_scene.dart';

/// app3/tour.jsx TOUR_STEPS 1:1.
class Tour21Step {
  const Tour21Step({
    required this.day,
    required this.key,
    required this.title,
    required this.say,
    required this.act,
    this.doAction,
    required this.where,
    this.peek = false,
  });
  final int day;
  final String key;
  final String title;
  final String say;
  final String act;
  /// null = 액션 없음(바로 "해봤어요"로 진행). '@xxx' = 탭 이동, 그 외 = 시트 열기(미구현 시트는 탭 이동으로 대체).
  final String? doAction;
  final (double, double) where;
  final bool peek;
}

const List<Tour21Step> kTour21Steps = [
  Tour21Step(day: 2, key: 'guardian', title: '2일째 · 수호자가 찾아와요',
      say: '혼자가 아니에요. 당신이 없는 동안에도 수호자가 촛불을 지켜봐 줘요.',
      act: '👤 수호자 탭 열기', doAction: '@guardians', where: (117, 800)),
  Tour21Step(day: 3, key: 'decor', title: '3일째 · 방을 꾸밀 수 있어요',
      say: '장식 하나만 놓아도 방이 훨씬 더 당신다워져요.',
      act: '장식 하나 놓기', doAction: '@decor', where: (300, 460)),
  Tour21Step(day: 4, key: 'together', title: '4일째 · 함께 빌어줄 수 있어요',
      say: '다른 분의 소원방에도 하루 한 번, 마음을 보탤 수 있어요.',
      act: '함께 빌러 가기', doAction: '@together', where: (195, 800)),
  Tour21Step(day: 5, key: 'wardrobe', title: '5일째 · 옷장이 열려요',
      say: '수호자에게 새 옷을 입혀줄 수 있어요.',
      act: '👗 옷 갈아입히기', doAction: '@guardians', where: (86, 560)),
  Tour21Step(day: 7, key: 'theme', title: '7일째 · 원하면 방을 바꿀 수 있어요',
      say: '자유·하나님·부처님·무속인 중 마음에 드는 곳으로 바꿀 수 있어요.',
      act: '다음', where: (356, 74), peek: true),
  Tour21Step(day: 14, key: 'shop', title: '14일째 · 소원 상점이 열려요',
      say: '꾸미기·수호자·옷을 복주머니로 살 수 있는 곳이에요.',
      act: '🛍 상점 둘러보기', doAction: '@shop', where: (273, 800)),
  Tour21Step(day: 21, key: 'goal', title: '21일째 · 목표한 날이에요',
      say: '21일 동안 쌓아온 정성이 이렇게 빛나는 순간으로 이어져요.',
      act: '이루어지는 순간 보기', where: (195, 300)),
];

class Tour21Screen extends StatefulWidget {
  const Tour21Screen({super.key, required this.onEnd});
  /// true = "🙏 진짜 첫 기도 올리러 가기"(실제 정성 유도), false = 건너뜀.
  final ValueChanged<bool> onEnd;
  @override
  State<Tour21Screen> createState() => _Tour21ScreenState();
}

class _Tour21ScreenState extends State<Tour21Screen> {
  /// -1 = 시작 카드, 0..len-1 = 코치마크 단계, len = 마지막 reveal 연출.
  int _i = -1;
  final Set<String> _done = {};

  void _go(String tabId) {
    final p = context.read<WishRoomProvider>();
    const order = ['home', 'guardians', 'together', 'shop', 'vault'];
    // decor(꾸미기)는 셸 5탭 중 정식 상점 자리가 아직 DecorScreen이므로(wishroom_shell.dart
    // 주석 참고) decor/shop 모두 같은 탭(3)으로 보낸다.
    final idx = switch (tabId) {
      '@guardians' => 1,
      '@together' => 2,
      '@decor' || '@shop' => 3,
      _ => order.indexOf(tabId.replaceFirst('@', '')),
    };
    if (idx >= 0) p.requestTab(idx);
  }

  void _next() => setState(() => _i++);

  void _act(Tour21Step s) {
    if (s.doAction == null) { _next(); return; }
    setState(() => _done.add(s.key));
    if (s.doAction!.startsWith('@')) _go(s.doAction!);
  }

  void _finish(bool remind) {
    // ignore: discarded_futures
    GuidePrefs.I.setTour21Done();
    widget.onEnd(remind);
  }

  @override
  Widget build(BuildContext context) {
    if (_i == -1) return _startCard();
    if (_i >= kTour21Steps.length) return _revealScene();
    return _stepCard(kTour21Steps[_i]);
  }

  Widget _startCard() {
    return Stack(children: [
      Positioned.fill(child: Container(color: const Color(0xE6080308))),
      Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 22),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          decoration: WrDeco.sheet,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('✧ 21 DAYS · 1분 미리보기', style: WrF.mono(size: 11, color: WrC.blossom2)),
            const SizedBox(height: 10),
            Text('첫 기도가 닿았어요', style: WrF.display(20, color: Colors.white), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('앞으로 21일, 미리 걸어볼까요', style: WrF.body(13, color: WrC.muted), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
              for (final s in kTour21Steps)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: WrDeco.chip,
                  child: Text('${s.day}일', style: WrF.body(11, color: WrC.muted)),
                ),
            ]),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, height: WrSize.btnH, child: DecoratedBox(decoration: WrDeco.btnGold,
              child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _i = 0),
                child: const Center(child: Text('✦ 21일 미리 걸어보기', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF4A2A10)))))))),
            const SizedBox(height: 10),
            GestureDetector(onTap: () => _finish(false),
              child: Text('괜찮아요, 바로 시작할게요', style: WrF.body(12.5, color: WrC.muted))),
          ]),
        ),
      ),
    ]);
  }

  Widget _stepCard(Tour21Step s) {
    final (x, y) = s.where;
    final up = y > 430;
    final acted = _done.contains(s.key);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Stack(children: [
        // 진행 띠
        Positioned(left: 16, right: 16, top: 14, child: Row(children: [
          for (var k = 0; k < kTour21Steps.length; k++)
            Expanded(child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2), height: 3,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: k <= _i ? WrC.blossom2 : Colors.white24),
            )),
        ])),
        Positioned(right: 16, top: 24, child: GestureDetector(onTap: () => _finish(false),
          child: Text('그만 보기', style: WrF.body(12, color: WrC.muted)))),
        // 점선 하이라이트 링(장식용 — 실제 해당 UI는 다른 탭에 있을 수 있어 장식 효과로만 둔다)
        Positioned(left: x - 44, top: y - 44, child: IgnorePointer(child: Container(
          width: 88, height: 88,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x99FFBED2), width: 2)),
        ))),
        Positioned(
          left: 18, right: 18,
          top: up ? null : 120,
          bottom: up ? 120 : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: WrDeco.sheet,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DAY ${s.day}/21', style: WrF.mono(size: 10, color: WrC.blossom2)),
              const SizedBox(height: 6),
              Text(s.title, style: WrF.display(17, color: Colors.white)),
              const SizedBox(height: 8),
              Text(s.say, style: WrF.body(12.5, color: const Color(0xD9FFF0E6), height: 1.6)),
              if (s.peek) ...[
                const SizedBox(height: 12),
                Row(children: [for (final t in WrCatalog.I.themes) Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0x14FFFFFF)),
                    child: Column(children: [
                      Text(t['glyph'] as String? ?? '✦', style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(t['label'] as String? ?? '', style: WrF.body(10, color: WrC.muted)),
                    ]),
                  ),
                ))]),
              ],
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: SizedBox(height: WrSize.btnSmH, child: DecoratedBox(decoration: WrDeco.btnPink,
                  child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16),
                    onTap: () => _act(s),
                    child: Center(child: Text(acted || s.doAction == null
                        ? (_i == kTour21Steps.length - 1 ? '이루어지는 순간 보기' : '✓ 해봤어요 · 다음')
                        : s.act,
                      style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)))))))),
                if (acted) ...[
                  const SizedBox(width: 8),
                  SizedBox(height: WrSize.btnSmH, child: DecoratedBox(decoration: WrDeco.btnDark,
                    child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16),
                      onTap: _next,
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Center(child: Text('다음',
                        style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 13, color: WrC.fg)))))))),
                ],
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _revealScene() {
    final p = context.watch<WishRoomProvider>();
    final room = p.room;
    if (room == null) return const SizedBox.shrink();
    return Stack(children: [
      Positioned.fill(child: RoomScene(
        room: room,
        items: p.items,
        pray: true,
        levelOverride: 10,
        brightnessOverride: 1,
        fx: const [
          WrPetalRain(n: 30, dur: (3.0, 5.0)),
          WrSpiral(x: 204, y: 330),
        ],
      )),
      Positioned.fill(child: Container(color: const Color(0x66080308))),
      Center(child: Container(
        width: 110, height: 110, alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: WrC.accent,
          boxShadow: const [BoxShadow(color: Color(0x99C94A3B), blurRadius: 30)]),
        child: const Text('成', style: TextStyle(fontFamily: 'NotoSerifKR', fontWeight: FontWeight.w900, fontSize: 48, color: Color(0xFFFFF9E8))),
      )),
      Positioned(left: 20, right: 20, bottom: 40, child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: WrDeco.sheet,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('✿ 이렇게 이루어져요 ✿', style: WrF.display(16, color: Colors.white), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('여기까지가 연습이었어요\n이제 진짜 첫 기도를 올려요', style: WrF.body(12.5, color: WrC.muted, height: 1.6), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0x1AF5CF6A), border: Border.all(color: const Color(0x66F5CF6A))),
            child: Text('🔔 내일 저녁 9시, 다시 올 수 있게 알려드릴게요', style: WrF.body(11.5, color: const Color(0xFFFFE7A0)), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: WrSize.btnH,
            child: DecoratedBox(
              decoration: WrDeco.btnPink,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _finish(true),
                  child: const Center(
                    child: Text(
                      '🙏 진짜 첫 기도 올리러 가기',
                      style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(onTap: () => _finish(false),
            child: Text('매일 알림 없이 돌아가기', style: WrF.body(12, color: WrC.muted))),
        ]),
      )),
    ]);
  }
}

/// toast 안내 문구 헬퍼 — main_room_screen.dart의 onEnd 콜백에서 사용.
void showTour21EndToast(BuildContext context) {
  WrToast.show(context, '이제 진짜 첫 기도예요 · 두 손 모아 3초 꾹 눌러 주세요');
}
