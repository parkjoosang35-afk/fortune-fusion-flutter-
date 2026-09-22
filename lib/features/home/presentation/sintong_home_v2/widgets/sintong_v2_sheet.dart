// ═══════════════════════════════════════════════════════════════
// FILE: sintong_v2_sheet.dart
// [신통방통 홈 v2] 하단 시트 — README §sheet 스펙:
// "전체보기 · N gates" 헤더 + 카드 그리드 + "프리패스" CTA(margin-top:
// auto로 시트 하단에 붙음).
//
// [6칸 확장] 사용자 요청으로 원래 3칸(소원방/타로/정통사주, 1행)이던
// 그리드를 2행(3+3, 총 6칸: +귀인지도/관상/손금)으로 확장했다. 카드
// 개수가 가변적이어도 항상 3열로 자동 줄바꿈되도록 Row 2개 대신
// Wrap 기반 3열 레이아웃으로 재구성한다.
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
          // [버그 수정] "전체보기" 텍스트에 탭 핸들러가 없어 눌러도 아무
          // 반응이 없었다(사용자 피드백). v1 [SintongModeChipRow]의
          // "전체보기" 칩과 동일한 목적지(`/home/all-categories`, 운세
          // 전체보기 카테고리 허브)로 이동하도록 InkWell로 감싼다.
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () =>
                  Navigator.of(context).pushNamed('/home/all-categories'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 6,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('전체보기', style: SHomeV2Text.sheetTitle()),
                    Text(
                      '${sHomeV2SheetCards.length} gates',
                      style: SHomeV2Text.sheetMeta(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 3열 고정 그리드 — 카드 개수가 3의 배수가 아니어도 항상
          // 왼쪽 정렬로 줄바꿈된다(LayoutBuilder로 전체 폭을 받아
          // (전체폭 - 간격*2)/3을 카드 폭으로 계산).
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 9.0;
              final tileWidth = (constraints.maxWidth - gap * 2) / 3;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final card in sHomeV2SheetCards)
                    SizedBox(
                      width: tileWidth,
                      child: _SheetCardTile(card: card),
                    ),
                ],
              );
            },
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
        onTap: () => card.customOnTap != null
            ? card.customOnTap!(context)
            : openSubScreen(context, card.category!),
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
