// ═══════════════════════════════════════════════════════════════
// FILE: sintong_mode_chip_row.dart
// [신통방통 메인 매핑] C-02 · ModeChip — Handoff.html §06
// "전체보기" 필터 칩(좌) + 그리드/리스트 뷰 스위치(우).
//
// [기능 매핑] 기존 화면의 "전체보기" 타이틀+그리드 아이콘 2개 탭 타겟을
// 새 디자인의 칩 1개 + 스위치 1개로 재배치한다.
// - 칩 탭 → 기존 그리드 아이콘이 담당하던 "운세 전체보기 카테고리 허브"
//   이동(`/home/all-categories`)으로 연결한다(칩 라벨 "전체보기"와 가장
//   의미가 부합).
// - 그리드 스위치 탭 → Handoff.html §06 C-02 스펙 그대로 "서비스 리스트
//   ↔ 2열 그리드" 뷰를 토글한다(신규 기능, 데이터/라우팅 변경 없음).
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../sintong_home_tokens.dart';

class SintongModeChipRow extends StatelessWidget {
  const SintongModeChipRow({
    super.key,
    required this.onChipTap,
    required this.isGrid,
    required this.onToggleGrid,
  });

  final VoidCallback onChipTap;
  final bool isGrid;
  final ValueChanged<bool> onToggleGrid;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // "전체보기" 칩 — 좌측 그라디언트 sparkle 동그라미 + 라벨.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onChipTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
            decoration: BoxDecoration(
              color: SintongHomeColors.chipBg,
              borderRadius: BorderRadius.circular(SintongHomeRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4A3B7A), Color(0xFF1A1530)],
                    ),
                  ),
                  child: const Text(
                    '✦',
                    style: TextStyle(fontSize: 11, color: Color(0xFFFFD66A)),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('전체보기', style: SintongHomeText.chip),
              ],
            ),
          ),
        ),
        const Spacer(),
        // 그리드/리스트 뷰 스위치 — 32×32, bg #1A1A1A.
        GestureDetector(
          onTap: () => onToggleGrid(!isGrid),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SintongHomeColors.ink,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
