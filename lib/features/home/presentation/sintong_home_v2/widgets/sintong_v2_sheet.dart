// ═══════════════════════════════════════════════════════════════
// FILE: sintong_v2_sheet.dart
// [신통방통 홈 v2] 하단 시트 — "전체보기" 헤더 + 카드 그리드/리스트 +
// 프리패스 바.
//
// [사용자 피드백 반영 — 이전 디자인 기능 복원]
// 1. "전체보기" 옆 "N gates" 텍스트 제거.
// 2. "전체보기" 옆에 있던 리스트⇄그리드 뷰 전환 스퀘어 버튼(v1
//    [SintongModeChipRow]의 그리드 스위치)이 이번 v2 교체 때 빠져
//    있었다 — 그대로 복원한다. 탭하면 카드가 세로형 리스트(가로로
//    넓게 펼쳐진 행)와 3열 그리드 사이를 전환한다.
// 3. 프리패스 CTA를 v2 전용 커스텀 pill 버튼 대신, v1
//    [SintongFreePassBar](검정 pill + 자물쇠 아이콘 + 실시간 잔여시간
//    + 초록 원형 화살표, AccessChecker 실시간 tick)를 그대로 재사용
//    한다(다크 테마에서도 원래 검정 배경이라 잘 어울림).
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../../sintong_home/widgets/sintong_free_pass_bar.dart';
import '../sintong_home_v2_data.dart';
import '../sintong_home_v2_routing.dart';
import '../sintong_home_v2_tokens.dart';

class SintongV2Sheet extends StatefulWidget {
  const SintongV2Sheet({super.key});

  @override
  State<SintongV2Sheet> createState() => _SintongV2SheetState();
}

class _SintongV2SheetState extends State<SintongV2Sheet> {
  bool _isGrid = true;

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
          Row(
            children: [
              // "전체보기" — 탭하면 운세 전체보기 카테고리 허브로 이동
              // (v1 [SintongModeChipRow] "전체보기" 칩과 동일한 목적지).
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed('/home/all-categories'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      child: Text('전체보기', style: SHomeV2Text.sheetTitle()),
                    ),
                  ),
                ),
              ),
              // [복원] 리스트⇄그리드 뷰 전환 스퀘어 버튼.
              GestureDetector(
                onTap: () => setState(() => _isGrid = !_isGrid),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: SHomeV2Colors.chipBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isGrid
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _isGrid
              ? LayoutBuilder(
                  // 3열 고정 그리드 — 카드 개수가 3의 배수가 아니어도
                  // 항상 왼쪽 정렬로 줄바꿈된다.
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
                            child: _SheetCardGridTile(card: card),
                          ),
                      ],
                    );
                  },
                )
              : Column(
                  children: [
                    for (int i = 0; i < sHomeV2SheetCards.length; i++) ...[
                      _SheetCardListTile(card: sHomeV2SheetCards[i]),
                      if (i != sHomeV2SheetCards.length - 1)
                        const SizedBox(height: 9),
                    ],
                  ],
                ),
          const SizedBox(height: 18),
          // [복원] v1 프리패스 바 그대로 재사용(검정 pill + 자물쇠 +
          // 실시간 잔여시간 + 초록 원형 화살표).
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: SintongFreePassBar(),
          ),
        ],
      ),
    );
  }
}

/// 그리드형(3열) 카드 — 이미지 위 + 제목 아래, 정사각형에 가까운 비율.
class _SheetCardGridTile extends StatelessWidget {
  const _SheetCardGridTile({required this.card});
  final SHomeV2SheetCard card;

  void _onTap(BuildContext context) => card.customOnTap != null
      ? card.customOnTap!(context)
      : openSubScreen(context, card.category!);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SHomeV2Colors.cardBg,
      borderRadius: BorderRadius.circular(SHomeV2Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(SHomeV2Radii.card),
        onTap: () => _onTap(context),
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
                alignment: card.imageAlignment,
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

/// 리스트형(가로) 카드 — 썸네일(좌) + 제목(우) + 화살표(더보기 시각
/// 힌트), v1 [SintongServiceTile]과 유사한 레이아웃을 다크 테마로 재현.
class _SheetCardListTile extends StatelessWidget {
  const _SheetCardListTile({required this.card});
  final SHomeV2SheetCard card;

  void _onTap(BuildContext context) => card.customOnTap != null
      ? card.customOnTap!(context)
      : openSubScreen(context, card.category!);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SHomeV2Colors.cardBg,
      borderRadius: BorderRadius.circular(SHomeV2Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(SHomeV2Radii.card),
        onTap: () => _onTap(context),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  card.thumbAsset,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  alignment: card.imageAlignment,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(card.title, style: SHomeV2Text.cardTitle()),
              ),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: SHomeV2Colors.glow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
