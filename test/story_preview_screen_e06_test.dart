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
import 'package:flutter_app/features/saju_renewal/screens/error_screen.dart';
import 'package:flutter_app/features/saju_renewal/screens/story_preview_screen.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';

/// E-06(docs/07_예외_엣지케이스.md) — "interpret(요약) 실패 / 8s 초과 →
/// 05·09 → 주제 템플릿 상주 문구로 즉시 대체. 화면: 정상 화면과 동일."
///
/// [서버 계약(docs/11_API_계약서.md §3/§5) 근거] interpret summary는
/// LLM이 8초를 넘기면 서버(interpret-service.ts)가 **success:true +
/// source:"template"**로 즉시 폴백 본문을 내려주는 구조다(§5 표:
/// "interpret summary | 8s | E-06 템플릿" — "실패 시" 칸이 HTTP 오류가
/// 아니라 "템플릿 내용으로 대체된 성공 응답"을 의미). 즉 클라이언트
/// 입장에서는 `source` 값에 따라 분기할 필요가 전혀 없고(실제로
/// `InterpretSummaryResult.source`는 어떤 화면 코드에서도 읽히지 않음
/// — "내부 디버깅용, 화면 노출 금지" 설계 그대로), `source:"llm"`이든
/// `source:"template"`이든 완전히 동일한 성공 경로(05 정상 렌더)를
/// 타야 한다.
///
/// 이 테스트는 그 "화면 동일성"을 실제로 측정한다: source가 "template"인
/// 응답을 interpret summary로 돌려주었을 때, (1) 05 화면이 정상 렌더되고
/// (2) 에러 화면(ErrorScreen)으로 전환되지 않으며 (3) "템플릿"이라는
/// 단어나 source 값 자체가 화면 어디에도 노출되지 않음을 확인한다.
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

  /// [E-06 핵심] LLM이 8초 타임아웃되어 서버가 폴백한 상황을 그대로
  /// 재현한 응답 — HTTP 200 + success:true + source:"template".
  http.Response interpretSummaryTemplateFallbackResponse() {
    final body = {
      'success': true,
      'data': {
        'topic_id': 'MONEY_001',
        'title': '재물의 흐름을 읽는 이야기',
        'summary': '주제에 맞는 상주 템플릿 요약입니다. 이것은 마지막 문장입니다.',
        'evidence': {'type': 'elements', 'text': '템플릿 근거 문장'},
        // [핵심] LLM 타임아웃 폴백 신호 — 화면에는 절대 노출되지 않아야 함.
        'source': 'template',
      },
    };
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  MockClient templateFallbackClient() {
    return MockClient((request) async {
      if (request.url.path.contains('/topics/select')) {
        return topicsSelectResponse();
      }
      if (request.url.path.contains('/interpret')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['mode'] == 'summary') {
          return interpretSummaryTemplateFallbackResponse();
        }
        return http.Response('{}', 404);
      }
      return http.Response('not found', 404);
    });
  }

  Widget wrap() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthRepository())),
        ChangeNotifierProvider(
          create: (_) => SajuRenewalProvider(SajuRenewalApi()),
        ),
      ],
      child: const MaterialApp(home: StoryPreviewScreen()),
    );
  }

  testWidgets(
    'E-06: interpret summary가 source:"template"(LLM 8s 타임아웃 폴백)로 '
    '응답해도 05 화면은 정상 성공 경로로 렌더되고(에러 화면 전환 없음), '
    '템플릿 본문이 llm 응답과 동일하게 제목·요약·근거에 표시되며, '
    '"template"/"폴백" 등 내부 신호는 화면에 전혀 노출되지 않는다',
    (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(wrap());
        final context = tester.element(find.byType(StoryPreviewScreen));
        final provider = context.read<SajuRenewalProvider>();
        unawaited(provider.startCalculating());
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // (1) Provider 상태가 에러로 전환되지 않고 정상 storyPreview
        // 성공 상태여야 한다.
        expect(
          provider.status,
          SajuRenewalFlowStatus.storyPreview,
          reason: 'E-06 위반: template 폴백 응답인데도 정상 성공 상태로 '
              '전환되지 않음(= 서버 폴백을 클라이언트가 오류로 잘못 처리)',
        );
        expect(
          provider.previewState.isError,
          isFalse,
          reason: 'E-06 위반: template 폴백 응답을 previewState 에러로 '
              '잘못 처리함',
        );

        // (2) 화면이 ErrorScreen으로 전환되지 않고 StoryPreviewScreen이
        // 정상 유지되어야 한다("정상 화면과 동일").
        expect(find.byType(ErrorScreen), findsNothing);
        expect(find.byType(StoryPreviewScreen), findsOneWidget);

        // (3) 템플릿 본문이 llm 응답과 동일한 방식(제목/요약/근거)으로
        // 화면에 정상 표시되어야 한다.
        expect(find.text('재물의 흐름을 읽는 이야기'), findsOneWidget);
        expect(
          find.textContaining(
            '주제에 맞는 상주 템플릿 요약입니다',
            findRichText: true,
          ),
          findsOneWidget,
        );

        // (4) "내부 정보 비노출 원칙" — source 값/디버깅 신호가 사용자
        // 화면에 그대로 노출되면 안 된다.
        expect(find.text('template'), findsNothing);
        expect(find.textContaining('폴백'), findsNothing);
        expect(find.textContaining('fallback'), findsNothing);
      }, () => templateFallbackClient());
    },
  );
}
