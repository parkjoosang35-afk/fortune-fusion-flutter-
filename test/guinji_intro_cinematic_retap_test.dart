// [사용자 버그 리포트 — "내지도 만들기 누른 후 뒤로가기 누르면 내지도
// 만들기 클릭 안됨"] 회귀 방지 테스트.
//
// [원인] `GuinjiIntroCinematic._go()`가 중복 탭 방지용 `_warping` 플래그를
// true로 설정한 뒤 `widget.onStart()`(기존 타입 `VoidCallback`)를 그냥
// 호출하고 끝냈다. 이 위젯은 `Navigator.push`로 다음 화면(02 정보입력)을
// 띄운 뒤에도 그 아래에서 State가 그대로 유지되므로, 사용자가 뒤로가기로
// 복귀해도 `_warping`은 계속 true로 남아 "if (_warping) return;"에 걸려
// CTA가 다시는 반응하지 않았다.
//
// [수정] `onStart`를 `Future<void> Function()`으로 바꿔 `Navigator.push`가
// 반환하는 Future(해당 라우트가 pop될 때 완료)를 전달받고, 그 Future가
// 완료된 뒤(= 복귀한 뒤) `_warping`을 다시 false로 되돌린다.
//
// [테스트 시나리오] CTA 탭 → 다음 화면 push(실제 push를 흉내 낸 목
// 화면으로 대체, 애니메이션/엔진 의존 없이 순수 네비게이션 동작만 검증)
// → 뒤로가기(pop) → CTA 재탭 → onStart가 2번째로 정상 호출되는지 확인.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/guinji/widgets/guinji_intro_cinematic.dart';

void main() {
  testWidgets(
    '내 지도 만들기 CTA: push 후 뒤로가기로 복귀하면 다시 탭 가능하다',
    (tester) async {
      var startCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: GuinjiIntroCinematic(
            onStart: () async {
              startCount++;
              // 실제 앱의 `Navigator.of(context).pushNamed('/guinji-map/new')`를
              // 간이 재현: push 후 그 Future를 반환(라우트가 pop될 때 완료).
              final context = tester.element(
                find.byType(GuinjiIntroCinematic),
              );
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('정보입력(목)')),
                    body: const Center(child: Text('02 화면')),
                  ),
                ),
              );
            },
          ),
        ),
      );
      // 인트로 애니메이션이 CTA를 노출할 때까지 충분히 진행시킨다
      // (_titleAt + 500 = 7220ms 이후 opacity 1).
      await tester.pump(const Duration(milliseconds: 7300));
      // [타이머 정리] CTA가 나타나는 시점(tt>_done=6420)에 함께 등장하는
      // _GoldDust/_DustDot이 각각 일회성 Timer(delay 0~2700ms)를 예약한다.
      // 이 타이머들이 다 발동할 때까지 충분히 pump해두어야 테스트
      // 종료 시 "Timer is still pending" 어서션을 피한다(우리 수정과
      // 무관한 기존 애니메이션 구현 특성).
      await tester.pump(const Duration(milliseconds: 3000));

      final ctaFinder = find.text('내 지도 만들기');
      expect(ctaFinder, findsOneWidget, reason: 'CTA 버튼이 보여야 함');

      // 1차 탭 — 02 화면으로 push.
      // [무한 반복 애니메이션 주의] GuinjiIntroCinematic은 CTA breath/
      // sheen 애니메이션과 별 필드 등 여러 `..repeat()` 컨트롤러를 가지고
      // 있어 `pumpAndSettle()`이 끝나지 않는다. 고정 시간만큼만 `pump`한다.
      await tester.tap(ctaFinder);
      await tester.pump(); // push 애니메이션 시작
      await tester.pump(const Duration(milliseconds: 400)); // 전환 완료
      expect(startCount, 1, reason: '첫 탭에서 onStart가 호출되어야 함');
      expect(find.text('02 화면'), findsOneWidget, reason: '정보입력 화면으로 이동해야 함');

      // 뒤로가기 — 인트로 화면으로 복귀.
      final navContext = tester.element(find.text('02 화면'));
      Navigator.of(navContext).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // pop 전환 완료
      expect(
        find.byType(GuinjiIntroCinematic),
        findsOneWidget,
        reason: '뒤로가기 후 인트로 화면으로 돌아와야 함',
      );

      // [핵심 회귀 검증] 재탭 시 onStart가 다시 호출되어야 한다
      // (수정 전에는 `_warping`이 true로 남아있어 여기서 아무 반응이 없었음).
      final ctaFinderAgain = find.text('내 지도 만들기');
      expect(ctaFinderAgain, findsOneWidget);
      await tester.tap(ctaFinderAgain);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        startCount,
        2,
        reason: '뒤로가기 후 재탭 시 onStart가 다시 호출되어야 함(복귀 후 클릭 안되는 버그 수정 검증)',
      );
      expect(find.text('02 화면'), findsOneWidget);

      // [정리] GuinjiIntroCinematic은 Timer.periodic(인원 카운터)을 들고
      // 있어 위젯 트리를 비우지 않으면 테스트 종료 시 "타이머가 아직
      // 떠 있다" 어서션에 걸린다. 위젯을 교체해 dispose를 트리거한다.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    '내 지도 만들기 CTA: 같은 화면에서 연속 더블탭해도 onStart는 1번만 호출된다(중복 탭 방지 유지)',
    (tester) async {
      var startCount = 0;
      final completers = <Future<void> Function()>[];

      await tester.pumpWidget(
        MaterialApp(
          home: GuinjiIntroCinematic(
            onStart: () async {
              startCount++;
              // 즉시 완료되지 않는 비동기 작업을 흉내 내 "진행 중" 구간을
              // 넓게 만들어 더블탭이 실제로 겹치는지 검증한다.
              await Future<void>.delayed(const Duration(milliseconds: 200));
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 7300));
      await tester.pump(const Duration(milliseconds: 3000)); // 일회성 Timer 발동 대기

      final ctaFinder = find.text('내 지도 만들기');
      await tester.tap(ctaFinder);
      await tester.tap(ctaFinder); // 아직 onStart 진행 중 — 무시되어야 함.
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        startCount,
        1,
        reason: '진행 중 더블탭은 여전히 무시되어야 함(중복 탭 방지 기존 동작 보존)',
      );
      expect(completers, isEmpty);

      // onStart의 지연(200ms)이 끝나지 않은 채 테스트가 끝나지 않도록
      // 먼저 흘려보낸 뒤, Timer.periodic 정리를 위해 위젯을 교체한다.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
