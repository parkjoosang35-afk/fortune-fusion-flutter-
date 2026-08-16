/// [정통사주 69종 개인화 해석 엔진 — A06 검증 TEST3, 가장 중요]
/// 같은 spousePattern 내부 차별화 검증(사용자 지시 §4/§5/§15).
///
/// health_pattern_differentiation_test.dart(A05용)와 동일한 설계 원칙을
/// A06(LoveAnalysis.spousePattern)에 그대로 적용한다: "120명 중 다수가
/// spousePattern=정연형(正緣形) 이라고 나오더라도, 그 안의 결과가 똑같은
/// 근거/판단이 되어서는 안 된다."
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/love_analyzer.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import '../fixtures/jeontong_sample_120.dart';

void main() {
  final loveAnalyzer = const LoveAnalyzer();
  final refDate = DateTime.utc(2026, 8, 13);

  test('같은 spousePattern 그룹 내부에서 세부 근거(interpretationContext)가 서로 다르다', () {
    // 1) 120명 전원을 spousePattern별로 그룹화한다.
    final byPattern = <String, List<String>>{}; // pattern -> [userId,...]
    final contextByUser = <String, Map<String, String>>{};
    final supportingByUser = <String, String>{};
    final bondStrengthByUser = <String, String>{};
    final palaceConditionByUser = <String, String>{};
    final riskPatternByUser = <String, String>{};
    final daewoonByUser = <String, String>{};

    for (final input in kJeontongSample120) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final a = loveAnalyzer.analyze(built.profile, referenceDate: refDate);
      byPattern.putIfAbsent(a.spousePattern, () => []).add(input.userId);
      contextByUser[input.userId] = a.interpretationContext;
      supportingByUser[input.userId] =
          a.supportingEvidence.map((e) => e.toJson().toString()).join('|');
      bondStrengthByUser[input.userId] = a.spouseBondStrength;
      palaceConditionByUser[input.userId] = a.spousePalaceCondition;
      riskPatternByUser[input.userId] = a.romanceRiskPattern;
      daewoonByUser[input.userId] = a.marriagePeakDaewoonLabel;
    }

    // ignore: avoid_print
    print('spousePattern 그룹 크기: ${byPattern.map((k, v) => MapEntry(k, v.length))}');

    // 2) 가장 인원이 많은 그룹(최다 그룹)을 범용적으로 선택한다.
    final largestPatternEntry =
        byPattern.entries.reduce((a, b) => a.value.length >= b.value.length ? a : b);
    final groupUsers = largestPatternEntry.value;
    // ignore: avoid_print
    print('검증 대상 그룹: "${largestPatternEntry.key}" (${groupUsers.length}명) $groupUsers');

    expect(groupUsers.length, greaterThanOrEqualTo(3),
        reason: '그룹 내부 차별화를 검증하려면 최소 3명 이상의 동일 패턴 그룹이 필요함(현재 120명 표본에서 미달 시 표본을 늘려야 함)');

    // 3) 그룹 내부에서 interpretationContext(성별, 배우자성/비겁 개수,
    //    신강신약, 용신, 일지 관계, 애정신살, 정점대운 등)가 실제로
    //    서로 다른지 확인한다.
    final contextStrings = groupUsers.map((u) => contextByUser[u].toString()).toSet();
    // ignore: avoid_print
    print('그룹 내부 interpretationContext 종류 수=${contextStrings.length}/${groupUsers.length}');
    expect(contextStrings.length, greaterThan(1),
        reason: '같은 spousePattern이라도 배우자성/비겁 개수 등이 전원 동일하면 §5 위반');

    // 4) supportingEvidence(일지 관여 관계 상세, 애정 신살 존재 여부 등)도
    //    그룹 내부에서 다양해야 한다.
    final supportingStrings = groupUsers.map((u) => supportingByUser[u]!).toSet();
    // ignore: avoid_print
    print('그룹 내부 supportingEvidence 종류 수=${supportingStrings.length}/${groupUsers.length}');
    expect(supportingStrings.length, greaterThan(1),
        reason: '같은 spousePattern 그룹의 supportingEvidence(§5 세부 근거)가 전원 동일하면 안 됨');

    // 5) §15 "그릇의 크기/배우자궁 상태/리스크/정점 대운이 서로 다른지" —
    //    문장 이전 단계 대응 필드로 확인.
    final bondStrengths = groupUsers.map((u) => bondStrengthByUser[u]!).toSet();
    final palaceConditions = groupUsers.map((u) => palaceConditionByUser[u]!).toSet();
    final riskPatterns = groupUsers.map((u) => riskPatternByUser[u]!).toSet();
    final daewoons = groupUsers.map((u) => daewoonByUser[u]!).toSet();

    // ignore: avoid_print
    print('그룹 내부: spouseBondStrength=${bondStrengths.length}종, '
        'spousePalaceCondition=${palaceConditions.length}종, romanceRiskPattern=${riskPatterns.length}종, '
        'daewoon=${daewoons.length}종');

    // 최소한 이 4개 중 다수가 그룹 내에서 갈라져야 한다(전부 1종류로
    // 뭉치면 "제목만 다르고 내용은 같다"는 §19 금지사항에 해당).
    final differentiatedFieldCount = [
      bondStrengths.length > 1,
      palaceConditions.length > 1,
      riskPatterns.length > 1,
      daewoons.length > 1,
    ].where((b) => b).length;

    expect(differentiatedFieldCount, greaterThanOrEqualTo(2),
        reason: '같은 spousePattern 그룹 내부에서 최소 2개 이상의 실질 필드가 갈라져야 함(§15)');
  });

  test('정연형 그룹이 별도로 존재하면 그 안에서도 세부 조성이 다르다(있을 때만 검증)', () {
    final jeongyeonUsers = <String>[];
    final contexts = <String>[];

    for (final input in kJeontongSample120) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final a = loveAnalyzer.analyze(built.profile, referenceDate: refDate);
      if (a.spousePattern.startsWith('정연형')) {
        jeongyeonUsers.add(input.userId);
        contexts.add(a.interpretationContext.toString());
      }
    }

    // ignore: avoid_print
    print('정연형 그룹: ${jeongyeonUsers.length}명');
    if (jeongyeonUsers.length >= 2) {
      expect(contexts.toSet().length, greaterThan(1),
          reason: '정연형 그룹 내부의 신강신약/일지관계/신살/대운 조성이 전원 동일하면 §5 위반');
    } else {
      // ignore: avoid_print
      print('정연형 표본이 2명 미만이라 이 회차에서는 skip (표본 확대 필요 시 후속 조치)');
    }
  });
}
