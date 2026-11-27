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

  /// [비회원 둘러보기 결함수정 — 복주머니(pouch_box) 화면 비회원 오표시]
  /// 비로그인 상태임이 확인된 경우 전용으로 사용하는 안전한 기본값.
  /// [initial]은 "서버 응답을 아직 못 받았을 뿐인 정상 회원"을 가정한
  /// 낙관적 기본값(watchable:true)이라 비회원에게 그대로 노출되면 "5/5회
  /// 열람 가능"처럼 보이는 버그가 발생한다(실사용 재현으로 확정). 비회원은
  /// 애초에 지급 대상이 아니므로 watchable=false/dailyLeft=0으로 명확히
  /// 구분한다 — 정상 회원의 [initial] 사용처(로딩 중 낙관적 렌더링)는 그대로
  /// 둔다.
  static const PouchBoxState notLoggedIn = PouchBoxState(
    dailyLimit: 5,
    todayOpenedCount: 0,
    dailyLeft: 0,
    watchable: false,
    reason: 'LOGIN_REQUIRED',
    reasonLabel: '로그인 후 이용할 수 있어요',
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
