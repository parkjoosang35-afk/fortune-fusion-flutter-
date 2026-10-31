import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/guinji/presentation/guinji_node_sheet.dart';

// [반응형 화면 규격 통일 — 조사 기록 1차] GuinjiNodeSheet의 "판정 근거" Row는
// mainAxisAlignment.spaceBetween 구조에서 value(오른쪽) 쪽만 Expanded로
// 보호되어 있고 rowLabel(왼쪽) 쪽은 보호가 없다. 인위적으로 매우 긴
// rowLabel을 주면 재현되지만(디버그 확인: 308px 오버플로), 실제 유일한
// 호출부(guinji_map_result_screen.dart _handleNodeTap())가 넘기는 값은
// 코드에 하드코딩된 짧은 라벨('오행', '판정 근거')뿐이고, value 쪽
// (GuinjiPerson.note)도 명리학적 근거 짧은 메모(실측 최대 약 10자 내외)
// 라서 실제 데이터로는 오버플로가 나지 않는다(원칙⑤ — 실제 확인된 문제만
// 수정).
//
// [반응형 화면 규격 통일 — 신규 확인 버그 2차] 1차 조사는 textScale 1.3까지만
// 검증했으나, 320x568 기준 textScale을 2.0/2.5까지 올리면 점수 Row
// ('92' + '/ 100', 폰트 34)가 부모 폭(약 252px)을 넘어서면서 가로 오버플로가
// 발생함을 확인(실측 @2.0 20px, @2.5 86px). → guinji_node_sheet.dart의 점수
// Row를 FittedBox(fit: BoxFit.scaleDown)로 감싸 수정. 아래 매트릭스를
// 2.0/2.5까지 확장해 회귀 검증한다.
void main() {
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      'N·Node Sheet(실제 호출 데이터)가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
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
                    onPressed: () => showGuinjiNodeSheet(
                      context: context,
                      // guinji_map_result_screen.dart _handleNodeTap()과
                      // 동일한 실사용 길이의 값.
                      name: '김민서',
                      birthLabel: '2002·11·03',
                      relationKey: 'CHEON_GWII',
                      score: 92,
                      narratorText:
                          '김민서님은 타고난 인연으로 서로를 살리고 크게 이끌어 주는 관계예요. 곁에 두면 결이 자연스레 풀리는 관계예요.',
                      evidenceRows: const [
                        ('오행', '화(火) 목(木)'),
                        ('판정 근거', '일간 상생 · 일지 육합'),
                      ],
                    ),
                    child: const Text('열기'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        // 전체화면 애니메이션(repeat 등)이 있을 수 있어 pumpAndSettle
        // 대신 바텀시트 등장 애니메이션이 끝날 만큼만 유한 pump한다.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        final ex = tester.takeException();
        if (ex != null) {
          debugDumpRenderTree();
        }
        expect(ex, isNull);
        expect(find.text('관계 자세히 보기'), findsOneWidget);
      },
    );
  }
}
