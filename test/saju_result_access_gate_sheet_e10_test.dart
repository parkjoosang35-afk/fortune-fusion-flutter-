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

/// E-10(docs/07_예외_엣지케이스.md) — "프리패스·복주머니 차감 API 실패 →
/// 06 → 오버레이 닫고 시트 복귀, **차감 없음** → 기존 오류 토스트."
///
/// [검증 대상] `_SajuResultAccessGateSheetState._handleFreePass()` →
/// `_beginAndClose()`가 `ResultAccessProvider.begin()`에서 실패
/// 응답(success:false)을 받았을 때:
/// 1) "프리패스로 이야기를 열고 있어요" 전체 오버레이가 사라지고 시트
///    (GateOption 3행)가 다시 보여야 한다(오버레이 닫고 시트 복귀).
/// 2) Navigator.pop(result)가 호출되지 않아야 한다(=07로 넘어가지 않음
///    — 차감 성공 취급 금지).
/// 3) 오류 토스트(SnackBar)가 떠야 한다.
/// 4) 같은 수단을 다시 탭할 수 있어야 한다(버튼이 영구 비활성화되지
///    않음 — "차감 없음"이므로 재시도 가능해야 정상).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void setTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  http.Response quoteResponse() {
    final body = {
      'success': true,
      'data': {
        'freePassRemaining': 2,
        'freePassHasLegacyUnlimited': false,
        'freePassAvailable': true,
        'pouchBalance': 500,
        'pouchPrice': 100,
        'pouchAvailable': true,
        'adAvailable': true,
        'coupangClaimedTodayKey': null,
        'todayClaimed': false,
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
            quoteText: '테스트 인용 문장입니다.',
          ),
        ),
      ),
    );
  }

  testWidgets(
    'E-10: 프리패스 차감(begin) API가 실패하면 오버레이가 닫히고 시트로 '
    '복귀하며(차감 없음), 오류 토스트가 뜨고 같은 수단을 다시 시도할 수 있다',
    (tester) async {
      setTallSurface(tester);
      var beginCallCount = 0;

      final client = MockClient((request) async {
        if (request.url.path.contains('/result-access/quote')) {
          return quoteResponse();
        }
        if (request.url.path.contains('/result-access/begin')) {
          beginCallCount++;
          // [E-10 핵심] begin이 실패 응답(success:false)을 내려주는
          // 상황을 재현한다 — 서버가 차감 자체를 하지 않았어야 하는
          // 시나리오(네트워크 단절, 서버 내부 오류 등).
          return http.Response(
            jsonEncode({'success': false, 'error': '결과보기에 실패했습니다.'}),
            500,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 404);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(host());
        await tester.pump(); // addPostFrameCallback(_loadQuote) 트리거.
        await tester.pump(const Duration(milliseconds: 100));

        // 시트의 3택 옵션이 정상 노출됨을 먼저 확인.
        expect(find.text('프리패스로 보기'), findsOneWidget);

        await tester.tap(find.text('프리패스로 보기'));
        // 06-D 오버레이 모션(1.2s) 도중 — 오버레이가 보여야 한다.
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('프리패스로 이야기를 열고 있어요'), findsOneWidget);

        // 모션 종료(1300ms) + begin() 호출/응답 처리까지 pump.
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // 1) begin이 정확히 1회 호출됐고(차감 시도 자체는 발생),
        //    실패 응답을 받았으므로 오버레이가 닫히고 시트로 복귀해야
        //    한다.
        expect(
          beginCallCount,
          1,
          reason: 'E-10 위반: begin()이 호출되지 않음(차감 시도 자체가 안 됨)',
        );
        expect(
          find.text('프리패스로 이야기를 열고 있어요'),
          findsNothing,
          reason: 'E-10 위반: begin 실패 후에도 오버레이가 닫히지 않음',
        );
        expect(
          find.text('프리패스로 보기'),
          findsOneWidget,
          reason: 'E-10 위반: begin 실패 후 시트(GateOption)로 복귀하지 않음',
        );

        // 2) 오류 토스트(SnackBar) 노출 확인.
        expect(
          find.byType(SnackBar),
          findsOneWidget,
          reason: 'E-10 위반: begin 실패 시 오류 토스트가 뜨지 않음',
        );

        // 3) "차감 없음" → 버튼이 영구 비활성화되지 않고 재시도 가능해야
        //    한다. quote 자체는 다시 불러오지 않으므로(=차감되지 않은
        //    기존 quote 유지), freePassAvailable 그대로 true라서 버튼이
        //    여전히 활성 상태여야 한다.
        final optionFinder = find.ancestor(
          of: find.text('프리패스로 보기'),
          matching: find.byType(Opacity),
        );
        final opacityWidget = tester.widget<Opacity>(optionFinder.first);
        expect(
          opacityWidget.opacity,
          1.0,
          reason: 'E-10 위반: 차감 실패(차감 안 됐음)인데도 버튼이 비활성(50%)로 남음'
              ' — 재시도가 불가능해짐',
        );
      }, () => client);
    },
  );
}
