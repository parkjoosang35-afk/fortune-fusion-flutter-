// 정통사주 결과 화면 '쉬운 설명' inline 토글 테스트.
//
// [STEP 0-B raw 로 확정한 실제 스키마 반영] easy_terms.json 은 미션이 가정한
// {ts}/{termsMap}/{terms:[]} 래퍼가 아니라, 최상위가 곧 {"<용어>":{"easy":..,
// "detail":..}, ...} 형태의 flat map이다(+ "_description" 메타키 1개는 용어
// 아님). "일간" 키의 실제 easy 값은 "나 자신"이다(원본 raw 확인 완료).
//
// [설계 참고] `EasyTerms.preload()`는 매 테스트마다 반복 호출하지 않는다 —
// asset 로드(Future)를 여러 테스트에서 reset+재호출하면 test binding teardown
// 타이밍과 얽혀 불안정할 수 있어, 로드가 필요한 테스트들은 `setUpAll`에서
// 단 1회만 미리 로드해 공유한다. "preload 안 된 상태" 시나리오만 별도로
// `resetForTest()`를 호출하고 preload는 호출하지 않는다(그 자체가 검증 대상).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/home/presentation/widgets/jeontong_easy_term_toggle.dart';

void main() {
  Widget harness(String token) {
    return MaterialApp(
      home: Scaffold(body: JeontongEasyTermToggle(token: token)),
    );
  }

  group('preload 완료 상태', () {
    setUpAll(() async {
      EasyTerms.resetForTest();
      await JeontongEasyTermToggle.preload();
    });

    testWidgets('매핑된 토큰: 초기 접힘 → 탭하면 쉬운 설명 펼침 → 다시 탭하면 접힘', (tester) async {
      await tester.pumpWidget(harness('일간'));
      await tester.pumpAndSettle();

      // 초기 상태: 접혀 있어 쉬운 설명 텍스트가 보이지 않는다.
      expect(find.text('나 자신'), findsNothing);

      // 탭 → 펼침.
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text('나 자신'), findsOneWidget);

      // 다시 탭 → 접힘.
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text('나 자신'), findsNothing);
    });

    testWidgets('매핑 없는 토큰은 펼치면 폴백 문구를 보여준다', (tester) async {
      await tester.pumpWidget(harness('없는키'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.text('쉬운 설명 준비 중'), findsOneWidget);
    });
  });

  testWidgets('preload 되지 않은 상태에서도 폴백 문구를 보여준다(크래시 없음)', (tester) async {
    EasyTerms.resetForTest();

    await tester.pumpWidget(harness('일간'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(find.text('쉬운 설명 준비 중'), findsOneWidget);
  });
}
