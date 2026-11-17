import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/theme/text_scale_provider.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_deep_result_screen.dart';
import 'package:flutter_app/features/guinji/domain/guinji_person.dart';
import 'package:flutter_app/features/guinji/widgets/guinji_map_widgets.dart'
    show GmTempleBg;

void main() {
  testWidgets('귀인지도 상세의 캡처 영역은 화면 뷰포트가 아닌 전체 본문', (tester) async {
    // [2026-11-14 나머지 실패 조사] GuinjiDeepResultScreen이 "결과페이지
    // 글씨 확대" 기능(커밋 e294710f, 이 테스트보다 나중에 추가됨)의
    // ResultTextScaleOverlay(TextScaleProvider 필요)로 감싸져
    // ProviderNotFoundException이 발생했다 — 캡처 영역 크기 계약 자체의
    // 버그가 아니라 테스트 인프라가 신규 기능을 따라가지 못한 것이다.
    //
    // [QA_CHECKLIST §1 전역 1 — 배경 bgGlow, 단색 0곳] RepaintBoundary.child가
    // 단색 ColoredBox에서 Stack([Positioned.fill(GmTempleBg()), Column(본문)])으로
    // 바뀌었다(guinji_map_relation_detail_screen.dart와 동일 패턴) — 캡처 영역이
    // 여전히 전체 본문 높이를 갖는다는 본질적 계약은 유지하되, 구조 단언을
    // 새 구조에 맞게 갱신한다.
    await tester.pumpWidget(ChangeNotifierProvider<TextScaleProvider>(
      create: (_) => TextScaleProvider(),
      child: MaterialApp(home:GuinjiDeepResultScreen(person:const GuinjiPerson(
        id:'test',name:'검수',birth:'1995·05·15',ohaeng:'mok',relation:'BI_HWA',score:70,note:'검수',
      ))),
    ));
    await tester.pump();
    final scroll=find.byType(SingleChildScrollView);
    expect(scroll, findsOneWidget);
    expect(tester.widget<SingleChildScrollView>(scroll).child, isA<RepaintBoundary>());
    final boundary=(tester.widget<SingleChildScrollView>(scroll).child as RepaintBoundary);
    expect(boundary.child,isA<Stack>());
    final stack=boundary.child as Stack;
    expect(stack.children.whereType<Positioned>().any(
      (p) => p.child is GmTempleBg,
    ), isTrue, reason: '배경 레이어로 GmTempleBg가 Positioned.fill로 깔려 있어야 한다');
    expect(stack.children.whereType<Column>(), isNotEmpty,
        reason: '본문 Column이 캡처 대상에 그대로 포함돼 있어야 한다');
    final rect=tester.getSize(find.byWidget(boundary));
    expect(rect.height,greaterThan(tester.view.physicalSize.height/tester.view.devicePixelRatio));
    expect(tester.takeException(),isNull);
  });
  test('결과 화면은 개별 이미지 전송·문구 대체 호출을 남기지 않는다', () {
    for(final path in [
      'lib/features/fortune/tarot/presentation/tarot_result_screen.dart',
      'lib/features/guinji/presentation/guinji_result_card_screen.dart',
      'lib/features/guinji/presentation/guinji_deep_result_screen.dart',
      'lib/features/guinji/presentation/guinji_map_relation_detail_screen.dart',
    ]) {
      final text=File(path).readAsStringSync();
      final executable=text.split('\n').where((line)=>!line.trimLeft().startsWith('//')).join('\n');
      expect(executable, isNot(contains('await Share.shareXFiles')),reason:path);
      expect(executable, isNot(contains('await safeShareText')),reason:path);
      expect(executable, isNot(contains('_legacyViewportStitch')),reason:path);
    }
  });
}
