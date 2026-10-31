import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/api/api_result.dart';
import 'package:flutter_app/features/luckybag/application/luckybag_provider.dart';
import 'package:flutter_app/features/luckybag/data/luckybag_repository.dart';
import 'package:flutter_app/features/luckybag/domain/luckybag_product_model.dart';
import 'package:flutter_app/features/luckybag/domain/luckybag_reward_model.dart';
import 'package:flutter_app/features/luckybag/presentation/widgets/luckybag_probability_sheet.dart';

class _FakeLuckyBagRepository extends LuckyBagRepository {
  @override
  Future<ApiResult<List<LuckyBagRewardPoolModel>>> getProbabilities(
    String productId,
  ) async {
    return ApiResult.ok([
      const LuckyBagRewardPoolModel(
        id: 'p1',
        grade: LuckyBagGrade(code: 'best', name: '최고', sortOrder: 3),
        rewardType: 'amulet',
        rewardLabel: '재물운 상승 부적 세트(한정판, 프리미엄 디자인)',
        probability: 1.5,
      ),
      const LuckyBagRewardPoolModel(
        id: 'p2',
        grade: LuckyBagGrade(code: 'rare', name: '레어', sortOrder: 2),
        rewardType: 'giftcard_fragment',
        rewardLabel: '기프트카드 조각(5000원 상당)',
        probability: 8.5,
      ),
      const LuckyBagRewardPoolModel(
        id: 'p3',
        grade: LuckyBagGrade(code: 'common', name: '일반', sortOrder: 1),
        rewardType: 'point',
        rewardLabel: '500P',
        rewardAmount: 500,
        probability: 40.0,
      ),
      const LuckyBagRewardPoolModel(
        id: 'p4',
        grade: LuckyBagGrade(code: 'none', name: '꽝', sortOrder: 0),
        rewardType: 'none',
        rewardLabel: '아쉽지만 다음 기회에',
        probability: 50.0,
      ),
    ]);
  }
}

class _FakeLuckyBagProvider extends LuckyBagProvider {
  _FakeLuckyBagProvider() : super(_FakeLuckyBagRepository());
}

void main() {
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '행운상자 확률공개 시트가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final provider = _FakeLuckyBagProvider();

        final product = const LuckyBagProductModel(
          id: 'lb_1',
          name: '프리미엄 복주머니',
          pricePoint: 500,
          iconEmoji: '🎁',
        );

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: ChangeNotifierProvider<LuckyBagProvider>.value(
              value: provider,
              child: MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () =>
                          showLuckyBagProbabilitySheet(context, product: product),
                      child: const Text('열기'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await provider.loadProbabilities(product.id);
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        final ex = tester.takeException();
        if (ex != null) debugDumpRenderTree();
        expect(ex, isNull);
      },
    );
  }
}
