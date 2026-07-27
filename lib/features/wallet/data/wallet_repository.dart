import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/config/env_config.dart';
import '../domain/point_history_model.dart';

/// 06단계 §4.2 `/v1/wallet` 대응 Repository — admin_web 공개 API
/// (`GET /api/public/wallet`, `POST /api/public/wallet/earn`,
/// `POST /api/public/wallet/spend`)를 호출한다.
///
/// [방법 A — 임시 인증 우회] 회원 로그인 시스템이 아직 없어, 서버가 시딩해둔
/// 테스트 유저(userId=1, "별빛나그네")를 고정으로 사용한다. 추후 실제 로그인이
/// 붙으면 [_userId]를 로그인한 사용자의 id로 교체하기만 하면 된다.
class WalletRepository {
  static const int _userId = 1;

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

  Future<({int balance, List<PointHistoryModel> history})> _fetchWalletOrThrow() async {
    final result = await _fetchWallet();
    if (!result.success) {
      throw Exception(result.errorMessage ?? '지갑 정보를 불러오지 못했습니다.');
    }
    return result.data!;
  }

  Future<ApiResult<({int balance, List<PointHistoryModel> history})>> _fetchWallet() async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/wallet?userId=$_userId',
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
        return ApiResult.fail(decoded['error'] as String? ?? '지갑 응답 형식이 올바르지 않습니다.');
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final balance = data['balance'] as int;
      final historyRaw = (data['history'] as List<dynamic>? ?? []);
      final history = historyRaw.map((e) {
        final map = e as Map<String, dynamic>;
        final type = map['type'] == 'earn' ? PointHistoryType.earn : PointHistoryType.spend;
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
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/wallet/earn');
    debugPrint('[WalletRepository] [earn] 요청 시작 -> amount=$amount, reason=$reason');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': _userId,
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

      final balance = (decoded['data'] as Map<String, dynamic>)['balance'] as int;
      debugPrint('[WalletRepository] [earn] 성공 -> balance=$balance');
      return balance;
    } catch (e) {
      debugPrint('[WalletRepository] [earn] 예외 -> $e');
      final current = await _fetchWalletOrThrow();
      return current.balance;
    }
  }

  /// WalletService.spend — 성공 시 true, 잔액 부족/오류 시 false.
  Future<bool> spend(int amount, String reason) async {
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/wallet/spend');
    debugPrint('[WalletRepository] [spend] 요청 시작 -> amount=$amount, reason=$reason');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': _userId,
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
