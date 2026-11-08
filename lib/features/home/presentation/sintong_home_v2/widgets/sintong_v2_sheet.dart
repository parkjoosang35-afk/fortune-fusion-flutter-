// ═══════════════════════════════════════════════════════════════
// FILE: sintong_v2_sheet.dart
// [신통방통 홈 v2] 하단 시트 — "운세 엔진" 헤더 + 카드 그리드/리스트 +
// 프리패스 바.
//
// [Midnight Navy 리뉴얼 — design_handoff_sintong_main(2).zip, 2026-11]
// 사용자 요청: "메인화면 디자인을 바꿀거야 기능은 바뀐거는없고 디자인
// 위치와 색상 디자인 이야 개발 기획서 보고 만들어주고". README.md가
// 지정한 새 헤더(금색 그라데이션 "운세 엔진" 타이틀 + "SINTONG · 命理書"
// 모노 서브타이틀 + 원형 햄버거 아이콘 버튼 + ◇ 장식 구분선)와 새
// 카드 그리드(큰 카드 2 + 작은 카드 6, [SintongEngineCardGrid])로
// 교체하고, 시트 배경에 README가 지정한 별빛·회전 원반 데코레이션
// ([SintongSheetBackground])을 추가한다.
//
// [기능 보존] 이 리뉴얼은 시각 레이어만 바꾼다 — 기존 동작은 전부
// 그대로 유지:
//  - "운세 엔진" 타이틀 탭 → `/home/fortune-engine` 이동(동일).
//  - 리스트⇄그리드 토글 기능 자체는 삭제하지 않는다. 다만 새 디자인은
//    전용 토글 버튼 없이 원형 메뉴(햄버거) 아이콘 하나만 두므로,
//    README "메뉴 아이콘 버튼 → 기존 사이드/전체 메뉴 열기" 지시에
//    맞춰 이 앱에 있는 가장 가까운 기존 동작(그리드⇄리스트 전환)을
//    그 버�른에 그대로 연결한다 — 탭 결과(뷰 전환)는 바뀌지 않고,
//    버튼 모양만 사각형 아이콘에서 새 디자인의 원형 햄버거로 바뀐다.
//  - 프리패스 바([SintongFreePassBar])도 동일하게 유지, 새 팔레트에
//    맞춰 주변 여백만 재조정.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../../../../saju_renewal/navigation/saju_dimension_transition.dart';
import '../../sintong_home/widgets/sintong_free_pass_bar.dart';
import '../sintong_home_v2_data.dart';
import '../sintong_home_v2_routing.dart';
import '../sintong_home_v2_tokens.dart';
import 'sintong_engine_card_grid.dart';
import 'sintong_sheet_background.dart';

class SintongV2Sheet extends StatefulWidget {
  const SintongV2Sheet({super.key});

  @override
  State<SintongV2Sheet> createState() => _SintongV2SheetState();
}

class _SintongV2SheetState extends State<SintongV2Sheet> {
  bool _isGrid = true;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(SHomeV2Radii.sheetTop),
      ),
      child: Container(
        // README "컨테이너": border-top 1px rgba(212,175,55,.35),
        // box-shadow 0 -10px 30px rgba(0,0,0,.45).
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0x59D4AF37), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Color(0x73000000),
              blurRadius: 30,
              offset: Offset(0, -10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 레이어 ①~⑤ — README "컨테이너 > 배경" 절(그라데이션 +
            // 별빛 + 회전 원반), 시트 전체 영역을 덮는다.
            const Positioned.fill(child: SintongSheetBackground()),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 그랩바 — 36×3, radius 2, rgba(212,175,55,.4).
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0x66D4AF37),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                // 헤더 — README "헤더" 절.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SHomeV2Spacing.headerHPad,
                    14,
                    SHomeV2Spacing.headerHPad,
                    0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            // [기능 보존] 기존과 동일하게 안내 페이지로 이동.
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed('/home/fortune-engine'),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 2),
                              child: _EngineHeaderTitle(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // [기능 보존] 원형 햄버거 버튼 — 기존 그리드⇄리스트
                      // 토글 동작을 그대로 수행(README "메뉴 아이콘 버튼"
                      // 자리에 가장 가까운 기존 기능을 매핑).
                      _EngineMenuIconButton(
                        onTap: () => setState(() => _isGrid = !_isGrid),
                      ),
                    ],
                  ),
                ),
                // 구분선 — ◇ 중앙 장식.
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    SHomeV2Spacing.headerHPad,
                    14,
                    SHomeV2Spacing.headerHPad,
                    0,
                  ),
                  child: _EngineDivider(),
                ),
                // 카드 그리드 — README "카드 그리드" 절.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SHomeV2Spacing.gridHPad,
                    14,
                    SHomeV2Spacing.gridHPad,
                    0,
                  ),
                  child: _isGrid
                      ? const SintongEngineCardGrid()
                      : Column(
                          children: [
                            for (
                              int i = 0;
                              i < sHomeV2SheetCards.length;
                              i++
                            ) ...[
                              _SheetCardListTile(card: sHomeV2SheetCards[i]),
                              if (i != sHomeV2SheetCards.length - 1)
                                const SizedBox(height: 9),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 18),
                // [복원] v1 프리패스 바 그대로 재사용(검정 pill + 자물쇠 +
                // 실시간 잔여시간 + 초록 원형 화살표).
                const Padding(
                  padding: EdgeInsets.only(
                    left: SHomeV2Spacing.gridHPad,
                    right: SHomeV2Spacing.gridHPad,
                    bottom: 16,
                  ),
                  child: SintongFreePassBar(showRemainingTime: false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// README "헤더" 절 좌측: "운세 엔진"(금색 그라데이션 텍스트) +
/// "SINTONG · 命理書"(모노 서브타이틀).
///
/// [그라데이션 텍스트] Flutter TextStyle은 그라데이션 색을 직접 지원하지
/// 않으므로 ShaderMask + BlendMode.srcIn으로 재현한다 — README:
/// `linear-gradient(180deg, #EBD58E, #D4AF37 55%, #8C7124)`.
class _EngineHeaderTitle extends StatelessWidget {
  const _EngineHeaderTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              SHomeV2Colors.goldHi,
              SHomeV2Colors.gold,
              SHomeV2Colors.goldLo,
            ],
            stops: [0, 0.55, 1.0],
          ).createShader(bounds),
          child: Text('운세 엔진', style: SHomeV2Text.sheetTitle()),
        ),
        const SizedBox(height: 8),
        Text('SINTONG · 命理書', style: SHomeV2Text.sheetSubtitleMono()),
      ],
    );
  }
}

/// README "헤더" 절 우측: 40×40 원형 버튼, border 1px rgba(212,175,55,.28),
/// bg radial-gradient(rgba(212,175,55,.12)→rgba(11,19,38,.6)), 내부
/// 햄버거 3줄 16px #D4AF37 stroke 1.3.
class _EngineMenuIconButton extends StatelessWidget {
  const _EngineMenuIconButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: Color(0x47D4AF37), width: 1),
          ),
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            colors: [Color(0x1FD4AF37), Color(0x990B1326)],
          ),
        ),
        child: CustomPaint(
          size: const Size(16, 16),
          painter: _HamburgerPainter(),
        ),
      ),
    );
  }
}

class _HamburgerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SHomeV2Colors.gold
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (final y in [0.0, size.height / 2, size.height]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// README "헤더" 절 구분선: margin 14 22 0, 1px 가로 그라데이션, 가운데
/// ◇ 9px 금색(배경 #0E1830로 덮어 선을 끊어 보이게 함).
class _EngineDivider extends StatelessWidget {
  const _EngineDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Color(0x47D4AF37),
                  Color(0x47D4AF37),
                  Colors.transparent,
                ],
                stops: [0, 0.2, 0.8, 1.0],
              ),
            ),
          ),
          Container(
            color: SHomeV2Colors.navyTop,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: const Text(
              '◇',
              style: TextStyle(
                fontSize: 9,
                height: 1,
                color: SHomeV2Colors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 리스트형(가로) 카드 — 썸네일(좌) + 제목(우) + 화살표(더보기 시각
/// 힌트). [Midnight Navy 리뉴얼] 카드 배경/테두리를 새 팔레트(네이비 +
/// 금색 테두리)로 재도장했다 — 기존 동작(탭 라우팅)은 전혀 바뀌지 않음.
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
      color: SHomeV2Colors.navyTop,
      borderRadius: BorderRadius.circular(SHomeV2Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(SHomeV2Radii.card),
        onTap: () => _onTap(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SHomeV2Radii.card),
            border: Border.all(color: SHomeV2Colors.cardBorderGold, width: 1),
          ),
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
                child: Text(
                  card.title,
                  style: SHomeV2Text.cardTitle(
                    color: SHomeV2Colors.ivory,
                    fontSize: 15,
                  ),
                ),
              ),
              const _GoldArrowDot(),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoldArrowDot extends StatelessWidget {
  const _GoldArrowDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFF6E6A8), SHomeV2Colors.gold, Color(0xFF7E6420)],
          stops: [0, 0.5, 1.0],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: Color(0xFF1A1406),
      ),
    );
  }
}
