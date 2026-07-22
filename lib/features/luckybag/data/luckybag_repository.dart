import '../../../core/api/api_result.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/luckybag_model.dart';

/// 06단계 §4.9 `GET /v1/luckybags/my?status=pending` 대응 Mock Repository
class LuckyBagRepository {
  Future<ApiResult<LuckyBagSummary>> getPendingSummary() async {
    await mockDelay(ms: 300);
    final seed = DateTime.now().day;
    final pending = seed % 3 == 0 ? 0 : 1 + (seed % 3);
    final grade = pending == 0
        ? 'none'
        : (['common', 'rare', 'epic'][seed % 3]);
    return ApiResult.ok(LuckyBagSummary(pendingCount: pending, grade: grade));
  }
}
