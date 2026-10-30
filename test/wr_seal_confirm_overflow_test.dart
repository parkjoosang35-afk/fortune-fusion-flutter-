// [반응형 화면 규격 통일 — 잘림 현상 수정] 소원 봉인 확인 팝업(WrSealConfirm,
// compose_screen.dart의 "봉인하기" 버튼을 누르면 뜨는 안내창) 전수조사 —
// 실제 버그 발견 및 수정.
//
// compose_screen_dialogs_overflow_test.dart의 주석은 이 위젯을 언급만 하고
// 실제로는 테스트하지 않았다(ComposeScreen 폼을 끝까지 채워 canSubmit을
// true로 만들지 않으면 띄울 수 없음). WrSealConfirm은 공개(public) 독립
// StatelessWidget이라 ComposeScreen 폼 전체를 거치지 않고 직접 pump해
// 가혹 조건을 실측했다.
//
// [실측 결과 — 수정 전] 바깥 Column(mainAxisSize:min)에 높이 제약이 전혀
// 없어, 좁고 짧은 화면(320x568)에서 글자 확대가 커질수록 RenderFlex가
// 세로로 오버플로했다.
//   320x568 @1.0~1.7 → 정상
//   320x568 @1.8      → overflow 7px
//   320x568 @2.0      → overflow 113px
//   320x568 @2.5      → overflow 259px
// (1.8~2.5배는 Android 접근성 설정의 "큰 글꼴" 범위 안에 있다.)
//
// [수정 내용] (디자인·문구·버튼 동작·애니메이션 변경 없음)
// character_shop_screen.dart의 _infoSheet/_shortageSheet와 동일한 공통
// 패턴 — `Container(constraints: BoxConstraints(maxHeight: 화면높이*.9))` +
// `Flexible(child: SingleChildScrollView(...))` — 을 적용해 전체 높이에
// 상한을 두고, "취소"/"봉인하기" 버튼 2개는 스크롤 영역 밖에 고정해 항상
// 화면 안에서 탭 가능하도록 했다. 제목·설명·날짜 안내 영역만 내부 스크롤.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/wishroom/features/compose/compose_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // (화면 크기, 글자 확대 배율) — 2.5배까지 포함(Android 큰 글꼴 접근성 범위).
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.0),
    (const Size(320, 568), 1.8),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ];

  group('WrSealConfirm 봉인 확인 팝업 — 오버플로 없음 + 버튼 항상 탭 가능', () {
    for (final (size, textScale) in conditions) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}@$textScale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var cancelled = false;
        var confirmed = false;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
            child: MaterialApp(
              home: Scaffold(
                body: WrSealConfirm(
                  date: DateTime(2027, 1, 1),
                  busy: false,
                  onCancel: () => cancelled = true,
                  onOk: () => confirmed = true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('이 소원을 봉인할까요?'), findsOneWidget);

        // 버튼 2개가 모두 화면 안쪽(탭 가능한 위치)에 있는지 확인.
        final cancelRect = tester.getRect(find.text('취소'));
        final okRect = tester.getRect(find.text('봉인하기'));
        expect(
          cancelRect.bottom <= size.height,
          isTrue,
          reason: '취소 버튼(bottom=${cancelRect.bottom})이 화면(${size.height}) 밖으로 밀려나면 안 됨',
        );
        expect(
          okRect.bottom <= size.height,
          isTrue,
          reason: '봉인하기 버튼(bottom=${okRect.bottom})이 화면(${size.height}) 밖으로 밀려나면 안 됨',
        );

        // 실제로 탭이 동작하는지(화면 밖으로 밀려 탭 불가 상태가 아닌지) 확인.
        await tester.tap(find.text('취소'));
        expect(cancelled, isTrue);
        await tester.tap(find.text('봉인하기'));
        expect(confirmed, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
