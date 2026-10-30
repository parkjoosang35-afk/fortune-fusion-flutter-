// [반응형 화면 규격 통일 — 잘림 현상 수정] 상점(Shop) 모듈의 팝업/
// 바텀시트 3종(ShortageDialog, PurchaseConfirmSheet, ShopGuideDialog)이
// 작은 화면+글자확대 조합에서 잘리던 회귀를 막기 위한 영구 회귀 테스트.
//
// 과거 발견된 문제(320x568 + 글자확대 130%):
// - PurchaseConfirmSheet: 기본(isScrollControlled: false) 바텀시트가
//   화면 절반 높이로 고정돼 "구매하기"/"취소" 버튼까지 61px 잘림
//   → isScrollControlled: true + SafeArea + SingleChildScrollView로 해결.
// - ShopGuideDialog(안내 3단계 다이얼로그, 4개 타입 공용): Dialog 내부
//   Column이 화면 높이를 넘는 내용을 그대로 받아 최대 170px 잘림
//   → 화면 높이의 85%로 제한 + SingleChildScrollView로 해결.
// - ShortageDialog: 이번 조건에서는 오버플로가 없었지만(짧은 내용),
//   회귀 방지 차원에서 같이 검증한다.
//
// 디자인·문구·색상·버튼 동작은 전혀 바꾸지 않았다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/shop/domain/shop_models.dart';
import 'package:flutter_app/features/shop/widgets/shop_widgets.dart';

const _item = ShopCatalogItem(
  itemType: ShopItemType.seal,
  itemCode: 'seal_gold',
  nameKo: '황금 인장',
  descriptionKo: '아주 긴 설명이 들어갈 수도 있는 품목 설명 텍스트입니다. 소원을 봉인할 때 사용해요.',
  price: 500,
  durationDays: 14,
  displayPriority: 1,
  isActive: true,
);

Future<void> _openAndCheck(
  WidgetTester tester, {
  required Size size,
  required double scale,
  required Widget Function(BuildContext) opener,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale), size: size),
    child: MaterialApp(
      home: Builder(builder: (context) {
        return Scaffold(body: Center(child: Builder(builder: opener)));
      }),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  final configs = <(Size, double)>[
    (const Size(360, 640), 1.0),
    (const Size(320, 568), 1.3), // 과거 ShopGuideDialog 170px, PurchaseConfirmSheet 61px 오버플로 재현 조건
  ];

  for (final (size, scale) in configs) {
    final label = '${size.width.toInt()}x${size.height.toInt()}@${scale}x';

    testWidgets('ShortageDialog $label 에서 오버플로 없이 렌더링된다', (tester) async {
      await _openAndCheck(
        tester,
        size: size,
        scale: scale,
        opener: (context) => ElevatedButton(
          onPressed: () =>
              ShortageDialog.show(context, item: _item, need: 500, have: 120),
          child: const Text('open'),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('PurchaseConfirmSheet $label 에서 오버플로 없이 렌더링된다', (tester) async {
      await _openAndCheck(
        tester,
        size: size,
        scale: scale,
        opener: (context) => ElevatedButton(
          onPressed: () => PurchaseConfirmSheet.show(context, item: _item),
          child: const Text('open'),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('취소'), findsOneWidget, reason: '맨 아래 버튼까지 실제로 그려져야 한다');
    });

    for (final type in ShopGuideType.values) {
      testWidgets('ShopGuideDialog $type $label 에서 오버플로 없이 렌더링된다', (tester) async {
        await _openAndCheck(
          tester,
          size: size,
          scale: scale,
          opener: (context) => ElevatedButton(
            onPressed: () => ShopGuideDialog.show(context, type),
            child: const Text('open'),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('알겠어요'), findsOneWidget, reason: '맨 아래 버튼까지 실제로 그려져야 한다');
      });
    }
  }
}
