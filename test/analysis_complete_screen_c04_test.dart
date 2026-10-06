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
import 'package:flutter_app/features/saju_renewal/screens/analysis_complete_screen.dart';
import 'package:flutter_app/features/saju_renewal/screens/story_preview_screen.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';
import 'package:flutter_app/features/saju_renewal/widgets/saju_base_widgets.dart';

/// C-04a(docs/08_QA_체크리스트.md): "카드에 제목이 없다."
/// C-04b(docs/08_QA_체크리스트.md): "봉인 해제 600ms(밀봉선 분리, 인장
/// 소멸, 빛) 후 05."
///
/// [방법] 화면④(AnalysisCompleteScreen)를 직접 pumpWidget하고, 실제
/// `topics/select` MockClient 응답으로 Provider가 `currentTopic`을
/// 채운 상태에서(테스트 응답의 topic.title = "테스트 이야기 제목") 이
/// 문자열이 화면④ 위젯 트리 어디에도 노출되지 않는지(C-04a) 확인한다.
/// 이어서 CTA를 탭한 뒤 650ms가 지나야 비로소 StoryPreviewScreen(05)로
/// 전환되는지(C-04b, 원본 jsx `setTimeout(() => go('05'), 650)`과
/// docs/03 "CTA 탭 → ... → 650ms 시점 05로 전환" 대응) 실측한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const topicTitle = '테스트 이야기 제목';

  http.Response _topicsSelectResponse() {
    final body = {
      'success': true,
      'data': {
        'first_topic': {
          'topic_id': 'MONEY_001',
          'scene': 'money',
          'title': topicTitle,
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
        'title': topicTitle,
        'summary': '테스트 요약 내용입니다.',
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
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthRepository())),
        ChangeNotifierProvider(
          create: (_) => SajuRenewalProvider(SajuRenewalApi()),
        ),
      ],
      child: const MaterialApp(home: AnalysisCompleteScreen()),
    );
  }

  testWidgets('C-04a: topics/select 응답의 topic.title이 화면④ 어디에도 '
      '문자열로 노출되지 않는다(봉인 카드에 제목 없음)', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap());

      final context = tester.element(find.byType(AnalysisCompleteScreen));
      unawaited(context.read<SajuRenewalProvider>().startCalculating());
      await tester.pump(const Duration(milliseconds: 50));

      final provider = context.read<SajuRenewalProvider>();
      expect(
        provider.currentTopic?.title,
        topicTitle,
        reason:
            'Provider가 topic.title을 실제로 들고 있어야 (= 테스트가 '
            '유효함을 보장) 이후 "화면에 노출 안 됨" 검증이 의미가 있음',
      );
      await tester.pump();

      // C-04a 핵심 검증: topic.title 문자열이 화면 어디에도 Text로
      // 렌더링되지 않아야 한다(= "카드에 제목이 없다").
      expect(
        find.text(topicTitle),
        findsNothing,
        reason:
            'C-04a 위반: topic.title("$topicTitle")이 화면④에 '
            '그대로 노출됨 — 디자인 핸드오프 원안은 제목을 05에서만 보여줌',
      );

      // CTA는 여전히 "이야기 열어 보기"(topic title이 아님)여야 한다.
      expect(find.text('이야기 열어 보기'), findsOneWidget);
    }, () => instantClient());
  });

  testWidgets('C-04b: CTA 탭 직후에는 아직 05(StoryPreviewScreen)로 전환되지 '
      '않고, 650ms 경과 후에야 전환된다(봉인 해제 600ms 애니메이션 + '
      '원본 jsx setTimeout(650) 재현)', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap());
      final context = tester.element(find.byType(AnalysisCompleteScreen));
      unawaited(context.read<SajuRenewalProvider>().startCalculating());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      final ctaFinder = find.widgetWithText(SajuButton, '이야기 열어 보기');
      expect(ctaFinder, findsOneWidget);

      await tester.tap(ctaFinder);
      await tester.pump();

      // CTA 탭 직후(600ms 미만)에는 아직 화면④에 머물러 있어야 한다
      // (봉인 해제 애니메이션이 진행 중 — 전환 전).
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byType(AnalysisCompleteScreen),
        findsOneWidget,
        reason:
            'C-04b 위반 가능성: CTA 탭 후 300ms 만에 이미 05로 '
            '전환됨(최소 600ms 봉인 해제 애니메이션 보장 안 됨)',
      );
      expect(find.byType(StoryPreviewScreen), findsNothing);

      // 650ms 시점(원본 jsx setTimeout(650))을 넘기면 05로 전환되어야 함.
      await tester.pump(const Duration(milliseconds: 400));
      // 라우트 전환 애니메이션(300ms)까지 추가로 흘려보낸다.
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.byType(StoryPreviewScreen),
        findsOneWidget,
        reason:
            'C-04b 위반: CTA 탭 후 650ms(+전환 300ms)가 지났는데도 '
            '05(StoryPreviewScreen)로 전환되지 않음',
      );
    }, () => instantClient());
  });

  testWidgets('C-04b 보조: CTA를 여러 번 연속 탭해도 1회만 전환된다(중복클릭 방어)', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap());
      final context = tester.element(find.byType(AnalysisCompleteScreen));
      unawaited(context.read<SajuRenewalProvider>().startCalculating());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      final ctaFinder = find.widgetWithText(SajuButton, '이야기 열어 보기');
      await tester.tap(ctaFinder);
      await tester.pump(const Duration(milliseconds: 50));
      // 두 번째 탭 시점엔 이미 CTA가 비활성화(onTap: null)되어 있어야
      // 하므로, 탭이 실제로 아무 효과가 없어야 한다(예외 없이 통과).
      await tester.tap(ctaFinder, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump(const Duration(milliseconds: 350)); // 라우트 전환(300ms)

      expect(find.byType(StoryPreviewScreen), findsOneWidget);
    }, () => instantClient());
  });
}
