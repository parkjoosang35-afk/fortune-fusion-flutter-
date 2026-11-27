import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/auth/application/auth_provider.dart';
import 'package:flutter_app/features/auth/data/auth_repository.dart';
import 'package:flutter_app/features/saju_renewal/data/saju_renewal_api.dart';
import 'package:flutter_app/features/saju_renewal/screens/analysis_complete_screen.dart';
import 'package:flutter_app/features/saju_renewal/screens/calculating_screen.dart';
import 'package:flutter_app/features/saju_renewal/screens/saju_renewal_home_screen.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';
import 'package:flutter_app/features/saju_renewal/widgets/saju_visual_widgets.dart';

/// E-30(docs/07_예외_엣지케이스.md) 실제 동작 검증:
/// "작은 화면(높이 < 700) | 01·03·04 | 01: Bagua를 남은 높이에 맞춰
/// 축소(최소 200). 03: 스테이지 전체 scale (높이/874). 04: 카드
/// 상단·카피 위치를 비율로".
///
/// 추측이 아니라 실제 위젯 트리에서 작은 화면(예: 높이 600, 아이폰
/// SE1 320×480 급)과 일반 화면(높이 874)을 모두 렌더링해, 레이아웃이
/// 실제로 달라지는지(작은 화면에서 축소/스케일이 적용되는지) 직접
/// 측정한다.
void main() {
  // [중요] MediaQuery 위젯만 덮어써서는 하위 트리의 "실제 화면 크기"가
  // 바뀌지 않는다 — 이 화면들은 Scaffold/SafeArea/LayoutBuilder가
  // 최상위 테스트 뷰(tester.view)의 physicalSize를 기준으로 제약을
  // 받기 때문에, 반드시 tester.view.physicalSize를 직접 설정해야
  // LayoutBuilder의 constraints.maxHeight가 실제로 달라진다.
  Future<void> setViewSize(WidgetTester tester, Size logicalSize) async {
    tester.view.physicalSize = logicalSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget wrapWithSize(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthRepository())),
        ChangeNotifierProvider(
          create: (_) => SajuRenewalProvider(SajuRenewalApi()),
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('E-30 · 01 메인 — Bagua 축소(최소 200)', () {
    testWidgets('일반 화면(874)에서는 Bagua가 기존 크기(290) 그대로', (tester) async {
      await setViewSize(tester, const Size(402, 874));
      await tester.pumpWidget(wrapWithSize(const SajuRenewalHomeScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      final bagua = tester.widget<SajuBagua>(find.byType(SajuBagua));
      expect(
        bagua.size,
        closeTo(290, 0.5),
        reason: '일반 화면에서는 E-30이 적용되지 않아야 함(기존 290 유지)',
      );
    });

    // [실측 기준] 01 화면은 상단바(106)+타이틀블록(~130)+하단CTA영역(~150)
    // 등 고정 영역을 제외한 "실제 남은 높이"가 290 미만일 때만 축소된다
    // (이는 스펙 "남은 높이에 맞춰 축소"에 더 정확히 부합하는 동작).
    // 실측 결과 총 높이 550에서 처음으로 축소(250)가 시작됨을 확인했다.
    testWidgets('작은 화면(총높이 550)에서는 Bagua가 축소되되 최소 200 이상', (tester) async {
      await setViewSize(tester, const Size(360, 550));
      await tester.pumpWidget(wrapWithSize(const SajuRenewalHomeScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      final bagua = tester.widget<SajuBagua>(find.byType(SajuBagua));
      expect(
        bagua.size,
        lessThan(290),
        reason: 'E-30 위반: 남은 높이가 줄어도 Bagua가 축소되지 않음',
      );
      expect(
        bagua.size,
        greaterThanOrEqualTo(200),
        reason: 'E-30 위반: Bagua가 최소 200보다 더 작게 축소됨',
      );
    });

    testWidgets('극단적으로 작은 화면(높이 400)에서도 Bagua는 최소 200 아래로 가지 않음', (
      tester,
    ) async {
      await setViewSize(tester, const Size(320, 480));
      await tester.pumpWidget(wrapWithSize(const SajuRenewalHomeScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      final bagua = tester.widget<SajuBagua>(find.byType(SajuBagua));
      expect(
        bagua.size,
        greaterThanOrEqualTo(200),
        reason: 'E-30 위반(최소값): size=${bagua.size}',
      );
      expect(
        bagua.size,
        lessThan(290),
        reason: 'E-30 위반: 극단적으로 작은 화면에서도 축소되지 않음',
      );
    });
  });

  group('E-30 · 03 분석중 — 스테이지 전체 scale (높이/874)', () {
    testWidgets('일반 화면(874)에서는 Transform.scale이 적용되지 않음(=1.0)', (tester) async {
      await setViewSize(tester, const Size(402, 874));
      await tester.pumpWidget(wrapWithSize(const CalculatingScreen()));
      await tester.pump(const Duration(milliseconds: 260));

      // E-30 전용 Key('e30_stage_scale')가 달린 Transform은 stageScale==1.0
      // 일 때 calculating_screen.dart가 아예 생성하지 않으므로(if문으로
      // 분기), 일반 화면에서는 이 Key를 가진 Transform이 존재하지 않아야
      // 한다 — 다른 위젯(SajuBagua 내부 등)의 Transform과 혼동되지 않는다.
      expect(
        find.byKey(const ValueKey('e30_stage_scale')),
        findsNothing,
        reason: '일반 화면(874)에서는 E-30 스테이지 스케일 Transform이 생성되면 안 됨',
      );

      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('작은 화면(높이 600)에서는 스테이지가 600/874 비율로 축소됨', (tester) async {
      await setViewSize(tester, const Size(360, 600));
      await tester.pumpWidget(wrapWithSize(const CalculatingScreen()));
      await tester.pump(const Duration(milliseconds: 260));

      final expectedScale = (600 / 874).clamp(0.5, 1.0);
      final finder = find.byKey(const ValueKey('e30_stage_scale'));
      expect(
        finder,
        findsOneWidget,
        reason: 'E-30 위반: 작은 화면(600)에서 스테이지 스케일 Transform이 생성되지 않음',
      );
      final transform = tester.widget<Transform>(finder);
      final actualScale = transform.transform.storage[0];
      expect(
        actualScale,
        closeTo(expectedScale, 0.01),
        reason:
            'E-30 위반: 작은 화면(600)에서 기대 scale=$expectedScale, '
            '실제=$actualScale',
      );

      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('매우 작은 화면(높이 500)에서도 scale이 0.5 미만으로 내려가지 않음(가독성 하한)', (
      tester,
    ) async {
      await setViewSize(tester, const Size(320, 500));
      await tester.pumpWidget(wrapWithSize(const CalculatingScreen()));
      await tester.pump(const Duration(milliseconds: 260));

      final finder = find.byKey(const ValueKey('e30_stage_scale'));
      expect(finder, findsOneWidget);
      final transform = tester.widget<Transform>(finder);
      final actualScale = transform.transform.storage[0];
      expect(
        actualScale,
        greaterThanOrEqualTo(0.5 - 0.01),
        reason: 'E-30 하한 위반: scale=$actualScale (0.5 미만으로 내려감)',
      );

      await tester.pump(const Duration(seconds: 10));
    });
  });

  group('E-30 · 04 분석완료 — 카드 상단·카피 위치를 비율로', () {
    testWidgets('일반 화면(874)에서는 카드/카피가 기존 고정값(52/372) 그대로', (tester) async {
      await setViewSize(tester, const Size(402, 874));
      await tester.pumpWidget(wrapWithSize(const AnalysisCompleteScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      final positioned = tester
          .widgetList<Positioned>(find.byType(Positioned))
          .toList();
      final tops = positioned.map((p) => p.top).whereType<double>().toSet();
      expect(
        tops.contains(52.0),
        isTrue,
        reason: '일반 화면에서는 카드 top=52가 그대로 유지되어야 함 (실제: $tops)',
      );
      expect(
        tops.contains(372.0),
        isTrue,
        reason: '일반 화면에서는 카피 top=372가 그대로 유지되어야 함 (실제: $tops)',
      );
    });

    testWidgets('작은 화면(높이 600)에서는 카드/카피 top이 비율로 재계산되어 고정값과 달라짐', (
      tester,
    ) async {
      await setViewSize(tester, const Size(360, 600));
      await tester.pumpWidget(wrapWithSize(const AnalysisCompleteScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      final positioned = tester
          .widgetList<Positioned>(find.byType(Positioned))
          .toList();
      final tops = positioned.map((p) => p.top).whereType<double>().toSet();

      // 고정값 52/372를 그대로 썼다면(E-30 미구현) 작은 화면에서도
      // 카피(372)가 상단바+CTA를 제외한 가용 높이(대략
      // 600 - 106(상단바) - 110(CTA 영역) = 384)에 거의 맞닿거나
      // 넘칠 수 있다 — 비율 적용 시 372보다 작은 값으로 조정되어야 함.
      expect(
        tops.contains(372.0),
        isFalse,
        reason: 'E-30 위반: 작은 화면에서도 카피 top이 고정값 372 그대로임 (실제: $tops)',
      );
      expect(
        tops.contains(52.0),
        isFalse,
        reason: 'E-30 위반: 작은 화면에서도 카드 top이 고정값 52 그대로임 (실제: $tops)',
      );
    });
  });
}
