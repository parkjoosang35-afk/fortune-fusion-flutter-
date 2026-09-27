import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/result_access_model.dart';

/// [결과보기 통합 권한 시스템 v1.0, Phase4] §8.1 공통화 원칙에 따라, 정통사주
/// 69종·타로 65종·운세 전체가 이 Repository 하나만 호출한다. admin_web의
/// 신규 공개 API 4개(quote/begin/ad-session start·complete)를 그대로 얇게
/// 감싼다 — 잔액 계산이나 차감 판정 로직은 여기에 절대 두지 않는다(§8.3
/// "서버 재검증 필수" 원칙, 클라이언트는 서버 응답을 그대로 신뢰만 한다).
class ResultAccessRepository {
  /// GET /api/public/result-access/quote — §6 3택 UI 상태 조회(차감 없음).
  Future<ApiResult<ResultAccessQuote>> getQuote({
    required String contentType,
    String? categoryKey,
  }) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/result-access/quote',
    ).replace(
      queryParameters: {
        'contentType': contentType,
        if (categoryKey != null) 'categoryKey': categoryKey,
      },
    );
    debugPrint('[ResultAccessRepository] [quote] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {
            'Accept': 'application/json',
            ...await AuthTokenStore.authHeader(),
          })
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '결과보기 권한 정보를 불러오지 못했습니다.';
        debugPrint('[ResultAccessRepository] [quote] 실패 -> $error');
        return ApiResult.fail(error);
      }
      return ApiResult.ok(
        ResultAccessQuote.fromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[ResultAccessRepository] [quote] 예외 -> $e');
      return ApiResult.fail('결과보기 권한 정보를 불러오지 못했습니다: $e');
    }
  }

  /// POST /api/public/result-access/begin — §8.5 "결제 확정". 이 호출이
  /// 성공(success==true)한 뒤에만 호출부가 AI 생성을 시작해야 한다.
  ///
  /// [transactionId]는 호출부가 매 "결과보기 시도"마다 새로 생성해서 넘겨야
  /// 하며(§8.4 멱등키), 사용자가 버튼을 더블탭해도 동일 transactionId로 다시
  /// 호출되면 서버가 중복 차감 없이 기존 pending 트랜잭션을 그대로 반환한다.
  Future<ApiResult<ResultAccessBeginResult>> begin({
    required String transactionId,
    required String contentType,
    String? contentId,
    String? categoryKey,
    required ResultAccessPaymentMethod paymentMethod,
    String? adSessionId,
  }) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/result-access/begin',
    );
    debugPrint(
      '[ResultAccessRepository] [begin] 요청 -> contentType=$contentType paymentMethod=${paymentMethod.code} transactionId=$transactionId',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              ...await AuthTokenStore.authHeader(),
            },
            body: jsonEncode({
              'transactionId': transactionId,
              'contentType': contentType,
              if (contentId != null) 'contentId': contentId,
              if (categoryKey != null) 'categoryKey': categoryKey,
              'paymentMethod': paymentMethod.code,
              if (adSessionId != null) 'adSessionId': adSessionId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '결과보기 권한 확인에 실패했습니다.';
        debugPrint('[ResultAccessRepository] [begin] 실패 -> $error (reason=${decoded['reason']})');
        return ApiResult.fail(error, code: decoded['reason'] as String?);
      }
      return ApiResult.ok(
        ResultAccessBeginResult.fromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[ResultAccessRepository] [begin] 예외 -> $e');
      return ApiResult.fail('결과보기 권한 확인 중 오류가 발생했습니다: $e');
    }
  }

  /// POST /api/public/result-access/ad-session/start — §8.3 광고 서버 재검증
  /// 1단계. 광고를 표시하기 "전에" 호출해 PENDING 세션을 발급받는다.
  Future<ApiResult<String>> startAdSession() async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/result-access/ad-session/start',
    );
    try {
      final response = await http
          .post(uri, headers: {
            'Content-Type': 'application/json',
            ...await AuthTokenStore.authHeader(),
          })
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '광고 세션을 시작하지 못했습니다.';
        return ApiResult.fail(error);
      }
      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(data['sessionId'] as String);
    } catch (e) {
      debugPrint('[ResultAccessRepository] [ad-session/start] 예외 -> $e');
      return ApiResult.fail('광고 세션을 시작하지 못했습니다: $e');
    }
  }

  /// POST /api/public/result-access/ad-session/complete — §8.3 광고 서버
  /// 재검증 2단계. AdMob RewardedAd의 onUserEarnedReward 콜백이 실제로
  /// 호출된 뒤에만(끝까지 시청 완료 신호) 호출해야 한다. 중도 종료/닫기/오류
  /// 시에는 이 메서드를 절대 호출하지 않는다(§5 "중도 종료 시 권한 승인 안 함").
  Future<ApiResult<void>> completeAdSession(String sessionId) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/result-access/ad-session/complete',
    );
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              ...await AuthTokenStore.authHeader(),
            },
            body: jsonEncode({'sessionId': sessionId}),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '광고 시청 완료 처리에 실패했습니다.';
        return ApiResult.fail(error);
      }
      return ApiResult.ok(null);
    } catch (e) {
      debugPrint('[ResultAccessRepository] [ad-session/complete] 예외 -> $e');
      return ApiResult.fail('광고 시청 완료 처리 중 오류가 발생했습니다: $e');
    }
  }
}

/// [§8.4 멱등성] 결과보기 시도 1건마다 고유한 transactionId를 생성한다.
/// uuid 패키지를 새로 추가하지 않고, timestamp+프로세스 내 랜덤값으로 충돌
/// 확률을 무시할 수준으로 낮춘다(서버는 어차피 @unique 제약으로 최종 방어).
String generateResultAccessTransactionId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final rand = Random().nextInt(0x7fffffff);
  return 'ra_${now}_$rand';
}
