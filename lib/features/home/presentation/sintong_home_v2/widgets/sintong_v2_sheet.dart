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
//
// [전체보기 6섹션 개편 — design_handoff_main_all_sections.zip, 2026-10-02]
// README.md가 요청한 두 가지만 변경:
//  1. 그리드 뷰(_isGrid==true)의 카드 디자인을 "사진이 카드 전체를 채우는"
//     2열×3행 포토 카드([SintongSectionPhotoGrid])로 교체. 3열 그리드 +
//     흰 라벨박스 디자인은 완전히 대체됨(리스트 뷰는 기존 그대로 유지—
//     토글 버튼 자체는 범위 밖이라 보존).
//  2. 프리패스 바에서 카운트다운 시간 텍스트 제거 — "프리패스"만 노출.
//     기존 [SintongFreePassBar](실시간 틱 로직 포함)는 계속 재사용하되,
//     이 화면에서만 시간 텍스트를 감추는 옵션을 추가했다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../../../../saju_renewal/navigation/saju_dimension_transition.dart';
import '../../sintong_home/widgets/sintong_free_pass_bar.dart';
import '../sintong_home_v2_data.dart';
import '../sintong_home_v2_routing.dart';
import '../sintong_home_v2_tokens.dart';
import 'sintong_section_photo_card.dart';

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
                    onTap: () =>
                        Navigator.of(context).pushNamed('/home/all-categories'),
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
                    _isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _isGrid
              // [전체보기 6섹션 개편] 2열×3행 포토 카드 그리드로 교체.
              ? SintongSectionPhotoGrid(cards: buildSHomeV2PhotoCards(context))
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
            // [전체보기 6섹션 개편] README "프리패스 바" — 카운트다운
            // 텍스트 제거, "프리패스"만 노출.
            child: SintongFreePassBar(showRemainingTime: false),
          ),
        ],
      ),
    );
  }
}

/// 리스트형(가로) 카드 — 썸네일(좌) + 제목(우) + 화살표(더보기 시각
/// 힌트), v1 [SintongServiceTile]과 유사한 레이아웃을 다크 테마로 재현.
class _SheetCardListTile extends StatelessWidget {
  const _SheetCardListTile({required this.card});
  final SHomeV2SheetCard card;

  // [디자인 핸드오프 00 셸 — 진입 전환] 정통사주 카드만 이 타일 자신의
  // 중심 좌표(docs/03 §00 "구현은 카드 중심 좌표를 원점으로")를 함께
  // 넘겨, `/saju-renewal`이 그 지점에서 원형 확산 전환을 재생하게 한다.
  void _onTap(BuildContext context) => card.customOnTap != null
      ? card.customOnTap!(context)
      : openSubScreen(
          context,
          card.category!,
          tapPosition: card.category == SHomeV2Category.saju
              ? sajuCardCenterOf(context)
              : null,
        );

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
              Expanded(child: Text(card.title, style: SHomeV2Text.cardTitle())),
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
