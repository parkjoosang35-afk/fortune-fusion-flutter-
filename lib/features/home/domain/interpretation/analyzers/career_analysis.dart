/// [정통사주 69종 개인화 해석 엔진 — 4단계] A04 평생 직업·명예운 분석 결과
/// 모델.
///
/// 사용자 최종 지시 §6 스키마 원칙(categoryId, coreEvidence, 카테고리 고유
/// 필드, favorableConditions, cautionConditions, timing, confidence)을
/// A01(LifeOverallAnalysis)/A03(WealthAnalysis)와 동일한 형태로 구현한다.
library;

import '../analysis_evidence.dart';
import '../category_analysis.dart';

class CareerAnalysis extends CategoryAnalysis {
  const CareerAnalysis({
    required super.categoryId,
    required super.categoryName,
    required super.coreEvidence,
    required super.favorableConditions,
    required super.cautionConditions,
    super.timing,
    super.confidence = AnalysisConfidence.medium,
    super.supportingEvidence = const [],
    super.interpretationContext = const {},
    required this.careerPattern,
    required this.careerStrength,
    required this.workStyle,
    required this.suitableFields,
    required this.careerRiskPattern,
    required this.careerPeakDaewoonLabel,
  });

  /// 관살/인성/식상 분포를 종합한 직업 "구조" 판정(예: '관인상생(官印相生)',
  /// '식상생재(食傷生財)형', '무관무인(無官無印)형', '살인상생(殺印相生)형',
  /// '혼합형'). 레거시 `interpretCareer()`의 4분류를 그대로 두지 않고,
  /// 재성/식상까지 함께 조합해 세분화한다(§4 "문장이 아니라 분석을
  /// 개인화").
  final String careerPattern;

  /// 신강신약 × 관살 개수를 조합한 "일을 감당하는 방식"의 크기 판정(예:
  /// '신강+관살多 → 관살을 다스릴 힘 충분', '신약+관살多 → 부담 큰 조직생활은
  /// 버거움' 등). A03의 wealthStrength와 동일한 설계 원칙.
  final String careerStrength;

  /// 조직형/독립형/전문가형/창작형 등 일하는 방식 서술(관살·인성·식상·비겁
  /// 조합에서 도출, 정재/편재 조합에서 도출하는 A03.incomePattern과
  /// 대응되는 위치).
  final String workStyle;

  /// 일간 오행 기준 전통 고정표(`day_master_rules.json`의 career_fit)에서
  /// 조회한 어울리는 분야 목록 — 새로 만든 판정이 아니라 이미 앱에 존재하는
  /// 전통 고정 데이터의 재사용.
  final List<String> suitableFields;

  /// 상관견관/편관 과다/무관무인 등 직업상 리스크 서술.
  final String careerRiskPattern;

  /// 직업·명예운이 가장 두드러지는 대운 라벨(관살 또는 용신 오행이 들어오는
  /// 대운 — PHASE4 실계산 대운 목록에서 실제로 찾은 것만, 없으면 빈 문자열).
  final String careerPeakDaewoonLabel;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'careerPattern': careerPattern,
    'careerStrength': careerStrength,
    'workStyle': workStyle,
    'suitableFields': suitableFields,
    'careerRiskPattern': careerRiskPattern,
    'careerPeakDaewoonLabel': careerPeakDaewoonLabel,
  };
}
