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
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 22),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      decoration: WrDeco.sheet,
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        // 168px 히어로 — 좌우 네거티브 마진(-18)으로 시트 폭 전체를 채운다.
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: -18),
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
                child: Text('🔒 $need일째에 열려요', style: WrF.body(11.5, w: FontWeight.w700, color: WrC.glow)),
              )),
            ]),
          ),
        ),
        const SizedBox(height: 12),
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
        if (lock)
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: Text('기다릴게요', style: WrF.body(14, w: FontWeight.w700, color: Colors.white)),
          ))
        else
          Row(children: [
            SizedBox(width: 96, height: 50, child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: WrC.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Text('닫기', style: WrF.body(13, color: WrC.fg)),
            )),
            const SizedBox(width: 8),
            Expanded(child: SizedBox(height: 50, child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onGo();
              },
              style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Text('바로 가기 ›', style: WrF.body(14, w: FontWeight.w700, color: Colors.white)),
            ))),
          ]),
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
