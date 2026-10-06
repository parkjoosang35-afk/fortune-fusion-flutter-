import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/saju_renewal/theme/saju_dark_tokens.dart';
import 'package:flutter_app/features/saju_renewal/widgets/saju_base_widgets.dart';

/// B-1(docs/08_QA_체크리스트.md) 실제 동작 검증: "Primary 버튼: h56 r14
/// #FAF3E0 / #111 텍스트 / Gowun Batang 700 16 / glow.cta".
///
/// docs/01_디자인토큰.md §2-2 `T-cta`("Gowun Batang 700 16 −0.01em,
/// 모든 CTA") 및 docs/02_컴포넌트.md C-01(Primary/Secondary 텍스트
/// 스펙)에 따라 Primary/Secondary는 Gowun Batang(SajuType.body)을
/// 써야 하고, 원본 `design_files/saju/screens-b.jsx`가 인라인으로
/// 오버라이드하는 Ghost만 Pretendard(SajuType.ui) 500 14를 써야 한다.
///
/// 이 테스트는 추측이 아니라 실제 위젯 트리에서 `Text` 위젯의
/// `style.fontFamily`/`fontWeight`/`fontSize`를 직접 읽어 검증한다.
void main() {
  Text findLabelText(WidgetTester tester, String label) {
    return tester.widget<Text>(find.text(label));
  }

  testWidgets('B-1: Primary 버튼 라벨은 Gowun Batang 700 16을 쓴다', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SajuButton(
            label: '내 사주 분석하기',
            variant: SajuButtonVariant.primary,
          ),
        ),
      ),
    );
    final text = findLabelText(tester, '내 사주 분석하기');
    expect(
      text.style?.fontFamily,
      SajuType.body, // 'GowunBatang'
      reason: 'B-1/T-cta 위반: Primary 버튼이 Gowun Batang이 아님 '
          '(실제: ${text.style?.fontFamily})',
    );
    expect(text.style?.fontWeight, FontWeight.w700);
    expect(text.style?.fontSize, 16);
  });

  testWidgets('B-1: Secondary 버튼 라벨도 Gowun Batang 700 16을 쓴다 '
      '(docs/02 C-01 Secondary 텍스트 = T-cta와 동일 스펙)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SajuButton(
            label: '복주머니로 보기',
            variant: SajuButtonVariant.secondary,
          ),
        ),
      ),
    );
    final text = findLabelText(tester, '복주머니로 보기');
    expect(text.style?.fontFamily, SajuType.body);
    expect(text.style?.fontWeight, FontWeight.w700);
    expect(text.style?.fontSize, 16);
  });

  testWidgets(
    'B-1: Ghost 버튼(↻ 새로운 이야기)은 원본 screens-b.jsx 인라인 '
    '오버라이드(Pretendard 500 14)를 그대로 따른다',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SajuButton(
              label: '↻ 새로운 이야기',
              variant: SajuButtonVariant.ghost,
              height: 48,
            ),
          ),
        ),
      );
      final text = findLabelText(tester, '↻ 새로운 이야기');
      expect(
        text.style?.fontFamily,
        SajuType.ui, // 'Pretendard'
        reason: 'B-1 위반: Ghost 버튼이 Pretendard가 아님 '
            '(실제: ${text.style?.fontFamily})',
      );
      expect(text.style?.fontWeight, FontWeight.w500);
      expect(text.style?.fontSize, 14);
    },
  );

  testWidgets('B-1: Primary 버튼 높이 56 / radius 14 / glow.cta 그림자', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SajuButton(label: '사주 분석 시작하기', onTap: () {}),
        ),
      ),
    );
    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final size = tester.getSize(find.byType(AnimatedContainer));
    expect(size.height, 56);
    final decoration = container.decoration as BoxDecoration;
    expect((decoration.borderRadius as BorderRadius).topLeft.x, 14);
    expect(decoration.color, SajuGold.g100);
    expect(decoration.boxShadow, isNotNull);
    expect(decoration.boxShadow!.first.color, SajuGold.glow);
  });
}
