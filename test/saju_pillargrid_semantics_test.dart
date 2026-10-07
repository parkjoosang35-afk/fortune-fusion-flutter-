import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/saju_renewal/data/saju_visual_adapter.dart';
import 'package:flutter_app/features/saju_renewal/widgets/saju_visual_widgets.dart';

/// [E-Semantics 실측] docs/08_QA_체크리스트.md "E. 모션·접근성":
/// "VoiceOver/TalkBack: 원국 셀 '태어난 해, 천간 갑, 나무' 형식 라벨".
///
/// SajuPillarGrid가 실제로 각 셀에 문장형 Semantics 라벨을 부여하는지
/// (수정 전에는 Semantics가 전혀 없었다 — 전체 saju_renewal grep으로
/// 확인된 결함) widget test로 검증한다.
void main() {
  testWidgets(
    'SajuPillarGrid 원국 셀이 "태어난 O, 천간/지지 O, 오행" 형식 Semantics 라벨을 갖는다',
    (tester) async {
      // 甲(목,양) 년주, 丙(화,양)子(수,양) 시주 조합의 pillars[4] =
      // [時, 日, 月, 年] 순서.
      final pillars = [
        const SajuVisualPillar(stemHanja: '丙', branchHanja: '子'), // 時
        const SajuVisualPillar(stemHanja: '戊', branchHanja: '午'), // 日
        const SajuVisualPillar(stemHanja: '乙', branchHanja: '卯'), // 月
        const SajuVisualPillar(stemHanja: '甲', branchHanja: '寅'), // 年
      ];

      // NOTE: testWidgets()는 기본적으로 semanticsEnabled: true 로 자체
      // SemanticsHandle을 생성한다. 여기서 추가로 tester.ensureSemantics()를
      // 호출하면 핸들이 중첩되어 addTearDown으로 dispose해도 프레임워크의
      // _endOfTestVerifications 검사 시점보다 늦어 "SemanticsHandle was
      // active at the end of the test" 오류가 발생한다 — 호출하지 않는다.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SajuPillarGrid(
              pillars: pillars,
              cell: 56,
              gap: 8,
              reveal: 8, // 전부 새겨진 상태.
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 年(연주) 천간 甲(갑, 목) — docs/01_디자인토큰.md §1-3 오행
      // 한글 라벨(나무/불/흙/쇠/물) 및 docs/08_QA_체크리스트.md 예시
      // "천간 갑, 나무"와 동일한 순우리말 표기를 사용한다.
      expect(find.bySemanticsLabel('태어난 해, 천간 갑, 나무'), findsOneWidget);
      // 年 지지 寅(인, 목).
      expect(find.bySemanticsLabel('태어난 해, 지지 인, 나무'), findsOneWidget);
      // 時(시주) 천간 丙(병, 화).
      expect(find.bySemanticsLabel('태어난 시, 천간 병, 불'), findsOneWidget);
      // 時 지지 子(자, 수).
      expect(find.bySemanticsLabel('태어난 시, 지지 자, 물'), findsOneWidget);
      // 月(월주) 천간 乙(을, 목).
      expect(find.bySemanticsLabel('태어난 달, 천간 을, 나무'), findsOneWidget);
      // 日(일주) 천간 戊(무, 토).
      expect(find.bySemanticsLabel('태어난 날, 천간 무, 흙'), findsOneWidget);
    },
  );

  testWidgets('시간 모름(時 칸이 모두 null)이면 "정보 없음" 라벨을 갖는다', (tester) async {
    final pillars = [
      null, // 時 — 시간 모름.
      const SajuVisualPillar(stemHanja: '戊', branchHanja: '午'),
      const SajuVisualPillar(stemHanja: '乙', branchHanja: '卯'),
      const SajuVisualPillar(stemHanja: '甲', branchHanja: '寅'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SajuPillarGrid(pillars: pillars, cell: 56, gap: 8, reveal: 8),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('태어난 시, 천간 정보 없음'), findsOneWidget);
    expect(find.bySemanticsLabel('태어난 시, 지지 정보 없음'), findsOneWidget);
  });

  testWidgets('아직 새겨지지 않은 칸(reveal 미달)은 "아직 비어 있음" 라벨을 갖는다', (tester) async {
    final pillars = [
      const SajuVisualPillar(stemHanja: '丙', branchHanja: '子'),
      const SajuVisualPillar(stemHanja: '戊', branchHanja: '午'),
      const SajuVisualPillar(stemHanja: '乙', branchHanja: '卯'),
      const SajuVisualPillar(stemHanja: '甲', branchHanja: '寅'),
    ];

    // reveal=0 — 아직 한 글자도 새겨지지 않음(새김 순서: 年→月→日→時).
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SajuPillarGrid(pillars: pillars, cell: 56, gap: 8, reveal: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('태어난 해, 천간 아직 비어 있음'), findsOneWidget);
  });
}
