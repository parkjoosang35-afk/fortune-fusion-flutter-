/// [정통사주 80종 · F03~F09/F10 특수 주제 그룹] 사업 아이템/창업·직장/
/// 이직 타이밍/부동산 매매 타이밍/투자 성향/결혼 적령기/자녀 출산 좋은
/// 해/유학·해외 진출운 계산 모듈.
///
/// B/C/D그룹과 마찬가지로 "원본 파이썬 이식"이 아니라 이번 세션에서
/// 신규 설계한 계산이다(사용자 최종 지시 §3 "F03~F08/F10 진행", 사용자
/// 승인 "응"; F09는 이후 재검토 라운드에서 추가 구현). F01/F02는 이미
/// A03/A04([getLifeWealth]/[getLifeCareer])를 재사용 중이다.
///
/// [F09 재검토 결론] "자녀 출산 좋은 해"는 A07([getLifeChildren])이 이미
/// 채택한 자녀성 배정(남=관성/여=식상, 자평명리 표준 관행)을 B05
/// ([getDaewoonLoveFlow] — 배우자성 대운 발동 타임라인)와 동일한 방식으로
/// 대운에 적용하면 새 판정 공식 없이 구현 가능하다고 판단해 구현
/// 대상으로 전환한다(§4 "구현 불가능하면 즉시 삭제, 가능하면 구현").
///
/// [절대 원칙] 새로운 명리 판정 공식을 만들지 않는다. 여기서 쓰는 모든
/// 판정은 이미 검증된 순수 함수/고정 테이블([getTenGod], [getGongmang],
/// [findSinsal], [ganElement]/[zhiElement])과, B02~B10이 이미 구현한
/// 대운×십신 복원 헬퍼([daewoonsWithTenGod], [getDaewoonCareerFlow],
/// [getDaewoonLoveFlow])를 조합·재사용하는 것뿐이다. 오행-업종 대응표
/// ([_businessItemsByElement])는 day_master_rules.json의 `career_fit`과
/// 동일한 성격의 "전통 오행-분야 고정 매핑표"이며, 등급 판정 로직도
/// A03([_assetStyleByVerdict])/A09 등 기존 A그룹이 채택한 "이미 계산된
/// 값에 고정 임계값을 적용해 등급을 매기는" 패턴을 그대로 따른다.
///
/// [건강 카테고리 아님] 이 파일의 카테고리는 건강 카테고리가 아니므로
/// §7 표현 제약과는 무관하다. 다만 F06(부동산)/F07(투자)/F08(결혼)은
/// `jeontong_eighty_matrix.dart`에서 이미 각각 finance/finance/relationship
/// disclaimer가 붙어 있어(수정 없음), 여기서는 "반드시/확정적" 같은
/// 단정 표현 대신 "~에 유리한 흐름" 수준의 완곡한 표현만 사용한다.
library;

import 'package:lunar/lunar.dart' show Solar;

import 'saju_daewoon_modules.dart' show DaewoonWithTenGod, daewoonsWithTenGod, getDaewoonCareerFlow, getDaewoonLoveFlow;
import 'saju_engine.dart';
import 'saju_interpreter.dart';

// ============================================================
// F03 — 맞는 사업 아이템 (일간 오행 기반 업종 추천)
// ============================================================

/// 전통 오행-업종 대응표. day_master_rules.json의 `career_fit`(일간 10종별
/// 직업 리스트)과 동일한 성격의 고정 매핑이나, "직업"이 아니라 "사업
/// 아이템"(자영업·창업 아이템)에 초점을 맞춘 별도 표다.
const Map<String, List<String>> _businessItemsByElement = {
  '목': ['교육·출판 콘텐츠', '원예·조경', '의류·패브릭', '목재·가구', '헬스케어·웰니스 스튜디오'],
  '화': ['IT·미디어 콘텐츠 제작', '요식업·카페', '뷰티·화장품', '엔터테인먼트 기획', '마케팅·광고 대행'],
  '토': ['부동산 중개', '농수산물 유통', '건설·인테리어', '요양·복지 서비스', '중고·경매 플랫폼'],
  '금': ['금융·재무 컨설팅', '기계·정밀 제조', '보석·액세서리', '법률·행정 서비스', 'IT 보안'],
  '수': ['물류·유통', '여행·숙박', '온라인 쇼핑몰', '수산업·양식', '주류·음료'],
};

class BusinessItemResult {
  const BusinessItemResult({
    required this.element,
    required this.items,
    required this.style,
    required this.message,
  });

  final String element;
  final List<String> items;
  final String style;
  final String message;
}

/// 일간 오행([SajuDayMaster.element])을 [_businessItemsByElement]에서
/// 조회하고, 이미 계산된 재성(편재/정재) 개수로 확장/전문성 성향을
/// 덧붙인다. 새 명리 판정 공식이 아니라 이미 계산된 값의 조회·분류다.
BusinessItemResult getBusinessItemFit(
  SajuResult saju,
  SajuFullInterpretation interp,
) {
  final element = saju.dayMaster.element;
  final items = _businessItemsByElement[element] ?? const [];
  final dist = interp.tenGodsAnalysis.distribution;
  final wealthCount = (dist['편재'] ?? 0) + (dist['정재'] ?? 0);

  final String style;
  if (wealthCount >= 2) {
    style = '적극 확장형 — 재성이 발달해 사업 확장·투자에 유리';
  } else if (wealthCount == 1) {
    style = '안정 운영형 — 무리한 확장보다 내실을 다지는 방식이 유리';
  } else {
    style = '전문성 기반형 — 재성이 약해 규모보다 전문성·기술력으로 승부하는 것이 유리';
  }

  return BusinessItemResult(
    element: element,
    items: items,
    style: style,
    message: '일간 오행($element) 기준으로 어울리는 사업 분야를 정리했어요. $style',
  );
}

// ============================================================
// F04 — 창업 vs 직장 (관성 유무·공망 확인)
// ============================================================

class CareerVsBusinessResult {
  const CareerVsBusinessResult({
    required this.officerCount,
    required this.gongmangHitsOfficer,
    required this.verdict,
    required this.message,
  });

  final int officerCount;
  final bool gongmangHitsOfficer;
  final String verdict;
  final String message;
}

/// 관성(정관/편관) 개수 + 관성이 자리한 지지가 공망(空亡)에 해당하는지
/// 조회한다. [getGongmang]이 원국 계산 시 이미 산출해 둔
/// [SajuResult.gongmang] 문자열("戌亥 (술해)" 형태)을 그대로 파싱해
/// 대조할 뿐, 새 공망 계산이 아니다.
CareerVsBusinessResult getCareerVsBusinessFit(
  SajuResult saju,
  SajuFullInterpretation interp,
) {
  final dist = interp.tenGodsAnalysis.distribution;
  final officerCount = (dist['정관'] ?? 0) + (dist['편관'] ?? 0);

  final gongmangZhis = saju.gongmang.length >= 2
      ? {saju.gongmang.substring(0, 1), saju.gongmang.substring(1, 2)}
      : <String>{};
  final dayGan = saju.dayMaster.gan;
  var officerOnGongmang = false;
  for (final key in ['year', 'month', 'hour']) {
    final zhi = saju.pillars[key]!.zhi;
    if (gongmangZhis.contains(zhi)) {
      final god = getTenGod(dayGan, zhi);
      if (god == '정관' || god == '편관') {
        officerOnGongmang = true;
      }
    }
  }

  final String verdict;
  final String message;
  if (officerCount == 0) {
    verdict = '창업·독립 적합형';
    message = '관성(조직·상사를 뜻하는 십신)이 원국에 없어, 조직에 얽매이기보다 '
        '스스로 결정하고 책임지는 창업·독립 사업이 잘 맞는 구조예요.';
  } else if (officerOnGongmang) {
    verdict = '창업·독립 고려형';
    message = '관성은 있지만 공망(空亡, ${saju.gongmang})에 걸려 있어, '
        '조직 소속의 안정감보다는 독립적인 활동에서 더 좋은 결과를 낼 수 있어요.';
  } else if (officerCount >= 2) {
    verdict = '조직·직장 적합형';
    message = '관성 $officerCount개가 힘 있게 자리 잡아, 조직 안에서 승진·안정적인 '
        '커리어를 쌓는 흐름이 유리한 구조예요.';
  } else {
    verdict = '균형형 — 상황에 따라 유연하게';
    message = '관성 $officerCount개로 무난한 수준이에요. 대운·세운의 흐름에 따라 '
        '조직 생활과 독립 사업 모두 고려해볼 수 있어요.';
  }

  return CareerVsBusinessResult(
    officerCount: officerCount,
    gongmangHitsOfficer: officerOnGongmang,
    verdict: verdict,
    message: message,
  );
}

// ============================================================
// F05 — 이직 타이밍 (관성 대운·세운 확인)
// ============================================================

/// [year] 세운 간지를 대표일(6/15) 기준으로 구한다 —
/// `saju_c_group_modules.dart`/`getDaewoonSewoonCombo()`와 완전히 동일한
/// 방식(신규 계산 방식 아님, 파일마다 로컬 재정의하는 기존 패턴을 따름).
(String gan, String zhi) _sewoonGanZhiF(int year) {
  final solar = Solar.fromYmd(year, 6, 15);
  final lunar = solar.getLunar();
  return (lunar.getYearGan(), lunar.getYearZhi());
}

const Set<String> _officerGodsF5 = {'편관', '정관'};

class JobChangeTimingResult {
  const JobChangeTimingResult({
    required this.currentDaewoonHit,
    required this.currentYearHit,
    required this.upcomingPeriods,
    required this.verdict,
    required this.message,
  });

  final bool currentDaewoonHit;
  final bool currentYearHit;
  final List<String> upcomingPeriods;
  final String verdict;
  final String message;
}

/// B03([getDaewoonCareerFlow])가 이미 계산한 대운별 관성 발동 타임라인을
/// 재사용하고, [year] 세운의 관성 발동 여부를 추가로 조회해 조합한다.
/// 새 판정 공식이 아니라 이미 검증된 [getTenGod] 결과를 대운·세운 각각에
/// 대해 조회하는 것뿐이다.
JobChangeTimingResult getJobChangeTiming(
  SajuResult saju, {
  required int year,
}) {
  final flow = getDaewoonCareerFlow(saju);
  final list = daewoonsWithTenGod(saju);
  final currentStart = saju.currentLuck?.startAge;
  final currentDaewoon = list.where((d) => d.luck.startAge == currentStart);
  final currentDaewoonHit = currentDaewoon.any(
    (d) => _officerGodsF5.contains(d.stemTenGod) || _officerGodsF5.contains(d.branchTenGod),
  );

  final dayGan = saju.dayMaster.gan;
  final (yGan, yZhi) = _sewoonGanZhiF(year);
  final currentYearHit =
      _officerGodsF5.contains(getTenGod(dayGan, yGan)) ||
      _officerGodsF5.contains(getTenGod(dayGan, yZhi));

  final upcoming = flow.shiftPeriods.where((p) {
    final age = int.tryParse(p.split('세').first);
    return age != null && (currentStart == null || age >= currentStart);
  }).toList();

  final String verdict;
  final String message;
  if (currentDaewoonHit && currentYearHit) {
    verdict = '지금이 이직 적기';
    message = '현재 대운과 올해 세운이 모두 관성을 발동시켜, 지금이 이직·전직을 '
        '실행하기에 좋은 흐름이에요.';
  } else if (currentDaewoonHit) {
    verdict = '대운상 이직 흐름은 있음, 시기 조율 필요';
    message = '현재 대운은 관성이 발동하는 흐름이지만 올해 세운은 그렇지 않아요. '
        '조급하게 서두르기보다 조건이 맞는 해를 기다려도 좋아요.';
  } else if (upcoming.isNotEmpty) {
    verdict = '${upcoming.first} 전후가 유력';
    message = '현재 대운에서는 관성이 뚜렷하지 않지만, ${upcoming.join(', ')} 시기에 '
        '관성이 발동해 이직·전직 기회가 열릴 수 있어요.';
  } else {
    verdict = '큰 변화보다 현재 자리에서 내실 다지기';
    message = '계산된 대운 범위 안에서는 관성이 뚜렷하게 발동하는 시기가 보이지 않아요. '
        '지금 자리에서 경력을 다지는 것이 더 유리할 수 있어요.';
  }

  return JobChangeTimingResult(
    currentDaewoonHit: currentDaewoonHit,
    currentYearHit: currentYearHit,
    upcomingPeriods: upcoming,
    verdict: verdict,
    message: message,
  );
}

// ============================================================
// F06 — 부동산 매매 타이밍 (토·재성 대운 확인)
// ============================================================

const Set<String> _wealthGodsF6 = {'편재', '정재'};

class RealEstateTimingResult {
  const RealEstateTimingResult({
    required this.timeline,
    required this.peakPeriods,
    required this.summary,
  });

  final List<String> timeline;
  final List<String> peakPeriods;
  final String summary;
}

/// B02([getDaewoonWealthFlow])와 동일한 방식으로, [daewoonsWithTenGod]가
/// 이미 복원한 대운별 오행/십신 값에서 토(土) 오행 + 재성(편재/정재)이
/// 동시에 발동하는 시기를 조회한다. 새 판정 공식이 아니다.
RealEstateTimingResult getRealEstateTiming(SajuResult saju) {
  final list = daewoonsWithTenGod(saju);
  final timeline = <String>[];
  final peaks = <String>[];
  for (final d in list) {
    final label = _f06Label(d);
    final earthHit = d.stemElement == '토' || d.branchElement == '토';
    final wealthHit =
        _wealthGodsF6.contains(d.stemTenGod) || _wealthGodsF6.contains(d.branchTenGod);
    if (earthHit && wealthHit) {
      timeline.add('$label — 토(土) 기운 + 재성 동시 발동: 부동산 관련 거래에 유리한 흐름');
      peaks.add(label);
    } else if (earthHit) {
      timeline.add('$label — 토(土) 기운 발동: 부동산에 대한 관심이 커질 수 있는 시기');
    } else {
      timeline.add('$label — 토·재성 미발동: 부동산보다 다른 재테크가 유리한 시기');
    }
  }
  final summary = peaks.isEmpty
      ? '계산된 대운 범위 안에서는 토 기운과 재성이 함께 발동하는 시기가 뚜렷하지 않아요. '
          '큰 거래보다 시장 상황을 지켜보며 신중하게 접근하면 좋아요.'
      : '${peaks.join(', ')} 시기에 토 기운과 재성이 함께 발동해, 부동산 매매·투자에 '
          '비교적 유리한 흐름이 만들어질 수 있어요.';
  return RealEstateTimingResult(timeline: timeline, peakPeriods: peaks, summary: summary);
}

String _f06Label(DaewoonWithTenGod d) =>
    '${d.luck.startAge}세(${d.luck.startYear}년, ${d.luck.ganZhiKr})';

// ============================================================
// F07 — 투자 성향 분석 (편재(공격)/정재(방어) 비율)
// ============================================================

class InvestmentStyleResult {
  const InvestmentStyleResult({
    required this.aggressiveCount,
    required this.defensiveCount,
    required this.style,
    required this.message,
  });

  final int aggressiveCount;
  final int defensiveCount;
  final String style;
  final String message;
}

/// 이미 계산된 십신 분포([TenGodsInterpretation.distribution])에서
/// 편재(공격형 재물)/정재(방어형 재물) 개수 비율만 조회한다. 새 판정
/// 공식이 아니다.
InvestmentStyleResult getInvestmentStyle(SajuFullInterpretation interp) {
  final dist = interp.tenGodsAnalysis.distribution;
  final aggressive = dist['편재'] ?? 0;
  final defensive = dist['정재'] ?? 0;

  final String style;
  final String message;
  if (aggressive == 0 && defensive == 0) {
    style = '재성 미발현형 — 투자보다 안정 소득 중심';
    message = '편재·정재가 모두 없어, 투자보다는 안정적인 소득 관리에 집중하는 편이 잘 맞아요. '
        '투자를 하더라도 소액·분산 위주로 접근하는 것이 좋아요.';
  } else if (aggressive > defensive) {
    style = '공격형 투자자 — 편재 우세';
    message = '편재($aggressive) > 정재($defensive) — 기회를 빠르게 포착하는 공격적 투자 '
        '성향이에요. 주식·사업성 투자에 강점이 있지만, 리스크 관리 습관을 함께 갖추면 좋아요.';
  } else if (defensive > aggressive) {
    style = '방어형 투자자 — 정재 우세';
    message = '정재($defensive) > 편재($aggressive) — 꾸준하고 안정적인 재테크를 선호하는 '
        '성향이에요. 예적금·우량자산 중심의 장기 투자가 잘 맞아요.';
  } else {
    style = '균형형 투자자 — 편재·정재 균형';
    message = '편재·정재가 $aggressive:$defensive로 균형을 이뤄, 안정 자산과 공격적 투자를 '
        '적절히 배분하는 포트폴리오 전략이 잘 맞아요.';
  }

  return InvestmentStyleResult(
    aggressiveCount: aggressive,
    defensiveCount: defensive,
    style: style,
    message: message,
  );
}

// ============================================================
// F08 — 결혼 적령기 (재/관성 대운 확인)
// ============================================================

class MarriageTimingResult {
  const MarriageTimingResult({
    required this.spouseGodLabel,
    required this.activePeriods,
    required this.nearestPeriod,
    required this.message,
  });

  final String spouseGodLabel;
  final List<String> activePeriods;
  final String? nearestPeriod;
  final String message;
}

/// B05([getDaewoonLoveFlow])가 이미 계산한 배우자성(남=재성/여=관성)
/// 발동 대운 타임라인을 그대로 재사용해, 그 중 현재 나이([SajuResult.currentAge])
/// 이후 가장 가까운 시기를 "적령기"로 안내한다. 새 판정 공식이 아니다.
MarriageTimingResult getMarriageTiming(SajuResult saju) {
  final flow = getDaewoonLoveFlow(saju);
  final currentAge = saju.currentAge;
  final future = flow.activePeriods.where((p) {
    final age = int.tryParse(p.split('세').first);
    return age != null && age >= currentAge;
  }).toList();
  final nearest = future.isNotEmpty
      ? future.first
      : (flow.activePeriods.isNotEmpty ? flow.activePeriods.first : null);

  final godLabel = saju.gender == 'male' ? '재성(배우자성)' : '관성(배우자성)';
  final String message;
  if (nearest == null) {
    message = '계산된 대운 범위 안에서는 $godLabel이 뚜렷하게 발동하는 시기가 보이지 않아요. '
        '조급해하기보다 자연스러운 인연의 흐름을 기다려도 좋아요.';
  } else if (future.isNotEmpty) {
    message = '$nearest 시기에 $godLabel이 발동해, 결혼 인연이 무르익기 좋은 흐름이에요.';
  } else {
    message = '$godLabel 발동 시기($nearest)는 이미 지났어요. 앞으로는 대운·세운의 흐름을 '
        '함께 참고하며 인연을 준비하면 좋아요.';
  }

  return MarriageTimingResult(
    spouseGodLabel: godLabel,
    activePeriods: flow.activePeriods,
    nearestPeriod: nearest,
    message: message,
  );
}

// ============================================================
// F10 — 유학·해외 진출운 (역마·편재·수 오행 확인)
// ============================================================

class OverseasFortuneResult {
  const OverseasFortuneResult({
    required this.hasYeokma,
    required this.wealthCount,
    required this.waterCount,
    required this.score,
    required this.style,
    required this.message,
  });

  final bool hasYeokma;
  final int wealthCount;
  final int waterCount;
  final int score;
  final String style;
  final String message;
}

/// 원국에 이미 판정된 역마([findSinsal] 결과가 [SajuResult.sinsal]에
/// '驛馬(역마)' 형태로 포함) + 편재 개수 + 수(水) 오행 개수, 3가지를
/// 조회해 단순 카운트로 등급을 매긴다. 새 판정 공식이 아니라 이미 계산된
/// 세 값을 조합 조회하는 것뿐이다.
OverseasFortuneResult getOverseasFortune(
  SajuResult saju,
  SajuFullInterpretation interp,
) {
  final hasYeokma = saju.sinsal.any((s) => s.startsWith('驛馬'));
  final dist = interp.tenGodsAnalysis.distribution;
  final wealthCount = dist['편재'] ?? 0;
  final waterCount = saju.fiveElementsCount['수'] ?? 0;

  var score = 0;
  if (hasYeokma) score += 1;
  if (wealthCount >= 1) score += 1;
  if (waterCount >= 2) score += 1;

  final String style;
  final String message;
  if (score >= 3) {
    style = '해외 진출 최적형';
    message = '역마(驛馬)를 갖추고, 편재($wealthCount)와 수(水, $waterCount) 기운까지 '
        '고르게 있어, 유학·해외 진출에 매우 유리한 흐름이에요.';
  } else if (score == 2) {
    style = '해외 인연 있음형';
    message = '역마·편재·수 오행 중 2가지 조건을 갖춰, 기회가 주어지면 해외 활동에서도 '
        '좋은 성과를 낼 수 있는 흐름이에요.';
  } else if (score == 1) {
    style = '국내외 병행형';
    message = '해외 진출 관련 기운이 일부 있어, 무리하지 않는 선에서 해외 경험을 '
        '시도해보는 것도 좋은 선택이 될 수 있어요.';
  } else {
    style = '국내 활동 중심형';
    message = '역마·편재·수 오행 조건이 뚜렷하지 않아, 해외보다는 국내에서 기반을 '
        '다지는 흐름이 더 잘 맞을 수 있어요.';
  }

  return OverseasFortuneResult(
    hasYeokma: hasYeokma,
    wealthCount: wealthCount,
    waterCount: waterCount,
    score: score,
    style: style,
    message: message,
  );
}

// ============================================================
// F09 — 자녀 출산 좋은 해 (자녀성 대운 발동 확인)
// ============================================================

const Set<String> _childGodsMale = {'정관', '편관'};
const Set<String> _childGodsFemale = {'식신', '상관'};

class GoodChildbirthTimingResult {
  const GoodChildbirthTimingResult({
    required this.childGodLabel,
    required this.timeline,
    required this.activePeriods,
    required this.summary,
  });

  final String childGodLabel;
  final List<String> timeline;
  final List<String> activePeriods;
  final String summary;
}

/// A07([getLifeChildren])이 이미 채택한 자녀성 배정(남=관성/여=식상)을
/// B05([getDaewoonLoveFlow])와 동일한 방식으로 대운 목록에 적용해, 자녀성이
/// 발동하는 대운 시기를 조회한다. 새 판정 공식이 아니라 이미 검증된
/// [getTenGod] 재호출 결과([daewoonsWithTenGod])에 A07의 자녀성 집합만
/// 대입해 조합하는 것뿐이다.
GoodChildbirthTimingResult getGoodChildbirthTiming(SajuResult saju) {
  final list = daewoonsWithTenGod(saju);
  final targetGods = saju.gender == 'male' ? _childGodsMale : _childGodsFemale;
  final godLabel = saju.gender == 'male' ? '관성(자녀성)' : '식상(자녀성)';

  final timeline = <String>[];
  final active = <String>[];
  for (final d in list) {
    final label = '${d.luck.startAge}세(${d.luck.startYear}년, ${d.luck.ganZhiKr})';
    final stemHit = targetGods.contains(d.stemTenGod);
    final branchHit = targetGods.contains(d.branchTenGod);
    if (stemHit || branchHit) {
      timeline.add('$label — $godLabel 발동: 자녀 인연·출산 관련 경사가 두드러질 수 있는 흐름');
      active.add(label);
    } else {
      timeline.add('$label — $godLabel 미발동: 특별한 변화 없이 안정적으로 이어지는 시기');
    }
  }

  final summary = active.isEmpty
      ? '계산된 대운 범위 안에서는 $godLabel이 뚜렷하게 발동하는 시기가 보이지 않아요. '
          '자녀 계획은 시기보다 개인 상황에 맞춰 결정하는 것이 좋아요.'
      : '${active.join(', ')} 시기에 $godLabel이 발동해 자녀 인연·출산 관련 흐름이 '
          '좋아질 수 있어요.';

  return GoodChildbirthTimingResult(
    childGodLabel: godLabel,
    timeline: timeline,
    activePeriods: active,
    summary: summary,
  );
}
