import '../../../core/api/api_result.dart';
import '../../../core/utils/mock_delay.dart';

/// 06단계 §4.13(출석/미션/랭킹) `/v1/attendance` 대응 Mock Repository
/// 04A 도메인 D `attendances` 대응
class AttendanceRepository {
  int _streak = 3;
  bool _checkedToday = false;

  Future<ApiResult<Map<String, dynamic>>> getStatus() async {
    await mockDelay(ms: 300);
    return ApiResult.ok({'streak': _streak, 'checked_today': _checkedToday});
  }

  Future<ApiResult<int>> checkIn() async {
    await mockDelay(ms: 400);
    if (_checkedToday) {
      return ApiResult.fail('이미 오늘 출석을 완료했습니다.');
    }
    _checkedToday = true;
    _streak += 1;
    final reward = 100 + (_streak % 7 == 0 ? 500 : 0);
    return ApiResult.ok(reward);
  }
}
