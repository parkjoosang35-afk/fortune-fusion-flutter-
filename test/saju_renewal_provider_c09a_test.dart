import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/features/saju_renewal/data/saju_renewal_api.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';

/// C-09a(docs/08_QA_체크리스트.md) — "05~07과 같은 컴포넌트, 조명·태그
/// 순번(N°02…)만 변경. facts 재호출 없음." 중 [SajuRenewalProvider.ordinalOf]
/// 검증.
///
/// [기존 결함] `viewedStoryCount + 1`(=상세보기 **완료** 횟수)을 그대로
/// ordinal으로 썼다. `onAccessGranted()`가 07 렌더링 직전에
/// `_viewedTopicIds.add()`를 실행하므로, 같은 이야기인데도 05에서는
/// "N°01", 07에서는 "N°02"로 1 증가해 보이는 불일치가 재현 테스트로
/// 확인되었다. jsx 원본(`screens-b.jsx` `pick()`)의 `ordinal`은 08에서
/// "새 주제를 선택"하는 순간에만 증가하고 05↔07 전환으로는 바뀌지 않는다.
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

  http.Response topicsResp(String firstId, List<String> candidateIds) =>
      http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'first_topic': topicJson(firstId),
            'candidates': candidateIds.map(topicJson).toList(),
            'key_facts': <String>['wood'],
            'fact_schema_version': 'v1',
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  http.Response summaryResp(String id) => http.Response(
    jsonEncode({
      'success': true,
      'data': {
        'topic_id': id,
        'title': 't',
        'summary': 's',
        'evidence': {'type': 'elements', 'text': 'e'},
        'source': 'template',
      },
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  http.Response detailResp(String id) => http.Response(
    jsonEncode({
      'success': true,
      'data': {
        'topic_id': id,
        'title': 't',
        'blocks': [
          {'n': 1, 'body': 'b'},
        ],
        'source': 'template',
      },
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  test(
    'ordinalOf: 같은 주제(topic A)는 05 진입 시점과 07(상세보기 완료) '
    '시점에 동일한 순번을 돌려준다',
    () async {
      var factsCallCount = 0;
      final client = MockClient((req) async {
        if (req.url.path.contains('/topics/select')) {
          factsCallCount++;
          return topicsResp('A', []);
        }
        if (req.url.path.contains('/interpret')) {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          if (body['mode'] == 'detail') return detailResp('A');
          return summaryResp('A');
        }
        return http.Response('not found', 404);
      });

      await http.runWithClient(() async {
        final provider = SajuRenewalProvider(SajuRenewalApi());
        await provider.startCalculating();
        final topic = provider.currentTopic!;

        final ordinalAt05 = provider.ordinalOf(topic.topicId);
        expect(ordinalAt05, 1, reason: 'C-09a: 첫 이야기는 N°01이어야 함');

        await provider.onAccessGranted();
        final ordinalAt07 = provider.ordinalOf(topic.topicId);

        expect(
          ordinalAt07,
          ordinalAt05,
          reason:
              'C-09a 위반: 같은 이야기(topic A)인데 05와 07에서 순번이 '
              '다름(05=$ordinalAt05, 07=$ordinalAt07) — 상세보기 완료가 '
              '순번에 영향을 주면 안 됨',
        );
        expect(
          factsCallCount,
          1,
          reason:
              'C-09a 위반: 05→07 전환 중 facts(topics/select)가 재호출됨 '
              '— "facts 재호출 없음"(docs/08) 원칙 위반',
        );
      }, () => client);
    },
  );

  test(
    'ordinalOf: 08에서 새 주제(topic B)를 선택하면 순번이 2로 증가하고, '
    '그 05/07 전환에도 다시 동일하게 유지된다',
    () async {
      final client = MockClient((req) async {
        if (req.url.path.contains('/topics/select')) {
          return topicsResp('A', ['B', 'C']);
        }
        if (req.url.path.contains('/interpret')) {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          final topicId = body['topic_id'] as String;
          if (body['mode'] == 'detail') return detailResp(topicId);
          return summaryResp(topicId);
        }
        return http.Response('not found', 404);
      });

      await http.runWithClient(() async {
        final provider = SajuRenewalProvider(SajuRenewalApi());
        await provider.startCalculating(); // topic A, ordinal 1.
        await provider.onAccessGranted(); // A 상세보기 완료.
        provider.showMoreTopics();

        final candidateB = provider.displayableCandidates.first;
        expect(candidateB.topicId, 'B');

        // 08에서 B를 선택(= loadPreview) → "새 주제 선택" 시점이므로
        // 순번이 2로 증가해야 한다(jsx `pick()`의 `ordinal+1`과 동일 시점).
        await provider.loadPreview(candidateB);
        final ordinalAt05 = provider.ordinalOf('B');
        expect(
          ordinalAt05,
          2,
          reason: 'C-09a: 두 번째로 선택한 주제는 N°02여야 함',
        );

        await provider.onAccessGranted(); // B 상세보기 완료.
        final ordinalAt07 = provider.ordinalOf('B');
        expect(
          ordinalAt07,
          2,
          reason:
              'C-09a 위반: B의 05 순번(2)과 07 순번($ordinalAt07)이 다름',
        );

        // 이전 주제 A의 순번은 그대로 1로 유지되어야 한다(재방문해도
        // 밀리지 않음).
        expect(provider.ordinalOf('A'), 1);
      }, () => client);
    },
  );
}
