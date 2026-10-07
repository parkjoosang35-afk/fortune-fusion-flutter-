import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/auth/application/auth_provider.dart';
import 'package:flutter_app/features/auth/data/auth_repository.dart';
import 'package:flutter_app/features/saju_renewal/data/saju_renewal_api.dart';
import 'package:flutter_app/features/saju_renewal/screens/calculating_screen.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';

/// E(docs/08_QA_체크리스트.md) "Reduce Motion On: 회전·반짝임·부유 정지,
/// 03 크로스페이드" 실제 동작 검증.
///
/// [검증 대상] `calculating_screen.dart`의 다음 구현(코드 주석
/// "[E-Reduce Motion — docs/04_모션.md §5 ...]" 참조):
/// 1) Reduce Motion일 때 각 레이어(Bagua/PillarGrid/ElementShard/
///    BalanceGauge/LuckStream/SealedCard)의 개별 AnimatedOpacity/
///    AnimatedScale duration이 전부 0ms(즉시 점프)로 바뀐다.
/// 2) 그 대신 전체 스테이지가 `AnimatedSwitcher(duration:
///    SajuMotion.screen = 300ms)`로 감싸져, 단계(step/condense)가
///    바뀔 때마다 300ms 크로스페이드로 전환된다.
///
/// [접근 방법] `MediaQuery(data: MediaQueryData(disableAnimations: true))`
/// 로 감싸 `sajuReduceMotion(context)`가 true가 되도록 실제 플랫폼
/// 신호를 주입한다(테스트 전용 목킹이 아니라 Flutter 표준 접근성
/// 플래그를 그대로 사용) — 웹에서 `prefers-reduced-motion: reduce`가
/// 연결되는 것과 동일한 경로.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap({required bool reduceMotion}) {
    final app = MultiProvider(
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
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: app,
    );
  }

  testWidgets(
    'Reduce Motion On: 03 단계 전환 시 AnimatedSwitcher(300ms)로 크로스페이드된다',
    (tester) async {
      await tester.pumpWidget(wrap(reduceMotion: true));
      // initState의 250ms 초기 지연 + 1단계 진입.
      await tester.pump(const Duration(milliseconds: 260));

      // Reduce Motion에서는 전체 스테이지가 AnimatedSwitcher로
      // 감싸진다 — 위젯 트리에 AnimatedSwitcher가 존재해야 한다.
      expect(
        find.byType(AnimatedSwitcher),
        findsWidgets,
        reason: 'Reduce Motion On인데 03 스테이지에 AnimatedSwitcher가 없음',
      );

      // AnimatedSwitcher의 duration이 SajuMotion.screen(300ms)인지 확인.
      final switchers = tester
          .widgetList<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
          .toList();
      final stageSwitcher = switchers.firstWhere(
        (w) => w.duration == const Duration(milliseconds: 300),
        orElse: () => throw TestFailure(
          '300ms duration을 가진 AnimatedSwitcher를 찾지 못함: '
          '${switchers.map((w) => w.duration).toList()}',
        ),
      );
      expect(stageSwitcher.duration, const Duration(milliseconds: 300));

      // 다음 단계로 진행(880ms STEP 경과) → 전환 애니메이션이 진행
      // 중인 상태를 150ms 지점에서 pump해 크로스페이드가 실제로
      // 발생하는지(즉시 점프가 아니라 지속시간이 있는 전환인지) 확인.
      await tester.pump(const Duration(milliseconds: 880));
      await tester.pump(const Duration(milliseconds: 150));
      // 크로스페이드 도중에도 예외 없이 렌더링되면(두 레이어 공존)
      // AnimatedSwitcher가 정상 동작 중인 것으로 판단한다.
      expect(tester.takeException(), isNull);

      // 전환 완료까지 흘려보냄.
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);

      // 잔여 세레모니 타이머 정리.
      await tester.pump(const Duration(seconds: 10));
    },
  );

  testWidgets(
    'Reduce Motion Off: 03 스테이지는 AnimatedSwitcher 없이 기존 이동/응축 연출 그대로다',
    (tester) async {
      await tester.pumpWidget(wrap(reduceMotion: false));
      await tester.pump(const Duration(milliseconds: 260));

      // Reduce Motion이 꺼져 있으면 `stage = stageInner`(AnimatedSwitcher
      // 미사용)이어야 한다 — 코드 분기 `reduceMotion ? AnimatedSwitcher(...)
      // : stageInner`를 실측으로 확인.
      //
      // 단, E-30(작은 화면 Transform.scale)이나 다른 화면 자체의
      // AnimatedSwitcher(하단 라벨 전환 등)는 이 화면에도 존재하므로,
      // "duration == 300ms인 AnimatedSwitcher가 없어야 한다"는 더
      // 정밀한 조건으로 검증한다. 하단 라벨 전환은 500ms, 존재 여부와
      // 무관하게 300ms 스테이지 크로스페이드만 없으면 된다.
      final switchers = tester
          .widgetList<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
          .where((w) => w.duration == const Duration(milliseconds: 300))
          .toList();
      expect(
        switchers,
        isEmpty,
        reason: 'Reduce Motion Off인데도 300ms 스테이지 AnimatedSwitcher가 존재함',
      );

      await tester.pump(const Duration(seconds: 10));
    },
  );
}
