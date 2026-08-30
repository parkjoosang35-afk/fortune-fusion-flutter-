/// [정통사주 69종 개인화 해석 엔진 — A06 검증] §14 문장 중복률 검사
/// + §16 Evidence → 결과 문장 연결 추적 검사.
///
/// health_duplication_and_traceability_test.dart(A05용)와 동일한 설계
/// 원칙을 A06(LoveAnalysis)에 그대로 적용한다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/love_analyzer.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import '../fixtures/jeontong_sample_120.dart';

void main() {
  final loveAnalyzer = const LoveAnalyzer();
  final refDate = DateTime.utc(2026, 8, 13);

  group('§14 문장(근사치) 중복률 검사 — A06 120명', () {
    final a06SpousePattern = <String>[];
    final a06SpouseBondStrength = <String>[];
    final a06SpousePalaceCondition = <String>[];
    final a06CoreEvidenceJudgments = <String>[];

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
        final love = loveAnalyzer.analyze(
          built.profile,
          referenceDate: refDate,
        );

        a06SpousePattern.add(love.spousePattern);
        a06SpouseBondStrength.add(love.spouseBondStrength);
        a06SpousePalaceCondition.add(love.spousePalaceCondition);
        a06CoreEvidenceJudgments.add(
          love.coreEvidence.map((e) => e.judgment).join(' '),
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

    test(
      'A06 spousePattern 중복률이 과도하지 않다(단, 배우자성 개수 분포 편중은 별도 findings로 기록)',
      () {
        // A03(재관쌍미 80%)/A04(관인상생 75%)와 마찬가지로 배우자성/비겁
        // 개수 조합 분류 특성상 특정 그룹으로 편중될 수 있어 완화된
        // 임계치(0.8)를 적용해 표본 변동에 따른 우발적 실패를 막는다.
        checkMaxDuplicateRatio(
          'A06.spousePattern',
          a06SpousePattern,
          maxRatio: 0.8,
        );
      },
    );

    test('A06 spouseBondStrength 중복률이 과도하지 않다', () {
      checkMaxDuplicateRatio(
        'A06.spouseBondStrength',
        a06SpouseBondStrength,
        maxRatio: 0.7,
      );
    });

    test('A06 spousePalaceCondition 중복률이 과도하지 않다', () {
      checkMaxDuplicateRatio(
        'A06.spousePalaceCondition',
        a06SpousePalaceCondition,
        maxRatio: 0.7,
      );
    });

    test('A06 coreEvidence judgment 전체 결합문 중복률이 과도하지 않다', () {
      checkMaxDuplicateRatio(
        'A06.coreEvidenceJudgments',
        a06CoreEvidenceJudgments,
        maxRatio: 0.5,
      );
    });
  });

  group('§16 Evidence 추적성 검증 — A06 120명 중 대표 샘플', () {
    final sampleIndices = [0, 30, 60, 90, 119];

    for (final idx in sampleIndices) {
      final input = kJeontongSample120[idx];
      test(
        '${input.userId}: A06 coreEvidence+supportingEvidence가 근거-판단 추적 요건을 만족한다',
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
          final love = loveAnalyzer.analyze(
            built.profile,
            referenceDate: refDate,
          );

          expect(love.coreEvidence, isNotEmpty);
          for (final e in love.coreEvidence) {
            expect(e.sourceField, isNotEmpty);
            expect(e.sourceValue, isNotEmpty);
            expect(e.rule, isNotEmpty);
            expect(e.judgment, isNotEmpty);
            expect(e.interpretationRole, isNotNull);
          }
          // §5 세부 근거(일지 관여 관계 상세, 애정 신살 존재 여부)가
          // supportingEvidence에 실제로 남아 있어야 한다.
          expect(love.supportingEvidence, isNotEmpty);

          // interpretationContext에 spousePattern/spouseBondStrength/
          // spousePalaceCondition 판단에 쓰인 원시 수치(성별, 배우자성/
          // 비겁 개수, 신강신약, 용신, 일지 관계, 애정신살, 정점대운)가
          // 모두 남아있어야 한다.
          final ctx = love.interpretationContext;
          for (final key in [
            'gender',
            'spouseCategory',
            'spouseCount',
            'biCount',
            'strengthVerdict',
            'yongsinElement',
            'dayBranchRelationTypes',
            'foundRomanceSinsal',
            'marriagePeakDaewoonLabel',
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
