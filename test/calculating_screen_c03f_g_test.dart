// ignore_for_file: no_leading_underscores_for_local_identifiers
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/auth/application/auth_provider.dart';
import 'package:flutter_app/features/auth/data/auth_repository.dart';
import 'package:flutter_app/features/saju_renewal/data/saju_renewal_api.dart';
import 'package:flutter_app/features/saju_renewal/screens/calculating_screen.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';

/// C-03f(docs/08_QA_체크리스트.md) 실제 동작 검증:
/// "캐시 히트여도 최소 3s, 정상 네트워크에서 9단계 완료 ≤ 8s(확정 STEP 기준)".
///
/// C-03g 실제 동작 검증:
/// "9단계 완료가 select 응답 도착 이후다."
///
/// [방법] `topics/select` + `interpret(summary)` 서버 응답을 **즉시(0ms
/// 지연)** 반환하는 MockClient로 `http.runWithClient`를 사용해 실제
/// [SajuRenewalApi]의 HTTP 레이어를 가로챈다 — 이것은 "캐시 히트"
/// 상황(서버가 즉시 응답)을 정확히 재현한다. 이 상태에서 실제
/// [CalculatingScreen] 위젯이 정말로 "최소 3s"(세레모니 STEP 리듬)를
/// 지킨 뒤에만 다음 화면(AnalysisCompleteScreen)으로 전환되는지 측정한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  http.Response _topicsSelectResponse() {
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
    return http.Response(jsonEncode(body), 200);
  }

  http.Response _interpretSummaryResponse() {
    final body = {
      'success': true,
      'data': {
        'summary': {
          'topic_id': 'MONEY_001',
          'title': '테스트 이야기 제목',
          'summary': '테스트 요약 내용입니다.',
          'evidence': {'type': 'elements', 'text': '테스트 근거'},
          'source': 'template',
        },
      },
    };
    return http.Response(jsonEncode(body), 200);
  }

  /// 즉시(지연 없이) 응답하는 MockClient — "캐시 히트" 상황 재현.
  MockClient instantClient() {
    return MockClient((request) async {
      if (request.url.path.contains('/topics/select')) {
        return _topicsSelectResponse();
      }
      if (request.url.path.contains('/interpret')) {
        return _interpretSummaryResponse();
      }
      return http.Response('not found', 404);
    });
  }

  Widget wrap() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(AuthRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => SajuRenewalProvider(SajuRenewalApi()),
        ),
      ],
      child: const MaterialApp(home: CalculatingScreen()),
    );
  }

  testWidgets(
    'C-03f/C-03g: topics/select + interpret(summary)이 즉시(0ms) 응답해도 '
    '(= 캐시 히트), 03 화면은 최소 3s 세레모니 리듬을 지킨 뒤에만 '
    '다음 화면으로 전환된다',
    (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(wrap());

        // 화면②에서 "입력완료"를 눌렀다고 가정하고 세레모니를 시작시킨다.
        final context = tester.element(find.byType(CalculatingScreen));
        // 실제 화면 플로우와 동일하게 Provider의 startCalculating()을
        // 호출해 즉시-응답 MockClient로 select+interpret을 완료시킨다.
        // (실제 앱에서는 birth_input_screen/home_screen이 호출함.)
        unawaited(context.read<SajuRenewalProvider>().startCalculating());

        // Provider의 비동기 체인(즉시 응답이어도 Future 스케줄링은 몇
        // microtask 필요)이 끝날 시간을 준다. 이 시점에 이미
        // factsReady/storyPreview에 도달했을 것이다(즉시 응답이므로).
        await tester.pump(const Duration(milliseconds: 50));

        final provider = context.read<SajuRenewalProvider>();
        expect(
          provider.status == SajuRenewalFlowStatus.factsReady ||
              provider.status == SajuRenewalFlowStatus.storyPreview,
          isTrue,
          reason:
              'MockClient가 즉시 응답했으므로 50ms 안에 Provider가 '
              'factsReady/storyPreview에 도달해야 함(현재: ${provider.status})',
        );

        // ── 핵심 검증: 서버가 이미 끝났어도(=0ms), 화면은 여전히 03에
        // 머물러 있어야 한다(최소 3s 세레모니 리듬 보장, C-03f). ──
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.byType(CalculatingScreen),
          findsOneWidget,
          reason:
              'C-03f 위반 가능성: 서버 응답이 즉시 와도 03 화면이 '
              '500ms 만에 이미 떠나 있음(최소 3s 보장 안 됨)',
        );

        await tester.pump(const Duration(milliseconds: 2000));
        expect(
          find.byType(CalculatingScreen),
          findsOneWidget,
          reason:
              'C-03f 위반: 서버 응답이 즉시 와도(캐시 히트) 03 화면 '
              '체류 시간이 2.5s(500+2000ms)에 불과한데, 이미 떠나 있음 '
              '— "최소 3s" 보장 위반',
        );

        // 최소 3s를 넘겨 9단계(완료 라벨 포함, 약 9.57s)까지 흘려보낸다.
        await tester.pump(const Duration(seconds: 7));
        await tester.pump(const Duration(milliseconds: 100));

        // 9단계 완료 후 AnalysisCompleteScreen으로 전환되었는지 확인
        // (= _maybeNavigate가 Provider 상태를 보고 실제로 전환을 수행).
        expect(
          find.byType(CalculatingScreen),
          findsNothing,
          reason:
              '9단계(최대 ~9.57s) 경과 후에도 03 화면에 머물러 있음 '
              '— select 응답 도착 후 정상적으로 04로 전환되어야 함',
        );
      }, () => instantClient());
    },
  );

  testWidgets(
    'C-03g: select(topics) 응답이 아직 오지 않았으면, 세레모니가 9단계 '
    'STEP 리듬을 모두 마쳐도 화면은 03에 머물며(대기 인디케이터), '
    'select 응답이 도착해야만 비로소 다음 화면으로 전환된다',
    (tester) async {
      // 응답을 영원히 보류하는(테스트 종료까지) Completer 기반 MockClient.
      final topicsCompleter = Completer<http.Response>();
      void releaseTopics() {
        if (!topicsCompleter.isCompleted) {
          topicsCompleter.complete(_topicsSelectResponse());
        }
      }

      MockClient delayedClient() {
        return MockClient((request) async {
          if (request.url.path.contains('/topics/select')) {
            return topicsCompleter.future;
          }
          if (request.url.path.contains('/interpret')) {
            return _interpretSummaryResponse();
          }
          return http.Response('not found', 404);
        });
      }

      await http.runWithClient(() async {
        await tester.pumpWidget(wrap());
        final context = tester.element(find.byType(CalculatingScreen));
        unawaited(context.read<SajuRenewalProvider>().startCalculating());
        await tester.pump(const Duration(milliseconds: 10));

        final provider = context.read<SajuRenewalProvider>();
        expect(
          provider.status,
          SajuRenewalFlowStatus.calculating,
          reason: 'select 응답을 보류 중이므로 Provider는 아직 calculating 상태여야 함',
        );

        // 9단계 전체 리듬(최대 9.57s)을 다 흘려보내도, select 응답이
        // 아직 없으므로 03 화면에 머물러 있어야 한다(C-03g).
        await tester.pump(const Duration(seconds: 9));
        await tester.pump(const Duration(milliseconds: 700));
        expect(
          find.byType(CalculatingScreen),
          findsOneWidget,
          reason:
              'C-03g 위반: select 응답이 아직 도착하지 않았는데도 '
              '03 화면이 9단계 리듬 경과만으로 다음 화면으로 떠나버림',
        );
        expect(
          provider.status,
          SajuRenewalFlowStatus.calculating,
          reason: '여전히 select 응답 대기 중이어야 함',
        );

        // 이제 select 응답을 풀어준다 — 비로소 다음 화면으로 전환되어야 함.
        releaseTopics();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.byType(CalculatingScreen),
          findsNothing,
          reason: 'select 응답 도착 후에는 즉시(또는 postFrameCallback 직후) '
              '04로 전환되어야 함(C-03g)',
        );
      }, delayedClient);
    },
  );
}
