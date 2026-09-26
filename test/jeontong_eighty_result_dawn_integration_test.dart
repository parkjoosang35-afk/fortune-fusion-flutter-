// [정통사주 69종 결과 화면 리뉴얼 — 6차 지시서] JeontongEightyResultScreen
// 실제 진입점을 통해, 프로필이 있을 때 새 [JeontongV3ReportView](실제
// saju_v3 백엔드 /saju/v3/report 9 PART + /saju/v3/interpret 카테고리 심층)
// 경로가 실제로 활성화되고 예외 없이 렌더링되는지 검증한다.
//
// [배경] 기존 jeontong_eighty_result_bookmark_toggle_test.dart /
// jeontong_eighty_result_frame_bench_test.dart는 둘 다
// `SharedPreferences.setMockInitialValues({})`로 "저장된 프로필 없음"
// 상태만 검증해, `_ResultBody.build()`의 `if (hasProfile) { ... }` v3
// 라우팅 분기를 전혀 통과하지 않는다. 이 파일이 그 커버리지 공백을
// 메운다 — `jeontongProfileStore.save()`로 실제 프로필을 채운 뒤 진입해,
// legacy `Column` 레이아웃이 아니라 [JeontongV3ReportView]가 렌더링되는지
// 직접 확인한다.
//
// [로컬 계산 완전 대체 — 6차 지시서 "진행"] 이전 버전은 프로필이 있으면
// 100% 로컬 계산(PHASE1~4 + Dawn Paper)으로 그렸으나, 이제는
// `/saju/v3/report`·`/saju/v3/interpret` 서버 응답을 그대로 반영한다.
// 실제 네트워크 호출 없이 `JeontongEightyResultScreen.testV3ApiClient`로
// `package:http/testing.dart`의 [MockClient]를 주입해 서버 응답을
// 시뮬레이션한다 — 계산 로직을 새로 만들지 않고 이미 검증된
// [SajuV3Api]/[SajuReportResult]/[InterpretationResult] 파싱 경로만
// 그대로 태운다.
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
import 'package:flutter_app/features/home/presentation/jeontong_eighty_result_screen.dart';

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
    return http.Response('not found', 404);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets(
    'A01(9 PART에 대응하는 카테고리) — 프로필이 있으면 JeontongV3ReportView로 렌더링',
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

      // [지연 빌드 방지] ListView가 뷰포트 밖 항목을 지연 빌드하므로, 9
      // PART + 심층 분석 카드가 전부 트리에 올라오도록 충분히 큰
      // 뷰포트를 준다(기존 saju_dawn_result_page_widget_test.dart와 동일한
      // 이유/패턴).
      tester.view.physicalSize = const Size(420, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        harness(categoryId: 'A01', client: _mockV3Client()),
      );
      await tester.pumpAndSettle();

      // legacy 레이아웃이 아니라 새 v3 리포트 화면이 렌더링됐는지 확인.
      expect(find.byType(JeontongV3ReportView), findsOneWidget);
      // 즐겨찾기 계약(ValueKey) 유지 확인 — 새 경로에서도 동일 키를 씀.
      expect(
        find.byKey(const ValueKey('jeontong_bookmark_toggle')),
        findsOneWidget,
      );
      // [2026-11 "주제에 맞는것만" 재수정] A01(평생 총운)은 PART9(종합
      // 분석)에 대응하므로, 그 카드 하나만 그려지고 나머지 8개(PART1~8,
      // "한눈에 보는 나" 등 무관한 축)는 화면에 전혀 노출되지 않아야 한다.
      expect(find.textContaining('홍길동의 사주 종합 분석'), findsOneWidget);
      expect(find.textContaining('홍길동의 사주, 한눈에 보기'), findsNothing);
      expect(find.textContaining('홍길동의 타고난 성향'), findsNothing);
      // PART9 카드 안에 카테고리 심층 해석(interpret 결과)이 자연스럽게
      // 엮여 있어야 한다.
      expect(find.textContaining('A01 핵심 상세 분석 headline'), findsOneWidget);
      // summary("~을 위한 한마디")도 9개 PART를 아우르는 무관한 요약이라
      // 더 이상 노출하지 않는다.
      expect(find.textContaining('을 위한 한마디'), findsNothing);
    },
  );

  testWidgets(
    'G01(9 PART 어디에도 대응하지 않는 카테고리) — 별도 심층 분석 블록(옵션 B)이 추가로 렌더링',
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
      await tester.pumpAndSettle();

      expect(find.byType(JeontongV3ReportView), findsOneWidget);
      expect(
        find.byKey(const ValueKey('jeontong_bookmark_toggle')),
        findsOneWidget,
      );
      // 이름이 없으면 "회원님"으로 대체된다.
      expect(find.textContaining('회원님이 선택한 주제'), findsOneWidget);
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
