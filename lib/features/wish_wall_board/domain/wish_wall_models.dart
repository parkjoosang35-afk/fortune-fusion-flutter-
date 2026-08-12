/// 소원벽게시판(Wish Wall Board) 데이터 모델.
///
/// [handoff.zip] "소원벽·복주머니통합 기획안" §6 데이터모델을 Dart로 이식.
/// "소원 하나 = 유리병 하나" 컨셉의 병(Bottle) 시각화에 필요한 카테고리별
/// 유리색/코르크색/불빛색과 정성지수(글로우/잎사귀/매듭) 계산 로직을 포함한다.
library;

import 'package:flutter/material.dart';

/// 9개 소원 카테고리. 각 카테고리는 병의 유리색(glass)/코르크색(cork)/
/// 내부 불빛색(light)을 가진다 (기획안 §5 카테고리별 병색 매핑).
enum WishCategory {
  exam,
  job,
  money,
  love,
  family,
  health,
  travel,
  growth,
  etc,
}

extension WishCategoryX on WishCategory {
  String get label {
    switch (this) {
      case WishCategory.exam:
        return '시험·학업';
      case WishCategory.job:
        return '취업·이직';
      case WishCategory.money:
        return '사업·금전';
      case WishCategory.love:
        return '연애·인연';
      case WishCategory.family:
        return '가족';
      case WishCategory.health:
        return '건강';
      case WishCategory.travel:
        return '여행·계획';
      case WishCategory.growth:
        return '자기계발';
      case WishCategory.etc:
        return '기타';
    }
  }

  /// 유리병 몸통 색(반투명 틴트).
  Color get glassColor {
    switch (this) {
      case WishCategory.exam:
        return const Color(0xFFFEF3C7);
      case WishCategory.job:
        return const Color(0xFFFEE2E2);
      case WishCategory.money:
        return const Color(0xFFFEF9C3);
      case WishCategory.love:
        return const Color(0xFFFCE7F3);
      case WishCategory.family:
        return const Color(0xFFF3E8FF);
      case WishCategory.health:
        return const Color(0xFFD1FAE5);
      case WishCategory.travel:
        return const Color(0xFFDBEAFE);
      case WishCategory.growth:
        return const Color(0xFFE0F2FE);
      case WishCategory.etc:
        return const Color(0xFFF5F5F5);
    }
  }

  /// 코르크(뚜껑) 색 — 라벨/테두리 색으로도 재사용.
  Color get corkColor {
    switch (this) {
      case WishCategory.exam:
        return const Color(0xFFA16207);
      case WishCategory.job:
        return const Color(0xFF991B1B);
      case WishCategory.money:
        return const Color(0xFF854D0E);
      case WishCategory.love:
        return const Color(0xFF9D174D);
      case WishCategory.family:
        return const Color(0xFF6B21A8);
      case WishCategory.health:
        return const Color(0xFF065F46);
      case WishCategory.travel:
        return const Color(0xFF1E40AF);
      case WishCategory.growth:
        return const Color(0xFF075985);
      case WishCategory.etc:
        return const Color(0xFF525252);
    }
  }

  /// 병 안쪽 불빛(글로우) 색.
  Color get lightColor {
    switch (this) {
      case WishCategory.exam:
        return const Color(0xFFF59E0B);
      case WishCategory.job:
        return const Color(0xFFEF4444);
      case WishCategory.money:
        return const Color(0xFFEAB308);
      case WishCategory.love:
        return const Color(0xFFEC4899);
      case WishCategory.family:
        return const Color(0xFFA855F7);
      case WishCategory.health:
        return const Color(0xFF10B981);
      case WishCategory.travel:
        return const Color(0xFF3B82F6);
      case WishCategory.growth:
        return const Color(0xFF0EA5E9);
      case WishCategory.etc:
        return const Color(0xFF737373);
    }
  }

  static const List<WishCategory> all = WishCategory.values;
}

/// 소원 공개 범위 (compose Step4).
enum WishVisibility { anonymous, public, private }

extension WishVisibilityX on WishVisibility {
  String get label {
    switch (this) {
      case WishVisibility.anonymous:
        return '익명으로 공개';
      case WishVisibility.public:
        return '이름과 함께';
      case WishVisibility.private:
        return '나만 보기';
    }
  }

  String get shortLabel {
    switch (this) {
      case WishVisibility.anonymous:
        return '익명';
      case WishVisibility.public:
        return '이름과 함께';
      case WishVisibility.private:
        return '나만 보기';
    }
  }
}

/// 모더레이션 상태 흐름 (기획안 §9): normal → pendingReview → approved/removed,
/// limited(사용자 제한), hiddenBySystem(자동필터 즉시 숨김).
enum ModerationStatus { normal, pendingReview, approved, removed, limited, hiddenBySystem }

/// 소원 게시물(=유리병) 하나.
class WishPost {
  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatarEmoji;
  final bool isAnonymous;
  final WishCategory categoryId;
  final String text;
  /// 병 안의 밝기(0.0~1.0) — compose Step2에서 사용자가 정한 값.
  final double glassLevel;
  final WishVisibility visibility;
  final ModerationStatus moderationStatus;
  final bool isGratitude;
  final DateTime createdAt;

  int supportCount;
  int prayerCount;
  int pouchCount;
  bool hasSupportedByMe;
  bool hasPrayedToday;
  bool hasNewReaction;

  WishPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarEmoji,
    required this.isAnonymous,
    required this.categoryId,
    required this.text,
    this.glassLevel = 0.7,
    this.visibility = WishVisibility.anonymous,
    this.moderationStatus = ModerationStatus.normal,
    this.isGratitude = false,
    required this.createdAt,
    this.supportCount = 0,
    this.prayerCount = 0,
    this.pouchCount = 0,
    this.hasSupportedByMe = false,
    this.hasPrayedToday = false,
    this.hasNewReaction = false,
  });

  bool get isPrivate => visibility == WishVisibility.private;

  String get displayName => isAnonymous ? '익명' : authorName;

  /// 병 안쪽 글로우 강도 — 응원(support) 수에 비례, 최대 1.0.
  double get glow => (supportCount / 400).clamp(0.0, 1.0);

  /// 병 옆 잎사귀(기도) 개수 — 최대 5개.
  int get leafCount => (prayerCount / 100).floor().clamp(0, 5);

  /// 병 목의 매듭(복주머니) 단계 — 0~3.
  int get ribbonCount {
    if (pouchCount > 50) return 3;
    if (pouchCount > 10) return 2;
    if (pouchCount > 0) return 1;
    return 0;
  }

  /// 정성지수(총합 스코어) — 화면에는 노출하지 않지만 정렬(인기)에 사용.
  int get sincerityScore => supportCount + prayerCount * 2 + pouchCount * 3;
}

/// 응원 댓글.
class WishComment {
  final String id;
  final String wishId;
  final String authorName;
  final String text;
  final DateTime createdAt;
  final bool isMine;
  final ModerationStatus moderationStatus;

  WishComment({
    required this.id,
    required this.wishId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.isMine = false,
    this.moderationStatus = ModerationStatus.normal,
  });
}

/// 복주머니 적립 사유 (기획안 §4.1 4채널).
enum BlessingBagEarnReason { dailyLogin, wishCreatedBonus, dailyPrayer, eventParticipation }

extension BlessingBagEarnReasonX on BlessingBagEarnReason {
  String get code {
    switch (this) {
      case BlessingBagEarnReason.dailyLogin:
        return 'daily_login';
      case BlessingBagEarnReason.wishCreatedBonus:
        return 'wish_created_bonus';
      case BlessingBagEarnReason.dailyPrayer:
        return 'daily_prayer';
      case BlessingBagEarnReason.eventParticipation:
        return 'event_participation';
    }
  }

  int get defaultAmount {
    switch (this) {
      case BlessingBagEarnReason.dailyLogin:
        return 1;
      case BlessingBagEarnReason.wishCreatedBonus:
        return 5;
      case BlessingBagEarnReason.dailyPrayer:
        return 1;
      case BlessingBagEarnReason.eventParticipation:
        return 3;
    }
  }
}

/// 복주머니 사용 사유 (기획안 §4.2 3채널).
enum BlessingBagSpendReason { sendPouch, boostBottle, promoteWish }

extension BlessingBagSpendReasonX on BlessingBagSpendReason {
  String get code {
    switch (this) {
      case BlessingBagSpendReason.sendPouch:
        return 'send_pouch';
      case BlessingBagSpendReason.boostBottle:
        return 'boost_bottle';
      case BlessingBagSpendReason.promoteWish:
        return 'promote_wish';
    }
  }

  String get label {
    switch (this) {
      case BlessingBagSpendReason.sendPouch:
        return '복주머니 보내기';
      case BlessingBagSpendReason.boostBottle:
        return '병 밝히기';
      case BlessingBagSpendReason.promoteWish:
        return '소원 홍보';
    }
  }
}

/// 신고 사유 (기획안 §9, 9종 중 자주 쓰이는 대표 세트).
const List<String> wishReportReasons = [
  '개인정보 노출',
  '금전 요청/사기 의심',
  '홍보성/스팸',
  '욕설·혐오 표현',
  '선정적 내용',
  '허위/거짓 정보',
  '괴롭힘/따돌림',
  '반복 게시(도배)',
  '기타',
];
