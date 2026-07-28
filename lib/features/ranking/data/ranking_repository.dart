import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/config/env_config.dart';
import '../domain/ranking_model.dart';

/// 06단계 §4.13 `/v1/ranking` 대응 Repository — admin_web 공개 API
/// (`/api/public/ranking/weekly`)를 호출한다. [방법 A] 테스트 유저(userId=1) 고정
/// (matching_repository.dart와 동일 패턴).
///
/// 서버는 ranking_snapshots에 미리 저장된 최신 주간(period) 스냅샷을 그대로
/// 반환한다(Mock의 "myPoints로 임의 순위 삽입" 방식은 사용하지 않음 - 설계결정 참조).
/// myPoints 파라미터는 서버에서 사용하지 않으며, isMe 판정은 서버가 userId로 자동 처리한다.
class RankingRepository {
  static const int _userId = 1;
  static String get _base => '${EnvConfig.adminApiBaseUrl}/api/public/ranking';

  Future<ApiResult<List<RankingEntryModel>>> getWeeklyRanking({
    required int myPoints,
  }) async {
    final uri = Uri.parse('$_base/weekly?userId=$_userId');
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '랭킹을 불러오지 못했습니다.');
      }
      final list = (decoded['data'] as List<dynamic>)
          .map((e) => _entryFromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[RankingRepository] [getWeeklyRanking] 예외 -> $e');
      return ApiResult.fail('랭킹을 불러오지 못했습니다: $e');
    }
  }

  RankingEntryModel _entryFromJson(Map<String, dynamic> j) {
    return RankingEntryModel(
      rank: (j['rank'] as num).toInt(),
      nickname: j['nickname'] as String,
      points: (j['points'] as num).toInt(),
      isMe: j['isMe'] as bool? ?? false,
    );
  }
}
