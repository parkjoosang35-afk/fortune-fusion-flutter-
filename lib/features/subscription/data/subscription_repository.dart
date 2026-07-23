import '../../../core/api/api_result.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/subscription_model.dart';

/// 06단계 §4.11(결제/구독) `/v1/subscriptions/*`, `/v1/payments` 대응 Mock Repository
///
/// 대응 API:
/// - GET  /subscriptions/plans        -> getPlans()
/// - POST /subscriptions/subscribe    -> subscribe() (PG SDK 호출은 Mock 시뮬레이션)
/// - POST /subscriptions/cancel       -> cancel()
/// - GET  /subscriptions/my           -> getMySubscription()
/// - POST /payments                   -> subscribe() 내부에서 결제건도 함께 생성(구독 결제 전용 단순화)
/// - GET  /payments/my                -> getPaymentHistory()
///
/// ⚠️ PCI-DSS/웹훅 관련(06§4.11 예외처리·보안): Mock 단계에서는 카드정보를
/// 전혀 저장하지 않고, 결제 성공/실패만 즉시 시뮬레이션한다(실제 PG 토큰/웹훅
/// 서명검증은 실제 API 연동 시점에 이 Repository 내부만 교체하면 됨).
class SubscriptionRepository {
  final List<SubscriptionPlanModel> _plans = const [
    SubscriptionPlanModel(
      id: 'plan_free',
      name: 'Free',
      price: 0,
      period: SubscriptionPeriod.monthly,
      benefits: ['기본 AI 사주/타로 하루 1회', '광고 노출'],
    ),
    SubscriptionPlanModel(
      id: 'plan_premium_monthly',
      name: 'Premium 월간',
      price: 9900,
      period: SubscriptionPeriod.monthly,
      benefits: ['무제한 AI 사주/타로/관상/손금', '심층 AI 해석 전체보기', '광고 제거'],
    ),
    SubscriptionPlanModel(
      id: 'plan_premium_yearly',
      name: 'Premium 연간',
      price: 99000,
      period: SubscriptionPeriod.yearly,
      benefits: [
        '무제한 AI 사주/타로/관상/손금',
        '심층 AI 해석 전체보기',
        '광고 제거',
        '2개월 무료(연간 할인)',
      ],
    ),
  ];

  UserSubscriptionModel? _mySubscription;
  final List<PaymentModel> _payments = [];
  int _subSeq = 1;
  int _paymentSeq = 1;

  Future<ApiResult<List<SubscriptionPlanModel>>> getPlans() async {
    await mockDelay(ms: 400);
    return ApiResult.ok(List.unmodifiable(_plans));
  }

  Future<ApiResult<UserSubscriptionModel?>> getMySubscription() async {
    await mockDelay(ms: 350);
    return ApiResult.ok(_mySubscription);
  }

  /// 결제 시뮬레이션 + 구독 시작(06§4.11 PG SDK 연동 지점, Mock에서는 즉시 성공 처리)
  Future<ApiResult<UserSubscriptionModel>> subscribe(
    SubscriptionPlanModel plan,
  ) async {
    await mockDelay(ms: 800);
    if (plan.price <= 0) {
      return ApiResult.fail('무료 플랜은 별도 결제가 필요하지 않습니다.');
    }
    final payment = PaymentModel(
      id: 'pay_${_paymentSeq++}',
      orderType: 'subscription',
      amount: plan.price,
      pgProvider: 'toss',
      status: PaymentStatus.paid,
      createdAt: DateTime.now(),
    );
    _payments.insert(0, payment);

    final now = DateTime.now();
    final periodEnd = plan.period == SubscriptionPeriod.yearly
        ? DateTime(now.year + 1, now.month, now.day)
        : DateTime(now.year, now.month + 1, now.day);

    final subscription = UserSubscriptionModel(
      id: 'sub_${_subSeq++}',
      plan: plan,
      status: SubscriptionStatus.active,
      startedAt: now,
      currentPeriodEnd: periodEnd,
    );
    _mySubscription = subscription;
    return ApiResult.ok(subscription);
  }

  Future<ApiResult<UserSubscriptionModel>> cancel() async {
    await mockDelay(ms: 400);
    final current = _mySubscription;
    if (current == null) return ApiResult.fail('구독 중인 플랜이 없습니다.');
    final updated = current.copyWith(status: SubscriptionStatus.cancelled);
    _mySubscription = updated;
    return ApiResult.ok(updated);
  }

  Future<ApiResult<List<PaymentModel>>> getPaymentHistory() async {
    await mockDelay(ms: 350);
    return ApiResult.ok(List.unmodifiable(_payments));
  }
}
