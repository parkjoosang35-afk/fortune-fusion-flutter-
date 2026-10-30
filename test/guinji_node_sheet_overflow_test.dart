import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/guinji/presentation/guinji_node_sheet.dart';

// [반응형 화면 규격 통일 — 조사 기록] GuinjiNodeSheet의 "판정 근거" Row는
// mainAxisAlignment.spaceBetween 구조에서 value(오른쪽) 쪽만 Expanded로
// 보호되어 있고 rowLabel(왼쪽) 쪽은 보호가 없다. 인위적으로 매우 긴
// rowLabel을 주면 재현되지만(디버그 확인: 308px 오버플로), 실제 유일한
// 호출부(guinji_map_result_screen.dart _handleNodeTap())가 넘기는 값은
// 코드에 하드코딩된 짧은 라벨('오행', '판정 근거')뿐이고, value 쪽
// (GuinjiPerson.note)도 명리학적 근거 짧은 메모(실측 최대 약 10자 내외)
// 라서 실제 데이터로는 오버플로가 나지 않는다(원칙⑤ — 실제 확인된 문제만
// 수정). 이 테스트는 실제 호출부와 동일한 값으로 "안전 확인됨"을 고정한다.
void main() {
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.3),
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
        expect(tester.takeException(), isNull);
        expect(find.text('관계 자세히 보기'), findsOneWidget);
      },
    );
  }
}
