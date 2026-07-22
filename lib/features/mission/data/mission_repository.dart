import '../../../core/api/api_result.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/mission_model.dart';

/// 06단계 §4.13 `/v1/missions` 대응 Mock Repository
class MissionRepository {
  final List<MissionModel> _missions = [
    const MissionModel(
      id: 'm_daily_1',
      title: '오늘의 운세 확인하기',
      description: '홈에서 오늘의 운세를 확인해보세요',
      rewardPoints: 50,
      period: MissionPeriod.daily,
      isCompleted: false,
    ),
    const MissionModel(
      id: 'm_daily_2',
      title: 'AI 타로 1회 이용하기',
      description: 'AI 타로에서 카드를 뽑아보세요',
      rewardPoints: 100,
      period: MissionPeriod.daily,
      isCompleted: false,
    ),
    const MissionModel(
      id: 'm_daily_3',
      title: '출석체크 하기',
      description: '오늘 출석체크를 완료해보세요',
      rewardPoints: 100,
      period: MissionPeriod.daily,
      isCompleted: false,
    ),
    const MissionModel(
      id: 'm_weekly_1',
      title: '이번 주 AI 사주 분석 받기',
      description: '사주 명식을 분석해보세요',
      rewardPoints: 300,
      period: MissionPeriod.weekly,
      isCompleted: false,
    ),
    const MissionModel(
      id: 'm_weekly_2',
      title: '커뮤니티에 소원글 남기기',
      description: '커뮤니티에 새 글을 작성해보세요',
      rewardPoints: 200,
      period: MissionPeriod.weekly,
      isCompleted: false,
    ),
  ];

  Future<ApiResult<List<MissionModel>>> getMissions() async {
    await mockDelay(ms: 400);
    return ApiResult.ok(List.unmodifiable(_missions));
  }

  Future<ApiResult<int>> completeMission(String id) async {
    await mockDelay(ms: 400);
    final idx = _missions.indexWhere((m) => m.id == id);
    if (idx == -1) return ApiResult.fail('미션을 찾을 수 없습니다.');
    if (_missions[idx].isCompleted) return ApiResult.fail('이미 완료한 미션입니다.');
    final mission = _missions[idx];
    _missions[idx] = mission.copyWith(isCompleted: true);
    return ApiResult.ok(mission.rewardPoints);
  }
}
