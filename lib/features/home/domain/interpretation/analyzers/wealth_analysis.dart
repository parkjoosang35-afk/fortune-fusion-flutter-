/// [정통사주 69종 개인화 해석 엔진 — 3단계] A03 평생재물운 분석 결과 모델.
///
/// 사용자 최종 지시 §6 스키마 예시(categoryId, coreEvidence, wealthPattern,
/// wealthStrength, incomePattern, riskPattern, favorableConditions,
/// cautionConditions, timing, confidence)를 그대로 필드로 구현한다.
library;

import '../analysis_evidence.dart';
import '../category_analysis.dart';

class WealthAnalysis extends CategoryAnalysis {
  const WealthAnalysis({
    required super.categoryId,
    required super.categoryName,
    required super.coreEvidence,
    required super.favorableConditions,
    required super.cautionConditions,
    super.timing,
    super.confidence = AnalysisConfidence.medium,
    super.supportingEvidence = const [],
    super.interpretationContext = const {},
    required this.wealthPattern,
    required this.wealthStrength,
    required this.incomePattern,
    required this.riskPattern,
    required this.assetManagementStyle,
    required this.wealthPeakDaewoonLabel,
  });

  /// 재성(정재+편재) 분포와 신강신약을 종합한 재물 "구조" 판정
  /// (예: '재관쌍미(財官雙美)', '재성 편중', '인다무재(印多無財)', '균형형').
  final String wealthPattern;

  /// 재물을 감당할 그릇의 크기 판정('신강용재' | '재다신약' | '재약신약' 등
  /// — 신강신약 × 재성 개수 조합으로 결정, 5개 고정테이블 룩업이 아니라
  /// 실제 이 사람의 재성 개수/신강신약 값으로 매번 재계산됨).
  final String wealthStrength;

  /// 정재(고정 수입) vs 편재(유동 수입) 중 어느 쪽이 우세한지 서술.
  final String incomePattern;

  /// 겁재/기신 관련 재물 리스크 서술(겁재 개수, 기신이 재성인 경우 등).
  final String riskPattern;

  /// 자산 운용 스타일 제안(§ 기존 assetStyle 대체 — 고정 5종 테이블이
  /// 아니라 wealthStrength+wealthPattern 조합으로 매번 생성).
  final String assetManagementStyle;

  /// 재물이 가장 활발해지는 대운 라벨(용신/재성 오행이 들어오는 대운 —
  /// PHASE4 실계산 대운 목록에서 실제로 찾은 것만, 없으면 빈 문자열).
  final String wealthPeakDaewoonLabel;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'wealthPattern': wealthPattern,
    'wealthStrength': wealthStrength,
    'incomePattern': incomePattern,
    'riskPattern': riskPattern,
    'assetManagementStyle': assetManagementStyle,
    'wealthPeakDaewoonLabel': wealthPeakDaewoonLabel,
  };
}
