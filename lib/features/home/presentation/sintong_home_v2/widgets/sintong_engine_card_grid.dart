// ═══════════════════════════════════════════════════════════════
// FILE: sintong_engine_card_grid.dart
// [Midnight Navy 리뉴얼 — design_handoff_sintong_main(2).zip]
// "운세 엔진" 시트의 카드 그리드: README "카드 그리드" 절 — 큰 카드 2개
// (귀인지도/궁합지도, 각 334×184, 2칸 전체 폭) + 작은 카드 6개(정통사주/
// 타로/소원방/오늘의 운세/관상/손금, 각 162×124, 2열) 총 8칸.
//
// [기능 보존 원칙] 이 파일은 오직 "무엇을 어떻게 그리는지"만 새로
// 정의하고, "어디로 이동하는지"는 전혀 새로 만들지 않는다 — 기존
// [sHomeV2SheetCards](category/customOnTap/라우팅 전부 보존)를 그대로
// 데이터 소스로 재사용해, 기존 openSubScreen/openFaceReading/
// openPalmReading 라우팅과 정통사주 원형 확산 전환(sajuCardCenterOf)이
// 모두 변경 없이 그대로 동작한다. 추가로 README가 지정한 "귀인지도"
// (guide)·"궁합지도"(gunghap) 2개 큰 카드도 기존
// [openSubScreen]/[openCompatibilityMap]을 그대로 호출한다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../../../../saju_renewal/navigation/saju_dimension_transition.dart';
import '../sintong_home_v2_data.dart';
import '../sintong_home_v2_routing.dart';
import '../sintong_home_v2_tokens.dart';

/// 카드 1개의 그리드 전용 메타데이터 — [sHomeV2SheetCards]와는 별개로
/// README MENU 배열의 "큰/작은" 구분과 한자 라벨, 커스텀 크롭(Alignment
/// 대신 FractionalOffset 기반 scale+align 조합)을 담는다.
class _EngineCard {
  const _EngineCard({
    required this.title,
    required this.asset,
    this.hanjaLabel,
    this.big = false,
    this.alignment = Alignment.center,
    this.scale = 1.0,
    this.scaleOrigin = Alignment.center,
    required this.onTap,
  });

  final String title;
  final String asset;
  final String? hanjaLabel;
  final bool big;
  final Alignment alignment;
  final double scale;
  final Alignment scaleOrigin;
  final void Function(BuildContext context) onTap;
}

/// README "카드 그리드" 절 순서 그대로: 귀인지도(big) · 궁합지도(big) ·
/// 정통사주 · 타로 · 소원방 · 오늘의 운세 · 관상 · 손금.
List<_EngineCard> _buildCards(BuildContext context) => [
  _EngineCard(
    title: '귀인지도',
    hanjaLabel: '貴人 · GUIN',
    big: true,
    // [Assets 표] guin_map.jpg는 사전에 README 지정 크롭 영역(x 23.4~
    // 83.5%, y 25~60%)으로 미리 잘라낸 guin_map_crop.jpg를 쓴다(원본을
    // 런타임에 166.5% 확대+좌표 이동하는 CSS 트릭 대신, 네이티브에서는
    // README가 권장한 "해당 영역을 잘라낸 별도 이미지" 방식을 그대로
    // 따름 — 결과物은 동일, 런타임 비용은 더 적음).
    asset: 'assets/images/sintong_home_v2/menu/guin_map_crop.jpg',
    onTap: (ctx) => openSubScreen(ctx, SHomeV2Category.guide),
  ),
  _EngineCard(
    title: '궁합지도',
    hanjaLabel: '宮合 · HARMONY',
    big: true,
    asset: 'assets/images/sintong_home_v2/menu/gunghap_map.jpg',
    alignment: const Alignment(0, -0.16), // center 42%
    onTap: (ctx) => openCompatibilityMap(ctx),
  ),
  _EngineCard(
    title: '정통사주',
    asset: 'assets/images/sintong_home_v2/menu/saju.png',
    alignment: const Alignment(0, -0.4), // center 30%
    onTap: (ctx) => openSubScreen(
      ctx,
      SHomeV2Category.saju,
      tapPosition: sajuCardCenterOf(ctx),
    ),
  ),
  _EngineCard(
    title: '타로',
    asset: 'assets/images/sintong_home_v2/menu/tarot_sun.jpg',
    alignment: const Alignment(0, -0.1), // center 45%
    onTap: (ctx) => openSubScreen(ctx, SHomeV2Category.tarot),
  ),
  _EngineCard(
    title: '소원방',
    asset: 'assets/images/sintong_home_v2/menu/sowon_pray.jpg',
    alignment: const Alignment(0, -0.08), // center 46%
    scale: 1.12,
    scaleOrigin: const Alignment(0.24, -0.04), // origin 62% 48%
    onTap: (ctx) => openSubScreen(ctx, SHomeV2Category.wish),
  ),
  _EngineCard(
    title: '오늘의 운세',
    asset: 'assets/images/sintong_home_v2/menu/today_phone.jpg',
    alignment: const Alignment(0, -0.2), // center 40%
    onTap: (ctx) => openTodayFortune(ctx, tapPosition: sajuCardCenterOf(ctx)),
  ),
  _EngineCard(
    title: '관상',
    asset: 'assets/images/sintong_home_v2/menu/gwansang.png',
    alignment: const Alignment(0, -0.4), // center 30%
    onTap: (ctx) => openFaceReading(ctx),
  ),
  _EngineCard(
    title: '손금',
    asset: 'assets/images/sintong_home_v2/menu/songeum2.png',
    alignment: Alignment.topCenter, // center top
    onTap: (ctx) => openPalmReading(ctx),
  ),
];

/// README "카드 그리드" 절 — padding 14 18 0, 2열, gap 10.
class SintongEngineCardGrid extends StatelessWidget {
  const SintongEngineCardGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = _buildCards(context);
    final bigCards = cards.where((c) => c.big).toList();
    final smallCards = cards.where((c) => !c.big).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in bigCards) ...[
          AspectRatio(
            aspectRatio: 334 / 184,
            child: _EngineCardTile(card: c),
          ),
          const SizedBox(height: SHomeV2Spacing.cardGap),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: smallCards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: SHomeV2Spacing.cardGap,
            crossAxisSpacing: SHomeV2Spacing.cardGap,
            childAspectRatio: 162 / 124,
          ),
          itemBuilder: (context, i) => _EngineCardTile(card: smallCards[i]),
        ),
      ],
    );
  }
}

/// 카드 1장 — README "카드 공통" 절(radius 12, border gold .5, 하단
/// 가독성 그라데이션, 제목, 원형 금색 화살표 버튼) + 큰/작은 카드별
/// 차이(제목 크기 21/15, 화살표 30/24, 한자 라벨 유무).
class _EngineCardTile extends StatefulWidget {
  const _EngineCardTile({required this.card});
  final _EngineCard card;

  @override
  State<_EngineCardTile> createState() => _EngineCardTileState();
}

class _EngineCardTileState extends State<_EngineCardTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final titleSize = card.big ? 21.0 : 15.0;
    final goSize = card.big ? 30.0 : 24.0;
    final rowPadding = card.big
        ? const EdgeInsets.fromLTRB(14, 0, 10, 12)
        : const EdgeInsets.fromLTRB(12, 0, 8, 9);

    return GestureDetector(
      onTap: () => card.onTap(context),
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      // README "눌림(press)": scale .96, transition transform .4s ease,
      // box-shadow .6s ease, 눌린 동안 금빛 glow 0 0 26px rgba(212,175,55,.25).
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SHomeV2Radii.card),
            boxShadow: [
              const BoxShadow(
                color: Color(0x66000000), // 0 8px 20px rgba(0,0,0,.4)
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
              if (_pressed)
                const BoxShadow(
                  color: Color(0x40D4AF37), // 0 0 26px rgba(212,175,55,.25)
                  blurRadius: 26,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SHomeV2Radii.card),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 배경 폴백(이미지 로딩 전) — linear-gradient(#0F1A33,#0A1224).
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF0F1A33), Color(0xFF0A1224)],
                    ),
                  ),
                ),
                // 이미지(커스텀 크롭/스케일 지원).
                Transform.scale(
                  scale: card.scale,
                  alignment: card.scaleOrigin,
                  child: Image.asset(
                    card.asset,
                    fit: BoxFit.cover,
                    alignment: card.alignment,
                  ),
                ),
                // 하단 50% 가독성 그라데이션.
                const Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      widthFactor: 1.0,
                      heightFactor: 0.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x000A0D1B), // rgba(7,13,27,0)
                              Color(0x8C070D1B), // rgba(7,13,27,.55)
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // 카드 테두리(안쪽 겹침) — border 1px rgba(212,175,55,.5).
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(SHomeV2Radii.card),
                      border: Border.all(
                        color: SHomeV2Colors.cardBorderGold,
                        width: 1,
                      ),
                    ),
                  ),
                ),
                // 큰 카드 한자 라벨(제목 위, left 14 / bottom 44).
                if (card.big && card.hanjaLabel != null)
                  Positioned(
                    left: 14,
                    bottom: 44,
                    child: Text(
                      card.hanjaLabel!,
                      style: SHomeV2Text.cardHanjaLabel().copyWith(
                        shadows: const [
                          Shadow(
                            color: Color(0xE6000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                // 하단 row — 제목 + 원형 화살표 버튼.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: rowPadding,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            card.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                SHomeV2Text.cardTitle(
                                  color: SHomeV2Colors.ivory,
                                  fontSize: titleSize,
                                ).copyWith(
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xE6000000),
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
                                    ),
                                    Shadow(
                                      color: Color(0x99000000),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _GoldArrowButton(size: goSize),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// README "카드 공통" 절 — 원형 화살표 버튼: radial-gradient(#F6E6A8→
/// #D4AF37 50%→#7E6420 100%), shadow 0 2px 10px rgba(212,175,55,.35) +
/// inset 0 1px 0 rgba(255,255,255,.55), 아이콘 '›' 11px stroke #1A1406 2px.
class _GoldArrowButton extends StatelessWidget {
  const _GoldArrowButton({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFF6E6A8), SHomeV2Colors.gold, Color(0xFF7E6420)],
          stops: [0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x59D4AF37),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.chevron_right_rounded,
          size: size * 0.55,
          color: const Color(0xFF1A1406),
        ),
      ),
    );
  }
}
