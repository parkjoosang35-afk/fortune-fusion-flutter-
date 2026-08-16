/// [정통사주 69종 개인화 해석 엔진 — 1단계] 판단 근거(Evidence) 모델.
///
/// 사용자 최종 지시 §7 "모든 결과에는 판단 근거가 존재해야 한다"에
/// 대응한다. 모든 [CategoryAnalyzer]는 최종 문장을 만들기 전에, 반드시
/// "어떤 만세력 데이터 → 어떤 규칙 → 어떤 판단"의 사슬을 [AnalysisEvidence]
/// 목록으로 먼저 기록해야 한다.
///
/// [절대 원칙] 이 파일 자체는 계산을 하지 않는다 — 오직 이미 계산된 값
/// (PHASE1~4/SajuProfile)과 그 값에 적용한 규칙 이름, 그리고 그로부터
/// 나온 판단을 "기록"하는 데이터 구조만 정의한다.
library;

/// 판단 근거 1건 — "이 계산값 때문에 이 규칙이 적용되어 이 판단이
/// 나왔다"를 추적 가능하게 기록한다.
class AnalysisEvidence {
  const AnalysisEvidence({
    required this.sourceField,
    required this.sourceValue,
    required this.rule,
    required this.judgment,
  });

  /// 이 근거가 어떤 SajuProfile 필드에서 왔는지(예: 'yongsin.yongsin',
  /// 'strength.verdict', 'tenGods.month_gan', 'relationships[삼합]').
  final String sourceField;

  /// 그 필드의 실제 값(예: '재성', '신강', '정재', '申子辰').
  final String sourceValue;

  /// 적용한 분석 규칙 이름(예: '재성이 용신과 같은 오행이면 재물 축적력
  /// 강함으로 판정').
  final String rule;

  /// 이 규칙 적용으로 도출된 판단(예: '재물 축적형').
  final String judgment;

  @override
  String toString() =>
      '[$sourceField=$sourceValue] --($rule)--> $judgment';

  Map<String, dynamic> toJson() => {
    'sourceField': sourceField,
    'sourceValue': sourceValue,
    'rule': rule,
    'judgment': judgment,
  };
}

/// 신뢰도 등급 — 근거 데이터가 충분한지(예: 원국에 재성이 아예 없으면
/// 재물 분석의 신뢰도는 낮아짐).
enum AnalysisConfidence { high, medium, low }

extension AnalysisConfidenceLabel on AnalysisConfidence {
  String get label => switch (this) {
    AnalysisConfidence.high => 'high',
    AnalysisConfidence.medium => 'medium',
    AnalysisConfidence.low => 'low',
  };
}
