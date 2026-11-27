import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/result_access/application/result_access_provider.dart';
import 'package:flutter_app/features/result_access/data/result_access_repository.dart';
import 'package:flutter_app/features/saju_renewal/widgets/saju_result_access_gate_sheet.dart';

// [조사 결과] GateOption의 "보유 N개" trailing 텍스트가 큰 잔액(예:
// 복주머니를 많이 모은 사용자) + 큰 textScale에서 320x568@2.0에서 25px,
// @2.5에서 91px RenderFlex 오버플로를 일으킴을 확인
// (result_access_gate_sheet.dart의 _GateOptionButton subLabel과 동일한
// 구조적 문제). Flexible(child: Text(..., overflow: ellipsis))로 감싸
// 해결 (디자인/색상/문구 변경 없음).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  http.Response quoteResponse({
    required bool freePassAvailable,
    required bool pouchSufficient,
    required bool todayClaimed,
    int? pouchBalanceOverride,
  }) {
    final body = {
      'success': true,
      'data': {
        'freePassRemaining': freePassAvailable ? 2 : 0,
        'freePassHasLegacyUnlimited': false,
        'freePassAvailable': freePassAvailable,
        'pouchBalance': pouchBalanceOverride ?? (pouchSufficient ? 500 : 10),
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

  Widget host() {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider(
          create: (_) => ResultAccessProvider(ResultAccessRepository()),
          child: const SajuResultAccessGateSheet(
            contentId: 'MONEY_001',
            contentTitle: '테스트 이야기',
            quoteText: '테스트 인용 문장입니다. 조금 더 길게 써서 실제 화면과 비슷하게 만들어본다.',
          ),
        ),
      ),
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
    final suffix = '${size.width.toInt()}x${size.height.toInt()}@$textScale';

    testWidgets('게이트 시트(쿠팡 클레임 활성, 비활성 프리패스) $suffix에서 오버플로 없이 뜬다', (
      tester,
    ) async {
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
            child: host(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final ex = tester.takeException();
        if (ex != null) debugDumpRenderTree();
        expect(ex, isNull);
        // 쿠팡 클레임 안내 문구까지 실제로 그려지는지 확인.
        expect(find.text('쿠팡 방문 시 하루 한 번 받을 수 있어요'), findsOneWidget);
      });
    });

    testWidgets('게이트 시트(복주머니 큰 잔액 "보유 123,456개") $suffix에서 오버플로 없이 뜬다', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        return quoteResponse(
          freePassAvailable: false,
          pouchSufficient: true,
          todayClaimed: true,
          pouchBalanceOverride: 123456,
        );
      });

      await runInZone(tester, client, () async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: host(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final ex = tester.takeException();
        if (ex != null) debugDumpRenderTree();
        expect(ex, isNull);
        // 큰 잔액 trailing 텍스트는 ellipsis로 잘릴 수 있으므로(의도된
        // 동작), 복주머니 GateOption의 "보유 123456개" 라벨이 존재하는지만
        // 확인한다 — 숫자 전체가 반드시 안 잘리고 보여야 하는 요구사항은
        // 아니다(핵심은 RenderFlex 오버플로 예외가 없는 것).
        expect(find.textContaining('보유 123456'), findsOneWidget);
      });
    });
  }
}
