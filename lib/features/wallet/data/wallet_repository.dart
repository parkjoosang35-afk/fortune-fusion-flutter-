import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/point_history_model.dart';

/// 06단계 §4.2 `/v1/wallet` 대응 Repository — admin_web 공개 API
/// (`GET /api/public/wallet`, `POST /api/public/wallet/earn`,
/// `POST /api/public/wallet/spend`)를 호출한다.
///
/// [방법 A — 임시 인증 우회] 회원 로그인 시스템이 아직 없어, 서버가 시딩해둔
/// 테스트 유저(userId=1, "별빛나그네")를 고정으로 사용한다. 추후 실제 로그인이
/// 붙으면 [userId]를 로그인한 사용자의 id로 교체하기만 하면 된다.
class WalletRepository {
  Future<ApiResult<int>> getBalance() async {
    final result = await _fetchWallet();
    if (!result.success) {
      return ApiResult.fail(result.errorMessage ?? '잔액을 불러오지 못했습니다.');
    }
    return ApiResult.ok(result.data!.balance);
  }

  Future<ApiResult<List<PointHistoryModel>>> getHistory() async {
    final result = await _fetchWallet();
    if (!result.success) {
      return ApiResult.fail(result.errorMessage ?? '내역을 불러오지 못했습니다.');
    }
    return ApiResult.ok(result.data!.history);
  }

  Future<({int balance, List<PointHistoryModel> history})>
  _fetchWalletOrThrow() async {
    final result = await _fetchWallet();
    if (!result.success) {
      throw Exception(result.errorMessage ?? '지갑 정보를 불러오지 못했습니다.');
    }
    return result.data!;
  }

  Future<ApiResult<({int balance, List<PointHistoryModel> history})>>
  _fetchWallet() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/wallet?userId=$userId',
    );
    debugPrint('[WalletRepository] [1] 지갑 조회 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      debugPrint(
        '[WalletRepository] [2] 응답 수신 -> statusCode=${response.statusCode}',
      );

      if (response.statusCode != 200) {
        return ApiResult.fail(
          '지갑 서버 응답 오류 (HTTP ${response.statusCode})',
          code: 'HTTP_${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '지갑 응답 형식이 올바르지 않습니다.',
        );
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final balance = data['balance'] as int;
      final historyRaw = (data['history'] as List<dynamic>? ?? []);
      final history = historyRaw.map((e) {
        final map = e as Map<String, dynamic>;
        final type = map['type'] == 'earn'
            ? PointHistoryType.earn
            : PointHistoryType.spend;
        final rawAmount = map['amount'] as int;
        return PointHistoryModel(
          id: 'ph_${map['id']}',
          type: type,
          amount: rawAmount.abs(),
          reason: map['reason'] as String? ?? '',
          createdAt: DateTime.parse(map['createdAt'] as String),
        );
      }).toList();

      return ApiResult.ok((balance: balance, history: history));
    } catch (e, st) {
      debugPrint('[WalletRepository] [X] 예외 발생 -> $e');
      if (kDebugMode) debugPrint('$st');
      return ApiResult.fail('지갑 정보를 불러오지 못했습니다: $e');
    }
  }

  /// WalletService.earn (02번 §1.2 Ledger 패턴 - 잔액은 파생값, 이력이 원본)
  /// 반환값: 적립 후 최신 잔액. 실패 시 예외를 던진다(기존 Mock 시그니처와 동일하게
  /// int를 반환하되, 통신 실패는 Provider 쪽에서 try/catch로 처리하도록 위임).
  Future<int> earn(int amount, String reason) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/wallet/earn',
    );
    debugPrint(
      '[WalletRepository] [earn] 요청 시작 -> amount=$amount, reason=$reason',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'amount': amount,
              'reason': reason,
              'sourceType': 'app',
            }),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        debugPrint('[WalletRepository] [earn] 실패 -> ${decoded['error']}');
        final current = await _fetchWalletOrThrow();
        return current.balance;
      }

      final balance =
          (decoded['data'] as Map<String, dynamic>)['balance'] as int;
      debugPrint('[WalletRepository] [earn] 성공 -> balance=$balance');
      return balance;
    } catch (e) {
      debugPrint('[WalletRepository] [earn] 예외 -> $e');
      final current = await _fetchWalletOrThrow();
      return current.balance;
    }
  }

  /// [Phase22 - 행복머니 경제철학 이식] "복 나누기(송금)" — POST /api/public/wallet/send
  /// 보낸 사람은 amount만큼 차감되지만 economy_config.send_refund_rate만큼 즉시 환급받고,
  /// 받은 사람은 amount 전액을 그대로 적립받는 "양쪽 증식" 구조.
  /// 반환값: 성공 시 (환급받은 복 액수, 오늘 남은 송금가능액), 실패 시 에러 메시지를 던진다.
  Future<ApiResult<({int refundAmount, int dailySendRemaining})>> sendBok({
    required int toUserId,
    required int amount,
    String memo = '복 나누기',
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/wallet/send',
    );
    debugPrint(
      '[WalletRepository] [sendBok] 요청 시작 -> toUserId=$toUserId, amount=$amount',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fromUserId': userId,
              'toUserId': toUserId,
              'amount': amount,
              'memo': memo,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '복 나누기에 실패했습니다.';
        debugPrint('[WalletRepository] [sendBok] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final refundAmount = data['refundAmount'] as int? ?? 0;
      final dailySendRemaining = data['dailySendRemaining'] as int? ?? 0;
      debugPrint(
        '[WalletRepository] [sendBok] 성공 -> refundAmount=$refundAmount, dailySendRemaining=$dailySendRemaining',
      );
      return ApiResult.ok((
        refundAmount: refundAmount,
        dailySendRemaining: dailySendRemaining,
      ));
    } catch (e) {
      debugPrint('[WalletRepository] [sendBok] 예외 -> $e');
      return ApiResult.fail('복 나누기 중 오류가 발생했습니다: $e');
    }
  }

  /// [Phase22-3 - 황금률 출구버튼] 닉네임 -> userId 조회 — GET /api/public/users/lookup
  /// 커뮤니티/부적/궁합 화면은 작성자를 닉네임(문자열)으로만 갖고 있어, "복 나누기"
  /// 실행 전에 이 API로 실제 userId를 확인한다. 활동 중(active)인 유저만 대상이 된다.
  Future<ApiResult<({int userId, String nickname})>> lookupUserByNickname(
    String nickname,
  ) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/users/lookup',
    ).replace(queryParameters: {'nickname': nickname});
    debugPrint('[WalletRepository] [lookup] 요청 시작 -> nickname=$nickname');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '유저를 찾을 수 없습니다.';
        debugPrint('[WalletRepository] [lookup] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final userId = data['userId'] as int;
      final resolvedNickname = data['nickname'] as String? ?? nickname;
      debugPrint('[WalletRepository] [lookup] 성공 -> userId=$userId');
      return ApiResult.ok((userId: userId, nickname: resolvedNickname));
    } catch (e) {
      debugPrint('[WalletRepository] [lookup] 예외 -> $e');
      return ApiResult.fail('유저 조회 중 오류가 발생했습니다: $e');
    }
  }

  /// WalletService.spend — 성공 시 true, 잔액 부족/오류 시 false.
  Future<bool> spend(int amount, String reason) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/wallet/spend',
    );
    debugPrint(
      '[WalletRepository] [spend] 요청 시작 -> amount=$amount, reason=$reason',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'amount': amount,
              'reason': reason,
              'sourceType': 'app',
            }),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        debugPrint('[WalletRepository] [spend] 실패 -> ${decoded['error']}');
        return false;
      }

      debugPrint('[WalletRepository] [spend] 성공');
      return true;
    } catch (e) {
      debugPrint('[WalletRepository] [spend] 예외 -> $e');
      return false;
    }
  }
}
