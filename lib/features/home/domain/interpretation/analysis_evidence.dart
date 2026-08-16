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

/// 판단 근거의 해석상 역할(사용자 지시 §8) — 이 증거가 최종 판단에서
/// "핵심 근거"인지 "보조 근거"인지 등을 명시한다. 값 하나를 여러 카테고리가
/// 자유롭게 재사용할 수 있도록 문자열 상수로 둔다(enum 강제 금지 — 향후
/// 카테고리별로 새 역할이 계속 추가될 수 있음, 예: 'career', 'health').
class InterpretationRole {
  const InterpretationRole._();
  static const String primary = 'primary';
  static const String secondary = 'secondary';
  static const String supporting = 'supporting';
  static const String caution = 'caution';
  static const String timing = 'timing';
  static const String strength = 'strength';
  static const String weakness = 'weakness';
  static const String relationship = 'relationship';
}

/// 판단 근거 1건 — "이 계산값 때문에 이 규칙이 적용되어 이 판단이
/// 나왔다"를 추적 가능하게 기록한다.
///
/// [2026-08 확장 — 사용자 지시 §7/§8] 기존 4개 필수 필드(sourceField/
/// sourceValue/rule/judgment)는 절대 삭제하지 않고 그대로 유지한다(이미
/// A01/A03이 전량 이 4개 필드로 동작 중이므로 삭제 시 기존 기능이 깨짐).
/// 사용자가 새로 요구한 `evidenceType/source/value/weight/
/// interpretationRole` 개념은 optional 필드로 "추가"만 한다:
///   - `key`   ≈ evidenceType/sourceField (없으면 sourceField로 대체)
///   - `value` ≈ value/sourceValue (없으면 sourceValue로 대체)
///   - `weight`: 이 근거가 최종 판단에서 차지하는 상대적 중요도(0.0~1.0,
///     명시하지 않으면 null — "가중치 모름"과 "가중치 0"을 구분하기 위해
///     기본값을 주지 않는다).
///   - `interpretationRole`: [InterpretationRole] 상수 중 하나 권장.
///   - `source`: 이 근거의 출처를 더 세밀하게 표기하고 싶을 때(예:
///     'PHASE3.strength_engine') — 비워도 sourceField로 충분히 추적 가능.
///   - `reason`: rule/judgment와 별개로 "왜 이 근거를 선택했는지"에 대한
///     부연 설명이 필요할 때만 사용(대부분의 경우 rule 필드로 충분함).
class AnalysisEvidence {
  const AnalysisEvidence({
    required this.sourceField,
    required this.sourceValue,
    required this.rule,
    required this.judgment,
    this.weight,
    this.interpretationRole,
    this.source,
    this.reason,
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

  /// [optional, 신규] 이 근거의 상대적 중요도(0.0~1.0). 값을 매기지 않은
  /// 근거는 null로 두고, NarrativeGenerator가 문장 우선순위를 정할 때
  /// interpretationRole(primary 등)을 1차 기준으로, weight는 보조 기준으로
  /// 참고한다.
  final double? weight;

  /// [optional, 신규] 이 근거가 최종 해석에서 맡는 역할
  /// ([InterpretationRole] 상수 권장: primary/secondary/supporting/caution/
  /// timing/strength/weakness/relationship 등). null이면 "역할 미분류".
  final String? interpretationRole;

  /// [optional, 신규] 근거의 세부 출처(예: 'PHASE2.hiddenStems',
  /// 'PHASE4.daewoon'). sourceField보다 더 시스템적인 표기가 필요할 때만
  /// 채운다 — 비워도 무방.
  final String? source;

  /// [optional, 신규] rule/judgment로 설명이 부족할 때 덧붙이는 부연 사유.
  final String? reason;

  /// evidenceType/key의 대체 접근자 — 사용자 요구 명칭(evidenceType)과
  /// 기존 구현(sourceField)을 동시에 만족시키기 위한 편의 getter.
  String get evidenceType => sourceField;

  /// value의 대체 접근자(사용자 요구 명칭 value ↔ 기존 sourceValue).
  String get value => sourceValue;

  @override
  String toString() =>
      '[$sourceField=$sourceValue] --($rule)--> $judgment'
      '${interpretationRole != null ? ' {role=$interpretationRole}' : ''}'
      '${weight != null ? ' {weight=$weight}' : ''}';

  Map<String, dynamic> toJson() => {
    'sourceField': sourceField,
    'sourceValue': sourceValue,
    'rule': rule,
    'judgment': judgment,
    if (weight != null) 'weight': weight,
    if (interpretationRole != null) 'interpretationRole': interpretationRole,
    if (source != null) 'source': source,
    if (reason != null) 'reason': reason,
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
