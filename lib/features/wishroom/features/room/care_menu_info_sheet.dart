// [v5 S2 — CHECKLIST.md "⋯ 소원방 돌보기 메뉴 10줄 + 안내창(menuinfo.js)"]
// app3/menuinfo.js `MenuInfo3({t,lock,need,dayN,onGo,onClose})` 1:1 포팅.
// 168px 히어로(이미지 또는 배경) + 🔒 배지(잠김) + mono 라벨(COMING SOON/HOW IT
// WORKS) + 제목 + tag + 1·2·3 스텝 카드 + 💡 note + (잠김: 진행막대+기다릴게요 /
// 열림: 닫기+바로가기).
import 'package:flutter/material.dart';
import '../../core/theme/wr_theme.dart';
import 'care_menu_info.dart';

/// [v5 S2] app3/shop.jsx Menu3 Row `tap()` 1:1 — 잠겨 있으면 항상 안내(lock
/// 모드), 열려 있고 처음 보는 항목이면 안내(바로가기 모드), 이미 한 번 본
/// 항목이면 안내 없이 바로 onGo()를 실행해야 한다. 이 판정은 호출부
/// (_CareSheet)에서 GuidePrefs.menuInfoSeen()을 확인해 결정하고, 이 위젯은
/// "이미 lock/need가 정해진 상태"만 그린다.
Future<void> showCareMenuInfoSheet(
  BuildContext context, {
  required CareMenuInfo info,
  required bool lock,
  required int need,
  required int dayN,
  required VoidCallback onGo,
  // [v5 S2 — 사용자 확정 "API가 없는 3줄 → 기능 미구현이면 항상 잠김"] true면
  // 날짜 배지("N일째에 열려요")·진행막대·"N일 뒤 열려요" 대신 "곧 열려요"만
  // 보여준다(날짜 계산이 의미 없는 미구현 기능이므로).
  bool comingSoon = false,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CareMenuInfoSheet(info: info, lock: lock, need: need, dayN: dayN, onGo: onGo, comingSoon: comingSoon),
  );
}

class _CareMenuInfoSheet extends StatelessWidget {
  const _CareMenuInfoSheet({required this.info, required this.lock, required this.need, required this.dayN, required this.onGo, this.comingSoon = false});
  final CareMenuInfo info;
  final bool lock;
  final int need;
  final int dayN;
  final VoidCallback onGo;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final pct = need > 0 ? (dayN / need * 100).clamp(0, 100).round() : 100;
    // [S5 조사 중 발견 — 기존 버그 수정, 이 시트 전체(돌보기 메뉴 10개 모두 공용)]
    // 이전에는 바깥 Container에 좌우 padding 18을 주고, 168px 히어로가 시트
    // 폭 전체를 채우도록 margin: EdgeInsets.symmetric(horizontal: -18)(음수
    // 마진)로 그 padding을 상쇄했다. Flutter Container는
    // `assert(margin == null || margin.isNonNegative)`로 음수 마진을 금지하므로
    // 이 안내창을 열 때마다(돌보기 메뉴의 "?" 아이콘 또는 잠긴 행 탭) 항상
    // "Assertion failed" 크래시가 났다. 바깥 Container의 좌우 padding을 없애고
    // (히어로가 자연히 폭 전체를 차지), 히어로 아래 나머지 콘텐츠만 별도
    // Padding(horizontal: 18)으로 감싸는 구조로 바꿔 음수 마진 없이 동일한
    // 시각 결과(히어로만 폭 전체, 본문은 18px 여백)를 낸다.
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 22),
      padding: const EdgeInsets.only(bottom: 24),
      decoration: WrDeco.sheet,
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        // 168px 히어로 — 바깥 Container에 좌우 padding이 없으므로 그대로 폭 전체를 채운다.
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: Container(
            height: 168,
            decoration: const BoxDecoration(
              gradient: RadialGradient(center: Alignment(0, .7), radius: .9, colors: [Color(0x61FFBE96), Colors.transparent]),
            ),
            child: Stack(fit: StackFit.expand, children: [
              if (info.isBg)
                Opacity(opacity: .85, child: Image.asset('assets/wishroom/${info.img}', fit: BoxFit.cover))
              else
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ColorFiltered(
                      colorFilter: lock
                          ? const ColorFilter.matrix(<double>[
                              0.5, 0.5, 0.5, 0, 0,
                              0.5, 0.5, 0.5, 0, 0,
                              0.5, 0.5, 0.5, 0, 0,
                              0, 0, 0, 0.7, 0,
                            ])
                          : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                      child: Image.asset('assets/wishroom/${info.img}', height: 148, fit: BoxFit.contain),
                    ),
                  ),
                ),
              // bottom fade
              const Align(alignment: Alignment.bottomCenter, child: SizedBox(height: 48, child: DecoratedBox(decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xE51E1018)])))))
              ,
              Positioned(top: 12, right: 14, child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(width: 32, height: 32, alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0x66000000), shape: BoxShape.circle, border: Border.all(color: WrC.line)),
                  child: const Icon(Icons.close, size: 14, color: Colors.white)),
              )),
              if (lock) Positioned(top: 14, left: 16, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0x73000000), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0x66FFDC96))),
                // [v5 S2 — 사용자 지시 "잠금 안내창 문구는 날짜 대신 '곧 열려요'로"]
                // API 미구현 기능(comingSoon)은 날짜 배지("N일째에 열려요") 대신
                // "곧 열려요"만 보여준다.
                child: Text(
                  comingSoon ? '🔒 곧 열려요' : '🔒 $need일째에 열려요',
                  style: WrF.body(11.5, w: FontWeight.w700, color: WrC.glow),
                ),
              )),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Center(child: Text(lock ? 'COMING SOON' : 'HOW IT WORKS', style: WrF.mono(size: 10, color: WrC.blossom2))),
            const SizedBox(height: 4),
            Center(child: Text(info.title, style: WrF.display(22, color: Colors.white))),
            const SizedBox(height: 4),
            Center(child: Text(info.tag, style: WrF.body(13.5, color: WrC.muted))),
            const SizedBox(height: 16),
            for (var i = 0; i < info.steps.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _StepCard(step: info.steps[i], index: i + 1),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x4DFFDCB4), width: 1, style: BorderStyle.solid)),
              child: Text('💡 ${info.note}', style: WrF.body(12.5, height: 1.65, color: WrC.muted)),
            ),
            if (lock && comingSoon) ...[
              const SizedBox(height: 14),
              Center(child: Text('준비하고 있어요 · 준비되는 대로 알려 드릴게요', style: WrF.body(12, color: WrC.muted))),
            ] else if (lock) ...[
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('오늘 $dayN일째', style: WrF.body(12, w: FontWeight.w700, color: WrC.muted)),
                Text('${(need - dayN).clamp(1, 999)}일 뒤 열려요', style: WrF.body(12, w: FontWeight.w700, color: WrC.glow)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(999), child: SizedBox(height: 7, child: Stack(children: [
                Container(color: Colors.white.withValues(alpha: .08)),
                FractionallySizedBox(widthFactor: pct / 100, child: Container(
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFF9CBC), Color(0xFFF5CF6A)])))),
              ]))),
              const SizedBox(height: 8),
              Center(child: Text('하루 한 번 기도하면 하나씩 가까워져요', style: WrF.body(12, color: WrC.muted))),
            ],
            const SizedBox(height: 14),
            // [QA 테스트 보조 — 대표 지시, 기본 규칙화] 좌표 클릭 대신 이름표로
            // 안내 시트 버튼을 트리거할 수 있도록 identifier 부여. 시각적 변화 없음.
            if (lock)
              SizedBox(width: double.infinity, height: 50, child: Semantics(identifier: 'care_info_wait', button: true, child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text('기다릴게요', style: WrF.body(14, w: FontWeight.w700, color: Colors.white)),
              )))
            else
              Row(children: [
                SizedBox(width: 96, height: 50, child: Semantics(identifier: 'care_info_close', button: true, child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: WrC.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text('닫기', style: WrF.body(13, color: WrC.fg)),
                ))),
                const SizedBox(width: 8),
                Expanded(child: SizedBox(height: 50, child: Semantics(identifier: 'care_info_go', button: true, child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onGo();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text('바로 가기 ›', style: WrF.body(14, w: FontWeight.w700, color: Colors.white)),
                )))),
              ]),
          ]),
        ),
      ])),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.index});
  final CareMenuStep step;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: WrDeco.card,
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(width: 38, height: 38, alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0x29F2628F), border: Border.all(color: const Color(0x59FFBED2))),
            child: Text(step.icon, style: const TextStyle(fontSize: 17))),
          Positioned(top: -4, left: -4, child: Container(width: 17, height: 17, alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: WrC.glow),
            child: Text('$index', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w800, fontSize: 10, color: Color(0xFF3A2008))))),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(step.title, style: WrF.body(14, w: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 1),
          Text(step.sub, style: WrF.body(12, color: WrC.muted)),
        ])),
      ]),
    );
  }
}
