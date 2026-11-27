import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/saju_renewal/widgets/saju_story_widgets.dart';

/// C-05d(docs/08_QA_체크리스트.md) 실제 동작 검증.
///
/// docs/02_컴포넌트.md §C-07 "점선 밑줄(주기 4pt 중 2pt 대시) 탭 → TermSheet,
/// 한자 병기는 시트 안에서만" + "미등록 termKey: 밑줄·탭 없이 쉬운 표현만
/// 렌더 + 에러 로그(크래시 금지)"(E-24, docs/07_예외_엣지케이스.md) 규정이
/// [SajuTermText]에서 실제로 동작하는지 측정한다.
void main() {
  Widget host(String text) {
    return MaterialApp(
      home: Scaffold(
        body: SajuTermScope(
          onOpenTerm: (_) {},
          child: SajuTermText(text: text),
        ),
      ),
    );
  }

  // [SajuTermText]는 Text가 아니라 RichText(TextSpan)로 렌더되므로
  // find.text/find.textContaining(Text 전용)이 아니라 RichText의
  // 평문(toPlainText)을 직접 비교하는 전용 finder가 필요하다.
  Finder findRichTextContaining(String substring) {
    return find.byWidgetPredicate((widget) {
      if (widget is RichText) {
        return widget.text.toPlainText().contains(substring);
      }
      return false;
    });
  }

  testWidgets('C-05d 등록된 termKey: 한자 원어(用神)는 본문에 노출되지 않고 '
      '쉬운 표현(용신 설명)만 밑줄 위젯으로 렌더된다', (tester) async {
    await tester.pumpWidget(host('이건 [[yongshin|용신 설명]]과 관련 있어요.'));
    await tester.pump();

    // A-5/A-6 원칙: 1차 문장에 사주 원어(한자)가 노출되면 안 된다.
    expect(findRichTextContaining('用神'), findsNothing);
    // 쉬운 표현은 노출되어야 한다('?' 뱃지가 같은 RichText 안에 있으므로
    // 평문 부분 매칭으로 확인).
    expect(findRichTextContaining('용신 설명'), findsOneWidget);
  });

  testWidgets('C-05d 등록된 termKey: 밑줄이 점선(CustomPaint)으로 그려진다 '
      '(실선 Border가 아니다)', (tester) async {
    await tester.pumpWidget(host('이건 [[yongshin|용신 설명]]과 관련 있어요.'));
    await tester.pump();

    // _DashedUnderline은 CustomPaint로 구현되어 있어야 한다.
    final customPaintFinder = find.descendant(
      of: find.byType(SajuTermText),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.foregroundPainter != null,
      ),
    );
    expect(customPaintFinder, findsOneWidget);
  });

  testWidgets(
    'C-05d 등록된 termKey: 탭하면 onOpenTerm(key)가 호출된다 (TermSheet 오픈 트리거)',
    (tester) async {
      String? openedKey;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SajuTermScope(
              onOpenTerm: (key) => openedKey = key,
              child: const SajuTermText(text: '이건 [[daewoon|대운 설명]]과 관련 있어요.'),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(findRichTextContaining('대운 설명'));
      await tester.pump();

      expect(openedKey, 'daewoon');
    },
  );

  testWidgets('C-05d/E-24 미등록 termKey: 밑줄·탭 없이 쉬운 표현 텍스트만 '
      '일반 텍스트로 렌더된다(크래시 없음)', (tester) async {
    // 'not_a_real_key'는 sajuTermLookup()에 존재하지 않는 키.
    await tester.pumpWidget(host('이건 [[not_a_real_key|미등록 용어 표현]]과 관련 있어요.'));
    await tester.pump();

    // 쉬운 표현은 그대로 노출되어야 한다.
    expect(findRichTextContaining('미등록 용어 표현'), findsOneWidget);

    // 미등록 키는 WidgetSpan(GestureDetector+CustomPaint)으로 감싸지지
    // 않아야 한다 — 즉 SajuTermText 하위에 CustomPaint(점선)가 없어야 함.
    final customPaintFinder = find.descendant(
      of: find.byType(SajuTermText),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.foregroundPainter != null,
      ),
    );
    expect(customPaintFinder, findsNothing);

    // 탭해도 예외 없이 동작해야 한다(GestureDetector 자체가 없으므로
    // 탭 대상이 없음 — 크래시 없이 프레임이 유지되는지만 확인).
    expect(tester.takeException(), isNull);
  });

  testWidgets('C-05d 혼합: 등록 termKey와 미등록 termKey가 섞여 있어도 '
      '등록된 것만 밑줄+탭이 생긴다', (tester) async {
    await tester.pumpWidget(
      host('[[yongshin|용신 설명]] 그리고 [[unknown_term|모르는 용어]]가 같이 있어요.'),
    );
    await tester.pump();

    expect(findRichTextContaining('용신 설명'), findsOneWidget);
    expect(findRichTextContaining('모르는 용어'), findsOneWidget);

    // 점선 CustomPaint는 등록된 termKey 1개에 대해서만 생성되어야 한다.
    final customPaintFinder = find.descendant(
      of: find.byType(SajuTermText),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.foregroundPainter != null,
      ),
    );
    expect(customPaintFinder, findsOneWidget);
  });

  testWidgets('E-25 마크업 깨짐(`[[` 미닫힘): 원문(`[[`, `]]`, `|키`)이 그대로 '
      '노출되지 않고 제거된 텍스트만 보인다', (tester) async {
    // 닫힘이 `]]`가 아니라 `]` 하나뿐인 깨진 마크업 → 정규식이 매치하지
    // 못해 평문 구간으로 떨어진다.
    await tester.pumpWidget(host('이건 [[yongshin|용신 설명]과 관련 있어요.'));
    await tester.pump();

    // 원문 마크업 토큰이 그대로 노출되면 안 된다.
    expect(findRichTextContaining('[['), findsNothing);
    expect(findRichTextContaining('yongshin|'), findsNothing);
    // 쉬운 표현 텍스트는 보존되어야 한다.
    expect(findRichTextContaining('용신 설명'), findsOneWidget);
  });

  testWidgets('E-25 마크업 깨짐: `[[`만 있고 전혀 닫히지 않은 경우도 '
      '원문 그대로 노출되지 않는다', (tester) async {
    await tester.pumpWidget(host('이건 [[broken 미닫힘 텍스트.'));
    await tester.pump();

    expect(findRichTextContaining('[['), findsNothing);
    expect(findRichTextContaining('미닫힘 텍스트'), findsOneWidget);
  });
}
