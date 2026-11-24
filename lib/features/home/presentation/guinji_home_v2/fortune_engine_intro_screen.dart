// ═══════════════════════════════════════════════════════════════
// FILE: fortune_engine_intro_screen.dart
// [운세 엔진 안내 페이지 — 디자인 핸드오프 전면 교체]
// design_handoff_fortune_engine (1).zip (README.md 13개 섹션 + 4개
// 인터랙티브 체험 명세)에 따라 기존 "다크 네이비 6개 엔진 카드" 화면을
// 완전히 교체한다. Midnight Temple 팔레트, CustomPaint 기반 시각화
// (사주 4기둥·귀인 Sigil·타로 카드·관상/손금 측정값), 시드 고정 셔플
// 데모, 결정론적 대조(agreementOf) 계산기를 포함한 단일 세로 스크롤
// 화면이다.
//
// [라우팅 — 변경 없음] '/home/fortune-engine' 라우트가 그대로 이
// 위젯(FortuneEngineIntroScreen)을 가리키므로 app_router.dart /
// sintong_v2_sheet.dart는 수정할 필요가 없다 — 이 파일 내부 구현만
// 전면 교체.
//
// [원칙 준수]
//  - LLM 미사용: feAgreementOf()는 최대편차 계산만 하는 순수 함수.
//  - 기존 엔진 재구현 금지: 여기 등장하는 모든 수치(사주 예시 명식,
//    귀인 궁위, 타로 데모 카드, 관상/손금 측정값)는 디자인 핸드오프가
//    제공한 "데모/예시" 데이터이며, 실제 정통사주 계산 엔진·69종
//    해석 API를 호출하거나 대체하지 않는다. 실제 각 서비스 결과
//    화면(사주/귀인지도/타로/관상/손금)의 로직과 완전히 분리된 별도
//    안내용 정적+데모 콘텐츠다.
//  - 이미지/스톡사진 금지: 전부 CustomPaint/텍스트/Container 기반.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import 'fortune_engine/fe_tokens.dart';
import 'fortune_engine/fe_widgets.dart';
import 'fortune_engine/sections/fe_section_combos.dart';
import 'fortune_engine/sections/fe_section_cross_check.dart';
import 'fortune_engine/sections/fe_section_demo.dart';
import 'fortune_engine/sections/fe_section_engines.dart';
import 'fortune_engine/sections/fe_section_flow.dart';
import 'fortune_engine/sections/fe_section_hero.dart';
import 'fortune_engine/sections/fe_section_journey_tone_closing.dart';
import 'fortune_engine/sections/fe_section_saju_deep.dart';
import 'fortune_engine/sections/fe_section_seed_demo.dart';
import 'fortune_engine/sections/fe_section_why_principles.dart';

class FortuneEngineIntroScreen extends StatelessWidget {
  const FortuneEngineIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FeColors.bgDeep,
      body: Stack(
        children: [
          Positioned.fill(child: DecoratedBox(decoration: fePageBackground())),
          const Positioned.fill(child: FeRadialWashes()),
          const Positioned.fill(child: FeStarField()),
          SafeArea(
            child: Column(
              children: [
                const FeTopBar(),
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: const [
                      SliverToBoxAdapter(child: FeHeroSection()),
                      SliverToBoxAdapter(child: FeMarqueeSection()),
                      SliverToBoxAdapter(child: FeWhySection()),
                      SliverToBoxAdapter(child: FePrinciplesSection()),
                      SliverToBoxAdapter(child: _FeHairline()),
                      SliverToBoxAdapter(child: FeFlowSection()),
                      SliverToBoxAdapter(child: FeEnginesSection()),
                      SliverToBoxAdapter(child: FeSajuDeepSection()),
                      SliverToBoxAdapter(child: _FeHairline()),
                      SliverToBoxAdapter(child: FeCombosSection()),
                      SliverToBoxAdapter(child: FeCrossCheckSection()),
                      SliverToBoxAdapter(child: _FeHairline()),
                      SliverToBoxAdapter(child: FeDemoSection()),
                      SliverToBoxAdapter(child: FeSeedDemoSection()),
                      SliverToBoxAdapter(child: _FeHairline()),
                      SliverToBoxAdapter(child: FeJourneySection()),
                      SliverToBoxAdapter(child: FeToneSection()),
                      SliverToBoxAdapter(child: FeClosingSection()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 섹션 사이 구분선 — engine.css `.hair` 재현.
class _FeHairline extends StatelessWidget {
  const _FeHairline();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FeSpace.screenH,
        26,
        FeSpace.screenH,
        0,
      ),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, FeColors.line, Colors.transparent],
          ),
        ),
      ),
    );
  }
}
