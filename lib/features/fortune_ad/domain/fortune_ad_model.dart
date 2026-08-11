/// [신통방통 복주머니 광고 적립 시스템] 복주머니 화면에 노출되는 광고 1건.
/// admin_web `GET /api/ads/fortune` 응답(`serializeFortuneAdSummary` +
/// todayWatchedCount/todayRemainingCount/watchable)을 그대로 매핑한다.
class FortuneAdModel {
  final int id;
  final String title;
  final String? description;
  final String adType; // image | video | external | network
  final String? imageUrl;
  final String? videoUrl;
  final String? externalUrl;
  final String? adSourceHtml;
  final int rewardAmount;
  final int watchSeconds;
  final int perUserDailyLimit;
  final int? dailyLimitReward;
  final int todayWatchedCount;
  final int todayRemainingCount;
  final bool watchable;

  const FortuneAdModel({
    required this.id,
    required this.title,
    this.description,
    required this.adType,
    this.imageUrl,
    this.videoUrl,
    this.externalUrl,
    this.adSourceHtml,
    required this.rewardAmount,
    required this.watchSeconds,
    required this.perUserDailyLimit,
    this.dailyLimitReward,
    required this.todayWatchedCount,
    required this.todayRemainingCount,
    required this.watchable,
  });

  factory FortuneAdModel.fromJson(Map<String, dynamic> json) {
    return FortuneAdModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      adType: json['adType'] as String? ?? 'image',
      imageUrl: json['imageUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
      externalUrl: json['externalUrl'] as String?,
      adSourceHtml: json['adSourceHtml'] as String?,
      rewardAmount: json['rewardAmount'] as int? ?? 0,
      watchSeconds: json['watchSeconds'] as int? ?? 15,
      perUserDailyLimit: json['perUserDailyLimit'] as int? ?? 3,
      dailyLimitReward: json['dailyLimitReward'] as int?,
      todayWatchedCount: json['todayWatchedCount'] as int? ?? 0,
      todayRemainingCount: json['todayRemainingCount'] as int? ?? 0,
      watchable: json['watchable'] as bool? ?? false,
    );
  }

  FortuneAdModel copyWith({
    int? todayWatchedCount,
    int? todayRemainingCount,
    bool? watchable,
  }) {
    return FortuneAdModel(
      id: id,
      title: title,
      description: description,
      adType: adType,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      externalUrl: externalUrl,
      adSourceHtml: adSourceHtml,
      rewardAmount: rewardAmount,
      watchSeconds: watchSeconds,
      perUserDailyLimit: perUserDailyLimit,
      dailyLimitReward: dailyLimitReward,
      todayWatchedCount: todayWatchedCount ?? this.todayWatchedCount,
      todayRemainingCount: todayRemainingCount ?? this.todayRemainingCount,
      watchable: watchable ?? this.watchable,
    );
  }
}

/// `POST /api/ads/{adId}/start` 응답 — 시청 세션 정보.
class FortuneAdWatchSession {
  final String sessionId;
  final int watchLogId;
  final int adId;
  final int watchSeconds;
  final int rewardAmount;

  const FortuneAdWatchSession({
    required this.sessionId,
    required this.watchLogId,
    required this.adId,
    required this.watchSeconds,
    required this.rewardAmount,
  });

  factory FortuneAdWatchSession.fromJson(Map<String, dynamic> json) {
    return FortuneAdWatchSession(
      sessionId: json['sessionId'] as String,
      watchLogId: json['watchLogId'] as int,
      adId: json['adId'] as int,
      watchSeconds: json['watchSeconds'] as int? ?? 15,
      rewardAmount: json['rewardAmount'] as int? ?? 0,
    );
  }
}

/// `POST /api/ads/{adId}/complete` 응답 — 실제 지급 결과.
class FortuneAdRewardResult {
  final int rewardAmount;
  final int? balance;
  final bool idempotent;

  const FortuneAdRewardResult({
    required this.rewardAmount,
    this.balance,
    this.idempotent = false,
  });

  factory FortuneAdRewardResult.fromJson(
    Map<String, dynamic> json, {
    bool idempotent = false,
  }) {
    final data = json['data'] as Map<String, dynamic>;
    return FortuneAdRewardResult(
      rewardAmount: data['rewardAmount'] as int? ?? 0,
      balance: data['balance'] as int?,
      idempotent: idempotent,
    );
  }
}
