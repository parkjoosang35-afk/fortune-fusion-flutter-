import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/subscription_model.dart';

/// 06단계 §4.11(결제/구독) `/v1/subscriptions/*`, `/v1/payments` 대응 Repository
/// — admin_web 공개 API(`/api/public/subscription/*`)를 호출한다.
/// [방법 A] 테스트 유저(userId=1) 고정(matching_repository.dart와 동일 패턴).
///
/// ⚠️ 실제 PG 연동은 범위 밖(서버가 즉시 성공 시뮬레이션 처리).
class SubscriptionRepository {
  static String get _base => '${EnvConfig.adminApiBaseUrl}/api/public/subscription';

  Future<ApiResult<List<SubscriptionPlanModel>>> getPlans() async {
    final uri = Uri.parse('$_base/plans');
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '구독 플랜을 불러오지 못했습니다.');
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
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('$_base/my?userId=$userId');
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '구독 현황을 불러오지 못했습니다.');
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
    final userId = await AuthTokenStore.getCurrentUserId();
    if (plan.price <= 0) {
      return ApiResult.fail('무료 플랜은 별도 결제가 필요하지 않습니다.');
    }
    final uri = Uri.parse('$_base/subscribe');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'planId': plan.id}),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '구독 처리에 실패했습니다.');
      }
      return ApiResult.ok(_subscriptionFromJson(decoded['data'] as Map<String, dynamic>));
    } catch (e) {
      debugPrint('[SubscriptionRepository] [subscribe] 예외 -> $e');
      return ApiResult.fail('구독 처리 중 오류가 발생했습니다: $e');
    }
  }

  Future<ApiResult<UserSubscriptionModel>> cancel() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('$_base/cancel');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '구독 중인 플랜이 없습니다.');
      }
      return ApiResult.ok(_subscriptionFromJson(decoded['data'] as Map<String, dynamic>));
    } catch (e) {
      debugPrint('[SubscriptionRepository] [cancel] 예외 -> $e');
      return ApiResult.fail('구독 취소 중 오류가 발생했습니다: $e');
    }
  }

  Future<ApiResult<List<PaymentModel>>> getPaymentHistory() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('$_base/payments?userId=$userId');
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '결제 내역을 불러오지 못했습니다.');
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
    );
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
