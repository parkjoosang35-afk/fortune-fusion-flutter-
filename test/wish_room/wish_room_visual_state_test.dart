import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/wish_room/data/models/wish_room_visual_state_model.dart';
import 'package:flutter_app/features/wish_room/data/models/wish_item_model.dart';

/// [Sprint 2 단위테스트] 방(Room) 전체 오브제 레벨(WishObjectLevel) 경계값
/// 검증. 연속 방문일수 기준 3/7/14일 지점에서 단계가 바뀌며, 이 축은
/// 개별 소원의 WishGrowthStage(정성 누적 기반)와 완전히 다른 축이므로
/// 절대 혼용되지 않는지도 함께 확인한다.
void main() {
  group('WishObjectLevelX.fromStreak 경계값', () {
    test('0~2일 -> seed', () {
      expect(WishObjectLevelX.fromStreak(0), WishObjectLevel.seed);
      expect(WishObjectLevelX.fromStreak(2), WishObjectLevel.seed);
    });

    test('3일 -> glow (경계값 그 자체)', () {
      expect(WishObjectLevelX.fromStreak(3), WishObjectLevel.glow);
    });

    test('3~6일 -> glow', () {
      expect(WishObjectLevelX.fromStreak(6), WishObjectLevel.glow);
    });

    test('7일 -> bloom (경계값 그 자체)', () {
      expect(WishObjectLevelX.fromStreak(7), WishObjectLevel.bloom);
    });

    test('7~13일 -> bloom', () {
      expect(WishObjectLevelX.fromStreak(13), WishObjectLevel.bloom);
    });

    test('14일 -> radiant (경계값 그 자체)', () {
      expect(WishObjectLevelX.fromStreak(14), WishObjectLevel.radiant);
    });

    test('14일 초과도 상한 없이 radiant 유지', () {
      expect(WishObjectLevelX.fromStreak(365), WishObjectLevel.radiant);
    });
  });

  group('WishRoomVisualState.fromRoom 파생 계산', () {
    test('오늘 기도했으면 glowIntensity=0.9', () {
      final state = WishRoomVisualState.fromRoom(
        consecutivePrayerDays: 3,
        hasPrayedToday: true,
      );
      expect(state.glowIntensity, 0.9);
    });

    test('오늘 기도하지 않았으면 glowIntensity=0.4', () {
      final state = WishRoomVisualState.fromRoom(
        consecutivePrayerDays: 3,
        hasPrayedToday: false,
      );
      expect(state.glowIntensity, 0.4);
    });

    test('backgroundSparkleLevel은 streak/14로 계산되며 최소 0.2로 clamp', () {
      // 0일 방문 -> 0/14=0.0이지만 clamp(0.2, 1.0)로 최소값 보정.
      final zero = WishRoomVisualState.fromRoom(
        consecutivePrayerDays: 0,
        hasPrayedToday: false,
      );
      expect(zero.backgroundSparkleLevel, 0.2);
    });

    test('backgroundSparkleLevel은 streak=14 이상이면 최대 1.0으로 clamp', () {
      final full = WishRoomVisualState.fromRoom(
        consecutivePrayerDays: 30,
        hasPrayedToday: true,
      );
      expect(full.backgroundSparkleLevel, 1.0);
    });

    test('objectLevel은 WishObjectLevelX.fromStreak과 동일 경계를 따른다', () {
      final atMilestone = WishRoomVisualState.fromRoom(
        consecutivePrayerDays: 7,
        hasPrayedToday: false,
      );
      expect(atMilestone.objectLevel, WishObjectLevel.bloom);
    });

    test(
      '대표 소원이 없으면(빈 상태) representativeGrowthStage 기본값 ember',
      () {
        final state = WishRoomVisualState.fromRoom(
          consecutivePrayerDays: 0,
          hasPrayedToday: false,
        );
        // 파라미터 미지정 시 기본값 ember를 사용해야 한다(WishRoomData.visualState의
        // "대표 소원 없으면 ember" 규칙과 동일해야 함).
        expect(state.representativeGrowthStage, WishGrowthStage.ember);
      },
    );

    test(
      'objectLevel(방문일 기반)과 representativeGrowthStage(정성 누적 기반)는 '
      '서로 다른 축이므로 동일 streak/growthPoint 값이라도 독립적으로 계산된다',
      () {
        // 연속 방문 14일(radiant)이지만 대표 소원 정성치는 아직 ember 단계.
        final state = WishRoomVisualState.fromRoom(
          consecutivePrayerDays: 14,
          hasPrayedToday: true,
          representativeGrowthStage: WishGrowthStage.ember,
        );
        expect(state.objectLevel, WishObjectLevel.radiant);
        expect(state.representativeGrowthStage, WishGrowthStage.ember);
      },
    );
  });
}
