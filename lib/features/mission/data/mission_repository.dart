import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/config/env_config.dart';
import '../domain/mission_model.dart';

/// 06단계 §4.13 `/v1/missions` 대응 Repository — admin_web 공개 API
/// (`GET /api/public/missions`)를 호출하는 실제 구현체 (Mock→실API 전환).
///
/// [Phase5 - 게임화 최소연동] "복 나누기(send_bok)"와 "오늘의 운세 확인
/// (view_daily_fortune)" 실제 사용자 행동이 발생하면 서버(wallet/send,
/// fortune/daily API)가 관련 미션의 진행률을 자동으로 갱신하고, 목표 달성 시
/// 즉시 보상을 지급(claim)한다. 이 Repository는 그 결과를 조회만 한다
/// (완료 처리 버튼은 더 이상 필요 없으나, 기존 화면 호환을 위해 completeMission은
/// "이미 서버가 자동 처리했다"는 안내로 남겨둔다).
///
/// [방법 A — 임시 인증 우회] 회원 로그인 시스템이 아직 없어, 서버가 시딩해둔
/// 테스트 유저(userId=1)를 고정으로 사용한다.
class MissionRepository {
  static const int _userId = 1;

  Future<ApiResult<List<MissionModel>>> getMissions() async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/missions?userId=$_userId',
    );
    debugPrint('[MissionRepository] [getMissions] 요청 시작 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      debugPrint(
        '[MissionRepository] [getMissions] 응답 수신 -> statusCode=${response.statusCode}',
      );

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '미션 목록을 불러오지 못했습니다.';
        debugPrint('[MissionRepository] [getMissions] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final dataList = decoded['data'] as List<dynamic>;
      final missions = dataList.map((e) {
        final map = e as Map<String, dynamic>;
        final periodRaw = map['period'] as String? ?? 'daily';
        final period = periodRaw == 'weekly'
            ? MissionPeriod.weekly
            : MissionPeriod.daily;
        return MissionModel(
          id: map['id'] as String,
          title: map['title'] as String,
          description: map['description'] as String? ?? '',
          rewardPoints: (map['rewardPoints'] as num).toInt(),
          period: period,
          isCompleted: map['isCompleted'] as bool? ?? false,
          progressCount: (map['progressCount'] as num?)?.toInt() ?? 0,
          targetCount: (map['targetCount'] as num?)?.toInt() ?? 1,
        );
      }).toList();

      debugPrint('[MissionRepository] [getMissions] 성공 -> ${missions.length}건');
      return ApiResult.ok(missions);
    } catch (e, st) {
      debugPrint('[MissionRepository] [getMissions] 예외 -> $e');
      if (kDebugMode) debugPrint('$st');
      return ApiResult.fail('미션 목록을 불러오지 못했습니다: $e');
    }
  }

  /// [Phase5] 진행률/완료 처리는 이제 실제 행동(오늘의 운세 확인, 복 나누기 등)이
  /// 발생하는 API에서 서버가 자동으로 처리(자동 claim)한다. 화면에서 별도의
  /// "받기" 버튼 액션이 필요 없어졌지만, 기존 UI 호환을 위해 메서드는 유지하고
  /// 안내 메시지만 반환한다.
  Future<ApiResult<int>> completeMission(String id) async {
    return ApiResult.fail('이 미션은 관련 활동(오늘의 운세 확인, 복 나누기 등)을 하면 자동으로 완료 처리됩니다.');
  }
}
