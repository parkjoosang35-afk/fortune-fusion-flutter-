// [정통사주 69종 결과 화면 리뉴얼 — 6차 지시서] JeontongEightyResultScreen
// 실제 진입점을 통해, 프로필이 있을 때 새 [SajuDawnResultPage](실제
// saju_v3 백엔드 /saju/v3/report 9 PART + /saju/v3/interpret + /saju/v3/narrative
// 적용 개선 결과화면) 경로가 실제로 활성화되고 예외 없이 렌더링되는지 검증한다.
//
// [배경] 기존 jeontong_eighty_result_bookmark_toggle_test.dart /
// jeontong_eighty_result_frame_bench_test.dart는 둘 다
// `SharedPreferences.setMockInitialValues({})`로 "저장된 프로필 없음"
// 상태만 검증해, `_ResultBody.build()`의 `if (hasProfile) { ... }` v3
// 라우팅 분기를 전혀 통과하지 않는다. 이 파일이 그 커버리지 공백을
// 메운다 — `jeontongProfileStore.save()`로 실제 프로필을 채운 뒤 진입해,
// legacy `Column` 레이아웃이 아니라 [SajuDawnResultPage]가 렌더링되는지
// 직접 확인한다.
//
// [정통사주 로딩 개선 — Dawn Paper를 스켈레톤 호스트로 전환] 이전에는
// `showDawnPaper = reportState.isSuccess` 게이트로 report가 성공해야
// [JeontongV3ReportView]에서 [SajuDawnResultPage]로 화면이 통째로 바뀌었다.
// 이제는 프로필이 있으면 report/interpret/narrative 상태와 무관하게
// 항상 [SajuDawnResultPage]가 즉시 렌더링되고(지역 계산 섹션은 0ms),
// 오직 사주풀이·실전조언 섹션만 응답 도달에 따라 점진적으로 채워진다.
//
// [로컬 계산 완전 대체 — 6차 지시서 "진행"] 이전 버전은 프로필이 있으면
// 100% 로컬 계산(PHASE1~4 + Dawn Paper)으로 그렸으나, 이제는
// `/saju/v3/report`·`/saju/v3/interpret`·`/saju/v3/narrative` 서버 응답을
// 그대로 반영한다. 실제 네트워크 호출 없이
// `JeontongEightyResultScreen.testV3ApiClient`로
// `package:http/testing.dart`의 [MockClient]를 주입해 서버 응답을
// 시뮬레이션한다 — 계산 로직을 새로 만들지 않고 이미 검증된
// [SajuV3Api]/[SajuReportResult]/[InterpretationResult]/[NarrativeResult]
// 파싱 경로만 그대로 태운다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/home/data/jeontong_history_store.dart';
import 'package:flutter_app/features/home/data/jeontong_profile_store.dart';
import 'package:flutter_app/features/home/domain/jeontong_input.dart';
import 'package:flutter_app/features/home/domain/jeontong_report_cache.dart';
import 'package:flutter_app/features/home/presentation/jeontong_design/jeontong_v3_report_view.dart';
import 'package:flutter_app/features/home/presentation/jeontong_design/saju_result_redesign/saju_dawn_result_page.dart';
import 'package:flutter_app/features/home/presentation/jeontong_eighty_result_screen.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// [/saju/v3/report] 9 PART 고정 스켈레톤 목(mock) 응답 — 실제 서버
/// `_fallback_report()` 구조(9개 PART 제목)를 그대로 흉내낸다. 카테고리별로
/// `focusPartTitleSuffix`를 넣어 "같은 9 PART라도 카테고리마다 강조/본문이
/// 달라진다"는 사용자 요구사항을 목 데이터로도 검증할 수 있게 한다.
Map<String, dynamic> _mockReportJson({required String focusHint}) {
  const titles = [
    '한눈에 보는 나',
    '타고난 성향',
    '숨겨진 성향',
    '재능·직업',
    '재물운',
    '연애·배우자·인간관계',
    '인생 흐름',
    '현재 운',
    '종합 분석',
  ];
  return {
    'source': 'rule_fallback',
    'report': {
      'parts': [
        for (var i = 0; i < titles.length; i++)
          {
            'no': i + 1,
            'title': titles[i],
            'paras': ['PART${i + 1} 본문 — $focusHint 관련 계산값 문단'],
            'evidence': <String>[],
          },
      ],
      'summary': '$focusHint 에 대한 한마디 요약',
      'evidence_used': <String>[],
    },
    'input_flags': <String>[],
  };
}

/// [/saju/v3/interpret] 선택 카테고리 심층 해석 목 응답.
Map<String, dynamic> _mockInterpretJson({required String categoryCode}) {
  return {
    'source': 'rule_fallback',
    'headline': '$categoryCode 핵심 상세 분석 headline',
    'sections': [
      {
        'key': 's1',
        'title': '$categoryCode 섹션',
        'body': ['$categoryCode 본문 줄'],
      },
    ],
    'actions': ['$categoryCode 참고 행동 1'],
    'closing': '$categoryCode 마무리 문장',
    'evidence_used': <String>[],
  };
}

/// [/saju/v3/narrative] 이야기형 줄글 해석 목 응답 — 一(총평) 챕터가
/// 최우선으로 쓰는 소스([buildSajuDawnResultDataFromV3Report] 주석 참고).
Map<String, dynamic> _mockNarrativeJson({required String categoryCode}) {
  return {
    'source': 'rule_fallback',
    'category_code': categoryCode,
    'category_name': categoryCode,
    'text': '$categoryCode 에 대한 이야기형 해석 본문 줄',
    'evidence_used': <String>[],
    'qa_passed': true,
  };
}

http.Client _mockV3Client() {
  return MockClient((request) async {
    final path = request.url.path;
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (path == '/saju/v3/report') {
      final question = (body['question'] ?? '').toString();
      return http.Response(
        jsonEncode(_mockReportJson(focusHint: question)),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path == '/saju/v3/interpret') {
      final categoryCode = (body['category_code'] ?? '').toString();
      return http.Response(
        jsonEncode(_mockInterpretJson(categoryCode: categoryCode)),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path == '/saju/v3/narrative') {
      final categoryCode = (body['category_code'] ?? '').toString();
      return http.Response(
        jsonEncode(_mockNarrativeJson(categoryCode: categoryCode)),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('not found', 404);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // [애니벌이션 타이럐 잔쌍 방지 — 기존
    // saju_dawn_result_page_widget_test.dart와 동일한 이유] VisibilityDetector는
    // 기본 500ms 주기 타이럐로 가시성 갱신을 스케줄한다 — 테스트 pump 직후
    // 위젯 트리가 해제되면 pending 타이럐로 인해 실패하밀로, 테스트
    // 환경에서는 즉시 갱신하도망 0으로 닮충다.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  setUp(() {
    jeontongReportCache.clear();
    JeontongHistoryStore.instance.clearForTest();
    jeontongProfileStore.clearForTest();
    SharedPreferences.setMockInitialValues({});
  });

  Widget harness({required String categoryId, http.Client? client}) {
    return MaterialApp(
      home: JeontongEightyResultScreen(
        categoryId: categoryId,
        testV3ApiClient: client,
      ),
    );
  }

  // [드롭캡 대응 헬퍼] 一/四 챕터의 첫 문단은 SajuDawnStoryChapters가
  // 첫 글자를 분리해 별도 드롭캡 위젯으로 렌더링하므로(§
  // saju_dawn_story_chapters.dart _StoryParagraphText), 전체 문자열이
  // 하나의 Text/RichText에 있지 않다. RichText.text.toPlainText()로 모은
  // 뒤 포함 여부를 검사한다(기존 find.textContaining이 드롭캡 문단에는
  // 맞지 않아 신규로 추가).
  Matcher findsRichTextContaining(String needle) {
    return predicate<Iterable<Element>>((elements) {
      for (final element in elements) {
        final widget = element.widget;
        if (widget is RichText && widget.text.toPlainText().contains(needle)) {
          return true;
        }
      }
      return false;
    }, 'contains RichText with text "$needle"');
  }

  testWidgets(
    'A01(9 PART에 대응하는 카테고리) — 프로필이 있으면 SajuDawnResultPage로 렌더링(스켈레톤 호스트 전환 후)',
    (tester) async {
      await jeontongProfileStore.save(
        '1',
        JeontongInput(
          birthDateTimeLocal: DateTime(1990, 6, 15, 12, 0),
          gender: 'M',
          isLunar: false,
          name: '홍길동',
        ),
      );

      // [지연 빌드 방지] ListView가 뷰포트 밖 항목을 지연 빌드하므로, 7개
      // 섹션이 전부 트리에 올라오도록 충분히 큰 뷰포트를 준다(기존
      // saju_dawn_result_page_widget_test.dart와 동일한 이유/패턴).
      tester.view.physicalSize = const Size(420, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        harness(categoryId: 'A01', client: _mockV3Client()),
      );
      // [애니메이션 타이머 잔존 방지] BrushInHanja/OhaengBar/
      // StaggeredCellReveal은 Future.delayed로 애니메이션을 지연 시작하므로
      // (기존 saju_dawn_result_page_widget_test.dart와 동일한 이유),
      // pumpAndSettle에 시간 예산을 줘 적용해야 "Timer still pending"을 피한다.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // [정통사주 로딩 개선] 프로필이 있으면 legacy JeontongV3ReportView가
      // 아니라 Dawn Paper(SajuDawnResultPage)가 항상 렌더링된다 —
      // report/interpret/narrative 상태와 무관하게(이 테스트에서는 3개
      // 백엔드 모두 mock으로 성공함).
      expect(find.byType(SajuDawnResultPage), findsOneWidget);
      expect(find.byType(JeontongV3ReportView), findsNothing);
      // 즐겨찾기 계약(ValueKey) 유지 확인 — 새 경로에서도 동일 키를 씀.
      expect(
        find.byKey(const ValueKey('jeontong_bookmark_toggle')),
        findsOneWidget,
      );
      // 一(총평) 최우선 소스는 narrative(이야기형 줄글)다 — mock이 성공하므로
      // 즉시 렌더링되어야 한다(스켈레톤 없음).
      expect(find.byType(RichText).evaluate(), findsRichTextContaining('01 에 대한 이야기형 해석 본문 줄'));
      // interpret().headline이 一 챕터의 제목으로 쓰인다.
      expect(find.textContaining('A01 핵심 상세 분석 headline'), findsOneWidget);
      // interpret().actions가 二(강점과 조심할점) 챕터와 伍(실전 조언)
      // 섹션에 둘 다 렌더링되므로 기대값을 findsWidgets로 늦춘다.
      expect(find.textContaining('A01 참고 행동 1'), findsWidgets);
      // interpret().closing이 四(실전 조언·맺음말) 챕터에 렌더링된다.
      expect(find.byType(RichText).evaluate(), findsRichTextContaining('01 마무리 문장'));
    },
  );

  testWidgets(
    'G01(9 PART 어디에도 대응하지 않는 카테고리) — 여전히 SajuDawnResultPage로 렌더링(대응 PART 없어도 interpret만으로 채워짐)',
    (tester) async {
      await jeontongProfileStore.save(
        '1',
        JeontongInput(
          birthDateTimeLocal: DateTime(1985, 3, 2, 8, 30),
          gender: 'F',
          isLunar: false,
        ),
      );

      tester.view.physicalSize = const Size(420, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        harness(categoryId: 'G01', client: _mockV3Client()),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.byType(SajuDawnResultPage), findsOneWidget);
      expect(find.byType(JeontongV3ReportView), findsNothing);
      expect(
        find.byKey(const ValueKey('jeontong_bookmark_toggle')),
        findsOneWidget,
      );
      expect(find.byType(RichText).evaluate(), findsRichTextContaining('01 에 대한 이야기형 해석 본문 줄'));
      expect(find.textContaining('G01 핵심 상세 분석 headline'), findsOneWidget);
    },
  );

  testWidgets(
    '프로필이 없으면(미입력) 여전히 legacy 레이아웃으로 폴백한다(회귀 없음)',
    (tester) async {
      // setUp에서 SharedPreferences를 빈 값으로 초기화 + 프로필 미저장
      // 상태이므로 hasProfile == false → v3 경로가 활성화되지 않아야 함.
      await tester.pumpWidget(harness(categoryId: 'A01'));
      await tester.pumpAndSettle();

      expect(find.byType(JeontongV3ReportView), findsNothing);
      expect(
        find.byKey(const ValueKey('jeontong_bookmark_toggle')),
        findsOneWidget,
      );
    },
  );
}
