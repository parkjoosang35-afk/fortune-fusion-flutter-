/// [정통사주 80종 · C06~C10 세운(올해) 그룹] 이동수/시험운/관재수/인간관계/
/// 12개월 월별 계산 모듈.
///
/// C01~C05와 마찬가지로 "원본 파이썬 이식"이 아니라 이번 세션에서 신규
/// 설계한 계산이다(사용자 최종 지시 §3 "C06~C10 진행"). C01~C05가 이미
/// 채택한 패턴(대표일 `Solar.fromYmd(year, 6, 15)`로 세운 간지를 구해
/// 일간 대비 십신을 계산)을 그대로 재사용해, [SajuProfile]이 없어도(레거시
/// `SajuEngine.calculate()` 경로에서도) 동일하게 동작하게 한다.
///
/// [절대 원칙] 새로운 명리 판정 공식을 만들지 않는다. 여기서 쓰는 판정은
/// 모두 이미 검증된 순수 함수/고정 테이블([getTenGod], [yeokma],
/// [munchangGwiin], [RelationshipsEngine])을 조회·조합하는 것뿐이다.
///
/// [C08/D10 공통 엔진화 — 사용자 확정 지시 §5] "세운/일진과 원국 관계
/// 비교"는 `relationships_engine.dart`의 [RelationshipsEngine.analyzeExternal]
/// (원국 4주 + 외부 1주 교차 비교 공용 메서드)을 통해서만 수행한다. C08은
/// 이 함수를 세운 간지로 호출하고, 향후 D10은 동일 함수를 일진 간지로
/// 호출한다 — 개별 임시 코드를 만들지 않는다.
///
/// [건강 표현과 무관] 이 파일의 카테고리들은 건강 카테고리가 아니므로
/// §7 표현 제약과는 무관하지만, C08(관재수)은 "반드시 소송을 겪는다"는
/// 단정적 표현 대신 "주의가 필요한 시기" 수준의 완곡한 안내로만 표현한다
/// (법률 자문 유도 disclaimer는 `jeontong_eighty_matrix.dart`의
/// `DisclaimerTag.legalDate`가 이미 담당).
library;

import 'package:lunar/lunar.dart' show Solar;

import 'manseryeok/luck_pillar_factory.dart' show buildLuckPillar;
import 'manseryeok/relationships_engine.dart' show RelationshipsEngine;
import 'saju_engine.dart';
import 'saju_fortune_modules.dart' show getMonthlyFortune;
import 'saju_fortune_rules.dart' show SajuFortuneRules;

/// [year] 세운 간지를 대표일(6/15) 기준으로 구한다 — `getYearFortune()`/
/// `getDaewoonSewoonCombo()`와 완전히 동일한 방식(신규 계산 방식 아님).
(String gan, String zhi) _sewoonGanZhi(int year) {
  final solar = Solar.fromYmd(year, 6, 15);
  final lunar = solar.getLunar();
  return (lunar.getYearGan(), lunar.getYearZhi());
}

String _yearLabel(int year, String gan, String zhi) =>
    '$year년 $gan$zhi (${ganKr[gan]}${zhiKr[zhi]})';

// ============================================================
// C06 — 올해 이사·이동수 (역마 발동 여부)
// ============================================================

class YearlyMovementFortuneResult {
  const YearlyMovementFortuneResult({
    required this.title,
    required this.overall,
    required this.advice,
    required this.triggered,
  });

  final String title;
  final String overall;
  final String advice;
  final bool triggered;
}

/// 원국 일지 기준 역마([yeokma] 고정표)가 이번 세운 지지와 일치하는지
/// 조회한다. [findSinsal]이 원국 자체 판정에 쓰는 것과 동일한 표를,
/// "세운 지지가 그 역마를 발동시키는지"로 교차 조회만 확장했다.
YearlyMovementFortuneResult getYearlyMovementFortune(
  SajuResult saju, {
  required int year,
}) {
  final (yGan, yZhi) = _sewoonGanZhi(year);
  final dayZhi = saju.pillars['day']!.zhi;
  final targetYeokma = yeokma[dayZhi];
  final triggered = targetYeokma != null && targetYeokma == yZhi;
  final label = _yearLabel(year, yGan, yZhi);

  if (triggered) {
    return YearlyMovementFortuneResult(
      title: '이동수가 들어오는 해',
      overall:
          '$label 세운이 역마(驛馬)를 발동시켜, 이사·이직·출장·여행처럼 '
          '움직임과 관련된 변화가 생기기 쉬운 흐름이에요.',
      advice: '미리 일정을 여유 있게 잡아두면 갑작스러운 이동도 순조롭게 넘길 수 있어요.',
      triggered: true,
    );
  }
  return YearlyMovementFortuneResult(
    title: '이동수가 뚜렷하지 않은 해',
    overall:
        '$label 세운에서는 역마(驛馬)가 뚜렷하게 발동하지 않아, '
        '생활 반경이 비교적 안정적으로 유지될 가능성이 높아요.',
    advice: '변화를 원한다면 스스로 계획을 세워 움직여보는 것도 좋은 방법이에요.',
    triggered: false,
  );
}

// ============================================================
// C07 — 올해 시험·자격운 (문창귀인 + 인성 발동 여부)
// ============================================================

class YearlyExamFortuneResult {
  const YearlyExamFortuneResult({
    required this.title,
    required this.overall,
    required this.advice,
    required this.triggered,
  });

  final String title;
  final String overall;
  final String advice;
  final bool triggered;
}

const Set<String> _studyGods = {'정인', '편인'};

/// 원국 일간 기준 문창귀인([munchangGwiin] 고정표)이 세운 지지와
/// 일치하는지, 또는 세운 십신이 인성(정인/편인)인지를 조회한다.
YearlyExamFortuneResult getYearlyExamFortune(
  SajuResult saju, {
  required int year,
}) {
  final (yGan, yZhi) = _sewoonGanZhi(year);
  final dayGan = saju.dayMaster.gan;
  final targetMunchang = munchangGwiin[dayGan];
  final munchangTriggered = targetMunchang != null && targetMunchang == yZhi;
  final ganGod = getTenGod(dayGan, yGan);
  final zhiGod = getTenGod(dayGan, yZhi);
  final studyGodHit =
      _studyGods.contains(ganGod) || _studyGods.contains(zhiGod);
  final label = _yearLabel(year, yGan, yZhi);

  if (munchangTriggered) {
    return YearlyExamFortuneResult(
      title: '문창귀인이 들어오는 해',
      overall:
          '$label 세운이 문창귀인(文昌貴人)을 발동시켜, 시험·자격증·학업 성과에 '
          '유리한 기운이 들어오는 해예요.',
      advice: '평소 미뤄뒀던 시험이나 자격증 준비를 시작하기 좋은 시기예요.',
      triggered: true,
    );
  }
  if (studyGodHit) {
    return YearlyExamFortuneResult(
      title: '학습운이 양호한 해',
      overall:
          '$label 세운에 인성($ganGod/$zhiGod 중 인성) 기운이 들어와, '
          '차분히 공부하고 배우는 흐름이 뒷받침되는 해예요.',
      advice: '꾸준한 학습 루틴을 유지하면 좋은 결과로 이어지기 쉬워요.',
      triggered: false,
    );
  }
  return YearlyExamFortuneResult(
    title: '평소 페이스를 유지하면 좋은 해',
    overall:
        '$label 세운에서는 문창귀인·인성이 뚜렷하게 발동하지 않아, '
        '급격한 학습운 상승보다는 꾸준함이 중요한 해예요.',
    advice: '단기간의 벼락치기보다 장기 계획을 세워 준비하면 좋아요.',
    triggered: false,
  );
}

// ============================================================
// C08 — 올해 소송·관재수(§5 공통 관계 비교 엔진 사용)
// ============================================================

class YearlyLegalRiskFortuneResult {
  const YearlyLegalRiskFortuneResult({
    required this.title,
    required this.overall,
    required this.advice,
  });

  final String title;
  final String overall;
  final String advice;
}

const Set<String> _officerGodsC = {'편관', '정관'};

/// [§5 공통 엔진화] 세운 간지를 [RelationshipsEngine.analyzeExternal]로
/// 원국 4주와 교차 비교해 형충파해원진귀문 관계를 찾고, 세운 십신의
/// 관성(편관/정관) 발동 여부와 함께 판정한다.
///
/// [표현 원칙] "소송을 겪는다"는 단정적 진단이 아니라 "주의가 필요한
/// 시기"라는 완곡한 표현만 사용한다(disclaimers: legalDate가 이미
/// 참고용임을 안내).
YearlyLegalRiskFortuneResult getYearlyLegalRiskFortune(
  SajuResult saju, {
  required int year,
}) {
  final (yGan, yZhi) = _sewoonGanZhi(year);
  final dayGan = saju.dayMaster.gan;
  final officerHit =
      _officerGodsC.contains(getTenGod(dayGan, yGan)) ||
      _officerGodsC.contains(getTenGod(dayGan, yZhi));

  final yearPillar = buildLuckPillar(
    saju.pillars['year']!.gan,
    saju.pillars['year']!.zhi,
  );
  final monthPillar = buildLuckPillar(
    saju.pillars['month']!.gan,
    saju.pillars['month']!.zhi,
  );
  final dayPillar = buildLuckPillar(
    saju.pillars['day']!.gan,
    saju.pillars['day']!.zhi,
  );
  final hourPillar = buildLuckPillar(
    saju.pillars['hour']!.gan,
    saju.pillars['hour']!.zhi,
  );
  final sewoonPillar = buildLuckPillar(yGan, yZhi);

  final relations = RelationshipsEngine.analyzeExternal(
    yearPillar: yearPillar,
    monthPillar: monthPillar,
    dayPillar: dayPillar,
    hourPillar: hourPillar,
    externalPillar: sewoonPillar,
    externalLabel: '세운',
  );
  const cautionTypes = {'지지충', '형', '자형', '삼형', '파', '해', '원진', '귀문', '천간충'};
  final cautionHits = relations
      .where((r) => cautionTypes.contains(r.type))
      .toList();
  final label = _yearLabel(year, yGan, yZhi);

  if (officerHit && cautionHits.isNotEmpty) {
    final types = cautionHits.map((r) => r.type).toSet().join('·');
    return YearlyLegalRiskFortuneResult(
      title: '계약·문서 관련 주의가 필요한 해',
      overall:
          '$label 세운이 관성을 발동시키면서 동시에 원국과 $types 관계를 이뤄, '
          '계약·문서·분쟁과 관련된 사안에서 평소보다 신중함이 필요한 시기예요.',
      advice:
          '중요한 계약서는 서명 전 꼼꼼히 검토하고, 다툼이 될 만한 사안은 '
          '전문가(변호사·법무사)의 자문을 받아보는 것을 권해요. '
          '(※ 사주 명리학적 참고 정보이며, 실제 법적 결과를 예측하는 것은 아니에요.)',
    );
  }
  if (cautionHits.isNotEmpty) {
    final types = cautionHits.map((r) => r.type).toSet().join('·');
    return YearlyLegalRiskFortuneResult(
      title: '주변과의 갈등에 유의하면 좋은 해',
      overall:
          '$label 세운이 원국과 $types 관계를 이뤄, 사람들과의 마찰이나 '
          '오해가 생기기 쉬운 흐름이에요.',
      advice: '감정적인 대응보다 차분한 대화로 풀어가면 큰 갈등으로 번지는 것을 막을 수 있어요.',
    );
  }
  if (officerHit) {
    return YearlyLegalRiskFortuneResult(
      title: '책임과 규칙이 강조되는 해',
      overall: '$label 세운이 관성을 발동시켜, 계약·규정·책임이 강조되는 해예요.',
      advice: '맡은 일이나 계약 조건을 꼼꼼히 확인하고 지키면 큰 문제 없이 넘어갈 수 있어요.',
    );
  }
  return YearlyLegalRiskFortuneResult(
    title: '법적 분쟁 위험이 낮은 해',
    overall:
        '$label 세운에서는 관성이나 형충 관계가 뚜렷하게 발동하지 않아, '
        '계약·분쟁 관련해 비교적 평온하게 지나갈 가능성이 높은 해예요.',
    advice: '평소처럼 기본적인 서류 관리 습관만 유지해도 충분해요.',
  );
}

// ============================================================
// C09 — 올해 인간관계 (세운 십신 기준)
// ============================================================

class YearlyRelationshipFortuneResult {
  const YearlyRelationshipFortuneResult({
    required this.title,
    required this.overall,
    required this.advice,
  });

  final String title;
  final String overall;
  final String advice;
}

/// 세운 십신(간/지)을 조회해 어떤 유형의 인간관계가 두드러지는 해인지
/// 안내한다. 새 판정 공식이 아니라 이미 검증된 [getTenGod]의 결과값을
/// 유형별로 분류해 안내 문구만 붙이는 것뿐이다.
YearlyRelationshipFortuneResult getYearlyRelationshipFortune(
  SajuResult saju, {
  required int year,
}) {
  final (yGan, yZhi) = _sewoonGanZhi(year);
  final dayGan = saju.dayMaster.gan;
  final gods = {getTenGod(dayGan, yGan), getTenGod(dayGan, yZhi)};
  final label = _yearLabel(year, yGan, yZhi);

  if (gods.intersection({'비견', '겁재'}).isNotEmpty) {
    return YearlyRelationshipFortuneResult(
      title: '동료·또래와의 교류가 활발해지는 해',
      overall:
          '$label 세운에 비겁 기운이 들어와, 동료·친구·경쟁자 같은 또래 관계의 '
          '교류가 활발해질 수 있는 해예요.',
      advice: '함께 일할 땐 역할을 분명히 나누면 불필요한 마찰을 줄일 수 있어요.',
    );
  }
  if (gods.intersection({'정인', '편인'}).isNotEmpty) {
    return YearlyRelationshipFortuneResult(
      title: '도움을 주고받는 인연이 이어지는 해',
      overall:
          '$label 세운에 인성 기운이 들어와, 스승·선배·후원자처럼 도움을 주는 '
          '인연을 만나기 좋은 해예요.',
      advice: '먼저 조언을 구하는 데 주저하지 않으면 좋은 인연으로 이어질 수 있어요.',
    );
  }
  if (gods.intersection({'편재', '정재'}).isNotEmpty) {
    return YearlyRelationshipFortuneResult(
      title: '실속 있는 관계가 두드러지는 해',
      overall:
          '$label 세운에 재성 기운이 들어와, 거래·이성 관계 등 실질적인 이익이 '
          '오가는 관계가 두드러질 수 있는 해예요.',
      advice: '관계에서 주고받는 균형을 신경 쓰면 오래가는 인연으로 이어져요.',
    );
  }
  if (gods.intersection({'편관', '정관'}).isNotEmpty) {
    return YearlyRelationshipFortuneResult(
      title: '윗사람·조직과의 관계가 중요한 해',
      overall:
          '$label 세운에 관성 기운이 들어와, 상사·기관 등 위계 관계에서 '
          '영향을 받기 쉬운 해예요.',
      advice: '예의와 기본을 지키면 윗사람의 신뢰를 얻기 좋은 시기예요.',
    );
  }
  // 남은 경우(식신/상관) — 소통·표현 기운.
  return YearlyRelationshipFortuneResult(
    title: '소통과 표현이 활발해지는 해',
    overall: '$label 세운에 식상 기운이 들어와, 사람들과의 대화와 표현이 활발해지는 해예요.',
    advice: '말이 많아지는 만큼, 중요한 자리에서는 한 번 더 생각하고 말하면 좋아요.',
  );
}

// ============================================================
// C10 — 올해 12개월 월별 (기존 getMonthlyFortune 12회 재사용)
// ============================================================

class YearlyMonthlyOverviewResult {
  const YearlyMonthlyOverviewResult({
    required this.overall,
    required this.monthlySummary,
  });

  final String overall;
  final List<String> monthlySummary;
}

/// D01(이달의 운세)이 이미 검증한 [getMonthlyFortune]을 1~12월 각각에
/// 대해 재호출한다 — 새 월운 계산 로직을 만들지 않는다.
YearlyMonthlyOverviewResult getYearlyMonthlyOverview(
  SajuResult saju,
  SajuFortuneRules rules, {
  required int year,
}) {
  final lines = <String>[];
  for (var month = 1; month <= 12; month++) {
    final r = getMonthlyFortune(saju, rules, year: year, month: month);
    final headline = r.title.isNotEmpty
        ? r.title
        : (r.overall.isNotEmpty ? r.overall : '흐름 정리 중');
    lines.add('$month월 (${r.monthGanZhi}) — $headline');
  }
  return YearlyMonthlyOverviewResult(
    overall: '$year년 12개월 전체 흐름을 월별 세운 십신 기준으로 정리했어요.',
    monthlySummary: lines,
  );
}
