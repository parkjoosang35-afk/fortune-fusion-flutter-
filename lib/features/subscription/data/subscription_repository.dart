import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/subscription_model.dart';

/// [초심/정성/신통 구독 실결제 연동 — 2026-11-27] confirmRealPurchase()의 확장
/// 반환값 — 구독 활성화 결과 + 이번 결제로 서버가 지급한 복주머니 총량.
/// 멱등(이미 처리된 재시도) 응답일 때는 grantedPouchAmount=0(서버가 이중
/// 지급을 방지하기 위해 명시적으로 0을 반환 — confirm-purchase/route.ts 참고).
class SubscriptionPurchaseConfirmation {
  final UserSubscriptionModel subscription;
  final int grantedPouchAmount;
  const SubscriptionPurchaseConfirmation({
    required this.subscription,
    required this.grantedPouchAmount,
  });
}

/// 06단계 §4.11(결제/구독) `/v1/subscriptions/*`, `/v1/payments` 대응 Repository
/// — admin_web 공개 API(`/api/public/subscription/*`)를 호출한다.
/// [방법 A] 테스트 유저(userId=1) 고정(matching_repository.dart와 동일 패턴).
///
/// ⚠️ 실제 PG 연동은 범위 밖(서버가 즉시 성공 시뮬레이션 처리).
class SubscriptionRepository {
  static String get _base =>
      '${EnvConfig.adminApiBaseUrl}/api/public/subscription';

  Future<ApiResult<List<SubscriptionPlanModel>>> getPlans() async {
    final uri = Uri.parse('$_base/plans');
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '구독 플랜을 불러오지 못했습니다.',
        );
      }
      final list = (decoded['data'] as List<dynamic>)
          .map((e) => _planFromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[SubscriptionRepository] [getPlans] 예외 -> $e');
      return ApiResult.fail('구독 플랜을 불러오지 못했습니다: $e');
    }
  }

  Future<ApiResult<UserSubscriptionModel?>> getMySubscription() async {
    final uri = Uri.parse('$_base/my');
    try {
      final headers = {
        'Accept': 'application/json',
        ...await AuthTokenStore.authHeader(),
      };
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '구독 현황을 불러오지 못했습니다.',
        );
      }
      final data = decoded['data'];
      if (data == null) return ApiResult.ok(null);
      return ApiResult.ok(_subscriptionFromJson(data as Map<String, dynamic>));
    } catch (e) {
      debugPrint('[SubscriptionRepository] [getMySubscription] 예외 -> $e');
      return ApiResult.fail('구독 현황을 불러오지 못했습니다: $e');
    }
  }

  /// 결제 시뮬레이션 + 구독 시작(서버가 payments + user_subscriptions 레코드 생성)
  Future<ApiResult<UserSubscriptionModel>> subscribe(
    SubscriptionPlanModel plan,
  ) async {
    if (plan.price <= 0) {
      return ApiResult.fail('무료 플랜은 별도 결제가 필요하지 않습니다.');
    }
    final uri = Uri.parse('$_base/subscribe');
    try {
      final headers = {
        'Content-Type': 'application/json',
        ...await AuthTokenStore.authHeader(),
      };
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({'planId': plan.id}),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '구독 처리에 실패했습니다.');
      }
      return ApiResult.ok(
        _subscriptionFromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[SubscriptionRepository] [subscribe] 예외 -> $e');
      return ApiResult.fail('구독 처리 중 오류가 발생했습니다: $e');
    }
  }

  Future<ApiResult<UserSubscriptionModel>> cancel() async {
    final uri = Uri.parse('$_base/cancel');
    try {
      final headers = {
        'Content-Type': 'application/json',
        ...await AuthTokenStore.authHeader(),
      };
      final response = await http
          .post(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '구독 중인 플랜이 없습니다.');
      }
      return ApiResult.ok(
        _subscriptionFromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[SubscriptionRepository] [cancel] 예외 -> $e');
      return ApiResult.fail('구독 취소 중 오류가 발생했습니다: $e');
    }
  }

  Future<ApiResult<List<PaymentModel>>> getPaymentHistory() async {
    final uri = Uri.parse('$_base/payments');
    try {
      final headers = {
        'Accept': 'application/json',
        ...await AuthTokenStore.authHeader(),
      };
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '결제 내역을 불러오지 못했습니다.',
        );
      }
      final list = (decoded['data'] as List<dynamic>)
          .map((e) => _paymentFromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[SubscriptionRepository] [getPaymentHistory] 예외 -> $e');
      return ApiResult.fail('결제 내역을 불러오지 못했습니다: $e');
    }
  }

  SubscriptionPlanModel _planFromJson(Map<String, dynamic> j) {
    return SubscriptionPlanModel(
      id: j['id'] as String,
      name: j['name'] as String,
      price: (j['price'] as num?)?.toInt() ?? 0,
      period: (j['period'] as String?) == 'yearly'
          ? SubscriptionPeriod.yearly
          : SubscriptionPeriod.monthly,
      benefits: (j['benefits'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      isActive: j['isActive'] as bool? ?? true,
      googlePlayProductId: j['googlePlayProductId'] as String?,
      pouchBaseAmount: (j['pouchBaseAmount'] as num?)?.toInt(),
      pouchBonusAmount: (j['pouchBonusAmount'] as num?)?.toInt(),
    );
  }

  /// [Google Play Billing 실연동] Flutter가 Google Play 결제를 완료시킨 뒤
  /// 받은 purchaseToken을 서버로 보내 실제 검증 + 구독 활성화를 요청한다.
  /// 서버가 503을 반환하면(서비스 계정 키 미설정) "결제 검증 시스템 준비중"
  /// 메시지를 그대로 전달한다 — 절대 클라이언트가 대신 성공 처리하지 않는다.
  Future<ApiResult<SubscriptionPurchaseConfirmation>> confirmRealPurchase({
    required String googlePlayProductId,
    required String purchaseToken,
  }) async {
    final uri = Uri.parse('$_base/confirm-purchase');
    try {
      final headers = {
        'Content-Type': 'application/json',
        ...await AuthTokenStore.authHeader(),
      };
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'googlePlayProductId': googlePlayProductId,
              'purchaseToken': purchaseToken,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '구독 결제 확인에 실패했습니다.');
      }
      final data = decoded['data'] as Map<String, dynamic>;
      final grantedPouchAmount = (data['grantedPouchAmount'] as num?)?.toInt() ?? 0;
      if (data['alreadyProcessed'] == true && data['plan'] == null) {
        // 멱등 응답(최초 요청이 이미 처리됨) — 최신 구독 상태를 다시 조회해 반환한다.
        final latest = await getMySubscription();
        if (latest.success && latest.data != null) {
          return ApiResult.ok(
            SubscriptionPurchaseConfirmation(
              subscription: latest.data!,
              grantedPouchAmount: grantedPouchAmount,
            ),
          );
        }
      }
      return ApiResult.ok(
        SubscriptionPurchaseConfirmation(
          subscription: _subscriptionFromJson(data),
          grantedPouchAmount: grantedPouchAmount,
        ),
      );
    } catch (e) {
      debugPrint('[SubscriptionRepository] [confirmRealPurchase] 예외 -> $e');
      return ApiResult.fail('구독 결제 확인 중 오류가 발생했습니다: $e');
    }
  }

  UserSubscriptionModel _subscriptionFromJson(Map<String, dynamic> j) {
    return UserSubscriptionModel(
      id: j['id'] as String,
      plan: _planFromJson(j['plan'] as Map<String, dynamic>),
      status: _statusFromString(j['status'] as String?),
      startedAt: DateTime.parse(j['startedAt'] as String),
      currentPeriodEnd: DateTime.parse(j['currentPeriodEnd'] as String),
    );
  }

  SubscriptionStatus _statusFromString(String? s) {
    switch (s) {
      case 'active':
        return SubscriptionStatus.active;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      case 'expired':
        return SubscriptionStatus.expired;
      case 'past_due':
        return SubscriptionStatus.pastDue;
      default:
        return SubscriptionStatus.cancelled;
    }
  }

  PaymentModel _paymentFromJson(Map<String, dynamic> j) {
    return PaymentModel(
      id: j['id'] as String,
      orderType: j['orderType'] as String? ?? 'subscription',
      amount: (j['amount'] as num?)?.toInt() ?? 0,
      pgProvider: j['pgProvider'] as String? ?? 'toss',
      status: _paymentStatusFromString(j['status'] as String?),
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }

  PaymentStatus _paymentStatusFromString(String? s) {
    switch (s) {
      case 'paid':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      case 'cancelled':
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.failed;
    }
  }
}
