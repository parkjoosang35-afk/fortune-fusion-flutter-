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

/// C-07a/C-07c/C-07d(docs/08_QA_체크리스트.md) 실제 동작 검증.
///
/// [C-07a] 블록 제목은 목차 칩과는 다른 완전한 문장(docs/06_카피덱.md
/// C-07-1~C-07-5)이어야 한다 — admin_web API 계약서(docs/11) 117행
/// "블록 제목은 클라이언트 고정 문구(C-07-1~5) 사용" 근거.
/// [C-07c] 시기(n=4) Fact가 없는 주제는 ④ 블록과 그 목차 칩이 사라지고
/// 번호가 01~04로 재정렬되어야 한다(docs/03 §07 275행).
/// [C-07d] 목차 칩을 탭하면 해당 블록으로 스크롤된다(docs/03 §07 275행).
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

  /// n=4(시기) 블록까지 전부 포함한 5블록 detail 응답.
  http.Response _interpretDetailFullResponse() {
    final body = {
      'success': true,
      'data': {
        'topic_id': 'MONEY_001',
        'title': '테스트 이야기 제목',
        'blocks': [
          {'n': 1, 'body': '핵심 블록 본문'},
          {
            'n': 2,
            'body': '왜 블록 본문',
            'evidence': {'type': 'elements', 'text': '근거 텍스트'},
          },
          {'n': 3, 'body': '생활 블록 본문'},
          {
            'n': 4,
            'body': '시기 블록 본문',
            'timing': {'luck_index': 2},
          },
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

  /// n=4(시기) 블록이 없는(Fact 못 찾음) 4블록 detail 응답 — C-07c용.
  http.Response _interpretDetailNoTimingResponse() {
    final body = {
      'success': true,
      'data': {
        'topic_id': 'MONEY_001',
        'title': '테스트 이야기 제목',
        'blocks': [
          {'n': 1, 'body': '핵심 블록 본문'},
          {
            'n': 2,
            'body': '왜 블록 본문',
            'evidence': {'type': 'elements', 'text': '근거 텍스트'},
          },
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

  MockClient clientWith(http.Response Function() detailResponse) {
    return MockClient((request) async {
      if (request.url.path.contains('/topics/select')) {
        return _topicsSelectResponse();
      }
      if (request.url.path.contains('/interpret')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['mode'] == 'detail') {
          return detailResponse();
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
      child: const MaterialApp(home: StoryDetailScreen()),
    );
  }

  /// StoryDetailScreen에 도달하기까지 필요한 Provider 상태(currentTopic +
  /// detailState=success)를 실제 HTTP 흐름(startCalculating →
  /// onAccessGranted)으로 만든다.
  Future<void> pumpToDetail(
    WidgetTester tester,
    http.Response Function() detailResponse,
  ) async {
    await tester.pumpWidget(wrap());
    final context = tester.element(find.byType(StoryDetailScreen));
    final provider = context.read<SajuRenewalProvider>();
    unawaited(provider.startCalculating());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    await provider.onAccessGranted();
    await tester.pump();
    await tester.pump();
  }

  testWidgets('C-07a: 블록 제목은 목차 칩(단어)과 다른 완전한 문장(C-07-1~5)으로 '
      '표시되고, 목차 칩은 단어만 표시된다', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await http.runWithClient(() async {
      await pumpToDetail(tester, _interpretDetailFullResponse);

      // 블록 제목(완전한 문장) — C-07-1~5.
      expect(
        find.text('당신의 사주에서 보이는 핵심'),
        findsOneWidget,
        reason: 'C-07a 위반: 블록01 제목이 카피덱 완전한 문장(C-07-1)이 아님',
      );
      expect(
        find.text('왜 이런 특징이 나타나는가'),
        findsOneWidget,
        reason: 'C-07a 위반: 블록02 제목이 카피덱 완전한 문장(C-07-2)이 아님',
      );
      expect(
        find.text('실제 생활에서는'),
        findsOneWidget,
        reason: 'C-07a 위반: 블록03 제목이 카피덱 완전한 문장(C-07-3)이 아님',
      );
      expect(
        find.text('어느 시기에 강한가'),
        findsOneWidget,
        reason: 'C-07a 위반: 블록04 제목이 카피덱 완전한 문장(C-07-4)이 아님',
      );
      expect(
        find.text('당신에게 중요한 포인트'),
        findsOneWidget,
        reason: 'C-07a 위반: 블록05 제목이 카피덱 완전한 문장(C-07-5)이 아님',
      );

      // 목차 칩(단어 라벨 + 번호) — C-07-5a. 블록 제목과는 별개 위젯.
      expect(
        find.text('01 핵심'),
        findsOneWidget,
        reason: 'C-07a 위반: 목차 칩이 단어 라벨(C-07-5a)로 안 보임',
      );
      expect(
        find.text('02 왜'),
        findsOneWidget,
        reason: 'C-07a 위반: 목차 칩이 단어 라벨(C-07-5a)로 안 보임',
      );
      expect(
        find.text('04 시기'),
        findsOneWidget,
        reason: 'C-07a 위반: 목차 칩이 단어 라벨(C-07-5a)로 안 보임',
      );

      // "핵심" 단어 단독 텍스트(목차 칩에만)는 블록 제목과 달라야
      // 하므로, 완전한 문장과 똑같은 텍스트 위젯이 중복되지 않는다.
      expect(find.text('핵심'), findsNothing);
    }, () => clientWith(_interpretDetailFullResponse));
  });

  testWidgets('C-07c: 시기(n=4) Fact가 없으면 ④ 블록과 목차 칩이 사라지고 '
      '남은 4개 블록이 01~04로 재번호된다', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await http.runWithClient(() async {
      await pumpToDetail(tester, _interpretDetailNoTimingResponse);

      // 시기 블록(n=4) 제목 자체가 통째로 없어야 한다.
      expect(
        find.text('어느 시기에 강한가'),
        findsNothing,
        reason: 'C-07c 위반: 시기 Fact가 없는데 시기 블록이 남아있음',
      );
      // 남은 블록: 01 핵심, 02 왜, 03 생활, 04 포인트(재번호 — 시기
      // 생략 후 포인트가 05가 아니라 04로 당겨짐).
      expect(find.text('01 핵심'), findsOneWidget);
      expect(find.text('02 왜'), findsOneWidget);
      expect(find.text('03 생활'), findsOneWidget);
      expect(
        find.text('04 포인트'),
        findsOneWidget,
        reason: 'C-07c 위반: 시기 블록 생략 후 포인트 칩이 04로 재번호되지 않음',
      );
      expect(find.text('05 포인트'), findsNothing);
    }, () => clientWith(_interpretDetailNoTimingResponse));
  });

  testWidgets('C-07d: 목차 칩을 탭하면 해당 블록으로 스크롤된다', (tester) async {
    // [의도적으로 작은 뷰포트] 스크롤이 실제로 필요한 상황을 만들어야
    // "탭 → 스크롤" 효과를 검증할 수 있다 — 800x900이면 마지막
    // 블록(05 포인트)이 초기 화면 밖에 있다.
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await http.runWithClient(() async {
      await pumpToDetail(tester, _interpretDetailFullResponse);

      // SingleChildScrollView는 자식 전체를 한 번에 빌드하므로
      // find.text만으로는 "화면 밖"인지 알 수 없다 — 실제 스크롤
      // 오프셋(pixels)이 탭 이후 움직였는지로 "스크롤 발생"을
      // 검증한다.
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final before = scrollable.position.pixels;

      // "05 포인트" 목차 칩을 탭한다.
      final chip = find.text('05 포인트');
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      // [주의] 이 화면은 SajuSceneBg 등 반복 애니메이션을 포함하므로
      // pumpAndSettle()은 타임아웃된다 — Scrollable.ensureVisible의
      // 400ms 스크롤 애니메이션이 끝날 만큼만 명시적으로 pump한다
      // (story_preview_screen_c05_test.dart와 동일한 패턴).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      final after = scrollable.position.pixels;
      expect(
        after,
        greaterThan(before),
        reason:
            'C-07d 위반: 목차 칩 탭 후 해당 블록으로 스크롤되지 않음'
            '(before=$before, after=$after)',
      );
      expect(
        find.text('당신에게 중요한 포인트'),
        findsOneWidget,
        reason: 'C-07d 위반: 스크롤 후에도 해당 블록 제목이 트리에서 사라짐',
      );
    }, () => clientWith(_interpretDetailFullResponse));
  });
}
