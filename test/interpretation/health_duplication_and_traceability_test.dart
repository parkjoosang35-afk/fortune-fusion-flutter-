/// [정통사주 69종 개인화 해석 엔진 — A05 검증] §14 문장 중복률 검사
/// + §16 Evidence → 결과 문장 연결 추적 검사.
///
/// career_duplication_and_traceability_test.dart(A04용)와 동일한 설계
/// 원칙을 A05(HealthAnalysis)에 그대로 적용한다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/health_analyzer.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import '../fixtures/jeontong_sample_120.dart';

void main() {
  final healthAnalyzer = const HealthAnalyzer();
  final refDate = DateTime.utc(2026, 8, 13);

  group('§14 문장(근사치) 중복률 검사 — A05 120명', () {
    final a05HealthConstitutionPattern = <String>[];
    final a05HealthVitality = <String>[];
    final a05VulnerableOrgans = <String>[];
    final a05CoreEvidenceJudgments = <String>[];

    setUpAll(() {
      for (final input in kJeontongSample120) {
        final kst = input.birthDateTimeUtc.toUtc().add(
          const Duration(hours: 9),
        );
        final built =
            JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
              kst: kst,
              gender: input.gender,
              isLunar: input.isLunar,
              referenceDate: refDate,
            );
        final health = healthAnalyzer.analyze(
          built.profile,
          referenceDate: refDate,
        );

        a05HealthConstitutionPattern.add(health.healthConstitutionPattern);
        a05HealthVitality.add(health.healthVitality);
        a05VulnerableOrgans.add(health.vulnerableOrgans.join(','));
        a05CoreEvidenceJudgments.add(
          health.coreEvidence.map((e) => e.judgment).join(' '),
        );
      }
    });

    void checkMaxDuplicateRatio(
      String label,
      List<String> values, {
      required double maxRatio,
    }) {
      final freq = <String, int>{};
      for (final v in values) {
        freq[v] = (freq[v] ?? 0) + 1;
      }
      final maxCount = freq.values.reduce((a, b) => a > b ? a : b);
      final ratio = maxCount / values.length;
      // ignore: avoid_print
      print(
        '[$label] 종류=${freq.length}, 최다반복=$maxCount/${values.length} (${(ratio * 100).toStringAsFixed(1)}%)',
      );
      expect(
        ratio,
        lessThanOrEqualTo(maxRatio),
        reason:
            '[$label] 동일 문자열이 $maxCount/${values.length}회(${(ratio * 100).toStringAsFixed(1)}%) 반복 — 과도한 중복(§14)',
      );
    }

    test('A05 healthConstitutionPattern 중복률이 과도하지 않다', () {
      // TEST3(health_pattern_differentiation_test.dart)에서 최다 그룹인
      // 단일편중형이 54/120(45%)로 확인되어 A03(재관쌍미 80%)/A04(관인상생
      // 75%)보다 편중이 낮다. 그럼에도 일관성을 위해 A03/A04와 동일하게
      // 완화된 임계치(0.8)를 적용해 표본 변동에 따른 우발적 실패를 막는다.
      checkMaxDuplicateRatio(
        'A05.healthConstitutionPattern',
        a05HealthConstitutionPattern,
        maxRatio: 0.8,
      );
    });

    test('A05 healthVitality 중복률이 과도하지 않다', () {
      checkMaxDuplicateRatio(
        'A05.healthVitality',
        a05HealthVitality,
        maxRatio: 0.6,
      );
    });

    test('A05 vulnerableOrgans 중복률이 과도하지 않다', () {
      checkMaxDuplicateRatio(
        'A05.vulnerableOrgans',
        a05VulnerableOrgans,
        maxRatio: 0.7,
      );
    });

    test('A05 coreEvidence judgment 전체 결합문 중복률이 과도하지 않다', () {
      checkMaxDuplicateRatio(
        'A05.coreEvidenceJudgments',
        a05CoreEvidenceJudgments,
        maxRatio: 0.5,
      );
    });
  });

  group('§16 Evidence 추적성 검증 — A05 120명 중 대표 샘플', () {
    final sampleIndices = [0, 30, 60, 90, 119];

    for (final idx in sampleIndices) {
      final input = kJeontongSample120[idx];
      test(
        '${input.userId}: A05 coreEvidence+supportingEvidence가 근거-판단 추적 요건을 만족한다',
        () {
          final kst = input.birthDateTimeUtc.toUtc().add(
            const Duration(hours: 9),
          );
          final built =
              JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
                kst: kst,
                gender: input.gender,
                isLunar: input.isLunar,
                referenceDate: refDate,
              );
          final health = healthAnalyzer.analyze(
            built.profile,
            referenceDate: refDate,
          );

          expect(health.coreEvidence, isNotEmpty);
          for (final e in health.coreEvidence) {
            expect(e.sourceField, isNotEmpty);
            expect(e.sourceValue, isNotEmpty);
            expect(e.rule, isNotEmpty);
            expect(e.judgment, isNotEmpty);
            expect(e.interpretationRole, isNotNull);
          }
          // §5 세부 근거(과다/부족 오행별 excess/lack 증상)가
          // supportingEvidence에 실제로 남아 있어야 한다.
          expect(health.supportingEvidence, isNotEmpty);

          // interpretationContext에 healthConstitutionPattern/healthVitality
          // 판단에 쓰인 원시 수치(과다/부족 오행, 신강신약, 용신/기신,
          // 건강신살, 일간)가 모두 남아있어야 한다.
          final ctx = health.interpretationContext;
          for (final key in [
            'dominantElements',
            'deficientElements',
            'isImbalanced',
            'strengthVerdict',
            'yongsinElement',
            'yongsinRooted',
            'gisinElement',
            'gisinCount',
            'foundHealthSinsal',
            'careBaseElement',
            'dayGan',
          ]) {
            expect(
              ctx.containsKey(key),
              isTrue,
              reason: 'interpretationContext에 "$key"가 없음(§16 추적성 위반)',
            );
          }
        },
      );
    }
  });
}
