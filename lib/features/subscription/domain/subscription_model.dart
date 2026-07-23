/// 04A 도메인K `subscription_plans`(K-3, 마스터) 대응 모델(Mock 단계)
/// benefits는 02§21 향후확장성(À la carte) 대비 JSON 원본 스펙을 기능단위
/// 플래그 목록(List&lt;String&gt;)으로 단순화(03§9.2 과설계 방지 원칙).
class SubscriptionPlanModel {
  final String id;
  final String name;
  final int price;
  final SubscriptionPeriod period;
  final List<String> benefits;
  final bool isActive;

  const SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.price,
    required this.period,
    required this.benefits,
    this.isActive = true,
  });
}

/// 04A K-3 `period` 컬럼(VARCHAR) 대응 - `monthly`/`yearly`
enum SubscriptionPeriod { monthly, yearly }

/// 04A 도메인K `user_subscriptions`(K-4) 대응 모델(Mock 단계)
class UserSubscriptionModel {
  final String id;
  final SubscriptionPlanModel plan;
  final SubscriptionStatus status;
  final DateTime startedAt;
  final DateTime currentPeriodEnd;

  const UserSubscriptionModel({
    required this.id,
    required this.plan,
    required this.status,
    required this.startedAt,
    required this.currentPeriodEnd,
  });

  bool get isActive => status == SubscriptionStatus.active;

  UserSubscriptionModel copyWith({SubscriptionStatus? status}) {
    return UserSubscriptionModel(
      id: id,
      plan: plan,
      status: status ?? this.status,
      startedAt: startedAt,
      currentPeriodEnd: currentPeriodEnd,
    );
  }
}

/// 04A K-4 `status`(Base) 사용값 대응 - `active`/`cancelled`/`expired`/`past_due`
enum SubscriptionStatus { active, cancelled, expired, pastDue }

/// 04A 도메인K `payments`(K-1) 대응 모델(Mock 단계, 구독 결제건만 다룸)
/// 06§4.11: 실제 결제 승인은 웹훅이 확정하지만, Mock 단계에서는 결제 시도 즉시
/// 성공/실패를 반환하는 시뮬레이션으로 단순화.
class PaymentModel {
  final String id;
  final String orderType; // 'subscription' 고정(이번 소단위 범위)
  final int amount;
  final String pgProvider;
  final PaymentStatus status;
  final DateTime createdAt;

  const PaymentModel({
    required this.id,
    required this.orderType,
    required this.amount,
    required this.pgProvider,
    required this.status,
    required this.createdAt,
  });
}

/// 04A K-1 `status`(Base) 사용값 대응 - `paid`/`failed`/`cancelled`
enum PaymentStatus { paid, failed, cancelled }
