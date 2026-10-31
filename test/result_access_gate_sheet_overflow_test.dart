import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/result_access/application/result_access_provider.dart';
import 'package:flutter_app/features/result_access/data/result_access_repository.dart';
import 'package:flutter_app/features/result_access/presentation/result_access_gate_sheet.dart';

// [반응형 화면 규격 통일 — 신규 확인 버그] 기존 매트릭스는 textScale 1.3까지만
// 검증했으나, _GateOptionButton(복주머니 옵션)의 subLabel('보유 N개')이
// Flexible 없이 고정 폭으로 Row에 추가되어 있어, label이 줄어들어도
// 320x568 기준 textScale 2.5에서 Row 폭을 초과해 가로 오버플로가 발생함을
// 확인했다(실측 28px, debugDumpRenderTree로 RenderFlex#5b2b8 확인).
// → result_access_gate_sheet.dart의 subLabel Text를 Flexible+ellipsis로
// 감싸 수정. 아래 매트릭스를 2.0/2.5까지 확장해 회귀 검증한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  http.Response quoteResponse({
    required bool freePassAvailable,
    required bool pouchSufficient,
    required bool todayClaimed,
  }) {
    final body = {
      'success': true,
      'data': {
        'freePassRemaining': freePassAvailable ? 2 : 0,
        'freePassHasLegacyUnlimited': false,
        'freePassAvailable': freePassAvailable,
        'pouchBalance': pouchSufficient ? 500 : 10,
        'pouchPrice': 100,
        'pouchAvailable': true,
        'adAvailable': true,
        'coupangClaimedTodayKey': null,
        'todayClaimed': todayClaimed,
      },
    };
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  Future<void> runInZone(
    WidgetTester tester,
    http.Client client,
    Future<void> Function() body,
  ) {
    return http.runWithClient(body, () => client);
  }

  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '정통사주·타로·80종 공용 결과보기 게이트 시트(쿠팡 클레임 노출)가 '
      '${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final client = MockClient((request) async {
          return quoteResponse(
            freePassAvailable: false,
            pouchSufficient: true,
            todayClaimed: false,
          );
        });

        await runInZone(tester, client, () async {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(textScale),
              ),
              child: ChangeNotifierProvider<ResultAccessProvider>(
                create: (_) => ResultAccessProvider(ResultAccessRepository()),
                child: MaterialApp(
                  home: Scaffold(
                    body: Builder(
                      builder: (context) => ElevatedButton(
                        onPressed: () => showResultAccessGateSheet(
                          context,
                          contentType: 'saju_renewal',
                          categoryKey: 'wealth',
                          contentTitle: '재물운 상세 풀이',
                          returnRoute: '/saju-renewal/home',
                        ),
                        child: const Text('열기'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('열기'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          final ex = tester.takeException();
          if (ex != null) debugDumpRenderTree();
          expect(ex, isNull);
          // 쿠팡 클레임 버튼 문구까지 실제로 그려지는지 확인(가장 아래 요소).
          expect(find.text('오늘의 프리패스 2회 받기 (쿠팡 방문)'), findsOneWidget);
        });
      },
    );
  }
}
