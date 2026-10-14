import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_deep_result_screen.dart';
import 'package:flutter_app/features/guinji/domain/guinji_person.dart';

void main() {
  testWidgets('귀인지도 상세의 캡처 영역은 화면 뷰포트가 아닌 전체 본문', (tester) async {
    await tester.pumpWidget(MaterialApp(home:GuinjiDeepResultScreen(person:const GuinjiPerson(
      id:'test',name:'검수',birth:'1995·05·15',ohaeng:'mok',relation:'BI_HWA',score:70,note:'검수',
    ))));
    await tester.pump();
    final scroll=find.byType(SingleChildScrollView);
    expect(scroll, findsOneWidget);
    expect(tester.widget<SingleChildScrollView>(scroll).child, isA<RepaintBoundary>());
    final boundary=(tester.widget<SingleChildScrollView>(scroll).child as RepaintBoundary);
    expect(boundary.child,isA<ColoredBox>());
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
