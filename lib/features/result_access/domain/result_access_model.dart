/// [결과보기 통합 권한 시스템 v1.0, Phase4] §8 공통 ResultAccessService의
/// Flutter측 도메인 모델 — admin_web `/api/public/result-access/quote`,
/// `/api/public/result-access/begin` 두 API의 응답을 1:1로 매핑한다.
///
/// [§8.1 공통화 원칙] 정통사주 69종·타로 65종·운세 전체가 이 모델과
/// [ResultAccessRepository]/[ResultAccessProvider]만 공유해서 쓴다.
/// 콘텐츠별로 별도 모델/Repository를 새로 만들지 않는다.
library;

/// [ResultAccessPaymentMethod] 3택 결제수단(§6/§8.3).
enum ResultAccessPaymentMethod { freepass, pouch, ad }

extension ResultAccessPaymentMethodCode on ResultAccessPaymentMethod {
  /// 서버가 기대하는 문자열("FREEPASS"/"POUCH"/"AD").
  String get code => switch (this) {
    ResultAccessPaymentMethod.freepass => 'FREEPASS',
    ResultAccessPaymentMethod.pouch => 'POUCH',
    ResultAccessPaymentMethod.ad => 'AD',
  };
}

/// GET /api/public/result-access/quote 응답 — §6 3택 UI를 그리는 데 필요한
/// 모든 상태를 한 번에 담는다. 조회 전용(차감 없음).
class ResultAccessQuote {
  /// 신규 횟수제 프리패스 잔여 횟수(§6.1/6.2 "N회 남음" 표시).
  final int freePassRemaining;

  /// 레거시 시간제 프리패스가 현재 활성 상태로 남아있는지(하위호환 전용).
  /// [freePassRemaining]이 0이어도 이 값이 true면 FREEPASS를 선택할 수 있다.
  final bool freePassHasLegacyUnlimited;

  /// 지금 FREEPASS로 진행 가능한지(freePassRemaining>0 || 레거시 무제한).
  final bool freePassAvailable;

  /// 복주머니(포인트) 현재 잔액.
  final int pouchBalance;

  /// 결과보기 1건당 복주머니 가격(기본 100, 예외가는 Phase5).
  final int pouchPrice;

  final bool pouchAvailable;
  final bool adAvailable;

  /// 오늘(KST) 쿠팡 프리패스를 이미 획득했으면 그 날짜키("YYYY-MM-DD"), 아니면 null.
  final String? coupangClaimedTodayKey;

  /// [§6.4] coupangClaimedTodayKey != null과 동일한 정보의 boolean 편의 필드.
  final bool todayClaimed;

  const ResultAccessQuote({
    required this.freePassRemaining,
    required this.freePassHasLegacyUnlimited,
    required this.freePassAvailable,
    required this.pouchBalance,
    required this.pouchPrice,
    required this.pouchAvailable,
    required this.adAvailable,
    required this.coupangClaimedTodayKey,
    required this.todayClaimed,
  });

  /// 복주머니가 가격보다 충분한지(버튼 활성/비활성 판단용, 서버가 최종 판정).
  bool get pouchSufficient => pouchBalance >= pouchPrice;

  factory ResultAccessQuote.fromJson(Map<String, dynamic> json) {
    return ResultAccessQuote(
      freePassRemaining: json['freePassRemaining'] as int? ?? 0,
      freePassHasLegacyUnlimited:
          json['freePassHasLegacyUnlimited'] as bool? ?? false,
      freePassAvailable: json['freePassAvailable'] as bool? ?? false,
      pouchBalance: json['pouchBalance'] as int? ?? 0,
      pouchPrice: json['pouchPrice'] as int? ?? 100,
      pouchAvailable: json['pouchAvailable'] as bool? ?? true,
      adAvailable: json['adAvailable'] as bool? ?? true,
      coupangClaimedTodayKey: json['coupangClaimedTodayKey'] as String?,
      todayClaimed: json['todayClaimed'] as bool? ?? false,
    );
  }
}

/// POST /api/public/result-access/begin 응답 — 서버가 실제 차감까지 확정한
/// 결과(§8.5 "결제 확정"). 이 결과를 받은 뒤에만 AI 생성을 시작해야 한다.
class ResultAccessBeginResult {
  final String transactionId;
  final ResultAccessPaymentMethod paymentMethod;
  final String status; // pending/success/failed/refunded
  final int amount;
  final int? freePassRemaining;
  final int? pouchBalance;
  final bool idempotent;

  const ResultAccessBeginResult({
    required this.transactionId,
    required this.paymentMethod,
    required this.status,
    required this.amount,
    this.freePassRemaining,
    this.pouchBalance,
    required this.idempotent,
  });

  factory ResultAccessBeginResult.fromJson(Map<String, dynamic> json) {
    return ResultAccessBeginResult(
      transactionId: json['transactionId'] as String,
      paymentMethod: _parseMethod(json['paymentMethod'] as String?),
      status: json['status'] as String? ?? 'pending',
      amount: json['amount'] as int? ?? 0,
      freePassRemaining: json['freePassRemaining'] as int?,
      pouchBalance: json['pouchBalance'] as int?,
      idempotent: json['idempotent'] as bool? ?? false,
    );
  }

  static ResultAccessPaymentMethod _parseMethod(String? code) {
    switch (code) {
      case 'FREEPASS':
        return ResultAccessPaymentMethod.freepass;
      case 'POUCH':
        return ResultAccessPaymentMethod.pouch;
      case 'AD':
      default:
        return ResultAccessPaymentMethod.ad;
    }
  }
}
