// [정통사주 결과 화면 개편 - Dawn Paper] saju_dawn_data_builder.dart 검증.
//
// [목적] 새로 작성한 매핑 레이어(saju_dawn_data_builder.dart)가 실계산
// 파이프라인(buildProfileAndSajuResultViaPhase1to4 → SajuInterpreter/
// getLuckyItems)의 실제 출력값을 받아 [SajuResultData]를 예외 없이
// 만들어내는지, 그리고 그 안의 필드들이 "재계산이 아니라 실데이터를 그대로
// 옮긴 값"인지 확인한다. 새 명리 판단 로직 여부를 검증하는 것이 아니라
// (그건 기존 계산 계층의 책임), 매핑 자체가 정확한지만 확인한다.
import 'package:flutter_app/features/home/domain/interpretation/analyzers/life_overall_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/generators/life_overall_narrative_generator.dart';
import 'package:flutter_app/features/home/presentation/jeontong_design/jeontong_deep_report_card.dart'
    show JeontongDeepReportData, buildDeclarativeVerdict;
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import 'package:flutter_app/features/home/domain/saju_fortune_rules.dart';
import 'package:flutter_app/features/home/domain/saju_interpreter.dart';
import 'package:flutter_app/features/home/presentation/jeontong_design/saju_result_redesign/saju_dawn_data_builder.dart';
import 'package:flutter_test/flutter_test.dart';

final _kFixedDate = DateTime.utc(2026, 8, 13);
final _birthUtc = DateTime.utc(1990, 6, 15, 3, 0, 0); // KST 12:00

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await SajuRules.preload();
    await SajuFortuneRules.preload();
  });

  final entryA01 = JeontongEightyMatrix.byId('A01')!;
  final entryA02 = JeontongEightyMatrix.byId('A02')!; // fallback 경로 대표

  test('Pipeline A(JeontongDeepReportData) — SajuResultData가 예외 없이 만들어진다', () {
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
    const noRiskFixed = '특별히 두드러진 위험 신호는 확인되지 않음';
    final hasRisk = !(analysis.weaknesses.length == 1 &&
        analysis.weaknesses.first == noRiskFixed);
    final verdict = buildDeclarativeVerdict(
      categoryLabel: '전체적인 삶',
      hasRisk: hasRisk,
      reasonSentence: hasRisk
          ? analysis.weaknesses.first
          : analysis.strengths.isNotEmpty
              ? analysis.strengths.first
              : analysis.lifeTheme,
      actionSentence: narrative.practicalGuidance?.isNotEmpty == true
          ? narrative.practicalGuidance!.first
          : null,
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

    final result = buildSajuDawnResultDataFromDeepReport(
      entry: entryA01,
      profile: built.profile,
      saju: built.saju,
      fortuneRules: SajuFortuneRules.cachedOrNull,
      content: deepData,
      referenceDate: _kFixedDate,
      userRefId: '#test0001',
    );

    // [매핑 정확성] 4주 8글자는 실계산 profile과 한 글자도 다르지 않아야
    // 한다 — 단순 필드 이동이지 재계산이 아님을 검증.
    expect(result.yearPillar.stemHanja, built.profile.yearPillar.stemHanja);
    expect(result.monthPillar.stemHanja, built.profile.monthPillar.stemHanja);
    expect(result.dayPillar.stemHanja, built.profile.dayPillar.stemHanja);
    expect(result.timePillar.stemHanja, built.profile.hourPillar.stemHanja);
    expect(result.dayPillar.branchHanja, built.profile.dayPillar.branchHanja);

    // 일간 테마가 실제 일간 한자와 일치.
    expect(result.ilganTheme.hanja, built.profile.dayPillar.stemHanja);

    // 오행 카운트 합계가 실계산 fiveElements.totalCount 합계와 일치.
    final expectedTotal = built.profile.fiveElements!.totalCount.values
        .fold<int>(0, (a, b) => a + b);
    final actualTotal =
        result.ohaengCounts.values.fold<int>(0, (a, b) => a + b);
    expect(actualTotal, expectedTotal);

    // 4개 챕터가 모두 채워짐 + 챕터3(대운흐름)만 includeTimeline=true.
    expect(result.chapters.length, 4);
    expect(result.chapters[2].includeTimeline, isTrue);
    expect(result.chapters[0].includeTimeline, isFalse);

    // 대운 타임라인 — 실계산 daewoon 존재 시 비어있지 않다(최대 4개로 제한).
    expect(result.daeunTimeline, isNotEmpty);
    expect(result.daeunTimeline.length, lessThanOrEqualTo(4));

    // doList/avoidList가 실계산 strengths/cautions 그대로.
    expect(result.doList, analysis.strengths);
    expect(result.avoidList, analysis.weaknesses);

    // lucky는 getLuckyItems() 실데이터 기반 — 숫자 목록이 비어있지 않다.
    expect(result.lucky.numbers, isNotEmpty);

    // related — 같은 대카테고리(A) 안의 다른 카테고리 중 최대 4개.
    expect(result.related, isNotEmpty);
    expect(result.related.length, lessThanOrEqualTo(4));
    expect(result.related.any((r) => r.code == 'A01'), isFalse);

    // userRefId는 호출부가 넘긴 값을 그대로 보존.
    expect(result.userRefId, '#test0001');
  });

  test('Pipeline B(paragraphs) — SajuFullInterpretation 기반으로도 예외 없이 만들어진다', () {
    final kst = _birthUtc.add(const Duration(hours: 9));
    final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst,
      gender: 'female',
      isLunar: false,
      referenceDate: _kFixedDate,
    );
    // Pipeline B는 SajuFullInterpretation을 직접 쓰지 않고, 이미 조합된
    // paragraphs(JeontongNarrativeInterpreter.paragraphs()의 산출물 형태)만
    // 받는다 — 여기서는 그 산출물을 흉내낸 리스트를 넘긴다(재계산 없음,
    // 매핑 레이어 자체의 계약만 검증).
    final interp = SajuInterpreter.fullInterpretation(built.saju);
    expect(interp.dayMasterAnalysis.nature, isNotEmpty); // 실계산 확인용

    final result = buildSajuDawnResultDataFromParagraphs(
      entry: entryA02,
      profile: built.profile,
      saju: built.saju,
      fortuneRules: SajuFortuneRules.cachedOrNull,
      paragraphs: const ['타고난 성격을 살펴보면...', '이렇게 하면 더 좋아요.'],
      referenceDate: _kFixedDate,
      userRefId: '#test0002',
    );

    expect(result.categoryCode, 'A02');
    expect(result.chapters.length, 4);
    // Pipeline B는 personalitySentences 자리에 paragraphs 전체를 그대로
    // 一(총평) 챕터에 배치한다(§ 빌더 상단 주석 "열린 설계 질문 처리" 2번).
    final chapterOneText =
        result.chapters.first.paragraphs.expand((p) => p.runs).map((r) => r.text).join();
    expect(chapterOneText, contains('타고난 성격을 살펴보면'));
  });

  test('verdict 없이 호출해도 문단 첫 줄이 oneLineSummary로 안전하게 폴백한다', () {
    final kst = _birthUtc.add(const Duration(hours: 9));
    final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst,
      gender: 'female',
      isLunar: false,
      referenceDate: _kFixedDate,
    );
    final result = buildSajuDawnResultDataFromParagraphs(
      entry: entryA02,
      profile: built.profile,
      saju: built.saju,
      fortuneRules: SajuFortuneRules.cachedOrNull,
      paragraphs: const ['첫 문단입니다.'],
      referenceDate: _kFixedDate,
      userRefId: '#test0003',
    );
    expect(result.ilganDescription, contains('첫 문단입니다'));
  });
}
