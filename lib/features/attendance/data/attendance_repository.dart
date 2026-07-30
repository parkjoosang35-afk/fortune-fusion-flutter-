import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';

/// 06단계 §4.13(출석/미션/랭킹) `/v1/attendance` 대응 Repository — admin_web 공개 API
/// (`GET /api/public/attendance/status`, `POST /api/public/attendance/checkin`)를 호출한다.
///
/// [실API 전환] 서버 checkin 라우트가 지갑 적립(wallet.balance)까지 트랜잭션 내부에서
/// 직접 처리하므로, 여기서는 서버가 반환한 `balanceAfter`를 그대로 신뢰하고 클라이언트는
/// 별도로 WalletProvider.earn()을 호출하지 않는다(중복 적립 방지) — 대신 WalletProvider.load()로
/// 최신 잔액만 재조회한다(호출부는 attendance_provider.dart 참조).
class AttendanceRepository {
  Future<ApiResult<Map<String, dynamic>>> getStatus() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/attendance/status?userId=$userId',
    );
    debugPrint('[AttendanceRepository] [status] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '출석 현황을 불러오지 못했습니다.';
        debugPrint('[AttendanceRepository] [status] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok({
        'streak': data['streak'] as int? ?? 0,
        'checked_today': data['checkedToday'] as bool? ?? false,
      });
    } catch (e) {
      debugPrint('[AttendanceRepository] [status] 예외 -> $e');
      return ApiResult.fail('출석 현황을 불러오지 못했습니다: $e');
    }
  }

  /// POST /api/public/attendance/checkin — 성공 시 rewardPoint/streak/balanceAfter/
  /// alreadyChecked를 담아 반환한다. 서버가 이미 지갑 적립까지 처리하므로 호출부는
  /// 반환된 rewardPoint>0일 때 WalletProvider.load()로 잔액만 새로고침하면 된다.
  Future<ApiResult<Map<String, dynamic>>> checkIn() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/attendance/checkin',
    );
    debugPrint('[AttendanceRepository] [checkin] 요청 시작 -> userId=$userId');

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
        final error = decoded['error'] as String? ?? '출석 체크인에 실패했습니다.';
        debugPrint('[AttendanceRepository] [checkin] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok({
        'streak': data['streak'] as int? ?? 0,
        'rewardPoint': data['rewardPoint'] as int? ?? 0,
        'balanceAfter': data['balanceAfter'] as int?,
        'alreadyChecked': data['alreadyChecked'] as bool? ?? false,
      });
    } catch (e) {
      debugPrint('[AttendanceRepository] [checkin] 예외 -> $e');
      return ApiResult.fail('출석 체크인 중 오류가 발생했습니다: $e');
    }
  }
}
