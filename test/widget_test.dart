// Fortune Fusion 앱 기본 스모크 테스트
// 앱이 크래시 없이 기동하여 SplashScreen이 표시되는지 확인한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/app.dart';

void main() {
  testWidgets('App boots and shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pump();

    expect(find.text('Fortune Fusion'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
