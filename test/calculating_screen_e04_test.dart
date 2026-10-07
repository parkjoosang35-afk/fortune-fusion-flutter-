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

/// E-04(docs/07_예외_엣지케이스.md) — "topics/select 실패 | 03 | 9단계
/// 대기 상태로 재시도 1회 → 실패 시 `LIFE_000`을 첫 이야기로 04 진행 |
/// 없음".
///
/// [E-03과의 구분 — 서버 코드 실측 확정]
/// admin_web `topics/select/route.ts`를 직접 확인한 결과:
/// - `FACT_ENGINE_UNAVAILABLE`(getSajuFacts() 실패, 503) → E-03 영역
///   (연출 정지 → 폴백 시트, [다시 시도]→03 재시작).
/// - `UNAUTHORIZED`(401) → 재로그인 필요, 재시도/폴백 대상 아님.
/// - 그 외 실패(네트워크 예외, 서버 처리 중 예상치 못한 500 등 —
///   `errorCode`가 위 두 값이 아닌 모든 경우)가 E-04가 말하는
///   "select 실패"에 해당한다. 서버의 `topic-engine.ts` ⑤단계
///   "LIFE_000 폴백 보장"은 `selectTopics()` 함수가 **성공적으로
///   호출되었을 때** 후보 풀이 비지 않도록 보장하는 것으로, API 호출
///   자체가 실패하는 이 시나리오와는 무관하다 — 즉 "호출 실패 시 1회
///   재시도 + 클라이언트 측 LIFE_000 합성"은 Flutter의 책임이다.
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

  http.Response topicsSelectGenericFailureResponse() {
    // reason 필드가 없는(=FACT_ENGINE_UNAVAILABLE도 UNAUTHORIZED도 아닌)
    // 일반 서버 오류. route.ts의 "예상치 못한 내부 오류" catch 분기와
    // 동일한 형태(status 500, reason 없음).
    return http.Response(
      jsonEncode({'success': false, 'error': '주제를 불러오는 중 오류가 발생했습니다.'}),
      500,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  http.Response interpretSummarySuccessResponse(String topicId) {
    final body = {
      'success': true,
      'data': {
        'topic_id': topicId,
        'title': '평생 총론',
        'summary': 'LIFE_000 폴백 요약 내용입니다. 마지막 문장입니다.',
        'evidence': {'type': 'elements', 'text': '테스트 근거'},
        'source': 'template',
      },
    };
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  testWidgets(
    'E-04 실측: topics/select가 일반 오류로 2회(최초+재시도 1회) 실패하면 '
    'ErrorScreen으로 보내지 않고 LIFE_000을 첫 이야기로 04(분석완료)까지 '
    '진행한다 — 빈 화면/오류 화면 금지',
    (tester) async {
      var selectCallCount = 0;
      final failingClient = MockClient((request) async {
        if (request.url.path.contains('/topics/select')) {
          selectCallCount++;
          return topicsSelectGenericFailureResponse();
        }
        if (request.url.path.contains('/interpret')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return interpretSummarySuccessResponse(
            body['topic_id'] as String? ?? 'LIFE_000',
          );
        }
        return http.Response('{}', 404);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(wrap());
        final navContext = tester.element(find.byType(_Screen01Stub));
        final provider = navContext.read<SajuRenewalProvider>();
        provider.startCalculating();
        Navigator.of(navContext).push(
          MaterialPageRoute(builder: (_) => const CalculatingScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(CalculatingScreen), findsOneWidget);

        // 03의 "최소 3s" 세레모니 리듬 + 내부 재시도 1회(네트워크
        // 왕복 2회)가 끝날 때까지 충분히 pump한다.
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find.byType(AnalysisCompleteScreen).evaluate().isNotEmpty ||
              find.byType(ErrorScreen).evaluate().isNotEmpty) {
            break;
          }
        }

        expect(
          selectCallCount,
          2,
          reason: 'E-04: topics/select가 정확히 1회 재시도(최초 1 + 재시도 '
              '1 = 총 2회)되지 않음',
        );
        expect(
          find.byType(ErrorScreen),
          findsNothing,
          reason: 'E-04 위반: select 실패 시 오류 화면으로 빠짐(빈 화면/'
              '오류화면 금지 원칙 위반) — LIFE_000 폴백으로 04까지 '
              '진행해야 함',
        );
        expect(
          find.byType(AnalysisCompleteScreen),
          findsOneWidget,
          reason: 'E-04: LIFE_000 폴백 후 04(분석 완료)로 진행되지 않음',
        );
        expect(
          provider.currentTopic?.topicId,
          'LIFE_000',
          reason: 'E-04: currentTopic이 LIFE_000 폴백으로 설정되지 않음',
        );
        expect(
          provider.status,
          SajuRenewalFlowStatus.storyPreview,
          reason:
              'E-04: LIFE_000 폴백 후에도 summary interpret까지 이어져 '
              '정상 진행되지 않음(04→05 자연 전이 경로 유지 확인)',
        );
      }, () => failingClient);
    },
  );

  testWidgets(
    'E-04: topics/select 1차 실패 후 재시도가 성공하면 LIFE_000 폴백을 '
    '쓰지 않고 정상 서버 응답(실제 first_topic)으로 04까지 진행한다',
    (tester) async {
      var selectCallCount = 0;
      final mixedClient = MockClient((request) async {
        if (request.url.path.contains('/topics/select')) {
          selectCallCount++;
          if (selectCallCount == 1) {
            return topicsSelectGenericFailureResponse();
          }
          final body = {
            'success': true,
            'data': {
              'first_topic': {
                'topic_id': 'MONEY_002',
                'scene': 'money',
                'title': '재시도로 받은 정상 주제',
                'is_timing': false,
                'evidence_fact_keys': <String>[],
              },
              'candidates': <Map<String, dynamic>>[],
              'key_facts': <String>['wood'],
              'fact_schema_version': 'v1',
            },
          };
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path.contains('/interpret')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return interpretSummarySuccessResponse(
            body['topic_id'] as String? ?? 'MONEY_002',
          );
        }
        return http.Response('{}', 404);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(wrap());
        final navContext = tester.element(find.byType(_Screen01Stub));
        final provider = navContext.read<SajuRenewalProvider>();
        provider.startCalculating();
        Navigator.of(navContext).push(
          MaterialPageRoute(builder: (_) => const CalculatingScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find.byType(AnalysisCompleteScreen).evaluate().isNotEmpty) {
            break;
          }
        }

        expect(selectCallCount, 2, reason: '1차 실패 + 재시도 1회(성공)가 아님');
        expect(find.byType(ErrorScreen), findsNothing);
        expect(find.byType(AnalysisCompleteScreen), findsOneWidget);
        expect(
          provider.currentTopic?.topicId,
          'MONEY_002',
          reason: 'E-04: 재시도 성공 시 LIFE_000이 아니라 서버가 실제로 '
              '내려준 first_topic을 써야 함',
        );
      }, () => mixedClient);
    },
  );

  testWidgets(
    'E-04: FACT_ENGINE_UNAVAILABLE(E-03 영역)은 LIFE_000 폴백 대상이 '
    '아니며 기존처럼 ErrorScreen으로 전환된다(재시도 횟수도 1회만)',
    (tester) async {
      var selectCallCount = 0;
      final factsFailClient = MockClient((request) async {
        if (request.url.path.contains('/topics/select')) {
          selectCallCount++;
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

        expect(
          selectCallCount,
          1,
          reason: 'E-03(FACT_ENGINE_UNAVAILABLE)은 E-04 재시도 로직의 '
              '대상이 아니므로 1회만 호출되어야 함',
        );
        expect(find.byType(ErrorScreen), findsOneWidget);
        expect(find.byType(AnalysisCompleteScreen), findsNothing);

        // [테스트 정리] CalculatingScreen이 pushReplacement로 dispose된
        // 직후에도 `_pausableDelay`의 80ms 폴링 타이머가 한두 틱 남아
        // 있을 수 있다 — 추가로 pump해 완전히 정리되도록 한다(E-03
        // 테스트의 두 번째 케이스와 동일한 패턴, 거기서는 이어지는
        // 상호작용이 자연스럽게 이 역할을 했다).
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }, () => factsFailClient);
    },
  );
}

/// 화면①(SajuRenewalHomeScreen) 역할을 하는 최소 스텁 — E-03 테스트와
/// 동일한 패턴.
class _Screen01Stub extends StatelessWidget {
  const _Screen01Stub();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('화면01 스텁')));
  }
}
