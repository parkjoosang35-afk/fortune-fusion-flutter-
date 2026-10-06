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
import 'package:flutter_app/features/saju_renewal/screens/story_preview_screen.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';
import 'package:flutter_app/features/saju_renewal/widgets/saju_base_widgets.dart';
import 'package:flutter_app/features/saju_renewal/widgets/saju_story_widgets.dart';

/// C-05a/b/c/d(docs/08_QA_체크리스트.md) 실제 동작 검증.
///
/// [방법] topics/select + interpret(summary/detail) 서버 응답을 즉시
/// 반환하는 MockClient로 실제 Provider 흐름을 구동해, 화면⑤
/// (StoryPreviewScreen)의 CTA 분기(미해제/해제됨)가 원본
/// `design_files/saju/screens-b.jsx` `ScreenPreview`의
/// `unlocked ? go('07') : go('06')` 로직과 1:1로 동작하는지 측정한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  http.Response _interpretSummaryResponse() {
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

  http.Response _interpretDetailResponse() {
    final body = {
      'success': true,
      'data': {
        'topic_id': 'MONEY_001',
        'title': '테스트 이야기 제목',
        'blocks': [
          {'n': 1, 'body': '핵심 블록 본문'},
          {'n': 2, 'body': '왜 블록 본문'},
          {'n': 3, 'body': '생활 블록 본문'},
          {'n': 5, 'body': '포인트 블록 본문'},
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

  MockClient instantClient() {
    return MockClient((request) async {
      if (request.url.path.contains('/topics/select')) {
        return _topicsSelectResponse();
      }
      if (request.url.path.contains('/interpret')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['mode'] == 'detail') {
          return _interpretDetailResponse();
        }
        return _interpretSummaryResponse();
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

  testWidgets('C-05c 미해제: 아직 상세보기를 완료하지 않은 topic은 '
      '[자세한 이야기 열어 보기] + 안내 문구가 보이고, [자세히 보기]는 없다', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap());
      final context = tester.element(find.byType(StoryPreviewScreen));
      unawaited(context.read<SajuRenewalProvider>().startCalculating());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(
        find.text('자세한 이야기 열어 보기'),
        findsOneWidget,
        reason: 'C-05c 위반: 미해제 상태인데 미해제 CTA(C-05-4)가 안 보임',
      );
      expect(
        find.text('프리패스 · 복주머니 · 광고 중 하나로 열 수 있어요'),
        findsOneWidget,
        reason: 'C-05c 위반: 미해제 CTA 아래 안내 문구(C-05-5)가 안 보임',
      );
      expect(
        find.widgetWithText(SajuButton, '자세히 보기'),
        findsNothing,
        reason: 'C-05c 위반: 아직 해제 안 된 topic인데 해제됨 CTA가 보임',
      );
    }, () => instantClient());
  });

  testWidgets('C-05c 해제됨: 이미 상세보기(onAccessGranted)까지 완료한 topic으로 '
      '같은 화면에 재진입하면 [자세히 보기] 버튼만 보이고, 이 버튼을 '
      '누르면 게이트 시트 없이 바로 07(StoryDetailScreen)로 전환된다 '
      '(원본 jsx unlocked 분기 재현)', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap());
      final context = tester.element(find.byType(StoryPreviewScreen));
      final provider = context.read<SajuRenewalProvider>();
      unawaited(provider.startCalculating());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      // 이 topic을 먼저 "상세까지 완료"시켜 unlocked 상태로 만든다
      // (게이트 시트를 거치지 않고 Provider API를 직접 호출 — 이미
      // 한 번 해제를 완료한 사용자가 05로 돌아온 상황을 재현).
      await provider.onAccessGranted();
      await tester.pump();
      expect(provider.status, SajuRenewalFlowStatus.storyDetail);
      expect(provider.isTopicUnlocked('MONEY_001'), isTrue);

      // 05로 다시 돌아왔다고 가정(실제로는 StoryDetailScreen에서
      // 뒤로가기) — 여기서는 동일 StoryPreviewScreen 위젯이 재빌드될
      // 때 unlocked 분기를 올바르게 타는지만 확인한다.
      await tester.pump();

      expect(
        find.widgetWithText(SajuButton, '자세히 보기'),
        findsOneWidget,
        reason: 'C-05c 위반: 이미 해제된 topic인데 해제됨 CTA(C-05-6)가 안 보임',
      );
      expect(
        find.text('자세한 이야기 열어 보기'),
        findsNothing,
        reason: 'C-05c 위반: 이미 해제된 topic인데 미해제 CTA가 그대로 남아있음',
      );
      expect(
        find.text('프리패스 · 복주머니 · 광고 중 하나로 열 수 있어요'),
        findsNothing,
        reason: 'C-05c 위반: 해제됨 상태에서도 미해제 안내 문구가 남아있음',
      );

      final cta = find.widgetWithText(SajuButton, '자세히 보기');
      await tester.tap(cta);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 350)); // 라우트 전환

      expect(
        find.byType(StoryDetailScreen),
        findsOneWidget,
        reason:
            'C-05c 위반: 해제됨 CTA 탭 후 게이트 없이 07로 '
            '직행해야 하는데 전환되지 않음',
      );
    }, () => instantClient());
  });

  testWidgets('C-05a: 주제군(scene)에 따라 SajuSceneBg가 올바른 scene으로 렌더된다', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap());
      final context = tester.element(find.byType(StoryPreviewScreen));
      unawaited(context.read<SajuRenewalProvider>().startCalculating());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      final sceneBg = tester.widget<SajuSceneBg>(find.byType(SajuSceneBg));
      expect(
        sceneBg.scene.name,
        'money',
        reason: 'C-05a 위반: topic.scene("money")과 SceneBg가 불일치',
      );
    }, () => instantClient());
  });
}
