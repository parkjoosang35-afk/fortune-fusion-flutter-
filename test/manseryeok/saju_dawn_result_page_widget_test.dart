// [정통사주 결과 화면 개편 - Dawn Paper] SajuDawnResultPage 렌더링 검증.
//
// [목적] 壹~柒 7개 섹션 위젯 전체가 실계산 데이터(buildSajuDawnResultData
// FromDeepReport로 조립한 SajuResultData)를 받아 예외 없이 렌더링되는지
// 확인한다. 애니메이션/VisibilityDetector가 실제 뷰포트에서 트리거되는지
// 까지는 검증하지 않고(테스트 환경 제약), "빌드 트리에 크래시 없이
// 올라가는가"만 스모크 테스트로 확인한다.
import 'package:flutter/material.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/life_overall_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/generators/life_overall_narrative_generator.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import 'package:flutter_app/features/home/domain/saju_fortune_rules.dart';
import 'package:flutter_app/features/home/domain/saju_interpreter.dart';
import 'package:flutter_app/features/home/presentation/jeontong_design/jeontong_deep_report_card.dart'
    show JeontongDeepReportData, buildDeclarativeVerdict;
import 'package:flutter_app/features/home/presentation/jeontong_design/saju_result_redesign/saju_dawn_data_builder.dart';
import 'package:flutter_app/features/home/presentation/jeontong_design/saju_result_redesign/saju_dawn_result_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

final _kFixedDate = DateTime.utc(2026, 8, 13);
final _birthUtc = DateTime.utc(1990, 6, 15, 3, 0, 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await SajuRules.preload();
    await SajuFortuneRules.preload();
    // VisibilityDetector는 기본 500ms 주기 타이머로 가시성 갱신을
    // 스케줄한다 — 테스트 pump 직후 위젯 트리가 해제되면 pending
    // 타이머로 인해 실패하므로, 테스트 환경에서는 즉시 갱신하도록 0으로
    // 낮춘다(공식 패키지가 테스트용으로 제공하는 옵션).
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('SajuDawnResultPage — 실계산 데이터로 예외 없이 렌더링된다', (tester) async {
    final kst = _birthUtc.add(const Duration(hours: 9));
    final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst,
      gender: 'female',
      isLunar: false,
      referenceDate: _kFixedDate,
    );

    final analysis = const LifeOverallAnalyzer().analyze(
      built.profile,
      referenceDate: _kFixedDate,
    );
    final narrative = const LifeOverallNarrativeGenerator().generate(
      built.profile,
      analysis,
    );
    final verdict = buildDeclarativeVerdict(
      categoryLabel: '전체적인 삶',
      hasRisk: false,
      reasonSentence: analysis.lifeTheme,
    );
    final deepData = JeontongDeepReportData(
      oneLineSummary: verdict.summary,
      isFortunate: verdict.isFortunate,
      personalitySentences: [
        analysis.coreNatureDescription,
        ...narrative.characteristics,
      ],
      strengths: analysis.strengths,
      cautions: analysis.weaknesses,
      generalGuidance: narrative.practicalGuidance ?? const [],
      finalSummary: narrative.finalSummary,
    );

    final entryA01 = JeontongEightyMatrix.byId('A01')!;
    final data = buildSajuDawnResultDataFromDeepReport(
      entry: entryA01,
      profile: built.profile,
      saju: built.saju,
      fortuneRules: SajuFortuneRules.cachedOrNull,
      content: deepData,
      referenceDate: _kFixedDate,
      userRefId: '#409670384',
    );

    // ListView는 뷰포트 밖 항목을 지연 빌드하므로, 스크롤 가능한 큰
    // 화면 크기를 줘서 사실상 모든 섹션이 최초 빌드에서 올라오도록 한다
    // (7개 섹션 + 히어로 + 풋터 — 대략 3000px 정도면 전부 포함).
    tester.view.physicalSize = const Size(420, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SajuDawnResultPage(
          data: data,
          strengthLabel: '신강(身强)',
          typeLabel: '조력형 助力型',
          bookmarkButton: const Icon(
            Icons.bookmark_border,
            key: ValueKey('jeontong_bookmark_toggle_test'),
          ),
        ),
      ),
    );
    // BrushInHanja/OhaengBar/StaggeredCellReveal 등은 Future.delayed로
    // 애니메이션을 지연 시작한다 — pumpAndSettle로 모든 타이머가 해소될
    // 때까지 기다려야 "Timer still pending" 어서션을 피할 수 있다.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // 크래시 없이 최소 한 번의 빌드가 완료되었는지 확인.
    expect(find.byType(SajuDawnResultPage), findsOneWidget);
    // Hero 타이틀이 실제 카테고리 제목으로 렌더링되었는지 확인.
    expect(find.text(entryA01.title), findsWidgets);
    // 壹~柒 섹션 라벨이 모두 그려졌는지 확인(스크롤 가능한 큰 뷰포트로
    // ListView가 모든 섹션을 지연 없이 빌드하도록 했다).
    for (final label in ['壹 · ONE', '貳 · TWO', '參 · THREE', '肆 · FOUR', '伍 · FIVE', '陸 · SIX', '柒 · SEVEN']) {
      expect(find.text(label), findsOneWidget, reason: '섹션 라벨 "$label"이 렌더링되지 않음');
    }
  });
}
