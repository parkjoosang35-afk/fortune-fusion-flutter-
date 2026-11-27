// [A11 신규 — 46개 안내 팝업 전수 대조 공백 보완] app3/tour.jsx `TabGuide({app,
// onClose})` 1:1 포팅. "⋯ 소원방 돌보기" 메뉴 「그 밖에」 1번 "소원방 쓰는 법"이
// 지금까지는(v5 S2 리팩토링 이전) 구버전 10주제 GuideBook을 열었는데, v5
// 스펙은 "탭 6개 · ⋯ 메뉴 · 각 열리는 날을 한 장으로" 요약하는 전용 1장짜리
// 시트를 요구한다 — 이 파일이 그 전용 시트다. GuideBook(구버전 백과사전)은
// 전혀 다른 용도(10주제 browsable encyclopedia)로 계속 그대로 둔다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';

/// app3/tour.jsx TabGuide `rows` 1:1 — (아이콘, 제목, 설명, unlock day, lock key).
/// lock key가 null이면 항상 "지금 가능"(day는 표시만 1로 둔다 — 원본도 동일).
const List<(String, String, String, String?)> _kTabGuideRows = [
  ('🕯', '내 소원', '매일 한 번, 버튼을 3초 꾹 눌러 빌어요', null),
  ('👤', '수호자', '22명 구경 · 함께할 수호자 바꾸기 · 자세히 보기', 'guardian'),
  ('👗', '옷 갈아입기', '방에서 수호자를 누르거나 👤 탭 → 옷 갈아입히기', 'wardrobe'),
  ('☾', '함께 빌기', '다른 분 소원에 두 손 모으기 · 복주머니 +2', 'together'),
  ('🛍', '상점', '수호자 · 옷 · 꾸미기를 복주머니로 결제', 'shop'),
  ('◈', '보관함', '이루어진 소원이 영원히 담겨요', null),
  ('⋯', '오른쪽 위 메뉴', '꾸미기 · 방 분위기 · 배경화면 · 소원 고치기', null),
];

/// 어디서든(소원방 돌보기 「그 밖에」 "소원방 쓰는 법") 호출 가능한 오프너.
void showTabGuideSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _TabGuideSheet(),
  );
}

class _TabGuideSheet extends StatelessWidget {
  const _TabGuideSheet();

  @override
  Widget build(BuildContext context) {
    final room = context.watch<WishRoomProvider>().room;
    final dayN = room?.dayN ?? 1;
    final unlock = Map<String, dynamic>.from(WrCatalog.I.raw['UNLOCK'] ?? const {});
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .86),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: WrDeco.sheet,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('HOW TO · 이제 여기서 해요', style: WrF.mono(size: 10.5, color: WrC.blossom2)),
          const SizedBox(height: 6),
          Text('소원방 쓰는 법, 한 장으로', style: WrF.display(20, color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            '미리보기에서 본 것들은 날이 되면 아래 탭에 하나씩 열려요.',
            style: WrF.body(12.5, color: WrC.muted, height: 1.5),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final row in _kTabGuideRows)
                    _TabGuideRow(
                      icon: row.$1,
                      title: row.$2,
                      sub: row.$3,
                      unlockDay: row.$4 == null ? 1 : (unlock[row.$4] as int? ?? 1),
                      open: row.$4 == null || dayN >= (unlock[row.$4] as int? ?? 1),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Semantics(
              identifier: 'tab_guide_close',
              button: true,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrC.blossom,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('알겠어요', style: WrF.body(14, w: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabGuideRow extends StatelessWidget {
  const _TabGuideRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.unlockDay,
    required this.open,
  });
  final String icon;
  final String title;
  final String sub;
  final int unlockDay;
  final bool open;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: WrC.line))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: WrC.card,
              border: Border.all(color: WrC.cardBorder),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: WrF.body(14, w: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 1),
                Text(
                  sub,
                  style: WrF.body(11.5, color: WrC.muted, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            open ? '지금 가능' : '$unlockDay일째',
            style: WrF.body(11, w: FontWeight.w700, color: open ? WrC.blossom2 : WrC.glow),
          ),
        ],
      ),
    );
  }
}
