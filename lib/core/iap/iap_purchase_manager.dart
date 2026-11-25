// [Google Play Billing 실연동 — 2026-11-26] `in_app_purchase` 패키지를 감싸는
// 공용 싱글톤 — 복주머니 충전(소모성)과 구독(비소모성) 양쪽에서 재사용한다.
//
// [설계 원칙 — 클라이언트는 절대 낙관적으로 지급하지 않는다]
// 이 매니저는 "Google Play 결제창을 띄우고 purchaseToken을 받아오는" 역할만
// 담당한다. 받은 purchaseToken을 admin_web의 confirm-purchase 엔드포인트로
// 보내 서버가 Google Play Developer API로 직접 검증하고 나서야 비로소
// 복주머니/구독이 지급된다(google-play-billing-verifier.ts와 짝을 이루는
// 클라이언트 측 절반). `completePurchase()`는 서버 확정 응답을 받은 뒤에만
// 호출한다 — 그래야 서버 확정에 실패했을 때 Google이 구매를 "미완료"
// 상태로 유지해 다음 앱 실행 시 purchaseStream으로 재통지(자연 재시도)한다.
//
// [purchaseStream 단일 구독 원칙] 패키지 문서가 권장하는 대로 앱 전체에서
// 이 스트림을 단 한 번만 구독한다(init()을 main/app 시작 시 1회 호출).
// buy() 호출 시점에 productId를 키로 Completer를 등록해두고, 리스너가 해당
// productId의 PurchaseDetails를 받으면 그 Completer를 완료시키는 방식으로
// "스트림 기반 API"를 "Future 기반 1회성 구매 요청"으로 감싼다.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

enum IapOutcome { purchased, restored, canceled, error, unavailable, timeout }

class IapPurchaseResult {
  final IapOutcome outcome;
  final String? purchaseToken; // Android: verificationData.serverVerificationData
  final String? productId;
  final String? errorMessage;

  const IapPurchaseResult({
    required this.outcome,
    this.purchaseToken,
    this.productId,
    this.errorMessage,
  });

  bool get isSuccess =>
      outcome == IapOutcome.purchased || outcome == IapOutcome.restored;
}

class IapPurchaseManager {
  IapPurchaseManager._();
  static final IapPurchaseManager instance = IapPurchaseManager._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _initialized = false;

  // productId별로 "지금 구매 응답을 기다리는 중"인 completer 1개씩만 유지한다
  // (동시에 같은 상품을 두 번 구매 시도하는 것은 UI 레벨에서 막아야 한다).
  final Map<String, Completer<PurchaseDetails>> _pending = {};

  // 서버 확정 전까지 completePurchase()를 미뤄야 하므로, buy()가 반환한
  // 구매의 원본 PurchaseDetails를 productId 기준으로 잠시 보관해둔다
  // (completePurchase 호출 시 이 객체가 필요 — pendingCompletePurchase 플래그 보유).
  final Map<String, PurchaseDetails> _awaitingCompletion = {};

  /// 앱 시작 시 1회만 호출한다(app.dart 초기화 단계 권장).
  void init() {
    if (_initialized) return;
    _initialized = true;
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) {
        if (kDebugMode) debugPrint('[IapPurchaseManager] 스트림 오류: $e');
      },
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      final completer = _pending[p.productID];
      if (completer != null &&
          !completer.isCompleted &&
          (p.status == PurchaseStatus.purchased ||
              p.status == PurchaseStatus.restored ||
              p.status == PurchaseStatus.error ||
              p.status == PurchaseStatus.canceled)) {
        completer.complete(p);
        _pending.remove(p.productID);
      }
    }
  }

  /// Google Play 결제창을 띄우고 완료될 때까지 기다린다.
  /// [consumable]이 true면 소모성(복주머니 충전 등 — 재구매 가능), false면
  /// 비소모성/구독(subscriptionId=productId로 동일하게 처리된다).
  ///
  /// 반환된 [IapPurchaseResult.purchaseToken]을 서버 confirm-purchase
  /// 엔드포인트로 보내 검증받기 전까지는 어떤 지급도 수행하지 않아야 한다.
  /// 서버 확정 후에는 반드시 [completePurchase]를 호출해 결제 파이프라인을
  /// 마무리해야 한다(안 하면 Google이 다음 세션에 같은 구매를 계속 재통지함).
  Future<IapPurchaseResult> buy({
    required String productId,
    required bool consumable,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    if (!_initialized) init();

    final available = await _iap.isAvailable();
    if (!available) {
      return const IapPurchaseResult(
        outcome: IapOutcome.unavailable,
        errorMessage: 'Google Play 결제를 사용할 수 없습니다.',
      );
    }

    final response = await _iap.queryProductDetails({productId});
    if (response.notFoundIDs.contains(productId) ||
        response.productDetails.isEmpty) {
      return IapPurchaseResult(
        outcome: IapOutcome.unavailable,
        productId: productId,
        errorMessage: 'Play Console에 등록되지 않은 상품입니다($productId).',
      );
    }

    final details = response.productDetails.first;
    final completer = Completer<PurchaseDetails>();
    _pending[productId] = completer;

    final param = PurchaseParam(productDetails: details);
    try {
      if (consumable) {
        await _iap.buyConsumable(purchaseParam: param);
      } else {
        await _iap.buyNonConsumable(purchaseParam: param);
      }
    } catch (e) {
      _pending.remove(productId);
      return IapPurchaseResult(
        outcome: IapOutcome.error,
        productId: productId,
        errorMessage: '$e',
      );
    }

    late final PurchaseDetails purchase;
    try {
      purchase = await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(productId);
      return IapPurchaseResult(
        outcome: IapOutcome.timeout,
        productId: productId,
        errorMessage: '결제 응답 대기 시간이 초과되었습니다.',
      );
    }

    switch (purchase.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        _awaitingCompletion[purchase.productID] = purchase;
        return IapPurchaseResult(
          outcome: purchase.status == PurchaseStatus.purchased
              ? IapOutcome.purchased
              : IapOutcome.restored,
          purchaseToken: purchase.verificationData.serverVerificationData,
          productId: purchase.productID,
        );
      case PurchaseStatus.canceled:
        return IapPurchaseResult(
          outcome: IapOutcome.canceled,
          productId: purchase.productID,
        );
      case PurchaseStatus.error:
      case PurchaseStatus.pending:
        return IapPurchaseResult(
          outcome: IapOutcome.error,
          productId: purchase.productID,
          errorMessage: purchase.error?.message ?? '결제 중 오류가 발생했습니다.',
        );
    }
  }

  /// 서버 confirm-purchase가 성공을 반환한 뒤 반드시 호출해 Google 결제
  /// 파이프라인을 마무리한다(안 하면 Google이 다음 앱 실행 시 동일 구매를
  /// purchaseStream으로 계속 재통지한다). [buy]가 반환한 [productId]로
  /// 보관해둔 PurchaseDetails를 찾아 완료 처리한다.
  Future<void> completePurchaseFor(String productId) async {
    final details = _awaitingCompletion.remove(productId);
    if (details != null && details.pendingCompletePurchase) {
      await _iap.completePurchase(details);
    }
  }
}
