// [정통사주 69종 결과 화면 리뉴얼 — 6차 지시서 · 전체 카테고리 크래시 없음
// 스모크 테스트]
//
// [배경] jeontong_eighty_result_dawn_integration_test.dart는 A01/G01 2종만
// 실제 화면 진입점을 통해 검증했다. 이 파일은 [JeontongEightyMatrix.all]
// 69종 전부를 실제 프로필로 진입시켜, 각 카테고리에서 예외 없이 렌더링되는지
// 직접 확인한다. 섹션 텍스트 상세 검증은 이미
// jeontong_eighty_result_dawn_integration_test.dart가 담당하므로, 여기서는
// "크래시 없음 + v3 경로 활성화" 2가지만 넓게 확인한다.
//
// [정통사주 로딩 개선 — Dawn Paper를 스켈레톤 호스트로 전환] 이전에는
// `showDawnPaper = reportState.isSuccess` 게이트로 report가 성공한
// 뒤에야 [JeontongV3ReportView]가 [SajuDawnResultPage]로 바뀌었으나, 이제
// 프로필이 있으면 report 상태와 무관하게 항상 [SajuDawnResultPage]가
// 렌더링된다(§ jeontong_eighty_result_screen.dart `_ResultBody.build()`).
// 이 테스트도 그 새 계약(항상 SajuDawnResultPage, legacy
// JeontongV3ReportView는 예외적 폴백 전용)에 맞춰 갱신한다.
//
// [로컬 계산 완전 대체 — 6차 지시서 "진행"] 실제 네트워크 호출 없이
// `JeontongEightyResultScreen.testV3ApiClient`로 MockClient를 주입해
// `/saju/v3/report`·`/saju/v3/interpret` 서버 응답을 시뮬레이션한다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/home/data/jeontong_history_store.dart';
import 'package:flutter_app/features/home/data/jeontong_profile_store.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';
import 'package:flutter_app/features/home/domain/jeontong_input.dart';
import 'package:flutter_app/features/home/domain/jeontong_report_cache.dart';
import 'package:flutter_app/features/home/presentation/jeontong_design/saju_result_redesign/saju_dawn_result_page.dart';
import 'package:flutter_app/features/home/presentation/jeontong_eighty_result_screen.dart';
import 'package:visibility_detector/visibility_detector.dart';

Map<String, dynamic> _mockReportJson() {
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
            'paras': ['PART${i + 1} 본문'],
            'evidence': <String>[],
          },
      ],
      'summary': '요약',
      'evidence_used': <String>[],
    },
    'input_flags': <String>[],
  };
}

Map<String, dynamic> _mockInterpretJson({required String categoryCode}) {
  return {
    'source': 'rule_fallback',
    'headline': '$categoryCode headline',
    'sections': [
      {
        'key': 's1',
        'title': '$categoryCode 섹션',
        'body': ['$categoryCode 본문'],
      },
    ],
    'actions': ['$categoryCode 행동'],
    'closing': '$categoryCode 마무리',
    'evidence_used': <String>[],
  };
}

Map<String, dynamic> _mockNarrativeJson({required String categoryCode}) {
  return {
    'source': 'rule_fallback',
    'category_code': categoryCode,
    'category_name': categoryCode,
    'text': '$categoryCode 에 대한 이야기형 해설 본문',
    'evidence_used': <String>[],
    'qa_passed': true,
  };
}

http.Client _mockV3Client() {
  return MockClient((request) async {
    final path = request.url.path;
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (path == '/saju/v3/report') {
      return http.Response(
        jsonEncode(_mockReportJson()),
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
    // [애니메이션 타이머 잔존 방지 — jeontong_eighty_result_dawn_integration_test.dart와
    // 동일한 이유] VisibilityDetector는 기본 500ms 주기 타이머로 가시성 갱신을
    // 스케줄한다 — 테스트 pump 직후 위젯 트리가 해제되면 pending 타이머로 인해
    // 실패하므로, 테스트 환경에서는 즉시 갱신하도록 0으로 낮춘다.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  setUp(() {
    jeontongReportCache.clear();
    JeontongHistoryStore.instance.clearForTest();
    jeontongProfileStore.clearForTest();
    SharedPreferences.setMockInitialValues({});
  });

  final entries = JeontongEightyMatrix.all;

  test('전제 조건: JeontongEightyMatrix.all이 비어 있지 않다(69종 기대)', () {
    expect(entries.length, greaterThan(0));
  });

  for (final entry in entries) {
    testWidgets(
      '[v3 전체 카테고리 스모크] ${entry.id}(${entry.title}) — 프로필이 있으면 JeontongV3ReportView가 예외 없이 렌더링된다',
      (tester) async {
        await jeontongProfileStore.save(
          '1',
          JeontongInput(
            birthDateTimeLocal: DateTime(1990, 6, 15, 12, 0),
            gender: 'M',
            isLunar: false,
          ),
        );
        // [지연 빌드 방지] ListView/CustomScrollView가 뷰포트 밖 항목을
        // 지연 빌드하므로, 충분히 큰 뷰포트를 준다(기존
        // saju_dawn_result_page_widget_test.dart와 동일한 이유/패턴).
        tester.view.physicalSize = const Size(420, 6000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: JeontongEightyResultScreen(
              categoryId: entry.id,
              testV3ApiClient: _mockV3Client(),
            ),
          ),
        );
        // [애니메이션 타이머 잔존 방지] BrushInHanja/OhaengBar/
        // StaggeredCellReveal은 Future.delayed로 애니메이션을 지연 시작하므로
        // (기존 saju_dawn_result_page_widget_test.dart와 동일한 이유),
        // pumpAndSettle에 시간 예산을 줘야 "Timer still pending"을 피한다.
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        expect(
          find.byType(SajuDawnResultPage),
          findsOneWidget,
          reason:
              '${entry.id}에서 SajuDawnResultPage가 렌더링되지 않음 — '
              'legacy로 조용히 폴백했을 가능성.',
        );
      },
    );
  }
}
