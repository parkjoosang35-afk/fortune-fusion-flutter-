// [반응형 화면 규격 통일 — 잘림 현상 수정] 회원가입 웰컴 리워드 팝업
// (WelcomeRewardModal)이 작은 화면·글자 확대 조합에서 세로/가로로
// 잘리던 회귀를 막기 위한 영구 회귀 테스트.
//
// 과거 발견된 문제:
// - 320x568(iPhone SE급) + 글자 확대 130%: 카드가 화면보다 커져
//   171px 세로 오버플로 → Center를 SingleChildScrollView +
//   ConstrainedBox(minHeight)로 감싸 해결.
// - 360x640(일반적인 중소형 안드로이드 폭) + 글자 확대 100%(기본값,
//   극단적 조건 아님)에서도 eyebrow/보상 카운터 줄에서 7px 가로
//   오버플로 → 해당 Row들을 FittedBox(fit: scaleDown)로 감싸 해결.
//
// 디자인·애니메이션·폰트는 전혀 바꾸지 않았고, 내용이 들어가면
// scale 1(또는 스크롤 없음)로 기존과 동일하게 보이며, 공간이
// 부족할 때만 미세 축소/스크롤되도록 한 최소 수정이다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/presentation/widgets/welcome_reward_modal.dart';

Future<void> _openModal(
  WidgetTester tester, {
  required Size size,
  required double textScale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(textScale),
      size: size,
    ),
    child: MaterialApp(
      home: Builder(builder: (context) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  WelcomeRewardModal.show(context, amount: 100, onClaim: () {}),
              child: const Text('open'),
            ),
          ),
        );
      }),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pump(); // showGeneralDialog transition
  await tester.pump(const Duration(milliseconds: 700)); // entry animation
}

void main() {
  final configs = <(Size, double)>[
    (const Size(320, 568), 1.3), // iPhone SE급 + 글자확대 130% (과거 세로 오버플로 재현 조건)
    (const Size(360, 640), 1.0), // 일반적인 중소형 안드로이드 폭, 글자확대 없음 (과거 7px 가로 오버플로 재현 조건)
    (const Size(360, 640), 1.15),
    (const Size(360, 640), 1.3),
    (const Size(390, 844), 1.3), // 표준 크기 + 글자확대 130%
  ];

  for (final (size, scale) in configs) {
    testWidgets(
      'WelcomeRewardModal ${size.width.toInt()}x${size.height.toInt()} @${scale}x 에서 오버플로 없이 렌더링된다',
      (tester) async {
        await _openModal(tester, size: size, textScale: scale);
        final exception = tester.takeException();
        expect(exception, isNull, reason: '팝업이 오버플로 없이 렌더링되어야 한다');
      },
    );
  }
}
