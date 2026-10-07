// ignore_for_file: no_leading_underscores_for_local_identifiers
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/auth/application/auth_provider.dart';
import 'package:flutter_app/features/auth/data/auth_repository.dart';
import 'package:flutter_app/features/saju_renewal/data/saju_renewal_api.dart';
import 'package:flutter_app/features/saju_renewal/screens/analysis_complete_screen.dart';
import 'package:flutter_app/features/saju_renewal/screens/calculating_screen.dart';
import 'package:flutter_app/features/saju_renewal/screens/error_screen.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';
import 'package:flutter_app/features/saju_renewal/widgets/saju_base_widgets.dart';

/// E-03(docs/07_예외_엣지케이스.md) / docs/03_화면명세.md §03 "예외" —
/// "facts 실패/타임아웃(15s) → 기존 광고 실패 폴백 시트 계열(문구
/// C-03-12). [다시 시도] → 03 처음부터, [나가기] → 01."
///
/// [서버 아키텍처 확인] Flutter 클라이언트에는 `/saju/v3/facts`를 직접
/// 호출하는 코드가 없다(`SajuRenewalApi`에는 `selectTopics()`와
/// `interpretSummary/Detail()`만 존재) — docs/05_데이터_API_상태.md
/// §1에 따르면 03 화면은 "POST /saju/v3/facts (+캐시)" 직후 바로
/// "topics/select"를 호출하는 것으로 명시되어 있고, 두 호출 모두
/// 03(CalculatingScreen) 체류 중 발생한다. 클라이언트 관점에서는
/// `selectTopics()` 실패 응답이 "facts 실패"와 "select 자체 실패"를
/// 구분하지 않고 동일한 오류 경로(`_loadTopics()`의 실패 분기 →
/// `status = error`)로 들어간다 — 즉 03 화면에서 발생하는 모든 초기
/// 적재 실패는 이 테스트가 재현하는 하나의 코드 경로를 공유한다.
///
/// 이 테스트는 그 실제 경로가 docs 요구사항과 어떻게 다른지(또는
/// 같은지)를 추측이 아니라 실측으로 확정한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthRepository())),
        ChangeNotifierProvider(
          create: (_) => SajuRenewalProvider(SajuRenewalApi()),
        ),
      ],
      child: const MaterialApp(home: _Screen01Stub()),
    );
  }

  http.Response topicsSelectSuccessResponse() {
    final body = {
      'success': true,
      'data': {
        'first_topic': {
          'topic_id': 'MONEY_001',
          'scene': 'money',
          'title': '테스트 이야기 제목',
          'is_timing': false,
          'evidence_fact_keys': <String>[],
        },
        'candidates': <Map<String, dynamic>>[],
        'key_facts': <String>['wood', 'fire'],
        'fact_schema_version': 'v1',
      },
    };
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  http.Response topicsSelectFactsFailureResponse() {
    // facts 생성 실패를 서버가 FACT_ENGINE_UNAVAILABLE(503)로 내려주는
    // 상황(SajuRenewalApi.selectTopics()의 errorCode 분기 참고).
    return http.Response(
      jsonEncode({
        'success': false,
        'error': '사주를 세우는 중에 연결이 끊겼어요. 다시 한 번 시도해 주세요.',
        'reason': 'FACT_ENGINE_UNAVAILABLE',
      }),
      503,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  http.Response interpretSummarySuccessResponse() {
    final body = {
      'success': true,
      'data': {
        'topic_id': 'MONEY_001',
        'title': '테스트 이야기 제목',
        'summary': '테스트 요약 내용입니다. 마지막 문장입니다.',
        'evidence': {'type': 'elements', 'text': '테스트 근거'},
        'source': 'llm',
      },
    };
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  testWidgets(
    'E-03 실측: facts/select 실패 시 03 체류 중 ErrorScreen으로 전환되고, '
    '[다시 시도]가 성공하면 03(세레모니) 화면을 다시 거치지 않고 04로 '
    '직행하며, [처음으로 돌아가기]는 01로 돌아간다 — 실제 동작을 '
    '있는 그대로 기록한다(불일치 여부 판정용)',
    (tester) async {
      // 1단계: topics/select가 항상 실패하도록 설정 — "facts 실패"에
      // 대응하는 클라이언트 관점 유일한 신호.
      var selectCallCount = 0;
      final failingClient = MockClient((request) async {
        if (request.url.path.contains('/topics/select')) {
          selectCallCount++;
          return topicsSelectFactsFailureResponse();
        }
        return http.Response('{}', 404);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(wrap());
        final navContext = tester.element(find.byType(_Screen01Stub));
        // 실제 01/02 화면이 CalculatingScreen push 직전에 수행하는 것과
        // 동일하게, 여기서도 명시적으로 startCalculating()을 먼저 호출한다
        // (CalculatingScreen 자신은 _loadTopics를 트리거하지 않음 — 호출부
        // 책임임을 실제 코드에서 확인함).
        navContext.read<SajuRenewalProvider>().startCalculating();
        Navigator.of(navContext).push(
          MaterialPageRoute(builder: (_) => const CalculatingScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350)); // 라우트 전환

        expect(find.byType(CalculatingScreen), findsOneWidget);

        // _loadTopics()는 즉시 실패를 반환하지만, 03의 세레모니는
        // "최소 3s" 리듬을 지키므로 실패 응답을 받은 즉시 전환되지
        // 않을 수 있다 — 넉넉하게 pump하며 전환을 기다린다.
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find.byType(ErrorScreen).evaluate().isNotEmpty) break;
        }

        expect(
          selectCallCount,
          1,
          reason: 'E-03 선행 조건 확인: topics/select가 호출되지 않음',
        );
        expect(
          find.byType(ErrorScreen),
          findsOneWidget,
          reason: 'E-03: facts/select 실패 시 ErrorScreen(폴백 시트 계열)으로 '
              '전환되지 않음',
        );
        // CalculatingScreen 자체는 pushReplacement로 대체되어 더 이상
        // 위젯 트리에 없어야 한다(세레모니 연출 정지).
        expect(find.byType(CalculatingScreen), findsNothing);
      }, () => failingClient);

      // 2단계: 이제부터는 재시도가 성공하도록 응답을 바꾼다 — "[다시
      // 시도]" 버튼을 눌렀을 때의 실제 경로를 측정한다.
      final succeedingClient = MockClient((request) async {
        if (request.url.path.contains('/topics/select')) {
          return topicsSelectSuccessResponse();
        }
        if (request.url.path.contains('/interpret')) {
          return interpretSummarySuccessResponse();
        }
        return http.Response('{}', 404);
      });

      await http.runWithClient(() async {
        final retryButton = find.widgetWithText(SajuButton, '다시 시도');
        expect(retryButton, findsOneWidget);
        await tester.tap(retryButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));

        // [실측 핵심] docs는 "[다시 시도] → 03 처음부터"를 요구하지만,
        // 실제 구현은 ErrorScreen에 머문 채 Provider.retry()만
        // 호출하고 성공하면 _maybeNavigateAfterRetry가 바로
        // AnalysisCompleteScreen(04)으로 pushReplacement한다 — 03
        // (세레모니 애니메이션)을 다시 보여주지 않는다. 이 테스트는
        // 그 실제 동작을 고정해 둔다(요구사항과 다르면 아래 expect가
        // 실패해 즉시 드러난다).
        expect(
          find.byType(CalculatingScreen),
          findsNothing,
          reason: '[참고] 만약 이 expect가 실패해 CalculatingScreen이 다시 '
              '보인다면, 구현이 바뀌어 docs 요구사항(03 처음부터 재시작)을 '
              '충족하게 된 것 — 이 테스트와 주석을 함께 갱신해야 한다.',
        );
        expect(
          find.byType(AnalysisCompleteScreen),
          findsOneWidget,
          reason: 'E-03 재시도 성공 후 04(분석 완료)로 전환되지 않음',
        );
      }, () => succeedingClient);
    },
  );

  testWidgets(
    'E-03: ErrorScreen의 [처음으로 돌아가기]는 내비게이션 스택 최초 '
    '화면(01 역할의 스텁)으로 돌아간다',
    (tester) async {
      final failingClient = MockClient((request) async {
        if (request.url.path.contains('/topics/select')) {
          return topicsSelectFactsFailureResponse();
        }
        return http.Response('{}', 404);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(wrap());
        final navContext = tester.element(find.byType(_Screen01Stub));
        navContext.read<SajuRenewalProvider>().startCalculating();
        Navigator.of(navContext).push(
          MaterialPageRoute(builder: (_) => const CalculatingScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find.byType(ErrorScreen).evaluate().isNotEmpty) break;
        }
        expect(find.byType(ErrorScreen), findsOneWidget);

        await tester.tap(find.text('처음으로 돌아가기'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(
          find.byType(_Screen01Stub),
          findsOneWidget,
          reason: 'E-03 위반: [나가기]가 01(스택 최초 화면)로 돌아가지 않음',
        );
        expect(find.byType(ErrorScreen), findsNothing);
        expect(find.byType(CalculatingScreen), findsNothing);
      }, () => failingClient);
    },
  );
}

/// 화면①(SajuRenewalHomeScreen) 역할을 하는 최소 스텁 — 실제 01 화면은
/// AuthProvider/프로필 상태 등 이 테스트와 무관한 의존성이 많아, "내비게이션
/// 스택의 첫 화면"이라는 역할만 필요한 이 테스트에서는 더미로 대체한다
/// (E-22 테스트의 `_FakePreviousScreen`과 동일한 패턴).
class _Screen01Stub extends StatelessWidget {
  const _Screen01Stub();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('화면01 스텁')));
  }
}
