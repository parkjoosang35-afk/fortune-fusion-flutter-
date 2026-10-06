import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/auth/application/auth_provider.dart';
import 'package:flutter_app/features/auth/data/auth_repository.dart';
import 'package:flutter_app/features/saju_renewal/data/saju_renewal_api.dart';
import 'package:flutter_app/features/saju_renewal/screens/calculating_screen.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';

/// E-22(docs/07_예외_엣지케이스.md) / C-03a(docs/08_QA_체크리스트.md)
/// 실제 동작 검증: "03 중 시스템 뒤로가기: 무시 (스킵 불가)".
///
/// 이 테스트는 추측이 아니라 실제 위젯 트리에서
/// [WidgetsBinding.instance.handlePopRoute]를 호출해(= 시스템
/// 뒤로가기 제스처/버튼이 플랫폼 채널을 통해 Flutter에 전달되는 실제
/// 경로와 동일) 03(CalculatingScreen)이 화면에 그대로 남아 있는지
/// (= pop되지 않았는지)를 직접 측정한다.
///
/// [중요] 반드시 MaterialApp이 자체적으로 만드는 최상위 Navigator의
/// 스택 위에 CalculatingScreen을 push해야 한다 — WidgetsApp.didPopRoute
/// 는 오직 그 최상위 Navigator에게만 maybePop()을 위임하므로, 별도의
/// 중첩 Navigator를 만들면 PopScope가 등록된 ModalRoute와 다른
/// 레이어가 되어 핸들러가 올바르게 연결되지 않는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(AuthRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => SajuRenewalProvider(SajuRenewalApi()),
        ),
      ],
      child: const MaterialApp(home: _FakePreviousScreen()),
    );
  }

  testWidgets(
    'E-22/C-03a: 시스템 뒤로가기(handlePopRoute)를 호출해도 '
    '03(CalculatingScreen)은 pop되지 않고 화면에 그대로 남는다',
    (tester) async {
      await tester.pumpWidget(wrap());
      expect(find.byType(_FakePreviousScreen), findsOneWidget);

      // 02(가짜 이전 화면) → 03(CalculatingScreen)으로, MaterialApp의
      // 최상위 Navigator에 직접 push한다.
      final navContext = tester.element(find.byType(_FakePreviousScreen));
      Navigator.of(navContext).push(
        MaterialPageRoute(builder: (_) => const CalculatingScreen()),
      );
      // pumpAndSettle은 쓰지 않는다 — CalculatingScreen 내부에
      // repeat(reverse: true)로 무한 반복되는 애니메이션(_PulsingDot
      // 등)이 있어 "settle"이 영원히 끝나지 않는다. 대신 push 전환
      // 애니메이션(기본 300ms)만큼만 고정 시간을 흘려보낸다.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.byType(CalculatingScreen),
        findsOneWidget,
        reason: '03 화면이 정상적으로 push되어 있어야 함',
      );
      expect(find.byType(_FakePreviousScreen), findsNothing);

      // ── 실제 시스템 뒤로가기 경로를 그대로 호출 ──────────────────
      // (Android 백버튼/제스처가 플랫폼 채널로 'popRoute'를 보내면
      // WidgetsBindingObserver.didPopRoute() → handlePopRoute()가
      // 호출되는 것과 동일한 경로.)
      final handled = await tester.binding.handlePopRoute();
      await tester.pump();

      // PopScope(canPop: false)가 있으면 해당 라우트의 popDisposition이
      // doNotPop이 되어 Navigator.maybePop()이 "소비했다"(true)고
      // 보고하면서도 실제 pop은 일어나지 않아야 한다 — 03 화면이
      // 여전히 떠 있어야 한다.
      expect(
        handled,
        isTrue,
        reason:
            'E-22 위반: PopScope가 뒤로가기를 가로채지 못함 '
            '(handlePopRoute가 false를 반환 = 아무도 소비하지 않음 → '
            '최상위까지 bubble되어 앱 종료 시도로 이어짐)',
      );
      expect(
        find.byType(CalculatingScreen),
        findsOneWidget,
        reason:
            'E-22 위반: 시스템 뒤로가기로 03 화면이 pop되어 사라짐 '
            '(무시되어야 하는데 실제로 이동함)',
      );
      expect(
        find.byType(_FakePreviousScreen),
        findsNothing,
        reason: 'E-22 위반: 뒤로가기로 02(이전) 화면이 다시 노출됨',
      );

      // 세레모니 내부 타이머 정리 (flutter_test의 "보류 타이머"
      // assertion 회피 목적 — 기능 검증과는 무관).
      await tester.pump(const Duration(seconds: 10));
    },
  );

  testWidgets(
    '대조군: PopScope가 없는 일반 화면(_FakePreviousScreen 위에 쌓인 '
    '또다른 일반 화면)은 시스템 뒤로가기로 정상적으로 pop된다 — 이 '
    '테스트 자체(handlePopRoute 측정 방식)가 유효함을 검증',
    (tester) async {
      await tester.pumpWidget(wrap());
      final navContext = tester.element(find.byType(_FakePreviousScreen));
      Navigator.of(navContext).push(
        MaterialPageRoute(builder: (_) => const _FakePlainScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(_FakePlainScreen), findsOneWidget);

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(
        find.byType(_FakePlainScreen),
        findsNothing,
        reason: 'PopScope가 없는 일반 화면은 뒤로가기로 정상 pop되어야 함',
      );
      expect(find.byType(_FakePreviousScreen), findsOneWidget);
    },
  );
}

class _FakePreviousScreen extends StatelessWidget {
  const _FakePreviousScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('FAKE_PREVIOUS_SCREEN')));
  }
}

class _FakePlainScreen extends StatelessWidget {
  const _FakePlainScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('FAKE_PLAIN_SCREEN')));
  }
}
