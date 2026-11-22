// [A12 신규 — 46개 안내 팝업 전수 대조 공백 보완] app3/tour.jsx TomorrowCard 1:1 포팅.
// 진짜 첫 기도 또는 그 이후의 매일 기도 직후, "내일(또는 며칠 뒤)은 무엇이
// 열려요"를 1장으로 보여준다. app3 원본은 `app.afterPray(first)`에서
// `first`면 Tour21을 띄우고(=우리 쪽 _tour21), 아니면 이 카드를 띄운다
// (shell.jsx `afterPray` 1:1) — 둘은 상호 배타적이다.
// OPEN_NEXT/U(RULES.unlock)는 클라이언트에 이미 있는 WrCatalog.I.raw['UNLOCK']
// (assets/wishroom/data/wishroom_data.json)과 완전히 동일한 키·값이라
// 서버 추가 작업 없이 그대로 쓴다. "오늘 하루 한 번만"(c.log[c.day].tmrShown)
// 판정은 GuidePrefs.I.tomorrowCardShown/markTomorrowCardShown(로컬, dayN 키)으로 대체.
import 'package:flutter/material.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';

// app3/tour.jsx OPEN_NEXT 1:1 — (unlock키, 아이콘, 제목, 설명).
const List<(String, String, String, String)> kOpenNext = [
  ('guardian', '👤', '수호자가 찾아와요', '소원방을 함께 지킬 친구가 생겨요'),
  ('decor', '✿', '방을 꾸밀 수 있어요', '복주머니 50개를 선물로 드려요'),
  ('together', '☾', '함께 빌 수 있어요', '다른 분 소원에 마음을 보내요'),
  ('wardrobe', '👗', '옷장이 열려요', '수호자 옷을 갈아입혀요'),
  ('theme', '⛩', '방 분위기를 고를 수 있어요', '원하면 교회 · 법당 · 신당 방으로'),
  ('shop', '🛍', '소원 상점이 열려요', '수호자 20명 · 옷 · 꾸미기'),
];

/// 지금 dayN 기준으로 다음에 열릴 기능을 찾는다 — app3
/// `OPEN_NEXT.find(([k]) => U[k] > v.dayN)` 1:1. 없으면(이미 전부 열렸으면) null.
(String, String, String, String, int)? findNextOpen(int dayN) {
  final unlock = Map<String, dynamic>.from(WrCatalog.I.raw['UNLOCK'] ?? const {});
  for (final n in kOpenNext) {
    final u = (unlock[n.$1] as num?)?.toInt();
    if (u != null && u > dayN) return (n.$1, n.$2, n.$3, n.$4, u);
  }
  return null;
}

class TomorrowCard extends StatelessWidget {
  const TomorrowCard({super.key, required this.dayN, required this.onClose});
  final int dayN;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final next = findNextOpen(dayN);
    // app3 `if (!next) return null` 1:1 — 전부 열렸으면 카드 자체를 그리지 않는다.
    if (next == null) return const SizedBox.shrink();
    final (key, icon, title, desc, unlockDay) = next;
    final inDays = unlockDay - dayN;
    final unlock = Map<String, dynamic>.from(WrCatalog.I.raw['UNLOCK'] ?? const {});
    // app3 `OPEN_NEXT.filter(([kk]) => U[kk] > U[k]).slice(0,3)` 1:1 — 그 다음다음들 칩.
    final later = kOpenNext
        .where((n) => ((unlock[n.$1] as num?)?.toInt() ?? 0) > unlockDay)
        .take(3)
        .toList();
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          onTap: onClose,
          child: Container(color: const Color(0x80080308)), // .dim
        ),
      ),
      Positioned(
        left: 24, right: 24, top: 190,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0x61FFDC96)),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF7461E38), Color(0xFA1A0812)]),
            boxShadow: [BoxShadow(color: const Color(0x38FFBE78), blurRadius: 60), const BoxShadow(color: Color(0x80000000), blurRadius: 50, offset: Offset(0, 24))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              inDays == 1 ? 'TOMORROW · $unlockDay일째' : 'D-$inDays · $unlockDay일째',
              style: WrF.mono(color: const Color(0xFFFFE0A0)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 96, height: 96,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 96, height: 96,
                  decoration: const BoxDecoration(shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [Color(0x59FFD282), Colors.transparent], stops: [0, .7])),
                ),
                Text(icon, style: const TextStyle(fontSize: 44)),
                const Positioned(right: 6, bottom: 6, child: Text('🔒', style: TextStyle(fontSize: 18))),
              ]),
            ),
            const SizedBox(height: 10),
            Text(
              inDays == 1 ? '내일은 $title' : '$inDays일 뒤엔 $title',
              textAlign: TextAlign.center,
              style: WrF.display(21),
            ),
            const SizedBox(height: 6),
            Text(desc, textAlign: TextAlign.center, style: WrF.body(13.5, color: WrC.muted)),
            if (later.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
                for (final l in later)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(999)),
                    child: Text('${l.$2} ${(unlock[l.$1] as num?)?.toInt() ?? 0}일째', style: WrF.body(11)),
                  ),
              ]),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: WrDeco.hanji,
              child: Row(children: [
                const Text('🔔', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontFamily: 'Pretendard', fontSize: 12.5, color: WrC.hanjiInk, height: 1.5),
                      children: [
                        const TextSpan(text: '내일 저녁 9시', style: TextStyle(fontWeight: FontWeight.w700)),
                        const TextSpan(text: '에 알려 드릴게요\n'),
                        TextSpan(text: '하루 한 번 기도하면 하나씩 열려요', style: TextStyle(color: WrC.hanjiInk.withValues(alpha: .65))),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity, height: 48,
              child: Semantics(
                identifier: 'tomorrow_card_close',
                button: true,
                child: DecoratedBox(
                  decoration: WrDeco.btnPink,
                  child: Material(color: Colors.transparent,
                    child: InkWell(borderRadius: BorderRadius.circular(16),
                      onTap: onClose,
                      child: const Center(
                        child: Text('내일 만나요',
                            style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}
