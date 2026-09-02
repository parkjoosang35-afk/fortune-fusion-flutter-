import 'dart:convert';

import '../../home/domain/saju_engine.dart';
import '../../home/domain/saju_interpreter.dart';

/// [흐름 정합성 — M화면 "나는 어떤 사람인지"] 호스트가 I(입력) 화면에서
/// 제출한 자신의 생년월일로 이미 실제 계산된 [SajuResult]를 그대로
/// 사용해(재계산 없음, [SajuInterpreter.interpretDayMaster] 순수 재사용)
/// M(결과) 화면에 노출할 "나는 이런 사람" 요약을 만든다.
///
/// [절대 원칙] 이 모델은 랜딩 화면의 "예시)" 마케팅 카드(`GmPreviewCard`
/// 등, 고정 텍스트)와 다르다 — 여기 담기는 값은 사용자가 실제로 입력한
/// 생년월일로 계산된 실데이터다.
class GuinjiOwnerSajuSummary {
  const GuinjiOwnerSajuSummary({
    required this.dayMasterKr,
    required this.dayMasterImage,
    required this.strengthLevelKr,
    required this.nature,
    required this.personality,
  });

  /// 일간 한글 표기(예: "갑목").
  final String dayMasterKr;

  /// 일간 이미지 표현(예: "큰 나무").
  final String dayMasterImage;

  /// 신강/중화/신약.
  final String strengthLevelKr;

  /// 일간 본성 한 줄 설명.
  final String nature;

  /// 신강/중화/신약 단계별 성격 해설(가장 핵심 문구).
  final String personality;

  /// [SajuResult] + 룰 DB로부터 실계산 요약을 만든다. 이미 검증된
  /// [SajuInterpreter.interpretDayMaster]를 그대로 재호출할 뿐, 새로운
  /// 명리 판정 로직을 추가하지 않는다.
  factory GuinjiOwnerSajuSummary.fromSajuResult(
    SajuResult saju,
    SajuRules rules,
  ) {
    final interp = SajuInterpreter.interpretDayMaster(saju, rules);
    final strength = saju.dayMasterStrength;
    final levelKr = strength.contains('强')
        ? '신강'
        : strength.contains('中')
        ? '중화'
        : '신약';
    return GuinjiOwnerSajuSummary(
      dayMasterKr: saju.dayMaster.kr,
      dayMasterImage: saju.dayMaster.image,
      strengthLevelKr: levelKr,
      nature: interp.nature,
      personality: interp.personality,
    );
  }

  Map<String, dynamic> toJson() => {
    'dayMasterKr': dayMasterKr,
    'dayMasterImage': dayMasterImage,
    'strengthLevelKr': strengthLevelKr,
    'nature': nature,
    'personality': personality,
  };

  factory GuinjiOwnerSajuSummary.fromJson(Map<String, dynamic> json) {
    return GuinjiOwnerSajuSummary(
      dayMasterKr: json['dayMasterKr'] as String? ?? '',
      dayMasterImage: json['dayMasterImage'] as String? ?? '',
      strengthLevelKr: json['strengthLevelKr'] as String? ?? '',
      nature: json['nature'] as String? ?? '',
      personality: json['personality'] as String? ?? '',
    );
  }

  String encode() => jsonEncode(toJson());

  static GuinjiOwnerSajuSummary? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return GuinjiOwnerSajuSummary.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }
}
