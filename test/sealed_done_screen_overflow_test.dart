// [반응형 화면 규격 통일 — 잘림 현상 수정] 소원 봉인 완료 화면(SealedDoneScreen)
// 전용 회귀 테스트 — 이 화면은 commit 61dc9de에서 이미 SafeArea(top:false)로
// 하단 "소원방 들어가기" CTA를 감싸는 수정이 들어갔지만(capsule_screen.dart,
// review_write_screen.dart와 동일 패턴), 정작 전용 테스트 파일이 없었던 공백을
// 메운다. 전수조사 중 이 공백을 발견해 추가 — 코드 변경은 없음(원칙⑤:
// 실제 문제가 확인된 곳만 고친다 — 이미 고쳐져 있으므로 테스트만 보강).
//
// 검증 내용 두 가지:
//  1) 애니메이션이 끝까지(3600ms) 진행되는 동안 예외 없이 렌더링되는지.
//  2) 하단 CTA(Positioned bottom:44 + SafeArea(top:false))가 제스처 내비게이션
//     인셋이 큰 기기에서도 실제로 안전영역 밖(화면 하단 바깥)으로 밀려나지
//     않는지 — FakeViewPadding으로 iOS 홈 인디케이터(34)·Android 제스처
//     인셋(48)·극단치(80)를 모두 시뮬레이션해 `tester.getRect()`로 실측한다.
//     디자인 여백 bottom:44가 SafeArea 안쪽에 추가로 더해지므로, 안전영역
//     인셋이 44보다 커지는 조건(80)에서도 버튼이 화면 안에 완전히 남아있는지
//     확인하는 것이 이 테스트의 핵심이다.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/compose/sealed_done_screen.dart';

Future<void> _pump(
  WidgetTester tester,
  Size size,
  double bottomInset, {
  bool advanceToEnd = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async { await WrCatalog.load(); });

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, padding: EdgeInsets.only(bottom: bottomInset)),
      child: MaterialApp(
        home: SealedDoneScreen(
          date: DateTime(2026, 1, 1),
          text: '건강하고 행복하게 오래오래오래오래오래 살고 싶어요 정말정말정말 아주 길게 써봅니다',
          wishColor: 'love',
          onGo: () {},
        ),
      ),
    ),
  );
  await tester.pump();
  if (advanceToEnd) {
    // CTA는 raw=(t*3600-3200)/1000 시점부터 서서히 나타나 3600ms에 완전히
    // 보인다 — 애니메이션 종료 시점까지 모두 펌프해 최종 상태를 확인한다.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SealedDoneScreen 봉인 완료 연출 — 전체 재생 중 예외 없음', () {
    for (final size in [const Size(390, 844), const Size(320, 568)]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} 3.6초 연출 전체 재생', (tester) async {
        await _pump(tester, size, 0, advanceToEnd: true);
        expect(tester.takeException(), isNull);
        expect(find.text('소원이 봉인되었습니다.'), findsOneWidget);
        expect(find.text('소원방 들어가기'), findsOneWidget);
      });
    }
  });

  group('SealedDoneScreen 하단 CTA — 제스처 내비게이션 인셋에 가려지지 않음', () {
    // (화면 크기, 하단 인셋) — 디자인 여백 bottom:44보다 큰 인셋(80)까지 포함.
    final conditions = <(Size, double)>[
      (const Size(390, 844), 0),
      (const Size(390, 844), 34), // iOS 홈 인디케이터 인셋
      (const Size(360, 640), 48), // Android 제스처 내비게이션 인셋
      (const Size(320, 568), 80), // 극단적으로 큰 인셋까지 확인
    ];

    for (final (size, inset) in conditions) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} inset=${inset.toInt()}', (tester) async {
        await _pump(tester, size, inset, advanceToEnd: true);
        expect(tester.takeException(), isNull);

        final btnFinder = find.text('소원방 들어가기');
        expect(btnFinder, findsOneWidget);
        final btnRect = tester.getRect(btnFinder);
        final safeBottom = size.height - inset;
        expect(
          btnRect.bottom <= safeBottom,
          isTrue,
          reason: '하단 CTA(bottom=${btnRect.bottom})가 제스처 내비게이션 인셋 영역'
              '(safeBottom=$safeBottom)을 침범하면 안 됨 — SafeArea(top:false) 누락 시 회귀',
        );
      });
    }
  });
}
