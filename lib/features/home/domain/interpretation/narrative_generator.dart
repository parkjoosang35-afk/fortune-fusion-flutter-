/// [정통사주 69종 개인화 해석 엔진 — 1단계] 문장 생성기 공통 인터페이스.
///
/// 사용자 최종 지시 §20 "결과 문장 생성 방법"을 그대로 구현한다.
///
///     SajuProfile + CategoryAnalysis + InterpretationRules
///                        ↓
///                  FortuneNarrative
///
/// [절대 원칙 — §21] 이 계층은 계산을 하지 않는다. [CategoryAnalysis]가
/// 이미 끝낸 판단(coreEvidence/favorableConditions/cautionConditions 등)을
/// 입력으로 받아 그것을 4단계 용어 변환(term_translation_layer.dart)을
/// 거쳐 쉬운 한국어 문장으로 "표현"만 한다. 만약 이 인터페이스의 구현체가
/// LLM을 호출한다면, LLM에게는 이미 계산·분석된 데이터만 넘기고 새로운
/// 판단(예: "재물운이 좋다/나쁘다")을 LLM이 만들어내지 않도록 프롬프트
/// 자체를 제한해야 한다 — 핵심 판단은 어디까지나 CategoryAnalyzer가
/// deterministic하게 이미 내린 상태여야 한다.
library;

import '../manseryeok/saju_profile.dart';
import 'category_analysis.dart';
import 'fortune_narrative.dart';
import 'interpretation_rules.dart';

/// [A]는 이 생성기가 소비하는 [CategoryAnalysis] 하위 타입(예:
/// WealthAnalysis). 카테고리마다 고유 필드가 다르므로, 실제 문장 생성
/// 로직은 카테고리별 NarrativeGenerator 구현체가 담당한다(예:
/// `WealthNarrativeGenerator implements NarrativeGenerator<WealthAnalysis>`).
abstract class NarrativeGenerator<A extends CategoryAnalysis> {
  const NarrativeGenerator();

  /// [profile]은 시기 섹션(⑥) 렌더링을 위해 참조용으로만 사용한다(예:
  /// 대운/세운 원본 라벨). 판단 자체는 이미 [analysis]에 끝나 있다.
  FortuneNarrative generate(
    SajuProfile profile,
    A analysis, {
    InterpretationRules rules = InterpretationRules.standard,
  });
}
