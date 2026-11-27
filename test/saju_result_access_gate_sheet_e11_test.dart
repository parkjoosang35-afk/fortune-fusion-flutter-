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

/// E-11(docs/07_예외_엣지케이스.md) — "프리패스 0 / 복주머니 100 미만 → 06
/// → 해당 수단 행 비활성(50%)·부제 교체. 광고는 항상 활성. 모달·충전
/// 유도 금지(C-06-3, C-06-4)."
///
/// docs/03_화면명세.md §06: "차감 직전 잔량 부족(다른 기기 사용 등) → 시트
/// 잔량 갱신, 해당 행 비활성. 강제 모달·충전 유도 금지."
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

  http.Response quoteResponse({
    required bool freePassAvailable,
    required int pouchBalance,
    required bool todayClaimed,
  }) {
    final body = {
      'success': true,
      'data': {
        'freePassRemaining': freePassAvailable ? 2 : 0,
        'freePassHasLegacyUnlimited': false,
        'freePassAvailable': freePassAvailable,
        'pouchBalance': pouchBalance,
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
            quoteText: '테스트 인용 문장입니다.',
          ),
        ),
      ),
    );
  }

  double opacityOf(WidgetTester tester, String labelText) {
    final finder = find
        .ancestor(of: find.text(labelText), matching: find.byType(Opacity))
        .first;
    return tester.widget<Opacity>(finder).opacity;
  }

  testWidgets(
    'E-11: 프리패스 0 + 복주머니 100 미만이면 두 행 모두 비활성(50%)·부제 '
    '교체되고, 광고 행은 항상 활성이며, 모달이 전혀 뜨지 않는다',
    (tester) async {
      setTallSurface(tester);
      // 오늘 이미 쿠팡 프리패스를 받았다고 설정(todayClaimed: true) —
      // "오늘의 프리패스 2회 받기" 유도 버튼이 추가로 렌더되어 화면이 더
      // 길어지는 것을 막아 테스트를 단순화한다. 이 버튼 자체는 E-11의
      // 검증 대상이 아니다.
      final client = MockClient((request) async {
        return quoteResponse(
          freePassAvailable: false,
          pouchBalance: 10, // < pouchPrice(100) → 복주머니도 부족
          todayClaimed: true,
        );
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(host());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }, () => client);

      // (1) 부제 교체 확인 — C-06-3/C-06-4 비활성 문구.
      expect(find.text('보유한 프리패스가 없어요'), findsOneWidget);
      expect(find.text('100개가 필요해요'), findsOneWidget);
      // 활성 전용 문구는 보이지 않아야 한다.
      expect(find.text('프리패스 1회 사용'), findsNothing);
      expect(find.text('복주머니 100개 사용'), findsNothing);

      // (2) 프리패스/복주머니 행이 50% 비활성(Opacity)이어야 한다.
      expect(
        opacityOf(tester, '프리패스로 보기'),
        0.5,
        reason: 'E-11 위반: 프리패스 0인데도 프리패스 행이 비활성(50%)으로 표시되지 않음',
      );
      expect(
        opacityOf(tester, '복주머니로 보기'),
        0.5,
        reason: 'E-11 위반: 복주머니 100 미만인데도 복주머니 행이 비활성(50%)으로 표시되지 않음',
      );

      // (3) 광고 행은 "항상 활성"이어야 한다(adAvailable: true인 한).
      expect(
        opacityOf(tester, '광고 보고 무료로 보기'),
        1.0,
        reason: 'E-11 위반: 프리패스/복주머니가 부족해도 광고 행은 항상 활성이어야 함',
      );

      // (4) 비활성 행을 탭해도 반응이 없어야 한다(onTap: null, 콜백 미호출
      // — GestureDetector의 disabled 처리로 begin() 등이 호출되지 않음을
      // 간접 확인: 탭 후에도 처리 중 오버레이/로딩 상태가 전혀 뜨지 않음).
      await tester.tap(find.text('프리패스로 보기'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('프리패스로 이야기를 열고 있어요'), findsNothing);

      await tester.tap(find.text('복주머니로 보기'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('복주머니를 열고 있어요'), findsNothing);

      // (5) "강제 모달·충전 유도 금지" — 어떤 AlertDialog/Dialog도 뜨지
      // 않아야 한다.
      expect(
        find.byType(AlertDialog),
        findsNothing,
        reason: 'E-11 위반: 잔량 부족 시 강제 모달(AlertDialog)이 뜸(금지 사항)',
      );
      expect(
        find.byType(Dialog),
        findsNothing,
        reason: 'E-11 위반: 잔량 부족 시 다이얼로그가 뜸(금지 사항)',
      );
    },
  );

  testWidgets(
    'E-11: 프리패스는 있지만 복주머니만 부족한 경우, 프리패스 행만 활성이고 '
    '복주머니 행만 비활성(50%)이다 — 수단별 독립 비활성 확인',
    (tester) async {
      setTallSurface(tester);
      final client = MockClient((request) async {
        return quoteResponse(
          freePassAvailable: true,
          pouchBalance: 50, // < pouchPrice(100)
          todayClaimed: false,
        );
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(host());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }, () => client);

      expect(
        opacityOf(tester, '프리패스로 보기'),
        1.0,
        reason: 'E-11 위반: 프리패스 보유 상태인데도 프리패스 행이 비활성으로 표시됨',
      );
      expect(
        opacityOf(tester, '복주머니로 보기'),
        0.5,
        reason: 'E-11 위반: 복주머니만 부족한데 복주머니 행이 비활성으로 표시되지 않음',
      );
      expect(find.text('100개가 필요해요'), findsOneWidget);
      expect(find.text('프리패스 1회 사용'), findsOneWidget);
    },
  );
}
