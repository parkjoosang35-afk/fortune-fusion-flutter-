/// 감사 도장(GratitudeSeal) 도메인 모델 — bokjumeoni-plan §07 "벗의 감사 도장" ·
/// admin_web `src/app/api/public/gratitude/_shared.ts`의 `toSealableCandidateDto()`
/// / `toGratitudeSealDto()`가 내려주는 JSON 구조를 그대로 따른다.
///
/// [배경] 누군가 내 소원에 복주머니를 보내면(sendPouch = `POST /wishes/:id/bokju`),
/// 나는 24시간 이내에 딱 한 번 "감사 도장"을 찍어 답례할 수 있다. 찍는 사람(원래
/// 받은 사람, sender) +2복, 받는 사람(원래 보낸 사람, recipient) +5복.
///
/// [명칭 주의] 기존 `BlessingBagSpendReason.giftSeal`("감사 도장 보내기",
/// code='gift_seal')은 소원에 복주머니를 보낼 때 "함께" 찍는 장식적 소액 소비로,
/// 이 파일의 GratitudeSeal(답례 도장, sourcePouchId 기반)과는 완전히 다른 기능이다.
/// UI 문구는 혼동을 피하기 위해 이 기능을 "답례 도장"으로 표기한다.
library;

/// `GET /gratitude/sealable` 응답 항목 — 내가 아직 도장을 찍지 않은, 24시간
/// 이내의 받은 sendPouch 후보 하나.
class GratitudeSealableCandidate {
  /// 원래 sendPouch에 해당하는 PointHistory.id. 답례(POST /gratitude/seal)
  /// 요청 시 그대로 전달한다.
  final int sourcePouchId;

  /// 복주머니를 받은 내 소원의 공개 id.
  final String wishId;

  /// 원래 보내진 복주머니 개수.
  final int amount;

  /// 원래 sendPouch가 발생한 시각.
  final DateTime createdAt;

  /// 답례 가능 마감 시각(createdAt + 24시간). 이 시각이 지나면 서버가
  /// 답례 요청을 400으로 거부한다.
  final DateTime expiresAt;

  const GratitudeSealableCandidate({
    required this.sourcePouchId,
    required this.wishId,
    required this.amount,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remaining => expiresAt.difference(DateTime.now());

  factory GratitudeSealableCandidate.fromJson(Map<String, dynamic> json) {
    return GratitudeSealableCandidate(
      sourcePouchId: (json['sourcePouchId'] as num).toInt(),
      wishId: json['wishId'] as String,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      expiresAt:
          DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// `POST /gratitude/seal` / `GET /gratitude/received` 응답 항목 — 이미
/// 생성된 GratitudeSeal 레코드.
class GratitudeSeal {
  final int id;
  final String wishId;
  final int sourcePouchId;

  /// [주의] 서버 DTO의 `amount`는 이 도장을 "받은" 쪽(recipient)에게 실제
  /// 지급된 금액이다(`POST /gratitude/seal` 응답에는 별도로
  /// `senderGrantedAmount`가 추가로 온다 — [senderGrantedAmount] 참조).
  final int amount;
  final DateTime createdAt;

  /// `POST /gratitude/seal` 응답에만 존재(도장을 "찍은" 사람에게 그 순간
  /// 지급된 금액). `GET /gratitude/received` 목록 조회 시에는 항상 null —
  /// 그 목록은 recipient 관점이라 sender 쪽 지급액을 알 필요가 없다.
  final int? senderGrantedAmount;

  const GratitudeSeal({
    required this.id,
    required this.wishId,
    required this.sourcePouchId,
    required this.amount,
    required this.createdAt,
    this.senderGrantedAmount,
  });

  factory GratitudeSeal.fromJson(Map<String, dynamic> json) {
    return GratitudeSeal(
      id: (json['id'] as num).toInt(),
      wishId: json['wishId'] as String,
      sourcePouchId: (json['sourcePouchId'] as num).toInt(),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      senderGrantedAmount: (json['senderGrantedAmount'] as num?)?.toInt(),
    );
  }
}

/// 답례 도장 찍기 실패 사유 — 서버 `seal/route.ts` catch 분기를 그대로 매핑.
enum GratitudeSealFailureReason {
  pouchNotFound,
  notPouchReceiver,
  selfSend,
  expired,
  alreadySealed,
  unknown,
}

/// 감사 도장 API 호출 실패 시 던지는 예외. [reason]으로 UI가 분기 처리할 수
/// 있게 하고, [message]는 사용자에게 그대로 보여줄 수 있는 한국어 문구.
class GratitudeException implements Exception {
  final GratitudeSealFailureReason reason;
  final String message;

  const GratitudeException(this.reason, this.message);

  @override
  String toString() => message;
}
