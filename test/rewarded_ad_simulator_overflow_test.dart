import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/pass/data/rewarded_ad_simulator.dart';
import 'package:flutter_app/features/pass/domain/open_pass_models.dart';

/// [반응형 화면 규격 통일 — 잘림 현상 수정]
/// RewardedAdSimulator는 Dialog 내부를 고정 height:380으로 구성한다.
/// 작은 화면(세로 568) + 글자 확대(1.3배) 조합에서 Column(아이콘+2줄 텍스트+
/// 진행바+결과라벨)이 그 고정 높이를 넘어 세로로 넘칠 가능성을 검증한다.
void main() {
  const source = OpenPassAdSourceBindingModel(
    bindingId: 1,
    adSourceId: 1,
    sourceName: '테스트 광고 소스 - 아주 긴 이름의 네트워크 파트너사 표기 테스트',
    sourceType: 'mock_rewarded_success',
    networkName: '매우 긴 네트워크 이름 표기 테스트용 파트너사 네트워크',
    cooldownSeconds: 0,
    testModeEnabled: true,
    priority: 1,
    isPrimary: true,
    platform: 'android',
    isMock: true,
    simulatedDurationSeconds: 2,
  );

  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.3),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '리워드 광고(목업) 다이얼로그가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => RewardedAdSimulator.show(
                      context,
                      source: source,
                    ),
                    child: const Text('열기'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pump();
        expect(tester.takeException(), isNull);

        // 진행바가 흐르는 중간(완료 전) 상태도 확인.
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);

        // mock 성공 시나리오는 지정된 시간 후 자동으로 닫힌다(400ms 지연
        // 포함) — 타이머가 모두 끝날 때까지 펌프해 예외 없이 종료되는지 확인.
        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
