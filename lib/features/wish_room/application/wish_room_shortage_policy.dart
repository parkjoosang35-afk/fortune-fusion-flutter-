import '../domain/wish_room_models.dart';
import 'wish_room_provider.dart';

/// 조각 부족 흐름(Shortage Flow)에서 "☾ 지금 광고 하나 보고 오기" shortcut을
/// 노출할지 결정하는 정책. 출처: `handoff/dev-spec.md` §4.3 표.
///
/// | 조건 | shortcut 표시 |
/// |---|---|
/// | 부족 조각 ≤ 오늘 광고로 획득 가능한 잔량 | O |
/// | 오늘 광고 시청 한도 소진 | X |
/// | 부족 조각 > 오늘 광고 남은 총량 | X |
/// | 고비용 아이템(>150) | 일반적으로 X |
bool wishRoomShouldOfferAdShortcut(
  WishRoomProvider provider, {
  required int shortage,
  required int itemCost,
}) {
  if (itemCost > 150) return false;
  final remainingAdCount =
      WishRoomTodayLimits.adDailyLimit - provider.todayLimits.adCount;
  if (remainingAdCount <= 0) return false;
  // 광고 1회당 기본 획득량은 earnAdWatched()의 기본 amount(5)를 기준으로 한다.
  const perAdShards = 5;
  final remainingAdShards = remainingAdCount * perAdShards;
  return shortage <= remainingAdShards;
}
