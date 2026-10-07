// ignore_for_file: no_leading_underscores_for_local_identifiers
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/features/saju_renewal/data/saju_renewal_api.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';

/// C-08b(docs/08_QA_체크리스트.md) — [SajuRenewalProvider.refreshCandidates]
/// 실제 동작 검증.
///
/// docs/03_화면명세.md §08 "[새로운 이야기]: 남은 후보로 교체(애니 rise
/// 재생). 남은 후보 < 3 → topics/select 재호출(exclude=본 주제들)." +
/// §08 목적 "선택에만 LLM 비용(후보 노출은 0비용)" 근거.
///
/// [기존 결함] 과거 `loadMoreTopics()`는 버튼을 누를 때마다 항상
/// `topics/select`뿐 아니라 그 끝에서 `interpretSummary`(LLM 호출)까지
/// 트리거했다. 이 테스트는 그 결함이 재발하지 않음을 서버 호출 횟수로
/// 직접 검증한다.
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

  http.Response interpretDetailResponse() {
    final body = {
      'success': true,
      'data': {
        'topic_id': 'FIRST_001',
        'title': '테스트 이야기 제목',
        'blocks': [
          {'n': 1, 'body': '핵심 블록 본문'},
        ],
        'source': 'template',
      },
    };
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  test(
    'refreshCandidates: 로컬에 3장 이상 남아있으면 topics/select를 다시 '
    '호출하지 않는다(0비용 로컬 교체, docs/03 §08)',
    () async {
      var topicsSelectCallCount = 0;
      var interpretCallCount = 0;
      final client = MockClient((request) async {
        if (request.url.path.contains('/topics/select')) {
          topicsSelectCallCount++;
          // 초기 풀: candidates 6개(A~F) — displayableCandidates가
          // 3장을 보여준 뒤에도 로컬에 3장(D,E,F)이 남는다.
          return topicsSelectResponse(['A', 'B', 'C', 'D', 'E', 'F']);
        }
        if (request.url.path.contains('/interpret')) {
          interpretCallCount++;
          return interpretSummaryResponse();
        }
        return http.Response('not found', 404);
      });

      await http.runWithClient(() async {
        final provider = SajuRenewalProvider(SajuRenewalApi());
        await provider.startCalculating();

        expect(topicsSelectCallCount, 1);
        // startCalculating → _loadTopics → loadPreview 순서로 interpret이
        // 정확히 1번만 호출되어야 한다(최초 진입 시의 정상 흐름).
        expect(interpretCallCount, 1);

        // 최초 후보 3장(A,B,C) 노출 확인.
        final firstBatch = provider.displayableCandidates
            .map((c) => c.topicId)
            .toList();
        expect(firstBatch, ['A', 'B', 'C']);
        expect(provider.remainingLocalCandidateCount, 6);
        final batchBefore = provider.candidateBatch;

        // [새로운 이야기] 클릭 — 로컬에 D,E,F가 남아있으므로(3장) 서버를
        // 다시 부르면 안 된다.
        await provider.refreshCandidates();

        expect(
          topicsSelectCallCount,
          1,
          reason: 'C-08b 위반: 로컬에 3장이 남아있는데도 topics/select를 '
              '다시 호출함(0비용 원칙 위반)',
        );
        expect(
          interpretCallCount,
          1,
          reason: 'C-08b 위반: 후보 교체만 했는데 interpretSummary(LLM)가 '
              '다시 호출됨 — "선택에만 LLM 비용" 원칙 위반',
        );

        final secondBatch = provider.displayableCandidates
            .map((c) => c.topicId)
            .toList();
        expect(
          secondBatch,
          ['D', 'E', 'F'],
          reason: 'C-08b 위반: "남은 후보로 교체"가 제대로 동작하지 않음',
        );
        expect(
          provider.candidateBatch,
          greaterThan(batchBefore),
          reason: 'C-08b 위반: 배치 변경 시 candidateBatch가 증가하지 않아 '
              '카드 rise 애니메이션 키가 바뀌지 않음(docs/04 §4-5)',
        );
        expect(provider.isRefreshingCandidates, isFalse);
      }, () => client);
    },
  );

  test(
    'refreshCandidates: 로컬 후보가 3장 미만이면 topics/select를 '
    'exclude_topic_ids와 함께 재호출한다(docs/03 §08)',
    () async {
      var topicsSelectCallCount = 0;
      var interpretCallCount = 0;
      List<String>? lastExcludeIds;
      final client = MockClient((request) async {
        if (request.url.path.contains('/topics/select')) {
          topicsSelectCallCount++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body.containsKey('exclude_topic_ids')) {
            lastExcludeIds = List<String>.from(
              body['exclude_topic_ids'] as List,
            );
          }
          if (topicsSelectCallCount == 1) {
            // 최초 풀: 후보 3개뿐(A,B,C) — 한 번 교체하면 로컬에 0장만
            // 남아 즉시 재호출 조건(<3)에 걸린다.
            return topicsSelectResponse(['A', 'B', 'C']);
          }
          // 재호출 응답: 새 후보 풀(G,H,I).
          return topicsSelectResponse(['G', 'H', 'I']);
        }
        if (request.url.path.contains('/interpret')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['mode'] == 'detail') {
            return interpretDetailResponse();
          }
          interpretCallCount++;
          return interpretSummaryResponse();
        }
        return http.Response('not found', 404);
      });

      await http.runWithClient(() async {
        final provider = SajuRenewalProvider(SajuRenewalApi());
        await provider.startCalculating();
        // [exclude_topic_ids 근거 마련] 화면⑦에서 FIRST_001 상세보기까지
        // 완료한 상태를 재현 — _viewedTopicIds에 담겨야 재호출 시
        // exclude_topic_ids로 서버에 전달된다(docs/03 §08 "exclude=본
        // 주제들").
        await provider.onAccessGranted();

        expect(topicsSelectCallCount, 1);
        expect(provider.remainingLocalCandidateCount, 3);

        // 첫 교체 — 로컬에 3장(A,B,C) 소비 후 0장 남음(<3) → 서버 재호출.
        final refreshFuture = provider.refreshCandidates();
        // 재호출 도중에는 전용 플래그만 켜지고, topicsState 자체는
        // loading으로 바뀌지 않아야 한다(화면은 카드 유지, 버튼만 disable).
        expect(provider.isRefreshingCandidates, isTrue);
        expect(provider.topicsState.isLoading, isFalse);
        await refreshFuture;

        expect(
          topicsSelectCallCount,
          2,
          reason: 'C-08b 위반: 로컬 후보가 소진됐는데 topics/select 재호출이 '
              '일어나지 않음',
        );
        expect(
          interpretCallCount,
          1,
          reason: 'C-08b 위반: 재호출(exclude) 흐름에서도 interpretSummary가 '
              '불필요하게 또 호출됨(LLM 비용 발생)',
        );
        expect(
          lastExcludeIds,
          contains('FIRST_001'),
          reason: 'C-08b/C-08a 연계: exclude_topic_ids에 이미 본 주제가 '
              '빠지면 Exposure History 정책과 정합이 깨짐',
        );
        expect(provider.isRefreshingCandidates, isFalse);

        final newBatch = provider.displayableCandidates
            .map((c) => c.topicId)
            .toList();
        expect(
          newBatch,
          ['G', 'H', 'I'],
          reason: 'C-08b 위반: 서버 재호출 후 새 후보 풀로 교체되지 않음',
        );
      }, () => client);
    },
  );

  test(
    'refreshCandidates: 재호출 중 중복 호출을 가드한다(중복클릭 방어)',
    () async {
      var topicsSelectCallCount = 0;
      final completer = Completer<void>();
      final client = MockClient((request) async {
        if (request.url.path.contains('/topics/select')) {
          topicsSelectCallCount++;
          if (topicsSelectCallCount == 1) {
            return topicsSelectResponse(['A', 'B', 'C']);
          }
          // 두 번째(재호출) 요청은 completer가 풀릴 때까지 대기 —
          // 그 사이 refreshCandidates를 또 호출해도 가드되어야 한다.
          await completer.future;
          return topicsSelectResponse(['G', 'H', 'I']);
        }
        if (request.url.path.contains('/interpret')) {
          return interpretSummaryResponse();
        }
        return http.Response('not found', 404);
      });

      await http.runWithClient(() async {
        final provider = SajuRenewalProvider(SajuRenewalApi());
        await provider.startCalculating();

        final first = provider.refreshCandidates();
        // 재호출이 진행 중인 상태에서 또 호출 — 가드되어 새 네트워크
        // 요청을 추가로 만들지 않아야 한다.
        final second = provider.refreshCandidates();
        expect(provider.isRefreshingCandidates, isTrue);

        completer.complete();
        await first;
        await second;

        expect(
          topicsSelectCallCount,
          2,
          reason: 'C-08b 위반: 재호출 중 중복 호출 가드가 동작하지 않아 '
              'topics/select가 3번 이상 호출됨',
        );
      }, () => client);
    },
  );
}
