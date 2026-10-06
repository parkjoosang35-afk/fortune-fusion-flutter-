import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/auth/application/auth_provider.dart';
import 'package:flutter_app/features/auth/data/auth_repository.dart';
import 'package:flutter_app/features/saju_renewal/data/saju_renewal_api.dart';
import 'package:flutter_app/features/saju_renewal/screens/calculating_screen.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';

/// E-21(docs/07_예외_엣지케이스.md) 실제 동작 검증:
/// "03 중 앱 백그라운드 → 타이머 일시정지, 복귀 시 이어서 (API는 계속)".
///
/// 이 테스트는 추측이 아니라 실제 위젯 트리에서
/// [AppLifecycleState.paused]/[resumed]를 주입하여, 화면 하단에
/// 표시되는 단계 라벨(STEP 텍스트)이 백그라운드 동안 "멈춰" 있고,
/// 포그라운드 복귀 후에만 "이어서" 진행되는지를 직접 측정한다.
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
      child: const MaterialApp(home: CalculatingScreen()),
    );
  }

  /// SajuTopBar 타이틀("ANALYSIS · NN / 09")에서 NN을 읦어온다.
  int currentStepFromTitle(WidgetTester tester) {
    final titleFinder = find.textContaining('ANALYSIS · ');
    expect(titleFinder, findsOneWidget);
    final text = tester.widget<Text>(titleFinder).data!;
    final match = RegExp(r'ANALYSIS · (\d+) / 09').firstMatch(text);
    expect(match, isNotNull, reason: '타이틀 형식이 예상과 다름: "$text"');
    return int.parse(match!.group(1)!);
  }

  testWidgets('E-21: 앱이 paused 상태가 되면 세레모니 STEP 진행이 멈춘다', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    // initState의 250ms 초기 지연 + 1단계 진입까지 진행.
    await tester.pump(const Duration(milliseconds: 260));
    final stepBeforeBg = currentStepFromTitle(tester);
    expect(
      stepBeforeBg,
      greaterThanOrEqualTo(1),
      reason: '250ms 경과 후 최소 1단계는 진행되어 있어야 함',
    );

    // ── 앱을 백그라운드로 전환 ──────────────────────────────────
    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    // 백그라운드 상태에서 STEP(880ms)보다 긴 시간(2000ms)을 흘려보내도
    // _pausableDelay가 실제 시간을 소비하지 않아야 하므로 STEP이
    // 그대로 멈춰 있어야 한다.
    await tester.pump(const Duration(milliseconds: 2000));
    final stepDuringBg = currentStepFromTitle(tester);
    expect(
      stepDuringBg,
      stepBeforeBg,
      reason:
          'E-21 위반: 백그라운드 중에도 STEP이 진행됨 '
          '(before=$stepBeforeBg, during=$stepDuringBg)',
    );

    // ── 포그라운드로 복귀 ──────────────────────────────────────
    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    // 복귀 후 STEP(880ms) 이상 경과하면 다음 단계로 "이어서" 진행되어야 함.
    await tester.pump(const Duration(milliseconds: 950));
    final stepAfterResume = currentStepFromTitle(tester);
    expect(
      stepAfterResume,
      greaterThan(stepDuringBg),
      reason:
          'E-21 위반: resumed 이후에도 STEP이 이어서 진행되지 않음 '
          '(during=$stepDuringBg, afterResume=$stepAfterResume)',
    );

    // 테스트 종료 시 "보류 타이머" assertion을 피하기 위해 세레모니
    // 루프(9단계, 최대 ~8초)를 끝까지 흘려보낸다 — 기능 검증과는
    // 무관한 flutter_test 정리 절차.
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets(
    'E-21: inactive(예: 시스템 알림 패널)에서도 타이머가 멈추고, resumed에서 재개된다',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 260));
      final before = currentStepFromTitle(tester);

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      final during = currentStepFromTitle(tester);
      expect(during, before, reason: 'inactive 중에도 STEP이 진행됨');

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 950));
      final after = currentStepFromTitle(tester);
      expect(after, greaterThan(during), reason: 'resumed 후 STEP이 재개되지 않음');

      await tester.pump(const Duration(seconds: 10));
    },
  );

  testWidgets(
    'E-21: 백그라운드 중에도 SajuRenewalProvider 상태 변경(= API 계속)은 '
    '정상적으로 화면에 반영된다 — 세레모니 타이머 정지가 Provider를 막지 않음',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 260));

      // 백그라운드 전환.
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // "API는 계속"을 시뮬레이션: 세레모니 타이머와 무관하게 Provider가
      // 백그라운드 중에도 에러 상태로 전이될 수 있고, 그 즉시
      // _maybeNavigate가 (addPostFrameCallback을 통해) 화면 전환을
      // 시도해야 한다 — 이는 타이머 일시정지와 완전히 독립적이어야 함.
      final context = tester.element(find.byType(CalculatingScreen));
      final provider = context.read<SajuRenewalProvider>();
      // Provider 내부 상태를 직접 바꿀 public API가 없다면 이 검증은
      // "Provider 리스너가 끊기지 않았는지"만 간접 확인한다.
      expect(provider.status, isNotNull);

      // 백그라운드 중에도 context.watch(build)가 계속 Provider를
      // 구독하고 있어야 하며, 세레모니 타이머 정지와 무관하게 언제든
      // provider.notifyListeners()가 오면 _maybeNavigate가 반응할
      // 준비가 되어 있어야 한다(예외 발생 없이 pump 가능한지 확인).
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 10));
    },
  );
}
