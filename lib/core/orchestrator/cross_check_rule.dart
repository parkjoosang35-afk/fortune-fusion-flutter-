import 'unified_fortune_profile.dart';

/// [엔진 통합 지시문 STEP 3] 교차검증 규칙 1개가 "양쪽 문(door)에서 각각
/// 점수를 뽑아냈을 때의 결과" — 점수 자체와 함께, 그 점수를 왜 그렇게
/// 매겼는지 설명하는 근거 텍스트를 함께 들고 있다(검증 결과에 근거
/// 없이 숫자만 나오지 않도록 하기 위함 — §6 "evidence" 요구사항).
///
/// [score] 범위는 항상 -1.0 ~ +1.0으로 정규화한다(축의 "음의 극단"과
/// "양의 극단" 사이에서 이 결과가 어디에 위치하는지). 축이 무엇을
/// 의미하는지는 [CrossCheckRule.axis]가 설명한다.
class ScoreExtraction {
  const ScoreExtraction({
    required this.score,
    required this.evidenceText,
    required this.sourceDoor,
  });

  /// -1.0 ~ +1.0으로 정규화된 점수.
  final double score;

  /// 이 점수를 산출한 근거(원문 일부 또는 집계 설명) — 화면/리포트에
  /// 그대로 노출 가능한 사람이 읽을 수 있는 한국어 문장.
  final String evidenceText;

  /// 이 점수가 어느 문(door)에서 나왔는지(예: '사주', '관상').
  final String sourceDoor;
}

/// 교차검증 규칙 1쌍의 정의. 구체 규칙(Saju↔Face 등)은 이 클래스를
/// 상속해 [extractA]/[extractB]만 구현한다 — **점수 추출 로직만** 규칙마다
/// 다르고, "두 점수를 비교해 match/complement/conflict로 판정하는 로직"은
/// [CrossCheckEngine]이 모든 규칙에 대해 동일하게(결정론적으로) 수행한다.
/// 이것이 "LLM이 판정하지 않고 결정론적 규칙 코드만 판정한다"는 지시문
/// 원칙의 구조적 보장이다 — 규칙 작성자가 실수로 판정 로직을 규칙 안에
/// 섞어 넣을 수 없는 구조.
///
/// [extractA]/[extractB]는 필요한 원본 데이터가 [UnifiedFortuneProfile]에
/// 없으면(해당 문을 아직 이용하지 않음) null을 반환해야 한다 — 이 경우
/// [CrossCheckEngine]은 이 규칙을 "미판정(unjudged)"으로 처리하고, 절대
/// 임의의 기본값(0.0 등)으로 채우지 않는다("Mock으로 실패를 가리지
/// 않는다" 원칙).
abstract class CrossCheckRule {
  const CrossCheckRule();

  /// 규칙 고유 ID(검증 JSON의 `ruleId`, 로그/테스트에서 특정).
  String get ruleId;

  /// 비교 대상 두 문의 표기(예: '사주↔관상').
  String get pair;

  /// 이 규칙이 비교하는 의미축(예: '추진력', '기질', '관계', '시기').
  String get axis;

  String get doorA;
  String get doorB;

  ScoreExtraction? extractA(UnifiedFortuneProfile profile);
  ScoreExtraction? extractB(UnifiedFortuneProfile profile);
}

/// 텍스트(요약/부위별 특징 등)에서 양/음 키워드 등장 횟수를 세어
/// -1.0~+1.0로 정규화하는 공용 헬퍼. 모든 텍스트 기반 점수 추출기가
/// 이 함수 하나를 공유해 "같은 방식으로 세는" 일관성을 보장한다
/// (규칙마다 다른 집계 방식을 쓰면 비교 가능성이 깨짐).
///
/// [TODO — 도메인 튜닝] `maxHits`(이 횟수 이상이면 ±1.0으로 포화)는
/// 현재 경험적으로 3을 사용한다. 실사용 데이터(실제 LLM이 생성하는
/// summary/features 분포)를 더 모은 뒤 도메인 전문가가 조정해야 한다.
double keywordBalanceScore({
  required String text,
  required List<String> positiveKeywords,
  required List<String> negativeKeywords,
  int maxHits = 3,
}) {
  final positiveHits = positiveKeywords
      .where((k) => text.contains(k))
      .length;
  final negativeHits = negativeKeywords
      .where((k) => text.contains(k))
      .length;
  final raw = (positiveHits - negativeHits) / maxHits;
  return raw.clamp(-1.0, 1.0);
}
