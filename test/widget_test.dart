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
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/app.dart';
import 'package:flutter_app/features/auth/presentation/splash_screen.dart';
import 'package:flutter_app/features/shrine/shrine_module.dart';

void main() {
  setUp(() async {
    // [기존 결함 수정] app.dart가 Provider 트리를 구성할 때
    // ChangeNotifierProvider(create: (_) => ShrineSessionProvider(ShrineModule.prefs))
    // 가 등록되는데, 이 등록 자체가 `ShrineModule.prefs`(static late 필드) 값을
    // "읽어서" 넘기는 것이므로, main()의 `await ShrineModule.init()`을 거치지
    // 않고 바로 App()을 pump하면 LateInitializationError가 발생한다
    // (U11 2~3단계 작업과 무관한 사전 존재 결함, flutter test 전체 실행 시 발견).
    // SharedPreferences를 목(mock) 초기화한 뒤 ShrineModule.prefs에 직접
    // 할당해, 실제 main()의 초기화 순서를 테스트에서도 재현한다.
    SharedPreferences.setMockInitialValues({});
    ShrineModule.prefs = await SharedPreferences.getInstance();
  });

  testWidgets('App boots and shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pump();

    // 최신 스플래시는 네 글자 워드마크를 개별 위젯으로 표시한다.
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.bySemanticsLabel('신통방통'), findsOneWidget);

    // [타이머 정리] SplashScreen._bootstrap()이 addPostFrameCallback으로 예약한
    // Future.wait(...Future.delayed(1300ms)...)이 테스트 종료 시점까지 남아있으면
    // "A Timer is still pending even after the widget tree was disposed."
    // assertion이 발생한다. pump(duration)은 flutter_test의 FakeAsync 클럭을
    // 전진시켜 그 Future.delayed를 실제로 완료시키므로, 애니메이션/부트스트랩
    // 타이머가 전부 해소될 만큼 충분히 흘려보낸 뒤 테스트를 마친다.
    //
    // [기존 결함 수정 — pumpAndSettle timed out] 위 ShrineModule.prefs 수정으로
    // LateInitializationError가 해소되자, 이번에는 부트스트랩이 실제로 끝까지
    // 진행되어 스플래시 이후 홈 화면(SintongHomeV2Screen의 배너 캐러셀)까지
    // 전환된다. 그 캐러셀은 `..repeat()`로 끝나지 않는 AnimationController를
    // 여러 개 띄우므로(home_banner_carousel.dart), "모든 애니메이션이 멈출
    // 때까지" 기다리는 pumpAndSettle()은 영원히 끝나지 않아 타임아웃된다.
    // 이 테스트의 목적은 스플래시 표시 확인 + 대기 중인 타이머 정리이지
    // "앱 전체가 완전히 정적 상태가 될 때까지 기다리는 것"이 아니므로,
    // 무한 반복 애니메이션에 영향받지 않는 고정 시간 pump로 대체한다.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 200));
  });
}
