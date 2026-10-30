// [반응형 화면 규격 통일 — 잘림 현상 수정] 신당(THE SHRINE) 설정 시트
// (showSettingsSheet)가 표준 화면 크기에서도 하단이 잘리던 회귀를 막기
// 위한 영구 회귀 테스트.
//
// 과거 발견된 문제: 소리/움직임/진동/타이머/글자크기/연결끊기/안내
// 다시보기/기록지우기까지 항목이 8개인데, 기본(isScrollControlled:
// false) 바텀시트는 내용 높이와 무관하게 화면의 절반으로 높이가
// 고정돼 버려 390x844(표준 크기, 글자 확대 없음)에서도 78px, 좁은
// 화면/글자확대 조합에서는 최대 365px까지 바닥 버튼(기록 지우기 등)이
// 통째로 눌리지 않는 상태였다. isScrollControlled: true + SafeArea +
// SingleChildScrollView로 감싸, 내용이 들어가면 그대로(스크롤 없이)
// 보이고 모자랄 때만 스크롤되도록 했다. 레이아웃·문구·수치·색상은
// 전혀 바꾸지 않았다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/shrine/state/shrine_session_provider.dart';
import 'package:flutter_app/features/shrine/widgets/sheets.dart';

Future<void> _openSettingsSheet(
  WidgetTester tester, {
  required Size size,
  required double textScale,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final provider = ShrineSessionProvider(prefs);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<ShrineSessionProvider>.value(
      value: provider,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale), size: size),
        child: MaterialApp(
          home: Builder(builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showSettingsSheet(context),
                  child: const Text('open'),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  final configs = <(Size, double)>[
    (const Size(390, 844), 1.0), // 표준 크기, 글자확대 없음 (과거 78px 오버플로 재현 조건)
    (const Size(360, 640), 1.0), // 일반적인 중소형 안드로이드 폭
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.3), // iPhone SE급 + 글자확대 130% (과거 365px 오버플로 재현 조건)
  ];

  for (final (size, scale) in configs) {
    testWidgets(
      'shrine 설정 시트 ${size.width.toInt()}x${size.height.toInt()} @${scale}x 에서 오버플로 없이 렌더링된다',
      (tester) async {
        await _openSettingsSheet(tester, size: size, textScale: scale);
        final exception = tester.takeException();
        expect(exception, isNull, reason: '설정 시트가 오버플로 없이 렌더링되어야 한다');
        expect(find.text('기록 지우기'), findsOneWidget, reason: '맨 아래 버튼까지 실제로 그려져야 한다');
      },
    );
  }
}
