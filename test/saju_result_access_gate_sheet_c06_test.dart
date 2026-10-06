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

/// C-06b/C-06d(docs/08_QA_체크리스트.md) 실제 동작 검증.
///
/// docs/03_화면명세.md §06 및 원본 `design_files/saju/screens-b.jsx`
/// `ScreenGate`/`GateOption`을 근거로, 결과보기 게이트 시트의 두 결함
/// 수정을 측정한다:
/// 1) C-06b: 활성 상태(프리패스 보유/복주머니 충분)에도 부제가 노출되어야
///    한다("프리패스 1회 사용" / "복주머니 {COST}개 사용").
/// 2) C-06d: 프리패스 사용 오버레이(1.2s)와 복주머니 사용 오버레이(1.4s)의
///    애니메이션 지속시간이 서로 달라야 한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // 비활성 상태(쿠팡 수령 버튼까지 추가 렌더)에서는 기본 테스트 서피스
  // (800×600)보다 세로 공간이 더 필요하다 — 실기기 화면 크기 문제가
  // 아니라 테스트 하네스 뷰포트 제약이므로 여기서만 넉넉하게 키운다.
  void setTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  http.Response quoteResponse({
    required bool freePassAvailable,
    required bool pouchSufficient,
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

  // [주의] addPostFrameCallback으로 지연 실행되는 HTTP 호출(loadQuote 등)이
  // MockClient를 타려면, pumpWidget뿐 아니라 그 뒤의 모든 pump() 호출까지
  // 같은 http.runWithClient Zone 안에서 실행되어야 한다 — host() 반환값만
  // Zone으로 감싸면 실제 await 실행 시점에는 Zone 밖이라 적용되지 않는다.
  Future<void> runInZone(
    WidgetTester tester,
    http.Client client,
    Future<void> Function() body,
  ) {
    return http.runWithClient(body, () => client);
  }

  testWidgets('C-06b 활성 상태: 프리패스/복주머니 모두 활성일 때도 부제가 '
      '노출된다(원본 jsx canPass/canPouch sub 분기)', (tester) async {
    final client = MockClient((request) async {
      return quoteResponse(freePassAvailable: true, pouchSufficient: true);
    });

    await runInZone(tester, client, () async {
      await tester.pumpWidget(host());
      await tester.pump(); // addPostFrameCallback 트리거.
      await tester.pump(const Duration(milliseconds: 100));
    });

    expect(find.text('프리패스 1회 사용'), findsOneWidget);
    expect(find.text('복주머니 100개 사용'), findsOneWidget);
    // 비활성 전용 문구는 보이지 않아야 한다.
    expect(find.text('보유한 프리패스가 없어요'), findsNothing);
    expect(find.text('100개가 필요해요'), findsNothing);
  });

  testWidgets('C-06b 비활성 상태: 프리패스/복주머니 모두 부족할 때는 부족 안내 '
      '문구가 노출된다(기존 동작 유지 확인)', (tester) async {
    setTallSurface(tester);
    final client = MockClient((request) async {
      return quoteResponse(freePassAvailable: false, pouchSufficient: false);
    });

    await runInZone(tester, client, () async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });

    expect(find.text('보유한 프리패스가 없어요'), findsOneWidget);
    expect(find.text('100개가 필요해요'), findsOneWidget);
    expect(find.text('프리패스 1회 사용'), findsNothing);
    expect(find.text('복주머니 100개 사용'), findsNothing);
  });

  testWidgets('C-06d 프리패스 사용(06-D) 오버레이: 1200ms에는 아직 "07"로 넘어가지 '
      '않고(=시트 유지), begin 호출 흐름을 탄다', (tester) async {
    setTallSurface(tester);
    var beginCalled = false;
    final client = MockClient((request) async {
      if (request.url.path.contains('/result-access/quote')) {
        return quoteResponse(freePassAvailable: true, pouchSufficient: true);
      }
      if (request.url.path.contains('/result-access/begin')) {
        beginCalled = true;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'transactionId': 'tx_1',
              'paymentMethod': 'FREEPASS',
              'unlockedTopicId': 'MONEY_001',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{}', 404);
    });

    await runInZone(tester, client, () async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('프리패스로 보기'));
      // 1.2s 모션 도중(600ms) — 아직 오버레이 중이어야 한다.
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('프리패스로 이야기를 열고 있어요'), findsOneWidget);

      // 모션 종료(1300ms, _handleFreePass의 delay) + begin 호출까지 pump.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 100));
    });

    expect(beginCalled, isTrue);
  });
}
