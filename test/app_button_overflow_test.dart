import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/widgets/app_button.dart';

/// [반응형 화면 규격 통일 — 잘림 현상 수정]
/// 공용 컴포넌트 [AppButton]은 showAppConfirmDialog 등 여러 화면에서
/// Row+Expanded로 좁게 분할된 자리에 배치된다. 내부 Row(mainAxisSize.min)가
/// Text 라벨에 아무 보호 장치가 없어, 좁은 폭(화면이 아니라 "주어진 제약
/// 폭" 자체가 좁은 경우) + 글자 확대(1.3배) 조합에서 라벨이 짧아도(예:
/// "탈퇴하기") 가로로 오버플로되는 버그가 있었다(최대 14px, app_dialog.dart의
/// 2버튼 Row에서 실측 확인). Flexible+ellipsis로 고정해, 이 컴포넌트를 쓰는
/// 모든 호출부가 한 번에 안전해지도록 한다(공통 원인 수정).
void main() {
  Widget wrap(Widget child, {required double width, required double textScale}) {
    return MediaQuery(
      data: MediaQueryData(
        size: Size(width, 600),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(width: width, child: child),
        ),
      ),
    );
  }

  final conditions = <(double, double)>[
    (390, 1.0),
    (150, 1.0), // 다이얼로그 2버튼(Row+Expanded)에서 흔히 나타나는 좁은 폭
    (150, 1.3),
    (90, 1.3), // 더 좁은 320px대 화면에서의 2분할 극단값
  ];

  for (final variant in [
    'primary',
    'secondary',
    'ghost',
    'danger',
  ]) {
    for (final (width, textScale) in conditions) {
      testWidgets(
        'AppButton.$variant(짧은 라벨 "탈퇴하기")가 폭 ${width.toInt()}@$textScale에서 오버플로 없이 그려진다',
        (tester) async {
          Widget button;
          switch (variant) {
            case 'primary':
              button = AppButton(label: '탈퇴하기', onPressed: () {});
              break;
            case 'secondary':
              button = AppButton.secondary(label: '탈퇴하기', onPressed: () {});
              break;
            case 'ghost':
              button = AppButton.ghost(label: '탈퇴하기', onPressed: () {});
              break;
            default:
              button = AppButton.danger(label: '탈퇴하기', onPressed: () {});
          }
          await tester.pumpWidget(wrap(button, width: width, textScale: textScale));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('AppButton(icon 포함, 좁은 폭)도 오버플로 없이 그려진다', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppButton(
          label: '출석하기',
          onPressed: null,
          icon: Icons.check_circle,
        ),
        width: 90,
        textScale: 1.3,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
