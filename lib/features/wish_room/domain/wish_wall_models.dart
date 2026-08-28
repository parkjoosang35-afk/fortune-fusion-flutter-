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
enum ModerationStatus {
  normal,
  pendingReview,
  approved,
  removed,
  limited,
  hiddenBySystem,
}

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

  // [복주머니 확장 Phase02-A 클라이언트 연동] 서버 `toWishDto()`가 내려주는
  // 봉인→밝히기→이루어짐 상태 머신 필드. MockWishWallRepository(서버 API가
  // 없는 로컬 목데이터)는 이 필드들을 세팅하지 않을 수 있으므로 전부
  // nullable(또는 sealedAt만 createdAt으로 안전한 기본값 대체)로 둔다 —
  // 기존 8개 생성자 호출부(Mock 시드 데이터 등)를 깨지 않기 위함.
  /// 'sealed'(봉인)/'fulfilled'(이루어짐) 등 서버 상태 문자열. 서버 응답이
  /// 없는 경우(Mock) 'sealed'로 간주한다.
  String wishState;

  /// 소원이 봉인된 시각. 서버 응답이 없는 경우 [createdAt]과 동일하게 취급.
  DateTime? sealedAt;

  /// 소원함이 열릴 수 있는 시각(서버가 sealedAt+100일로 계산해 내려줌).
  /// null이면 아직 알 수 없음(Mock 등).
  DateTime? unlockAt;

  /// 실제로 "이뤄졌어요"로 표시된 시각. null이면 아직 미성취.
  DateTime? fulfilledAt;

  /// 07 개봉 화면을 이미 보여준(서버에 기록된) 시각. null이면 미개봉.
  DateTime? openedBoxAt;

  // [복주머니 확장 Phase03 — 인장/촛불 "실사용" 연결] 작성 시 사용자가
  // 보유한 상점 인장/촛불 중 선택한 [ShopCatalogItem.itemCode] 스냅샷.
  // null이면 미선택(기본 인장/촛불 표시). 서버 `toWishDto()`가 그대로
  // 내려주는 값이며, Mock 데이터는 세팅하지 않아도 되도록 nullable로 둔다.
  String? sealItemCode;
  String? candleItemCode;

  // [복주머니 확장 Phase03 — 부적 "실사용" 연결, DECISION-004 합리적 판단]
  // 작성 시 사용자가 보유한 부적(ShopCatalogItem.itemType=talisman) 중 선택한
  // itemCode 스냅샷. talisman_guardian(지킴)은 "보호 배지" 표시용, null이면
  // 미선택. sealItemCode/candleItemCode와 동일한 nullable 패턴.
  String? talismanItemCode;

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
    this.wishState = 'sealed',
    this.sealedAt,
    this.unlockAt,
    this.fulfilledAt,
    this.openedBoxAt,
    this.sealItemCode,
    this.candleItemCode,
    this.talismanItemCode,
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

  /// 서버 wishState 기준 성취 여부(로컬 [isGratitude] 플래그와는 별개 축이나
  /// Phase02-A부터는 서버가 achievedAt도 함께 채워 항상 일치하도록 보장한다).
  bool get isFulfilled => wishState == 'fulfilled';

  /// unlockAt이 지났고 아직 개봉 화면을 보여준 적 없는(openedBoxAt이 null)
  /// 소원인지 여부 — [unlockAt]이 없으면(Mock 등) 판단 불가하므로 false.
  bool get isPendingBoxOpening {
    final u = unlockAt;
    if (u == null || openedBoxAt != null) return false;
    return !DateTime.now().isBefore(u);
  }
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
///
/// [소원방 리스킨 — 적립/사용 확장] `altarVisit`/`weeklyBoxOpening`/
/// `wishFulfilled` 3개는 새 소원방 "받기" 탭(복주머니 큰 팝업)을 위해
/// 추가된 채널이다. 전부 기존 [BlessingBagPolicyAdapter] → [LuckPouchProvider]
/// → [WalletProvider] 경로만 사용하며 새 화폐를 만들지 않는다.
enum BlessingBagEarnReason {
  dailyLogin,
  wishCreatedBonus,
  dailyPrayer,
  eventParticipation,
  altarVisit,
  weeklyBoxOpening,
  wishFulfilled,
  // [복주머니 확장 Phase02 항목4 — 일일 적립 이벤트 1/3] bokjumeoni-plan
  // §02 EARN "매일의 발자국" 4종 중 서버 정책(daily_candle, +1, 1일1회)이
  // 이미 등록되어 있던 항목. "받기" 탭에 5번째 채널로 노출한다.
  dailyCandle,
  // [복주머니 확장 Phase02 항목4 — 일일 적립 이벤트 2/3] daily_meditation
  // (+2, 1일1회) — 60초 명상 타이머를 실제로 완료해야만 지급 요청을
  // 보낸다(단순 버튼 탭이 아닌 "행위" 완료가 트리거).
  dailyMeditation,
  // [소원방 마무리 - Phase A] wish_comment(+2, 1일 3회 · 같은 소원엔 1회) —
  // bokjumeoni-plan §06 COMMENTS + §02 EARN. sourceId=wishId를 함께 넘겨
  // "같은 소원엔 1회"까지 서버가 함께 판정한다.
  wishComment,
  // [소원방 마무리 - Phase B] daily_feed_visit(+1, 1일 1회) — bokjumeoni-plan
  // §02 EARN "모두의 소원방을 스크롤해서 바닥까지 읽다". 클라이언트는 06
  // Feed 화면에서 "3소원 이상 스크롤"을 확인한 뒤(=itemBuilder가 index 2
  // 이상까지 실제로 빌드) 1회성으로 이 채널을 요청한다. 최종 1일 1회
  // 제한은 서버(scope='daily')가 판정한다.
  dailyFeedVisit,
}

extension BlessingBagEarnReasonX on BlessingBagEarnReason {
  String get code {
    switch (this) {
      case BlessingBagEarnReason.dailyLogin:
        return 'daily_login';
      case BlessingBagEarnReason.wishCreatedBonus:
        // [복주머니 정책표 §3] 서버 point_policies 테이블의 sourceType은
        // 'wish_reward'(금액2/1일1회)로 등록되어 있다 — 반드시 이 값과
        // 일치해야 서버측 일일상한(checkPolicyEligibility)이 실제로 적용된다.
        return 'wish_reward';
      case BlessingBagEarnReason.dailyPrayer:
        return 'daily_prayer';
      case BlessingBagEarnReason.eventParticipation:
        return 'event_participation';
      case BlessingBagEarnReason.altarVisit:
        return 'altar_visit';
      case BlessingBagEarnReason.weeklyBoxOpening:
        return 'weekly_box_opening';
      case BlessingBagEarnReason.wishFulfilled:
        return 'wish_fulfilled';
      case BlessingBagEarnReason.dailyCandle:
        return 'daily_candle';
      case BlessingBagEarnReason.dailyMeditation:
        return 'daily_meditation';
      case BlessingBagEarnReason.wishComment:
        return 'wish_comment';
      case BlessingBagEarnReason.dailyFeedVisit:
        return 'daily_feed_visit';
    }
  }

  String get label {
    switch (this) {
      case BlessingBagEarnReason.dailyLogin:
        return '매일 접속';
      case BlessingBagEarnReason.wishCreatedBonus:
        return '소원 봉인 완료';
      case BlessingBagEarnReason.dailyPrayer:
        return '오늘의 기도';
      case BlessingBagEarnReason.eventParticipation:
        return '이벤트 참여';
      case BlessingBagEarnReason.altarVisit:
        return '제단 참배';
      case BlessingBagEarnReason.weeklyBoxOpening:
        return '주간 소원함 개봉';
      case BlessingBagEarnReason.wishFulfilled:
        return '소원 성취 축하';
      case BlessingBagEarnReason.dailyCandle:
        return '오늘의 촛불';
      case BlessingBagEarnReason.dailyMeditation:
        return '60초 명상';
      case BlessingBagEarnReason.wishComment:
        return '응원 한 마디';
      case BlessingBagEarnReason.dailyFeedVisit:
        return '모두의 소원방 둘러보기';
    }
  }

  String get description {
    switch (this) {
      case BlessingBagEarnReason.altarVisit:
        return '오늘 소원방 제단에 처음 들어오면 받아요 (1일 1회)';
      case BlessingBagEarnReason.weeklyBoxOpening:
        return '이번 주 소원함을 열어보면 받아요 (7일 1회)';
      case BlessingBagEarnReason.wishFulfilled:
        return '내 소원이 이루어졌을 때 받아요';
      case BlessingBagEarnReason.dailyLogin:
        return '오늘 처음 접속하면 받아요 (1일 1회)';
      case BlessingBagEarnReason.wishCreatedBonus:
        return '새 소원을 봉인하면 받아요 (1일 1회)';
      case BlessingBagEarnReason.dailyPrayer:
        return '누군가의 소원에 오늘의 기도를 올리면 받아요';
      case BlessingBagEarnReason.dailyCandle:
        return '오늘 촛불을 한 번 켜면 받아요 (1일 1회)';
      case BlessingBagEarnReason.dailyMeditation:
        return '60초 동안 마음을 가라앉히면 받아요 (1일 1회)';
      case BlessingBagEarnReason.eventParticipation:
        return '진행 중인 이벤트에 참여하면 받아요';
      case BlessingBagEarnReason.wishComment:
        return '누군가의 소원에 응원 한 마디를 남기면 받아요 (15자 이상 · 1일 3회 · 같은 소원엔 1회)';
      case BlessingBagEarnReason.dailyFeedVisit:
        return '모두의 소원방에서 3개 이상 소원을 읽으면 받아요 (1일 1회)';
    }
  }

  /// [복주머니 정책표 §3] wishCreatedBonus(소원벽 첫 작성)는 1일 1회 +2로
  /// 확정되었다(기존 +5에서 하향 조정 — 정책표 최종안 반영).
  int get defaultAmount {
    switch (this) {
      case BlessingBagEarnReason.dailyLogin:
        return 1;
      case BlessingBagEarnReason.wishCreatedBonus:
        return 2;
      case BlessingBagEarnReason.dailyPrayer:
        return 1;
      case BlessingBagEarnReason.eventParticipation:
        return 3;
      case BlessingBagEarnReason.altarVisit:
        return 1;
      case BlessingBagEarnReason.weeklyBoxOpening:
        return 2;
      case BlessingBagEarnReason.wishFulfilled:
        return 3;
      case BlessingBagEarnReason.dailyCandle:
        return 1;
      case BlessingBagEarnReason.dailyMeditation:
        return 2;
      case BlessingBagEarnReason.wishComment:
        return 2;
      case BlessingBagEarnReason.dailyFeedVisit:
        return 1;
    }
  }
}

/// 복주머니 사용 사유 (기획안 §4.2 3채널).
///
/// [소원방 리스킨 — 적립/사용 확장] `giftSeal`은 새 소원방 팝업 "보내기" 탭에
/// 추가된 장식용 소액 소비 채널이다(감사 도장을 함께 보내는 응원 표현).
enum BlessingBagSpendReason { sendPouch, boostBottle, promoteWish, giftSeal }

extension BlessingBagSpendReasonX on BlessingBagSpendReason {
  String get code {
    switch (this) {
      case BlessingBagSpendReason.sendPouch:
        return 'send_pouch';
      case BlessingBagSpendReason.boostBottle:
        return 'boost_bottle';
      case BlessingBagSpendReason.promoteWish:
        return 'promote_wish';
      case BlessingBagSpendReason.giftSeal:
        return 'gift_seal';
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
      case BlessingBagSpendReason.giftSeal:
        return '감사 도장 보내기';
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
