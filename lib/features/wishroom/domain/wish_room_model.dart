/// [소원방(Wish Room) MVP] 소원방 도메인 모델.
///
/// [통합정책서] 소원방은 커뮤니티군 기능이며 주 자산은 복주머니다. 이 모델은
/// 열림패스/복주머니를 전혀 참조하지 않는다(§8 금지 원칙 — 운세군 자산을
/// 커뮤니티 기능에 끌어오지 않는다).
///
/// [필드 설계 노트] `todayRitualDone`은 저장 시점의 스냅샷일 뿐, 실제 "오늘
/// 치성을 드렸는가" 판정은 항상 [lastRitualAt]과 현재 시각을 비교해 동적으로
/// 계산한다([WishRoomProvider.getTodayRitualStatus] 참고) — 자정을 넘겨 앱을
/// 다시 열었을 때 이 값 하나만 믿고 판정하면 날짜가 바뀌어도 "완료 상태"가
/// 그대로 남는 버그가 생기기 때문이다. 필드 자체는 데이터 구조 명세(§18)를
/// 그대로 따르기 위해 유지한다.
class WishRoomModel {
  final String roomId;
  final String userId;
  final String roomStatus;
  final String wishText;
  final bool todayRitualDone;
  final DateTime? lastRitualAt;
  final int streakDays;
  final double wishLightPercent;
  final String altarTheme;
  final String candleType;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WishRoomModel({
    required this.roomId,
    required this.userId,
    required this.roomStatus,
    required this.wishText,
    required this.todayRitualDone,
    required this.lastRitualAt,
    required this.streakDays,
    required this.wishLightPercent,
    required this.altarTheme,
    required this.candleType,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 최초 진입 시 생성되는 기본 소원방 상태.
  factory WishRoomModel.initial({required String userId}) {
    final now = DateTime.now();
    return WishRoomModel(
      roomId: 'wish_room_$userId',
      userId: userId,
      roomStatus: 'active',
      wishText: '',
      todayRitualDone: false,
      lastRitualAt: null,
      streakDays: 0,
      wishLightPercent: 0,
      altarTheme: 'default',
      candleType: 'default',
      createdAt: now,
      updatedAt: now,
    );
  }

  WishRoomModel copyWith({
    String? wishText,
    bool? todayRitualDone,
    DateTime? lastRitualAt,
    int? streakDays,
    double? wishLightPercent,
    String? altarTheme,
    String? candleType,
    DateTime? updatedAt,
  }) {
    return WishRoomModel(
      roomId: roomId,
      userId: userId,
      roomStatus: roomStatus,
      wishText: wishText ?? this.wishText,
      todayRitualDone: todayRitualDone ?? this.todayRitualDone,
      lastRitualAt: lastRitualAt ?? this.lastRitualAt,
      streakDays: streakDays ?? this.streakDays,
      wishLightPercent: wishLightPercent ?? this.wishLightPercent,
      altarTheme: altarTheme ?? this.altarTheme,
      candleType: candleType ?? this.candleType,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'roomId': roomId,
    'userId': userId,
    'roomStatus': roomStatus,
    'wishText': wishText,
    'todayRitualDone': todayRitualDone,
    'lastRitualAt': lastRitualAt?.toIso8601String(),
    'streakDays': streakDays,
    'wishLightPercent': wishLightPercent,
    'altarTheme': altarTheme,
    'candleType': candleType,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory WishRoomModel.fromJson(Map<String, dynamic> json) {
    return WishRoomModel(
      roomId: json['roomId'] as String,
      userId: json['userId'] as String,
      roomStatus: json['roomStatus'] as String? ?? 'active',
      wishText: json['wishText'] as String? ?? '',
      todayRitualDone: json['todayRitualDone'] as bool? ?? false,
      lastRitualAt: json['lastRitualAt'] != null
          ? DateTime.parse(json['lastRitualAt'] as String)
          : null,
      streakDays: json['streakDays'] as int? ?? 0,
      wishLightPercent: (json['wishLightPercent'] as num?)?.toDouble() ?? 0,
      altarTheme: json['altarTheme'] as String? ?? 'default',
      candleType: json['candleType'] as String? ?? 'default',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}

/// 치성 완료 1건의 기록(§18 치성 기록 최소 필드).
class RitualRecordModel {
  final String ritualId;
  final String userId;
  final DateTime ritualDate;
  final int tapCount;
  final int rewardLuckPouch;
  final int rewardExp;
  final double lightIncrease;
  final int streakAfter;
  final DateTime createdAt;

  const RitualRecordModel({
    required this.ritualId,
    required this.userId,
    required this.ritualDate,
    required this.tapCount,
    required this.rewardLuckPouch,
    required this.rewardExp,
    required this.lightIncrease,
    required this.streakAfter,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'ritualId': ritualId,
    'userId': userId,
    'ritualDate': ritualDate.toIso8601String(),
    'tapCount': tapCount,
    'rewardLuckPouch': rewardLuckPouch,
    'rewardExp': rewardExp,
    'lightIncrease': lightIncrease,
    'streakAfter': streakAfter,
    'createdAt': createdAt.toIso8601String(),
  };

  factory RitualRecordModel.fromJson(Map<String, dynamic> json) {
    return RitualRecordModel(
      ritualId: json['ritualId'] as String,
      userId: json['userId'] as String,
      ritualDate: DateTime.parse(json['ritualDate'] as String),
      tapCount: json['tapCount'] as int,
      rewardLuckPouch: json['rewardLuckPouch'] as int,
      rewardExp: json['rewardExp'] as int,
      lightIncrease: (json['lightIncrease'] as num).toDouble(),
      streakAfter: json['streakAfter'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// 치성 완료 시 화면에 보여줄 보상 결과(보상 팝업/토스트 입력값).
class RitualRewardResult {
  final int luckPouch;
  final int exp;
  final double lightIncrease;
  final int streakAfter;
  final double wishLightPercent;

  const RitualRewardResult({
    required this.luckPouch,
    required this.exp,
    required this.lightIncrease,
    required this.streakAfter,
    required this.wishLightPercent,
  });
}

/// [CMS 연결 대비 §19] 치성 보상량 등 향후 관리자 설정값으로 옮겨갈 수 있는
/// 상수. 지금은 코드 상수지만, 이름/구조를 CMS 설정 키와 1:1로 맞춰두어
/// 나중에 "값만 서버에서 받아오는" 형태로 손쉽게 교체할 수 있게 한다.
class WishRoomRewardConfig {
  WishRoomRewardConfig._();

  /// 치성 완료 기본 보상 — 복주머니.
  static const int baseRitualLuckPouch = 15;

  /// 치성 완료 기본 보상 — 치성 경험치(표시용 숫자, 별도 레벨 시스템 없음).
  static const int baseRitualExp = 30;

  /// 치성 완료 기본 보상 — 소원의 빛 상승률(%p).
  static const double baseLightIncrease = 10;

  /// 연속 치성 3일 이상(주간 마일스톤 제외) 보너스 복주머니.
  static const int streakBonusLuckPouch = 5;

  /// 연속 치성 7일 단위 마일스톤 보너스 복주머니.
  static const int weeklyBonusLuckPouch = 10;

  /// 연속 치성 7일 단위 마일스톤 보너스 소원의 빛 상승률(%p).
  static const double weeklyBonusLight = 5;

  /// 오늘의 치성 진행 게이지(터치)에 필요한 터치 횟수 — 정책 §9 "5~7회 권장".
  static const int requiredTapCount = 6;
}
