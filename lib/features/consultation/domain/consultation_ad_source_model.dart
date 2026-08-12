import '../../pass/domain/open_pass_models.dart';

/// [AI 상담 채팅 실연동] `GET /api/public/consultation/ad-sources` 응답 —
/// 상담 세션 시작 전 광고게이트에 노출할 리워드 광고소스 1건.
///
/// 사주/타로 프리패스(`OpenPassAdSourceBindingModel`)와 필드 구성은 거의
/// 동일하지만 `bindingId`/`platform`/`isPrimary`(상품-광고소스 N:M 바인딩
/// 전용 필드) 개념이 전혀 없다 — 상담은 PassPolicy와 완전히 독립된 예산이므로
/// 서버도 `OpenPassProductAdSource` 테이블을 거치지 않고 `OpenPassAdSource`를
/// 직접 조회해 내려준다. 그래도 [RewardedAdSimulator.show]가 요구하는 mock
/// 판정 필드(isMock/simulatedDurationSeconds/failMode)는 동일하므로,
/// [toBindingModel]로 기존 광고 시청 다이얼로그 UI를 그대로 재사용한다
/// (§15: 광고 시청 UX를 두 곳에 따로 구현하지 않는다).
class ConsultationAdSourceModel {
  final int adSourceId;
  final String sourceName;
  final String sourceType;
  final String? networkName;
  final String? adUnitId;
  final String? placementId;
  final String? rewardType;
  final int? rewardValue;
  final int cooldownSeconds;
  final int? dailyLimit;
  final bool testModeEnabled;
  final int priority;
  final bool? eligible;
  final String? eligibilityReason;
  final bool isMock;
  final int? simulatedDurationSeconds;
  final String? failMode;

  const ConsultationAdSourceModel({
    required this.adSourceId,
    required this.sourceName,
    required this.sourceType,
    this.networkName,
    this.adUnitId,
    this.placementId,
    this.rewardType,
    this.rewardValue,
    required this.cooldownSeconds,
    this.dailyLimit,
    required this.testModeEnabled,
    required this.priority,
    this.eligible,
    this.eligibilityReason,
    this.isMock = false,
    this.simulatedDurationSeconds,
    this.failMode,
  });

  /// 서버가 eligible을 계산하지 않은 경우(userId 미전달)에는 null이며,
  /// 이때는 "우선 시도 가능"으로 간주한다(최종 판정은 ad-reward-complete가 수행).
  bool get isUsable => eligible != false;

  factory ConsultationAdSourceModel.fromJson(Map<String, dynamic> json) {
    return ConsultationAdSourceModel(
      adSourceId: json['adSourceId'] as int,
      sourceName: json['sourceName'] as String? ?? '',
      sourceType: json['sourceType'] as String? ?? '',
      networkName: json['networkName'] as String?,
      adUnitId: json['adUnitId'] as String?,
      placementId: json['placementId'] as String?,
      rewardType: json['rewardType'] as String?,
      rewardValue: json['rewardValue'] as int?,
      cooldownSeconds: json['cooldownSeconds'] as int? ?? 0,
      dailyLimit: json['dailyLimit'] as int?,
      testModeEnabled: json['testModeEnabled'] as bool? ?? false,
      priority: json['priority'] as int? ?? 0,
      eligible: json['eligible'] as bool?,
      eligibilityReason: json['eligibilityReason'] as String?,
      isMock: json['isMock'] as bool? ?? false,
      simulatedDurationSeconds: json['simulatedDurationSeconds'] as int?,
      failMode: json['failMode'] as String?,
    );
  }

  /// [광고 시청 UI 재사용] `RewardedAdSimulator.show()`는
  /// `OpenPassAdSourceBindingModel`을 요구하므로, PassPolicy 바인딩 전용
  /// 필드(bindingId/platform/isPrimary)는 상담에 의미 없는 placeholder 값으로
  /// 채워 변환한다. 다이얼로그가 실제로 읽는 필드(sourceName/sourceType/
  /// isMock/simulatedDurationSeconds/failMode 등)는 원본 값 그대로 전달된다.
  OpenPassAdSourceBindingModel toBindingModel() {
    return OpenPassAdSourceBindingModel(
      bindingId: adSourceId,
      adSourceId: adSourceId,
      sourceName: sourceName,
      sourceType: sourceType,
      networkName: networkName,
      adUnitId: adUnitId,
      placementId: placementId,
      rewardType: rewardType,
      rewardValue: rewardValue,
      cooldownSeconds: cooldownSeconds,
      dailyLimit: dailyLimit,
      testModeEnabled: testModeEnabled,
      priority: priority,
      isPrimary: priority == 0,
      platform: 'all',
      eligible: eligible,
      eligibilityReason: eligibilityReason,
      isMock: isMock,
      simulatedDurationSeconds: simulatedDurationSeconds,
      failMode: failMode,
    );
  }
}
