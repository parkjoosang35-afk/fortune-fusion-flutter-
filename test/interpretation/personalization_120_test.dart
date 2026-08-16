/// [정통사주 69종 개인화 해석 엔진 — A01/A03 검증 TEST2] 개인화 검증.
///
/// 사용자 지시 §3: 100명 이상 비교 시, A01/A03이 나열한 필드들이 실제
/// 사주 데이터에 따라 달라지는지 확인한다.
///
/// [필드 매핑 안내] 사용자가 나열한 필드 중 일부(dayMaster, fiveElements,
/// tenGods, hiddenStems, yongsin/heesin/gisin/gusin, relationships, sinsal,
/// daewoon)는 CategoryAnalysis가 아니라 SajuProfile(PHASE1~4 산출물) 원본
/// 필드다. CategoryAnalyzer는 이 원본 값을 "가공"해서 자기 카테고리에
/// 맞는 판단 필드(dominantTenGodCategory, strengthVerdict 등)로 바꿔
/// 노출하므로, 아래에서는 두 층을 모두 검증한다:
///   (a) SajuProfile 원본 층 — 120명이 실제로 서로 다른 원본 데이터를
///       갖는지 (다양성의 "원인"이 되는 층)
///   (b) CategoryAnalysis 출력 층 — A01/A03가 실제로 나열한 고유 필드들이
///       달라지는지 (다양성의 "결과"가 되는 층, 사용자가 진짜 원하는 것)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/life_overall_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/wealth_analyzer.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import '../fixtures/jeontong_sample_120.dart';

void main() {
  final lifeAnalyzer = const LifeOverallAnalyzer();
  final wealthAnalyzer = const WealthAnalyzer();
  final refDate = DateTime.utc(2026, 8, 13);

  group('TEST2 개인화 — (a) SajuProfile 원본 데이터 층 다양성(120명)', () {
    final dayMasterSet = <String>{};
    final fiveElementsSet = <String>{};
    final tenGodsSet = <String>{};
    final hiddenStemsSet = <String>{};
    final yongsinSet = <String>{};
    final heesinSet = <String>{};
    final gisinSet = <String>{};
    final gusinSet = <String>{};
    final relationshipsSet = <String>{};
    final sinsalSet = <String>{};
    final daewoonSet = <String>{};

    setUpAll(() {
      for (final input in kJeontongSample120) {
        final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
        final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
          kst: kst,
          gender: input.gender,
          isLunar: input.isLunar,
          referenceDate: refDate,
        );
        final p = built.profile;
        dayMasterSet.add(p.dayPillar.stemHanja);
        fiveElementsSet.add('${p.fiveElements?.dominant}|${p.fiveElements?.deficient}');
        tenGodsSet.add(p.tenGods?.values.join(',') ?? '');
        hiddenStemsSet.add(
          p.hiddenStems?.values
                  .map((e) => e.stems.map((s) => s.tenGod).join('/'))
                  .join(';') ??
              '',
        );
        yongsinSet.add(p.yongsin?.yongsin ?? '');
        heesinSet.add(p.yongsin?.heesin ?? '');
        gisinSet.add(p.yongsin?.gisin ?? '');
        gusinSet.add(p.yongsin?.gusin ?? '');
        relationshipsSet.add(
          (p.relationships ?? const []).map((r) => '${r.type}:${r.characters.join('')}').join(','),
        );
        sinsalSet.add((p.sinsal ?? const []).map((s) => s.nameKr).join(','));
        daewoonSet.add(
          (p.daewoon ?? const [])
              .map((d) => '${d.pillar.stemHanja}${d.pillar.branchHanja}')
              .join(','),
        );
      }
    });

    test('dayMaster(일간)가 120명 사이에서 다양하다', () {
      // ignore: avoid_print
      print('dayMaster 종류=${dayMasterSet.length}');
      expect(dayMasterSet.length, greaterThan(1));
    });
    test('fiveElements(오행 과다/부족 조합)이 다양하다', () {
      expect(fiveElementsSet.length, greaterThan(1));
    });
    test('tenGods(십신 7위치 조합)이 다양하다', () {
      expect(tenGodsSet.length, greaterThan(1));
    });
    test('hiddenStems(지장간 십신 조합)이 다양하다', () {
      expect(hiddenStemsSet.length, greaterThan(1));
    });
    test('yongsin(용신)이 다양하다', () {
      expect(yongsinSet.length, greaterThan(1));
    });
    test('heesin(희신)이 다양하다', () {
      expect(heesinSet.length, greaterThan(1));
    });
    test('gisin(기신)이 다양하다', () {
      expect(gisinSet.length, greaterThan(1));
    });
    test('gusin(구신)이 다양하다', () {
      expect(gusinSet.length, greaterThan(1));
    });
    test('relationships(합충형파해)가 다양하다', () {
      expect(relationshipsSet.length, greaterThan(1));
    });
    test('sinsal(신살)이 다양하다', () {
      expect(sinsalSet.length, greaterThan(1));
    });
    test('daewoon(대운 흐름)이 다양하다', () {
      expect(daewoonSet.length, greaterThan(1));
    });
  });

  group('TEST2 개인화 — (b) A01 LifeOverallAnalysis 출력 필드 다양성(120명)', () {
    final dominantTenGodCategorySet = <String>{};
    final lifeThemeSet = <String>{};
    final coreNatureSet = <String>{};
    final strengthsSet = <String>{};
    final weaknessesSet = <String>{};
    final favorableSet = <String>{};
    final cautionSet = <String>{};
    final strengthVerdictSet = <String>{};
    final yongsinElementSet = <String>{};
    final gisinElementSet = <String>{};
    final dominantElementsSet = <String>{};
    final deficientElementsSet = <String>{};
    final notableSinsalSet = <String>{};

    setUpAll(() {
      for (final input in kJeontongSample120) {
        final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
        final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
          kst: kst,
          gender: input.gender,
          isLunar: input.isLunar,
          referenceDate: refDate,
        );
        final a = lifeAnalyzer.analyze(built.profile, referenceDate: refDate);
        dominantTenGodCategorySet.add(a.dominantTenGodCategory);
        lifeThemeSet.add(a.lifeTheme);
        coreNatureSet.add(a.coreNatureDescription);
        strengthsSet.add(a.strengths.join(','));
        weaknessesSet.add(a.weaknesses.join(','));
        favorableSet.add(a.favorableConditions.join(','));
        cautionSet.add(a.cautionConditions.join(','));
        strengthVerdictSet.add(a.strengthVerdict);
        yongsinElementSet.add(a.yongsinElement);
        gisinElementSet.add(a.gisinElement);
        dominantElementsSet.add(a.dominantElements.join(','));
        deficientElementsSet.add(a.deficientElements.join(','));
        notableSinsalSet.add(a.notableSinsal.join(','));
      }
    });

    test('dominantTenGodCategory(중심 기운)이 다양하다', () {
      // ignore: avoid_print
      print('A01 dominantTenGodCategory 종류=$dominantTenGodCategorySet');
      expect(dominantTenGodCategorySet.length, greaterThan(1));
    });
    test('lifeTheme(인생 테마)가 다양하다', () {
      expect(lifeThemeSet.length, greaterThan(1));
    });
    test('coreNatureDescription(타고난 성향)이 다양하다', () {
      expect(coreNatureSet.length, greaterThan(1));
    });
    test('strengths(강점 목록)가 다양하다', () {
      expect(strengthsSet.length, greaterThan(1));
    });
    test('weaknesses(약점 목록)가 다양하다', () {
      expect(weaknessesSet.length, greaterThan(1));
    });
    test('favorableConditions(좋은 흐름)이 다양하다', () {
      expect(favorableSet.length, greaterThan(1));
    });
    test('cautionConditions(주의 흐름)이 다양하다', () {
      expect(cautionSet.length, greaterThan(1));
    });
    test('strengthVerdict(신강신약)이 신강/신약/중화 모두 존재한다', () {
      expect(strengthVerdictSet, containsAll(<String>{'신강', '신약', '중화'}));
    });
    test('yongsinElement(용신 오행)이 다양하다', () {
      expect(yongsinElementSet.length, greaterThan(1));
    });
    test('gisinElement(기신 오행)이 다양하다', () {
      expect(gisinElementSet.length, greaterThan(1));
    });
    test('dominantElements(오행 과다)가 다양하다', () {
      expect(dominantElementsSet.length, greaterThan(1));
    });
    test('deficientElements(오행 부족)이 다양하다', () {
      expect(deficientElementsSet.length, greaterThan(1));
    });
    test('notableSinsal(특이 신살)이 다양하다', () {
      expect(notableSinsalSet.length, greaterThan(1));
    });
  });

  group('TEST2 개인화 — (b) A03 WealthAnalysis 출력 필드 다양성(120명)', () {
    final wealthPatternSet = <String>{};
    final wealthStrengthSet = <String>{};
    final incomePatternSet = <String>{};
    final riskPatternSet = <String>{};
    final assetManagementStyleSet = <String>{};
    final wealthPeakDaewoonSet = <String>{};
    final favorableSet = <String>{};
    final cautionSet = <String>{};

    setUpAll(() {
      for (final input in kJeontongSample120) {
        final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
        final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
          kst: kst,
          gender: input.gender,
          isLunar: input.isLunar,
          referenceDate: refDate,
        );
        final a = wealthAnalyzer.analyze(built.profile, referenceDate: refDate);
        wealthPatternSet.add(a.wealthPattern);
        wealthStrengthSet.add(a.wealthStrength);
        incomePatternSet.add(a.incomePattern);
        riskPatternSet.add(a.riskPattern);
        assetManagementStyleSet.add(a.assetManagementStyle);
        wealthPeakDaewoonSet.add(a.wealthPeakDaewoonLabel);
        favorableSet.add(a.favorableConditions.join(','));
        cautionSet.add(a.cautionConditions.join(','));
      }
    });

    test('wealthPattern(재물 구조)이 다양하다', () {
      // ignore: avoid_print
      print('A03 wealthPattern 종류=$wealthPatternSet');
      expect(wealthPatternSet.length, greaterThan(1));
    });
    test('wealthStrength(그릇의 크기)가 다양하다', () {
      expect(wealthStrengthSet.length, greaterThan(1));
    });
    test('incomePattern(수입 패턴)이 다양하다', () {
      expect(incomePatternSet.length, greaterThan(1));
    });
    test('riskPattern(재물 리스크)이 다양하다', () {
      expect(riskPatternSet.length, greaterThan(1));
    });
    test('assetManagementStyle(자산 운용 스타일)이 다양하다', () {
      expect(assetManagementStyleSet.length, greaterThan(1));
    });
    test('wealthPeakDaewoonLabel(재물 정점 대운)이 다양하다', () {
      expect(wealthPeakDaewoonSet.length, greaterThan(1));
    });
    test('favorableConditions(좋은 흐름)이 다양하다', () {
      expect(favorableSet.length, greaterThan(1));
    });
    test('cautionConditions(주의 흐름)이 다양하다', () {
      expect(cautionSet.length, greaterThan(1));
    });
  });
}
