/// [행운상자 - 복주머니 탭 신규 기능] admin_web 공개 API 응답 모델.
library;

/// `GET /api/pouch-box/state` 응답 — 오늘 현황(하루 5회 한도).
class PouchBoxState {
  final int dailyLimit;
  final int todayOpenedCount;
  final int dailyLeft;
  final bool watchable;
  final String? reason;
  final String? reasonLabel;

  const PouchBoxState({
    required this.dailyLimit,
    required this.todayOpenedCount,
    required this.dailyLeft,
    required this.watchable,
    this.reason,
    this.reasonLabel,
  });

  factory PouchBoxState.fromJson(Map<String, dynamic> json) {
    return PouchBoxState(
      dailyLimit: json['dailyLimit'] as int? ?? 5,
      todayOpenedCount: json['todayOpenedCount'] as int? ?? 0,
      dailyLeft: json['dailyLeft'] as int? ?? 0,
      watchable: json['watchable'] as bool? ?? false,
      reason: json['reason'] as String?,
      reasonLabel: json['reasonLabel'] as String?,
    );
  }

  static const PouchBoxState initial = PouchBoxState(
    dailyLimit: 5,
    todayOpenedCount: 0,
    dailyLeft: 5,
    watchable: true,
  );
}

/// `POST /api/pouch-box/start` 응답 — 시청 세션 정보.
class PouchBoxSession {
  final String sessionId;
  final int openLogId;
  final int dailyLeft;

  const PouchBoxSession({
    required this.sessionId,
    required this.openLogId,
    required this.dailyLeft,
  });

  factory PouchBoxSession.fromJson(Map<String, dynamic> json) {
    return PouchBoxSession(
      sessionId: json['sessionId'] as String,
      openLogId: json['openLogId'] as int,
      dailyLeft: json['dailyLeft'] as int? ?? 0,
    );
  }
}

/// `POST /api/pouch-box/complete` 응답 — 실제 지급 결과(서버가 최종 결정).
class PouchBoxRewardResult {
  final int rewardAmount;
  final String? rewardTier; // common/uncommon/rare/jackpot
  final int? balance;
  final int dailyLeft;
  final bool idempotent;

  const PouchBoxRewardResult({
    required this.rewardAmount,
    this.rewardTier,
    this.balance,
    required this.dailyLeft,
    this.idempotent = false,
  });

  bool get isJackpot => rewardTier == 'jackpot';

  factory PouchBoxRewardResult.fromJson(
    Map<String, dynamic> json, {
    bool idempotent = false,
  }) {
    final data = json['data'] as Map<String, dynamic>;
    return PouchBoxRewardResult(
      rewardAmount: data['rewardAmount'] as int? ?? 0,
      rewardTier: data['rewardTier'] as String?,
      balance: data['balance'] as int?,
      dailyLeft: data['dailyLeft'] as int? ?? 0,
      idempotent: idempotent,
    );
  }
}
