// [정통사주 69종 결과 화면 리뉴얼 — 6차 지시서 · 전체 카테고리 크래시 없음
// 스모크 테스트]
//
// [배경] jeontong_eighty_result_dawn_integration_test.dart는 A01/G01 2종만
// 실제 화면 진입점을 통해 검증했다. 이 파일은 [JeontongEightyMatrix.all]
// 69종 전부를 실제 프로필로 진입시켜, 각 카테고리에서
// [JeontongV3ReportView]가 실제로 뜨는지(=legacy로 조용히 폴백하지
// 않았는지) 직접 확인한다. 섹션 텍스트 상세 검증은 이미
// jeontong_eighty_result_dawn_integration_test.dart가 담당하므로, 여기서는
// "크래시 없음 + v3 경로 활성화" 2가지만 넓게 확인한다.
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
import 'package:flutter_app/features/home/presentation/jeontong_design/jeontong_v3_report_view.dart';
import 'package:flutter_app/features/home/presentation/jeontong_eighty_result_screen.dart';

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
        await tester.pumpWidget(
          MaterialApp(
            home: JeontongEightyResultScreen(
              categoryId: entry.id,
              testV3ApiClient: _mockV3Client(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(JeontongV3ReportView),
          findsOneWidget,
          reason:
              '${entry.id}에서 JeontongV3ReportView가 렌더링되지 않음 — '
              'legacy로 조용히 폴백했을 가능성.',
        );
      },
    );
  }
}
