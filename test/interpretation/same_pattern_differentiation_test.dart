/// [정통사주 69종 개인화 해석 엔진 — A01/A03 검증 TEST3, 가장 중요]
/// 같은 wealthPattern 내부 차별화 검증(사용자 지시 §4/§5/§15).
///
/// "100명 중 20명이 wealthPattern=재관쌍미 라고 나오더라도, 20명의 결과가
/// 똑같은 문장이 되어서는 안 된다." A03은 아직 NarrativeGenerator(완성
/// 문장)를 갖지 않으므로, 이 테스트는 그 전 단계인
/// interpretationContext/supportingEvidence(§5가 요구하는 "정재/편재/
/// 관성/인성/비겁 개수, 대운" 등 세부 근거)가 같은 패턴 그룹 내부에서도
/// 실제로 달라지는지를 검증한다. 이 데이터가 서로 다르면, 그 위에 얹힐
/// NarrativeGenerator가 이 값을 문장에 반영하는 한 문장도 달라질 수 있는
/// "재료"가 이미 확보되어 있다는 뜻이다. 반대로 이 데이터부터 전원 동일
/// 하다면 그 위에 어떤 문장 생성기를 얹어도 개인화가 불가능하므로, 이
/// 단계에서 반드시 걸러내야 한다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/wealth_analyzer.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import '../fixtures/jeontong_sample_120.dart';

void main() {
  final wealthAnalyzer = const WealthAnalyzer();
  final refDate = DateTime.utc(2026, 8, 13);

  test('같은 wealthPattern 그룹 내부에서 세부 근거(interpretationContext)가 서로 다르다', () {
    // 1) 120명 전원을 wealthPattern별로 그룹화한다.
    final byPattern = <String, List<String>>{}; // pattern -> [userId,...]
    final contextByUser = <String, Map<String, String>>{};
    final supportingByUser = <String, String>{};
    final wealthStrengthByUser = <String, String>{};
    final incomePatternByUser = <String, String>{};
    final riskPatternByUser = <String, String>{};
    final assetStyleByUser = <String, String>{};
    final daewoonByUser = <String, String>{};

    for (final input in kJeontongSample120) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final a = wealthAnalyzer.analyze(built.profile, referenceDate: refDate);
      byPattern.putIfAbsent(a.wealthPattern, () => []).add(input.userId);
      contextByUser[input.userId] = a.interpretationContext;
      supportingByUser[input.userId] =
          a.supportingEvidence.map((e) => e.toJson().toString()).join('|');
      wealthStrengthByUser[input.userId] = a.wealthStrength;
      incomePatternByUser[input.userId] = a.incomePattern;
      riskPatternByUser[input.userId] = a.riskPattern;
      assetStyleByUser[input.userId] = a.assetManagementStyle;
      daewoonByUser[input.userId] = a.wealthPeakDaewoonLabel;
    }

    // ignore: avoid_print
    print('wealthPattern 그룹 크기: ${byPattern.map((k, v) => MapEntry(k, v.length))}');

    // 2) 가장 인원이 많은 그룹(사용자 예시의 '재관쌍미'에 해당하는 것이
    //    이상적이나, 표본 특성상 최다 그룹이 다를 수 있으므로 "최다 그룹"을
    //    범용적으로 선택한다 — 어떤 패턴이든 그룹 내부 차별화 원칙은 동일).
    final largestPatternEntry =
        byPattern.entries.reduce((a, b) => a.value.length >= b.value.length ? a : b);
    final groupUsers = largestPatternEntry.value;
    // ignore: avoid_print
    print('검증 대상 그룹: "${largestPatternEntry.key}" (${groupUsers.length}명) $groupUsers');

    expect(groupUsers.length, greaterThanOrEqualTo(3),
        reason: '그룹 내부 차별화를 검증하려면 최소 3명 이상의 동일 패턴 그룹이 필요함(현재 120명 표본에서 미달 시 표본을 늘려야 함)');

    // 3) 그룹 내부에서 interpretationContext(정재/편재/관성/인성/비겁 개수,
    //    신강신약, 용신/기신, 현재대운 등)가 실제로 서로 다른지 확인한다.
    final contextStrings = groupUsers.map((u) => contextByUser[u].toString()).toSet();
    // ignore: avoid_print
    print('그룹 내부 interpretationContext 종류 수=${contextStrings.length}/${groupUsers.length}');
    expect(contextStrings.length, greaterThan(1),
        reason: '같은 wealthPattern이라도 정재/편재/관성/인성/비겁 세부 개수 등이 전원 동일하면 §5 위반');

    // 4) supportingEvidence(정재:편재 비율, 겁재 개수, 현재 대운 등)도
    //    그룹 내부에서 다양해야 한다.
    final supportingStrings = groupUsers.map((u) => supportingByUser[u]!).toSet();
    // ignore: avoid_print
    print('그룹 내부 supportingEvidence 종류 수=${supportingStrings.length}/${groupUsers.length}');
    expect(supportingStrings.length, greaterThan(1),
        reason: '같은 wealthPattern 그룹의 supportingEvidence(§5 세부 근거)가 전원 동일하면 안 됨');

    // 5) §15 "핵심성향/재물획득방식/위험요소/자산관리방식/대운/조언이
    //    서로 다른지" — 현재 구현에서 문장 이전 단계 대응 필드로 확인.
    final wealthStrengths = groupUsers.map((u) => wealthStrengthByUser[u]!).toSet();
    final incomePatterns = groupUsers.map((u) => incomePatternByUser[u]!).toSet();
    final riskPatterns = groupUsers.map((u) => riskPatternByUser[u]!).toSet();
    final assetStyles = groupUsers.map((u) => assetStyleByUser[u]!).toSet();
    final daewoons = groupUsers.map((u) => daewoonByUser[u]!).toSet();

    // ignore: avoid_print
    print('그룹 내부: wealthStrength=${wealthStrengths.length}종, '
        'incomePattern=${incomePatterns.length}종, riskPattern=${riskPatterns.length}종, '
        'assetStyle=${assetStyles.length}종, daewoon=${daewoons.length}종');

    // 최소한 이 5개 중 다수가 그룹 내에서 갈라져야 한다(전부 1종류로
    // 뭉치면 "제목만 다르고 내용은 같다"는 §19 금지사항에 해당).
    final differentiatedFieldCount = [
      wealthStrengths.length > 1,
      incomePatterns.length > 1,
      riskPatterns.length > 1,
      assetStyles.length > 1,
      daewoons.length > 1,
    ].where((b) => b).length;

    expect(differentiatedFieldCount, greaterThanOrEqualTo(2),
        reason: '같은 wealthPattern 그룹 내부에서 최소 2개 이상의 실질 필드가 갈라져야 함(§15)');
  });

  test('재관쌍미 그룹이 별도로 존재하면 그 안에서도 세부 조성이 다르다(있을 때만 검증)', () {
    final jaegwanUsers = <String>[];
    final contexts = <String>[];

    for (final input in kJeontongSample120) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final a = wealthAnalyzer.analyze(built.profile, referenceDate: refDate);
      if (a.wealthPattern.startsWith('재관쌍미')) {
        jaegwanUsers.add(input.userId);
        contexts.add(a.interpretationContext.toString());
      }
    }

    // ignore: avoid_print
    print('재관쌍미 그룹: ${jaegwanUsers.length}명');
    if (jaegwanUsers.length >= 2) {
      expect(contexts.toSet().length, greaterThan(1),
          reason: '재관쌍미 그룹 내부의 정재/편재/관성/인성/비겁 조성이 전원 동일하면 §5 위반');
    } else {
      // ignore: avoid_print
      print('재관쌍미 표본이 2명 미만이라 이 회차에서는 skip (표본 확대 필요 시 후속 조치)');
    }
  });
}
