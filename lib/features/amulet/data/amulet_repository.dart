import '../../../core/api/api_result.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/amulet_model.dart';

/// 06단계 §4.8 `GET /v1/amulets/my?active=true` 대응 Mock Repository
class AmuletRepository {
  static const _names = ['재물 부적', '애정 부적', '건강 부적', '취업운 부적'];
  static const _icons = ['🧧', '💖', '🍀', '⭐'];

  Future<ApiResult<AmuletSummary>> getActiveSummary() async {
    await mockDelay(ms: 300);
    final seed = DateTime.now().day;
    final hasActive = seed % 4 != 0;
    return ApiResult.ok(
      AmuletSummary(
        hasActive: hasActive,
        name: _names[seed % _names.length],
        iconEmoji: _icons[seed % _icons.length],
      ),
    );
  }
}
