import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/router/global_bottom_nav_shell.dart';
import 'package:flutter_app/core/widgets/midnight_bottom_nav.dart';

/// [전역 하단바 자동 부착 — 사용자 요청 2026-10-14]
/// "소원방만 빼고 모든 화면에 하단바" — named route는 자동 부착, 제외
/// 목록(소원방·가입 전 화면·홈셸)과 이름 없는 직접 push는 그대로 유지.
void main() {
  Widget host(String? name) => MaterialApp(
    home: wrapWithGlobalBottomNav(name, const Scaffold(body: SizedBox())),
  );

  testWidgets('일반 라우트는 전역 하단바가 자동 부착된다', (tester) async {
    await tester.pumpWidget(host('/reward/wallet'));
    expect(find.byType(MidnightBottomNavBar), findsOneWidget);
    expect(tester.takeException(), null);
  });

  for (final name in const [
    '/home',
    '/splash',
    '/intro',
    '/onboarding',
    '/login',
    '/signup',
    '/policy/notice',
    '/wish-room',
    '/wish-wall',
  ]) {
    testWidgets('$name 는 제외 목록이라 하단바 없이 유지된다', (tester) async {
      await tester.pumpWidget(host(name));
      expect(find.byType(MidnightBottomNavBar), findsNothing);
      expect(tester.takeException(), null);
    });
  }

  testWidgets('이름 없는 직접 push 화면은 감싸지 않는다(기존 수동바 유지)', (tester) async {
    await tester.pumpWidget(host(null));
    expect(find.byType(MidnightBottomNavBar), findsNothing);
    expect(tester.takeException(), null);
  });
}
