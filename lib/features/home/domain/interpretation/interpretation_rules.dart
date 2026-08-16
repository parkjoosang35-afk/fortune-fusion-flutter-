/// [정통사주 69종 개인화 해석 엔진 — 1단계] 문장 생성 규칙(길이/톤) 모델.
///
/// 사용자 최종 지시 §12 "결과 문장의 길이"를 코드화한 것이다. 이 클래스는
/// "판단"에는 관여하지 않는다(판단은 [CategoryAnalyzer]가 이미 끝낸다) —
/// 오직 [NarrativeGenerator]가 문장을 만들 때 지켜야 할 분량/구조 가이드만
/// 담는다.
///
/// [절대 원칙] 분량을 늘리기 위해 의미 없는 문장을 반복하는 것을 막기
/// 위해, 상한(max) 값을 두고 이를 넘기지 않도록 강제하는 용도로 쓴다.
/// 하한(min) 값은 "너무 빈약한 근거로 대충 한 줄만 쓰고 끝내는 것"을
/// 막기 위한 최소 기준이며, 근거([AnalysisEvidence])가 부족하면 min을
/// 채우지 못할 수 있고 그 경우 억지로 채우지 않는다(§15 억지 개인화 금지).
library;

class InterpretationRules {
  const InterpretationRules({
    this.minCharacteristicParagraphs = 3,
    this.maxCharacteristicParagraphs = 6,
    this.minFavorableItems = 2,
    this.maxFavorableItems = 4,
    this.minCautionItems = 2,
    this.maxCautionItems = 4,
    this.maxCoreResultSentences = 3,
    this.maxSummarySentences = 5,
    this.useEasyTermTranslation = true,
  });

  /// 결과 페이지 ③ "나에게 나타나는 특징" 문단 수 하한/상한(§12: 3~6문단).
  final int minCharacteristicParagraphs;
  final int maxCharacteristicParagraphs;

  /// 결과 페이지 ④ "좋은 흐름" 항목 수 하한/상한(§12: 2~4개).
  final int minFavorableItems;
  final int maxFavorableItems;

  /// 결과 페이지 ⑤ "주의할 흐름" 항목 수 하한/상한(§12: 2~4개).
  final int minCautionItems;
  final int maxCautionItems;

  /// 결과 페이지 ① "핵심 결과" 문장 수 상한(§12: 1~3문장).
  final int maxCoreResultSentences;

  /// 결과 페이지 ⑦ "최종 정리" 문장 수 상한(§12: 3~5문장).
  final int maxSummarySentences;

  /// true면 term_translation_layer.dart의 4단계 변환(§8)을 적용해 전문
  /// 용어를 쉬운 한국어로 바꾼다. 내부 디버깅/테스트 용도로만 false 사용.
  final bool useEasyTermTranslation;

  /// 대부분의 카테고리에 적용되는 표준 규칙(§12 본문 그대로).
  static const InterpretationRules standard = InterpretationRules();
}
