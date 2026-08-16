/// [정통사주 69종 개인화 해석 엔진 — 1단계] 최종 자연어 결과 모델.
///
/// 사용자 최종 지시 §11 "결과 페이지 기본 구조"의 7단을 그대로 필드로
/// 구현한다. 이 객체는 [NarrativeGenerator]의 최종 산출물이며, 여기 담긴
/// 문자열들은 이미 §8의 4단계 용어 변환을 거친 "쉬운 한국어"여야 한다.
///
/// [절대 원칙] 이 클래스는 문장을 만들지 않는다 — 오직 이미 만들어진
/// 문장을 담는 그릇이다. 문장 생성 로직은 [NarrativeGenerator] 구현체에
/// 있다.
library;

/// 결과 페이지 7단 구조 그대로.
class FortuneNarrative {
  const FortuneNarrative({
    required this.categoryId,
    required this.categoryName,
    required this.coreResult,
    required this.whyThisResult,
    required this.characteristics,
    required this.favorableFlows,
    required this.cautionFlows,
    this.timingSection,
    required this.finalSummary,
  });

  /// 카테고리 ID(예: 'A03') — [CategoryAnalysis.categoryId]와 반드시 일치.
  final String categoryId;

  final String categoryName;

  /// ① 핵심 결과 — 사용자가 화면을 처음 봤을 때 바로 이해할 수 있는 문장
  /// (§12: 1~3문장, 여기서는 문장 단위 리스트로 보관해 UI가 자유롭게
  /// 렌더링할 수 있게 한다).
  final List<String> coreResult;

  /// ② 왜 이렇게 나왔는가 — 실제 사주 구조를 쉬운 말로 설명(coreEvidence
  /// 를 문장으로 변환한 결과).
  final List<String> whyThisResult;

  /// ③ 나에게 나타나는 특징 — 개인의 사주를 현실적인 언어로 해석한 문단들
  /// (§12: 3~6문단).
  final List<String> characteristics;

  /// ④ 좋은 흐름(§12: 2~4개).
  final List<String> favorableFlows;

  /// ⑤ 주의할 흐름(§12: 2~4개).
  final List<String> cautionFlows;

  /// ⑥ 시기 — 대운/세운/월운이 관련된 카테고리에서만 값이 있다. 관련 없는
  /// 카테고리(예: A02 성격)는 null.
  final List<String>? timingSection;

  /// ⑦ 최종 정리(§12: 3~5문장).
  final List<String> finalSummary;

  Map<String, dynamic> toJson() => {
    'categoryId': categoryId,
    'categoryName': categoryName,
    'coreResult': coreResult,
    'whyThisResult': whyThisResult,
    'characteristics': characteristics,
    'favorableFlows': favorableFlows,
    'cautionFlows': cautionFlows,
    'timingSection': timingSection,
    'finalSummary': finalSummary,
  };

  /// 기존 jeontong_eighty_report_builder.dart의 `_mapCalculatedResultToReport`
  /// 가 소비하는 `Map<String, dynamic>` data 형태로 변환(9단계 "결과 UI 연결"
  /// 에서 사용). 필드명은 그 파일의 `_overviewFieldOrder`/`_listFieldLabels`
  /// 매핑 테이블과 호환되도록 맞춘다.
  Map<String, dynamic> toLegacyReportData() => {
    'headline': coreResult.join(' '),
    'summary': finalSummary.join(' '),
    'core_nature': whyThisResult.join('\n\n'),
    'strengths': favorableFlows,
    'weaknesses': cautionFlows,
    if (timingSection != null && timingSection!.isNotEmpty)
      'periods': timingSection,
    'characteristics': characteristics,
  };
}
