// ═══════════════════════════════════════════════════════════════
// FILE: sintong_v2_sheet.dart
// [신통방통 홈 v2] 하단 시트 — README §sheet 스펙:
// "전체보기 · 3 gates" 헤더 + 3열 카드 그리드(소원방/타로/정통사주) +
// "프리패스" CTA(margin-top:auto로 시트 하단에 붙음).
//
// [기능 보존] CTA는 기존 v1 [SintongFreePassBar]와 동일한 목적지
// (`/free-pass-gate`)로 이동한다. 실시간 잔여시간 표시는 이 디자인
// 스펙에는 없으므로(README에 "프리패스" 고정 라벨만 존재) 생략하되,
// 탭 시 이동 로직만 그대로 재사용한다(신규 로직 없음).
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../sintong_home_v2_data.dart';
import '../sintong_home_v2_routing.dart';
import '../sintong_home_v2_tokens.dart';

class SintongV2Sheet extends StatelessWidget {
  const SintongV2Sheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SHomeV2Colors.sheetBg,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SHomeV2Radii.sheetTop),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('전체보기', style: SHomeV2Text.sheetTitle()),
                Text('3 gates', style: SHomeV2Text.sheetMeta()),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 0; i < sHomeV2SheetCards.length; i++) ...[
                Expanded(child: _SheetCardTile(card: sHomeV2SheetCards[i])),
                if (i != sHomeV2SheetCards.length - 1)
                  const SizedBox(width: 9),
              ],
            ],
          ),
          // [스크롤 레이아웃 전환] 원래 README `.cta-wrap { margin-top:auto }`을
          // Spacer()로 재현했으나, 화면 전체가 SingleChildScrollView로
          // 바뀌면서 이 위젯의 부모가 더 이상 고정 높이(Expanded)를 주지
          // 않아 Spacer가 무한 높이 오류를 일으킨다. 고정 간격으로 대체.
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              height: 50,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/free-pass-gate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SHomeV2Colors.ctaBg,
                  foregroundColor: SHomeV2Colors.ctaFg,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SHomeV2Radii.pill),
                  ),
                ),
                child: Text('프리패스', style: SHomeV2Text.cta()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetCardTile extends StatelessWidget {
  const _SheetCardTile({required this.card});
  final SHomeV2SheetCard card;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SHomeV2Colors.cardBg,
      borderRadius: BorderRadius.circular(SHomeV2Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(SHomeV2Radii.card),
        onTap: () => openSubScreen(context, card.category),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(SHomeV2Radii.card),
              ),
              child: Image.asset(
                card.thumbAsset,
                height: 82,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 10,
              ),
              child: Text(
                card.title,
                textAlign: TextAlign.center,
                style: SHomeV2Text.cardTitle(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
