// ignore_for_file: no_leading_underscores_for_local_identifiers
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/features/saju_renewal/data/saju_renewal_api.dart';
import 'package:flutter_app/features/saju_renewal/screens/more_stories_screen.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';

/// C-08b(docs/08_QA_체크리스트.md) 화면 수준 검증 — "[↻ 새로운 이야기]"
/// 버튼이 재호출 중 실제로 비활성화되는지(docs/03 §08 "재호출 중 버튼
/// disabled").
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Map<String, dynamic> topicJson(String id) => {
    'topic_id': id,
    'scene': 'money',
    'title': '테스트 $id',
    'is_timing': false,
    'evidence_fact_keys': <String>[],
  };

  http.Response topicsSelectResponse(List<String> candidateIds) {
    final body = {
      'success': true,
      'data': {
        'first_topic': topicJson('FIRST_001'),
        'candidates': candidateIds.map(topicJson).toList(),
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

  http.Response interpretSummaryResponse() {
    final body = {
      'success': true,
      'data': {
        'topic_id': 'FIRST_001',
        'title': '테스트 이야기 제목',
        'summary': '테스트 요약 내용입니다. 이것은 마지막 문장입니다.',
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

  Widget wrap(SajuRenewalProvider provider) {
    return ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: MoreStoriesScreen()),
    );
  }

  testWidgets(
    'C-08b: 로컬 후보가 3장 미만이라 서버 재호출이 발생하면 '
    '"[새로운 이야기]" 버튼이 재호출 중 비활성화된다',
    (tester) async {
      var topicsSelectCallCount = 0;
      final completer = Completer<http.Response>();
      final client = MockClient((request) async {
        if (request.url.path.contains('/topics/select')) {
          topicsSelectCallCount++;
          if (topicsSelectCallCount == 1) {
            // 후보 3장뿐 — 교체 1회로 즉시 소진되어 재호출 분기를 탄다.
            return topicsSelectResponse(['A', 'B', 'C']);
          }
          // 재호출 응답은 테스트가 명시적으로 completer.complete()할 때까지
          // 지연시켜, 그 사이 버튼 상태를 관찰할 수 있게 한다.
          return completer.future;
        }
        if (request.url.path.contains('/interpret')) {
          return interpretSummaryResponse();
        }
        return http.Response('not found', 404);
      });

      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await http.runWithClient(() async {
        final provider = SajuRenewalProvider(SajuRenewalApi());
        await provider.startCalculating();
        provider.showMoreTopics();

        await tester.pumpWidget(wrap(provider));
        await tester.pump();

        // 최초 상태 — 후보 3장(A,B,C) 노출, 버튼은 "새로운 이야기" 라벨.
        expect(find.text('새로운 이야기'), findsOneWidget);

        // 버튼 탭 — 로컬 소진 → 서버 재호출 시작(아직 completer 미완료).
        await tester.tap(find.text('새로운 이야기'));
        await tester.pump();

        // 재호출 중에는 버튼의 GestureDetector.onTap이 null이어야 한다
        // (docs/03 §08 "재호출 중 버튼 disabled").
        final gesture = tester.widget<GestureDetector>(
          find
              .ancestor(
                of: find.text('새로운 이야기'),
                matching: find.byType(GestureDetector),
              )
              .first,
        );
        expect(
          gesture.onTap,
          isNull,
          reason: 'C-08b 위반: 재호출 중에도 "새로운 이야기" 버튼이 '
              '활성 상태로 남아있어 중복 탭이 가능함',
        );

        // 서버 응답 도착 → 재호출 종료 → 버튼 다시 활성화.
        completer.complete(topicsSelectResponse(['G', 'H', 'I']));
        await tester.pump();
        await tester.pump();
        // [타이머 정리] 새 배치의 `_RiseIn`(Future.delayed 최대 160ms +
        // 600ms 애니메이션)이 테스트 종료 시점까지 남아있으면
        // "Timer is still pending" 어서션에 걸린다 — 충분히 흘려보낸다.
        await tester.pump(const Duration(milliseconds: 900));

        final gestureAfter = tester.widget<GestureDetector>(
          find
              .ancestor(
                of: find.text('새로운 이야기'),
                matching: find.byType(GestureDetector),
              )
              .first,
        );
        expect(
          gestureAfter.onTap,
          isNotNull,
          reason: 'C-08b 위반: 재호출 완료 후에도 버튼이 계속 비활성 상태임',
        );
      }, () => client);
    },
  );
}
