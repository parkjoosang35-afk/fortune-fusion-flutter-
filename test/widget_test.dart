// 신통방통(Fortune Fusion) 앱 기본 스모크 테스트
// 앱이 크래시 없이 기동하여 SplashScreen이 표시되는지 확인한다.
//
// [2026-08 갱신] 인트로 전면 개편(커밋 e1406f7)으로 SplashScreen이
// "Fortune Fusion" 텍스트 + CircularProgressIndicator 조합에서
// 로고 아이콘 + "신통방통" 타이틀 + FadeTransition 조합으로 교체됐으나
// 이 테스트가 갱신되지 않아 실패하고 있었다. 현재 SplashScreen
// (lib/features/auth/presentation/splash_screen.dart)의 실제 렌더링
// 내용에 맞춰 검증 대상을 갱신한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/app.dart';

void main() {
  testWidgets('App boots and shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pump();

    expect(find.text('신통방통'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);

    // [타이머 정리] SplashScreen._bootstrap()이 addPostFrameCallback으로 예약한
    // Future.wait(...Future.delayed(1300ms)...)이 테스트 종료 시점까지 남아있으면
    // "A Timer is still pending even after the widget tree was disposed."
    // assertion이 발생한다. pump(duration)은 flutter_test의 FakeAsync 클럭을
    // 전진시켜 그 Future.delayed를 실제로 완료시키므로, 애니메이션/부트스트랩
    // 타이머가 전부 해소될 만큼 충분히 흘려보낸 뒤 테스트를 마친다.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
  });
}
