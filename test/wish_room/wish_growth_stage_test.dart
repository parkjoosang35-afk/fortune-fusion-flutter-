import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/wish_room/data/models/wish_item_model.dart';

/// [Sprint 2 단위테스트] 소원 성장 단계(WishGrowthStage) 경계값 검증.
///
/// 정책표 ⑥ 기준값: 0/20/60/120/250 지점에서 단계가 바뀐다.
/// 경계값 바로 아래(19/59/119/249)와 경계값 그 자체(20/60/120/250)를
/// 모두 검사해 "이상(>=)" 비교가 실제로 올바른 방향으로 구현됐는지 확인한다.
void main() {
  group('WishGrowthStageX.fromGrowthPoint 경계값', () {
    test('0 이상 20 미만 -> ember', () {
      expect(WishGrowthStageX.fromGrowthPoint(0), WishGrowthStage.ember);
      expect(WishGrowthStageX.fromGrowthPoint(19), WishGrowthStage.ember);
    });

    test('20 -> smallCandle (경계값 그 자체)', () {
      expect(WishGrowthStageX.fromGrowthPoint(20), WishGrowthStage.smallCandle);
    });

    test('20 이상 60 미만 -> smallCandle', () {
      expect(WishGrowthStageX.fromGrowthPoint(59), WishGrowthStage.smallCandle);
    });

    test('60 -> steadyCandle (경계값 그 자체)', () {
      expect(WishGrowthStageX.fromGrowthPoint(60), WishGrowthStage.steadyCandle);
    });

    test('60 이상 120 미만 -> steadyCandle', () {
      expect(WishGrowthStageX.fromGrowthPoint(119), WishGrowthStage.steadyCandle);
    });

    test('120 -> brightCandle (경계값 그 자체)', () {
      expect(WishGrowthStageX.fromGrowthPoint(120), WishGrowthStage.brightCandle);
    });

    test('120 이상 250 미만 -> brightCandle', () {
      expect(WishGrowthStageX.fromGrowthPoint(249), WishGrowthStage.brightCandle);
    });

    test('250 -> goldenFlame (경계값 그 자체)', () {
      expect(WishGrowthStageX.fromGrowthPoint(250), WishGrowthStage.goldenFlame);
    });

    test('250 초과 값도 상한 없이 goldenFlame 유지', () {
      // growthPoint는 goldenFlame 도달 이후에도 상한 없이 계속 누적되므로
      // 매우 큰 값에서도 예외 없이 goldenFlame을 반환해야 한다.
      expect(WishGrowthStageX.fromGrowthPoint(999999), WishGrowthStage.goldenFlame);
    });
  });

  group('WishGrowthStageX.nextThreshold / currentThreshold', () {
    test('goldenFlame은 다음 단계가 없으므로 nextThreshold=null', () {
      expect(WishGrowthStage.goldenFlame.nextThreshold, isNull);
    });

    test('각 단계의 currentThreshold는 정책표 기준값과 일치', () {
      expect(WishGrowthStage.ember.currentThreshold, 0);
      expect(WishGrowthStage.smallCandle.currentThreshold, 20);
      expect(WishGrowthStage.steadyCandle.currentThreshold, 60);
      expect(WishGrowthStage.brightCandle.currentThreshold, 120);
      expect(WishGrowthStage.goldenFlame.currentThreshold, 250);
    });
  });

  group('WishItem.growthProgress 진행률 계산', () {
    WishItem buildWish(int growthPoint) => WishItem(
          id: 'w',
          title: 't',
          category: WishCategory.health,
          createdAt: DateTime(2024, 1, 1),
          growthPoint: growthPoint,
        );

    test('단계 시작점(growthPoint=0)은 진행률 0.0', () {
      expect(buildWish(0).growthProgress, 0.0);
    });

    test('단계 중간(growthPoint=10, ember 0~20)은 진행률 0.5', () {
      expect(buildWish(10).growthProgress, 0.5);
    });

    test('다음 단계 바로 아래(growthPoint=19)는 1.0에 근접(0.95)', () {
      expect(buildWish(19).growthProgress, closeTo(0.95, 0.001));
    });

    test('최종 단계(goldenFlame, growthPoint=250 이상)는 진행률 항상 1.0', () {
      expect(buildWish(250).growthProgress, 1.0);
      expect(buildWish(999999).growthProgress, 1.0);
    });
  });
}
