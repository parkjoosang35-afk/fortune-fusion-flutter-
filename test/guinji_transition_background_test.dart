import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/guinji/navigation/guinji_page_route.dart';
import 'package:flutter_app/core/router/global_bottom_nav_shell.dart';

void main() {
  testWidgets('귀인지도 전역 셸과 전환 여백은 밝은 테마를 노출하지 않는다', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey:nav, theme:ThemeData(scaffoldBackgroundColor:Colors.white),
      home:const Scaffold(backgroundColor:Color(0xFF0B0B0D),body:Text('귀인지도 소개'))));
    final wrapped = wrapWithGlobalBottomNav('/guinji-map/new', const Scaffold(backgroundColor:Color(0xFF0B0B0D),body:Text('정보 입력')));
    expect((wrapped as Scaffold).backgroundColor,const Color(0xFF0B0B0D));
    nav.currentState!.push(guinjiPageRoute(wrapped));
    await tester.pump();
    await tester.pump(const Duration(milliseconds:50));
    final transitions = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
    expect(transitions.any((box)=>box.color==const Color(0xFF0B0B0D)),true);
    expect(find.text('정보 입력'),findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
  });
}
