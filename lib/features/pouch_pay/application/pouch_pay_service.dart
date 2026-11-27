// [S5 복주머니 결제 — PAYMENT_MODE=mock 핵심 서비스]
//
// 설계 근거(admin_web 소스 직접 확인):
// - `/api/public/wallet/earn`(src/app/api/public/wallet/earn/route.ts)은
//   sourceType을 "admin_adjust/admin_grant/manual/signup_reward/
//   first_login_reward" 5개만 차단하고, 그 외 임의의 새 sourceType은 그대로
//   받아 `checkPolicyEligibility()`→`earnLuckPouch()`를 거쳐 실제
//   Wallet.balance/PointHistory에 적립한다(luck-pouch-engine.ts). 일치하는
//   PointPolicy 행이 없으면 일일상한 없이 통과한다.
// - 따라서 여기서 쓰는 `iap_pack_purchase`/`iap_sub_grant` sourceType은
//   서버 코드를 단 한 줄도 바꾸지 않고도 곧바로 동작하며, 지급되는 복주머니는
//   "가짜 숫자"가 아니라 실제 서버 원장에 기록되는 진짜 값이다.
// - PAYMENT_MODE=sandbox/live로 전환할 때는 이 서비스의 내부 구현(현재는
//   스토어 영수증 검증 없이 바로 earn 호출)만 교체하면 된다 — 화면/호출부는
//   변경할 필요가 없도록 인터페이스를 설계했다.
//
// [재화 절대 원칙] 이 서비스는 잔액을 직접 보유하지 않는다. earn() 호출 뒤
// LuckPouchProvider.balance가 자동으로 서버 최신값으로 갱신되며, 화면은 항상
// LuckPouchProvider만 구독해서 잔액을 표시해야 한다.
import 'package:flutter/foundation.dart';
import '../../../core/iap/iap_purchase_manager.dart';
import '../../luckpouch/application/luck_pouch_provider.dart';
import '../../subscription/data/subscription_repository.dart';
import '../../subscription/domain/subscription_model.dart';
import '../data/pouch_pay_local_store.dart';
import '../data/pouch_product_repository.dart';
import '../domain/pouch_pay_catalog.dart';
import '../domain/pouch_pay_models.dart';

/// 서버에 아직 등록되지 않은 신규 sourceType — admin_web 차단목록에 없음을
/// 위 주석에서 확인했다. 실결제 전환 시에도 그대로 재사용 가능.
const String kSourceTypePackPurchase = 'iap_pack_purchase';
const String kSourceTypeSubGrant = 'iap_sub_grant';

class PouchPayResult {
  final bool success;
  final int grantedAmount;
  final PouchReceipt? receipt;
  final String? blockedReason;
  const PouchPayResult({
    required this.success,
    this.grantedAmount = 0,
    this.receipt,
    this.blockedReason,
  });
}

class PouchPayService extends ChangeNotifier {
  LuckPouchProvider _pouch;
  final PouchProductRepository _pouchProducts = PouchProductRepository();
  // [초심/정성/신통 구독 실결제 연동 — 2026-11-27] 곳간 "매달 받기" 탭의
  // 구독 결제를 subscription_plans(서버)와 직접 연결하기 위한 레포지토리.
  // features/subscription 모듈의 SubscriptionProvider와는 별개 인스턴스로
  // 가볍게 조회만 한다(마이페이지→구독 쪽 상태관리와 분리 — 02§21 범위분리).
  final SubscriptionRepository _subscriptionRepo = SubscriptionRepository();
  List<SubscriptionPlanModel> _subPlans = [];
  bool _subPlansLoaded = false;

  PouchPayService(this._pouch) {
    PouchPayLocalStore.I.load();
  }

  void updatePouch(LuckPouchProvider pouch) {
    _pouch = pouch;
  }

  int get balance => _pouch.balance;

  PouchSubscriptionState? get activeSubscription =>
      PouchPayLocalStore.I.subscription;

  List<PouchReceipt> get recentReceipts => PouchPayLocalStore.I.receipts;

  PouchReceipt? findReceipt(String orderId) =>
      PouchPayLocalStore.I.findReceipt(orderId);

  String _genOrderId() =>
      'PP${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

  /// [디자인핸드오프 PayEntry.jsx `SUB_EXTRA_PCT` 로직 1:1] 활성 구독자가
  /// 팩을 살 때 base 수량의 kPouchSubExtraPct%를 추가로 더 준다.
  int _subscriberExtraFor(PouchPack pack) {
    if (!PouchPayLocalStore.I.hasActiveSub) return 0;
    return (pack.base * kPouchSubExtraPct / 100).round();
  }

  /// 복주머니 팩 1회 구매. 성공 시 실제 Wallet/PointHistory에 적립되고
  /// LuckPouchProvider.balance가 자동으로 갱신된다.
  Future<PouchPayResult> buyPack(PouchPack pack) async {
    final extra = _subscriberExtraFor(pack);
    final total = pack.total + extra;
    final granted = await _pouch.earn(
      total,
      '${pack.name} 복주머니 담기',
      sourceType: kSourceTypePackPurchase,
    );
    if (granted <= 0) {
      return PouchPayResult(
        success: false,
        blockedReason: _pouch.lastEarnBlockedReason,
      );
    }
    final orderId = _genOrderId();
    final rows = <List<String>>[
      ['복주머니', '${pack.base}개'],
      if (pack.bonus > 0) ['덤', '+${pack.bonus}개'],
      if (extra > 0) ['구독 보너스', '+$extra개'],
      ['정가', '${pack.base * kPouchUnitPrice}원'],
    ];
    final receipt = PouchReceipt(
      orderId: orderId,
      title: pack.name,
      rows: rows,
      payNow: pack.price,
      gain: total,
      createdAt: DateTime.now(),
      isSub: false,
    );
    await PouchPayLocalStore.I.addReceipt(receipt);
    notifyListeners();
    return PouchPayResult(
      success: true,
      grantedAmount: granted,
      receipt: receipt,
    );
  }

  /// 구독 가입/전환(업그레이드·다운그레이드 포함) — 가입 즉시 월/연 분의
  /// 복주머니를 담아준다(디자인핸드오프 PayCheckout.jsx `orderOf` sub 분기
  /// 1:1: gain = pouchSubGrant(tier)). 실제 정기결제 엔진이 없으므로
  /// "다음 결제일"은 로컬에서 월/연 단위로 1회 계산해 표시용으로만 보관한다.
  Future<PouchPayResult> buySubscription(
    PouchSubTier tier, {
    required String billing, // 'month' | 'year'
  }) async {
    final grant = pouchSubGrant(tier);
    final payNow = billing == 'year' ? pouchSubYearPrice(tier) : tier.month;
    final granted = await _pouch.earn(
      grant,
      '${tier.name} 구독 복주머니',
      sourceType: kSourceTypeSubGrant,
    );
    if (granted <= 0) {
      return PouchPayResult(
        success: false,
        blockedReason: _pouch.lastEarnBlockedReason,
      );
    }
    final orderId = _genOrderId();
    final next = DateTime.now().add(
      Duration(days: billing == 'year' ? 365 : 30),
    );
    final rows = <List<String>>[
      ['복주머니', '${pouchSubBase(tier)}개'],
      ['구독 덤 +${tier.bonusPct}%', '+${pouchSubBonus(tier)}개'],
      ['담기는 때', billing == 'year' ? '매년' : '매달'],
      [
        '다음 결제일',
        '${next.year}.${next.month.toString().padLeft(2, '0')}.${next.day.toString().padLeft(2, '0')}',
      ],
    ];
    final receipt = PouchReceipt(
      orderId: orderId,
      title: '${tier.hanja} · ${tier.name}',
      rows: rows,
      payNow: payNow,
      gain: grant,
      createdAt: DateTime.now(),
      isSub: true,
    );
    await PouchPayLocalStore.I.addReceipt(receipt);
    await PouchPayLocalStore.I.setSubscription(
      PouchSubscriptionState(
        tierId: tier.id,
        billing: billing,
        nextBillingAt: next,
      ),
    );
    notifyListeners();
    return PouchPayResult(
      success: true,
      grantedAmount: granted,
      receipt: receipt,
    );
  }

  /// [Google Play Billing 실연동 — 2026-11-26] 서버(PouchProduct)에
  /// googlePlayProductId가 등록된 상품의 "진짜" 결제 흐름.
  ///
  /// 순서: ①Google Play 결제창 호출 → ②purchaseToken을 서버
  /// confirm-purchase로 전송(서버가 Google Play Developer API로 직접 검증
  /// 후에만 복주머니 지급) → ③서버 성공 응답을 받은 뒤에만 Google 결제를
  /// 완료 처리(completePurchaseFor) → ④LuckPouchProvider를 재조회해 최신
  /// 잔액을 반영한다. 클라이언트는 어느 단계에서도 낙관적으로 먼저 지급하지
  /// 않는다 — ②에서 실패하면 결제창은 이미 끝났어도 복주머니는 0개 지급.
  Future<PouchPayResult> buyPackReal(PouchProductModel product) async {
    if (!product.canRealPurchase) {
      return const PouchPayResult(
        success: false,
        blockedReason: '아직 실결제가 준비되지 않은 상품입니다.',
      );
    }
    final purchase = await IapPurchaseManager.instance.buy(
      productId: product.googlePlayProductId!,
      consumable: true,
    );
    if (!purchase.isSuccess || purchase.purchaseToken == null) {
      return PouchPayResult(
        success: false,
        blockedReason: purchase.errorMessage ?? '결제가 완료되지 않았습니다.',
      );
    }

    final confirm = await _pouchProducts.confirmRealPurchase(
      googlePlayProductId: product.googlePlayProductId!,
      purchaseToken: purchase.purchaseToken!,
    );
    if (!confirm.success) {
      // 서버 확정에 실패하면 Google 결제를 완료 처리하지 않는다 — 다음 앱
      // 실행 시 purchaseStream이 동일 구매를 재통지해 재시도할 수 있게 한다.
      return PouchPayResult(
        success: false,
        blockedReason: confirm.errorMessage,
      );
    }

    await IapPurchaseManager.instance.completePurchaseFor(
      product.googlePlayProductId!,
    );

    final granted = confirm.data ?? 0;
    await _pouch.load();

    final orderId = _genOrderId();
    final rows = <List<String>>[
      ['복주머니', '${product.base}개'],
      if (product.bonus > 0) ['덤', '+${product.bonus}개'],
      ['정가', '${product.price}원'],
    ];
    final receipt = PouchReceipt(
      orderId: orderId,
      title: product.name,
      rows: rows,
      payNow: product.price,
      gain: granted,
      createdAt: DateTime.now(),
      isSub: false,
    );
    await PouchPayLocalStore.I.addReceipt(receipt);
    notifyListeners();
    return PouchPayResult(
      success: true,
      grantedAmount: granted,
      receipt: receipt,
    );
  }

  /// [초심/정성/신통 구독 실결제 연동 — 2026-11-27] 서버 subscription_plans를
  /// 로드해 캐시한다. 체크아웃 화면이 열릴 때 1회 호출하면 충분하다(관리자가
  /// 가격/상품ID를 바꾸면 다음 로드 때 반영됨 — 실시간 반영은 범위 밖).
  Future<void> loadSubPlans() async {
    final result = await _subscriptionRepo.getPlans();
    if (result.success) {
      _subPlans = result.data!;
      _subPlansLoaded = true;
      notifyListeners();
    }
  }

  bool get subPlansLoaded => _subPlansLoaded;

  /// [tier.id]("chosim"/"jeongseong"/"sintong")와 [billing]("month"/"year")에
  /// 대응하는 서버 SubscriptionPlan을 찾는다. tier.id가 Play Console의
  /// "부모 구독 상품ID"와 정확히 동일하도록 등록되어 있음을 전제한다(Play
  /// Console 스크린샷으로 확인됨: chosim/jeongseong/sintong).
  SubscriptionPlanModel? findServerPlan(PouchSubTier tier, String billing) {
    final period = billing == 'year'
        ? SubscriptionPeriod.yearly
        : SubscriptionPeriod.monthly;
    for (final p in _subPlans) {
      if (p.period == period && p.googlePlayParentProductId == tier.id) {
        return p;
      }
    }
    return null;
  }

  /// [Google Play Billing 실연동 — 2026-11-27] 곳간 "매달 받기" 탭의 진짜
  /// 결제 흐름. 순서는 buyPackReal()과 동일한 원칙(클라이언트는 절대 낙관적
  /// 지급을 하지 않는다): ①서버 플랜 확인 → ②Google Play 구독 결제창
  /// (부모ID+기본요금제 offerToken) → ③purchaseToken을 서버
  /// subscription/confirm-purchase로 전송(Google Play Developer API v2로
  /// 검증 후에만 복주머니 지급) → ④서버 성공 응답을 받은 뒤에만 Google 결제
  /// 완료 처리 → ⑤LuckPouchProvider 재조회.
  Future<PouchPayResult> buySubscriptionReal(
    PouchSubTier tier, {
    required String billing,
  }) async {
    final plan = findServerPlan(tier, billing);
    if (plan == null || !plan.canRealPurchase) {
      return const PouchPayResult(
        success: false,
        blockedReason: '아직 실결제가 준비되지 않은 구독입니다.',
      );
    }
    final parentId = plan.googlePlayParentProductId;
    if (parentId == null) {
      return const PouchPayResult(
        success: false,
        blockedReason: '구독 상품ID 구성이 올바르지 않습니다.',
      );
    }

    final purchase = await IapPurchaseManager.instance.buy(
      productId: parentId,
      basePlanId: plan.googlePlayProductId!,
      consumable: false,
    );
    if (!purchase.isSuccess || purchase.purchaseToken == null) {
      return PouchPayResult(
        success: false,
        blockedReason: purchase.errorMessage ?? '결제가 완료되지 않았습니다.',
      );
    }

    final confirm = await _subscriptionRepo.confirmRealPurchase(
      googlePlayProductId: plan.googlePlayProductId!,
      purchaseToken: purchase.purchaseToken!,
    );
    if (!confirm.success) {
      // 서버 확정 실패 시 Google 결제를 완료 처리하지 않는다 — 다음 앱 실행 시
      // purchaseStream이 재통지해 재시도할 수 있게 한다(buyPackReal과 동일 원칙).
      return PouchPayResult(
        success: false,
        blockedReason: confirm.errorMessage,
      );
    }

    // completePurchaseFor의 키는 buy()에 넘긴 productId(=parentId)와 일치해야 한다.
    await IapPurchaseManager.instance.completePurchaseFor(parentId);

    final granted = confirm.data!.grantedPouchAmount;
    await _pouch.load();

    final orderId = _genOrderId();
    final next = DateTime.now().add(
      Duration(days: billing == 'year' ? 365 : 30),
    );
    final rows = <List<String>>[
      ['복주머니', '${plan.pouchBaseAmount ?? 0}개'],
      if ((plan.pouchBonusAmount ?? 0) > 0)
        ['구독 덤', '+${plan.pouchBonusAmount}개'],
      ['담기는 때', billing == 'year' ? '매년' : '매달'],
      [
        '다음 결제일',
        '${next.year}.${next.month.toString().padLeft(2, '0')}.${next.day.toString().padLeft(2, '0')}',
      ],
    ];
    final receipt = PouchReceipt(
      orderId: orderId,
      title: '${tier.hanja} · ${tier.name}',
      rows: rows,
      payNow: plan.price,
      gain: granted,
      createdAt: DateTime.now(),
      isSub: true,
    );
    await PouchPayLocalStore.I.addReceipt(receipt);
    await PouchPayLocalStore.I.setSubscription(
      PouchSubscriptionState(
        tierId: tier.id,
        billing: billing,
        nextBillingAt: next,
      ),
    );
    notifyListeners();
    return PouchPayResult(
      success: true,
      grantedAmount: granted,
      receipt: receipt,
    );
  }

  /// 구독 해지(모의 — 즉시 해지, 환불 없음. 실결제 전환 시 스토어
  /// 구독관리로 안내하는 로직으로 교체될 자리).
  Future<void> cancelSubscription() async {
    await PouchPayLocalStore.I.setSubscription(null);
    notifyListeners();
  }

  void clearOnLogout() {
    PouchPayLocalStore.I.clearMemoryOnLogout();
    notifyListeners();
  }
}
