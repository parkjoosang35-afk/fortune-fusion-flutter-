// ignore_for_file: no_leading_underscores_for_local_identifiers
import 'dart:async';
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
import 'package:flutter_app/features/saju_renewal/screens/story_detail_screen.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';

/// E-07(docs/07_예외_엣지케이스.md) — "interpret(상세) 실패 → 07 → 템플릿
/// 상주 상세 → 없으면 요약+근거+C-07-9 [다시 시도]. 재게이트 금지."
///
/// [기존 결함] 서버가 템플릿 상세조차 내려주지 못해 `interpretDetail`
/// 자체가 실패(success:false)하면, 화면은 에러 메시지 Text 하나만 보여줄
/// 뿐 재시도 버튼이 전혀 없어 사용자가 막다른 길에 갇혔다(05/06 화면에는
/// 이미 재시도 버튼이 있는데 07에만 누락되어 있었음 — 실제 코드/화면
/// 대조로 확인).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  http.Response topicsSelectResponse() {
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

  http.Response interpretSummaryResponse() {
    final body = {
      'success': true,
      'data': {
        'topic_id': 'MONEY_001',
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

  http.Response interpretDetailFailResponse() {
    final body = {'success': false, 'error': '이야기를 불러오지 못했습니다.'};
    return http.Response(
      jsonEncode(body),
      500,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  http.Response interpretDetailSuccessResponse() {
    final body = {
      'success': true,
      'data': {
        'topic_id': 'MONEY_001',
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

  Widget wrap() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthRepository())),
        ChangeNotifierProvider(
          create: (_) => SajuRenewalProvider(SajuRenewalApi()),
        ),
      ],
      child: const MaterialApp(home: StoryDetailScreen()),
    );
  }

  testWidgets(
    'E-07: 상세 interpret이 실패하면 05 요약+근거 + "잠시 후 다시 열어 '
    '주세요"(C-07-9) + [다시 시도] 버튼을 보여주고, 재시도 성공 시 '
    'Access Gate 재오픈 없이 바로 상세로 전환된다',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var detailCallCount = 0;
      final client = MockClient((request) async {
        if (request.url.path.contains('/topics/select')) {
          return topicsSelectResponse();
        }
        if (request.url.path.contains('/interpret')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['mode'] == 'detail') {
            detailCallCount++;
            if (detailCallCount == 1) return interpretDetailFailResponse();
            return interpretDetailSuccessResponse();
          }
          return interpretSummaryResponse();
        }
        return http.Response('not found', 404);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(wrap());
        final context = tester.element(find.byType(StoryDetailScreen));
        final provider = context.read<SajuRenewalProvider>();
        unawaited(provider.startCalculating());
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
        await provider.onAccessGranted(); // 1차 detail 실패.
        await tester.pump();
        await tester.pump();

        // 05 요약 제목/본문이 07 실패 화면에 그대로 보여야 한다.
        expect(
          find.text('테스트 이야기 제목'),
          findsOneWidget,
          reason: 'E-07 위반: 상세 실패 시 05 요약 제목이 폴백으로 보이지 않음',
        );
        expect(
          find.text('잠시 후 다시 열어 주세요'),
          findsOneWidget,
          reason: 'E-07 위반: C-07-9 문구가 노출되지 않음',
        );
        final retryButton = find.text('다시 시도');
        expect(
          retryButton,
          findsOneWidget,
          reason: 'E-07 위반: 상세 실패 시 [다시 시도] 버튼이 없음(막다른 길)',
        );

        // [다시 시도] 탭 → onAccessGranted() 재호출(= provider.retry()) →
        // Access Gate가 다시 열리지 않고(이 화면 자체가 Gate를 띄우지
        // 않으므로 구조적으로 보장) 바로 두 번째 detail 응답(성공)으로
        // 전환되어야 한다.
        // [주의] 이 화면은 SajuSceneBg 등 반복 애니메이션을 포함하므로
        // pumpAndSettle()은 타임아웃된다(story_detail_screen_c07_test.dart
        // C-07d와 동일한 제약). 또한 [다시 시도]의 await
        // 체인(setState→provider.retry()→onAccessGranted()→
        // _api.interpretDetail()→http.post().timeout())은 내부적으로
        // Timer(타임아웃 가드)를 포함하므로, duration 없는 pump()만으로는
        // 트리거되지 않는다(=화면 진입 시 사용한 최초 체인과 동일하게
        // duration을 넣은 pump를 섞어야 fake clock이 전진하며 타이머
        // 콜백이 풀린다 — 위 최초 로드 체인과 동일 패턴).
        // [추가 주의] `detailCallCount`는 MockClient 핸들러가 요청을
        // "수신"한 시점에 증가하므로(= client.send() 디스패치 시점),
        // 카운터가 2가 됐다는 것은 "두 번째 요청이 전송됐다"는 뜻일 뿐,
        // jsonDecode→provider 상태 반영→위젯 리빌드까지 끝났다는 보장은
        // 아니다 — 응답이 실제로 화면에 반영될 때까지 pump를 반복한다.
        await tester.tap(retryButton);
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (find.text('핵심 블록 본문').evaluate().isNotEmpty) break;
        }

        expect(
          detailCallCount,
          2,
          reason: 'E-07 위반: [다시 시도]가 interpretDetail을 재호출하지 않음',
        );
        expect(
          find.text('핵심 블록 본문'),
          findsOneWidget,
          reason: 'E-07 위반: 재시도 성공 후 정상 상세 화면으로 전환되지 않음',
        );
        // 재게이트 금지 확인 — Access Gate 바텀시트(모달)가 뜨지 않았어야
        // 한다. 이 화면은애초에 Gate 위젯을 호출하지 않으므로, 여기서는
        // ModalBarrier가 없음으로 간접 확인한다.
        expect(find.byType(ModalBarrier), findsNothing);
      }, () => client);
    },
  );
}
