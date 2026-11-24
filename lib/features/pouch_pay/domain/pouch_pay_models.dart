// [S5 복주머니 결제] 결제 흐름 전역에서 쓰는 순수 데이터 모델.
// PAYMENT_MODE=mock 구현이므로 실제 스토어 영수증 대신, 이 모델들이
// "영수증 화면/구독 배지"에 보여줄 최소 정보를 들고 있는다. 실제
// Wallet/PointHistory 잔액은 이 파일이 아니라 LuckPouchProvider가 단일
// 소스로 유지한다(재화 절대 원칙) — 여기 상태는 전부 "표시용 메타"다.
library;

import 'pouch_pay_catalog.dart';

/// 체크아웃 화면에 들어온 "무엇을 사려는가" 요청.
/// pack: 복주머니 팩 1회 구매. sub: 구독 가입/전환.
class PouchPurchaseRequest {
  final PouchPack? pack;
  final PouchSubTier? sub;
  final String subBilling; // 'month' | 'year' (sub일 때만 의미 있음)

  /// 부족분 결제 흐름(ShortageQuickSheet)에서 넘어온 경우, 완료 후 돌아갈
  /// 화면에 보여줄 안내문구. null이면 일반 곳간 구매 흐름.
  final String? resumeLabel;

  const PouchPurchaseRequest.pack(this.pack)
    : sub = null,
      subBilling = 'month',
      resumeLabel = null;

  const PouchPurchaseRequest.packWithResume(this.pack, this.resumeLabel)
    : sub = null,
      subBilling = 'month';

  const PouchPurchaseRequest.sub(this.sub, {this.subBilling = 'month'})
    : pack = null,
      resumeLabel = null;

  bool get isSub => sub != null;

  String get title => isSub ? '${sub!.hanja} · ${sub!.name}' : pack!.name;

  /// 실제 지급될 복주머니 총량(덤 포함).
  int get gain => isSub ? pouchSubGrant(sub!) : pack!.total;

  /// 결제 금액(원).
  int get payNow =>
      isSub ? (subBilling == 'year' ? pouchSubYearPrice(sub!) : sub!.month) : pack!.price;
}

/// 완료된 구매 1건의 영수증 표시용 스냅샷(서버 orders 테이블이 아직 없으므로
/// 로컬에만 보관 — 실결제 전환 시 서버 주문 내역으로 교체될 자리).
class PouchReceipt {
  final String orderId;
  final String title;
  final List<List<String>> rows; // [label, value]
  final int payNow;
  final int gain;
  final DateTime createdAt;
  final bool isSub;

  const PouchReceipt({
    required this.orderId,
    required this.title,
    required this.rows,
    required this.payNow,
    required this.gain,
    required this.createdAt,
    required this.isSub,
  });

  int get vat => (payNow / 11).round();

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'title': title,
    'rows': rows,
    'payNow': payNow,
    'gain': gain,
    'createdAt': createdAt.toIso8601String(),
    'isSub': isSub,
  };

  factory PouchReceipt.fromJson(Map<String, dynamic> j) => PouchReceipt(
    orderId: j['orderId'] as String,
    title: j['title'] as String,
    rows: (j['rows'] as List)
        .map((e) => (e as List).map((x) => x.toString()).toList())
        .toList(),
    payNow: j['payNow'] as int,
    gain: j['gain'] as int,
    createdAt: DateTime.parse(j['createdAt'] as String),
    isSub: j['isSub'] as bool? ?? false,
  );
}

/// 현재 활성 구독 상태(모의 — 실제 정기결제 엔진이 없으므로 로컬에만 보관).
class PouchSubscriptionState {
  final String tierId; // chosim/jeongseong/sintong
  final String billing; // month/year
  final DateTime nextBillingAt;

  const PouchSubscriptionState({
    required this.tierId,
    required this.billing,
    required this.nextBillingAt,
  });

  PouchSubTier get tier => kPouchSubs.firstWhere((t) => t.id == tierId);

  Map<String, dynamic> toJson() => {
    'tierId': tierId,
    'billing': billing,
    'nextBillingAt': nextBillingAt.toIso8601String(),
  };

  factory PouchSubscriptionState.fromJson(Map<String, dynamic> j) =>
      PouchSubscriptionState(
        tierId: j['tierId'] as String,
        billing: j['billing'] as String,
        nextBillingAt: DateTime.parse(j['nextBillingAt'] as String),
      );
}
