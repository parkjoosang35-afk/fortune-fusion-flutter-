import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/wishroom/core/wr_nav_pill.dart';
import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';

class Repo implements WrRepository {
  @override dynamic noSuchMethod(Invocation i) => throw UnsupportedError('${i.memberName}');
}
void main() {
  testWidgets('작성 화면을 거친 캐릭터 하단 이동은 작성 화면이 아니라 셸로 복귀', (tester) async {
    final key = GlobalKey<NavigatorState>();
    final p = WishRoomProvider(Repo());
    await tester.pumpWidget(ChangeNotifierProvider.value(value:p, child:MaterialApp(
      navigatorKey:key, home:const Scaffold(body:Text('앱 홈')),
    )));
    key.currentState!.push(MaterialPageRoute(settings:const RouteSettings(name:'/wishroom-shell'), builder:(_) => const Scaffold(body:Text('소원방 셸'))));
    await tester.pumpAndSettle();
    key.currentState!.push(MaterialPageRoute(builder:(_) => const Scaffold(body:Text('작성 화면'))));
    await tester.pumpAndSettle();
    key.currentState!.push(MaterialPageRoute(builder:(context) => Scaffold(body:TextButton(
      onPressed:()=>wrReturnToTab(context,3), child:const Text('꾸미기로'),
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('꾸미기로'));
    await tester.pumpAndSettle();
    expect(find.text('소원방 셸'), findsOneWidget);
    expect(find.text('작성 화면'), findsNothing);
    expect(p.requestedTabIndex,3);
  });
}
