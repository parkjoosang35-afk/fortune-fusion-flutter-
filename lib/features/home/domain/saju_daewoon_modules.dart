/// [정통사주 80종 · B02~B10 대운 그룹] 대운(大運) 상세 분석 모듈.
///
/// A07~A10과 마찬가지로 원본 파이썬 포트가 아니라 이번 세션에서 신규
/// 설계한 계산이다(사용자 최종 지시 §3 "B02~B10부터 계속 진행"). PHASE4가
/// 이미 계산한 대운 목록([SajuResult.luckPillars] — 레거시 어댑터를 거치며
/// 십신이 유실되므로 [getTenGod]을 재호출해 복원, `saju_result_adapter.dart`의
/// "예외: getGongmang() 재호출" 패턴과 동일한 재사용 방식)과, PHASE3가
/// 계산한 용신/기신([SajuProfile.yongsin], `JeontongCalcContext.profile`을
/// 통해 노출)을 기반으로 대운별 재물/직업/건강/애정 흐름, 대운 전환기,
/// 다음 대운, 최고/최악 대운 시기, 대운×세운 조합을 판정한다.
///
/// [절대 원칙] 새로운 명리 판정 공식을 만들지 않는다. 여기서 쓰는 모든
/// 판정은 이미 검증된 순수 함수/고정 테이블([getTenGod], [ganElement],
/// [zhiElement], [sheng], [ke])을 조합하거나, PHASE3가 이미 계산해 둔
/// 용신/기신 값을 그대로 조회하는 것뿐이다.
///
/// [건강 표현 원칙 — 사용자 확정 지시 §7] B04는 "이 병에 걸립니다" 같은
/// 의학적 진단 표현을 절대 쓰지 않는다. "사주 오행의 균형을 기준으로 한
/// 생활 참고 정보"로만 표현한다.
library;

import 'package:lunar/lunar.dart' show Solar;

import 'manseryeok/saju_profile.dart' show SajuProfile;
import 'saju_engine.dart';

// ============================================================
// 공통 — 대운 목록 + 십신 복원
// ============================================================

/// 대운 1건 + 그 대운의 십신(간/지)·오행 — [getTenGod] 재호출로 복원.
class DaewoonWithTenGod {
  const DaewoonWithTenGod({
    required this.luck,
    required this.stemTenGod,
    required this.branchTenGod,
    required this.stemElement,
    required this.branchElement,
  });

  final SajuLuckPillar luck;
  final String stemTenGod;
  final String branchTenGod;
  final String stemElement;
  final String branchElement;
}

/// [saju.luckPillars]의 각 항목에 대해 [getTenGod]을 재호출해 십신을
/// 복원한다. 새 계산이 아니라 "이미 검증된 순수 함수의 재사용"이다
/// (saju_result_adapter.dart의 getGongmang() 재호출과 동일 원칙) — 대운
/// 간지 자체는 PHASE4([DaewoonEngine])가 이미 계산해 둔 값을 그대로 쓴다.
List<DaewoonWithTenGod> daewoonsWithTenGod(SajuResult saju) {
  final dayGan = saju.dayMaster.gan;
  return [
    for (final lp in saju.luckPillars)
      if (lp.ganZhi.length >= 2)
        DaewoonWithTenGod(
          luck: lp,
          stemTenGod: getTenGod(dayGan, lp.ganZhi.substring(0, 1)),
          branchTenGod: getTenGod(dayGan, lp.ganZhi.substring(1, 2)),
          stemElement: ganElement[lp.ganZhi.substring(0, 1)]!.$1,
          branchElement: zhiElement[lp.ganZhi.substring(1, 2)]!.$1,
        ),
  ];
}

String _label(SajuLuckPillar lp) => '${lp.startAge}세(${lp.startYear}년, ${lp.ganZhiKr})';

// ============================================================
// B02 — 대운별 재물 흐름
// ============================================================

class DaewoonWealthFlowResult {
  const DaewoonWealthFlowResult({
    required this.timeline,
    required this.peakPeriods,
    required this.summary,
  });

  final List<String> timeline;
  final List<String> peakPeriods;
  final String summary;
}

const Set<String> _wealthGods = {'편재', '정재'};

/// 대운별로 재성(편재/정재)이 발동하는 시기를 조회한다.
DaewoonWealthFlowResult getDaewoonWealthFlow(SajuResult saju) {
  final list = daewoonsWithTenGod(saju);
  final timeline = <String>[];
  final peaks = <String>[];
  for (final d in list) {
    final label = _label(d.luck);
    final stemHit = _wealthGods.contains(d.stemTenGod);
    final branchHit = _wealthGods.contains(d.branchTenGod);
    if (stemHit || branchHit) {
      final tag = stemHit ? d.stemTenGod : d.branchTenGod;
      timeline.add('$label — $tag 발동: 재물 활동이 활발해지는 흐름');
      peaks.add(label);
    } else {
      timeline.add('$label — 재성 미발동: 안정적 관리가 중요한 시기');
    }
  }
  final summary = peaks.isEmpty
      ? '계산된 대운 범위 안에서는 재성이 뚜렷하게 발동하는 시기가 보이지 않아요. 꾸준한 저축과 관리가 핵심이에요.'
      : '${peaks.join(', ')} 시기에 재성이 발동해 재물 활동이 활발해질 수 있어요.';
  return DaewoonWealthFlowResult(timeline: timeline, peakPeriods: peaks, summary: summary);
}

// ============================================================
// B03 — 대운별 직업 변화
// ============================================================

class DaewoonCareerFlowResult {
  const DaewoonCareerFlowResult({
    required this.timeline,
    required this.shiftPeriods,
    required this.summary,
  });

  final List<String> timeline;
  final List<String> shiftPeriods;
  final String summary;
}

const Set<String> _officerGods = {'편관', '정관'};

/// 대운별로 관성(편관/정관)이 발동하는 시기를 조회한다.
DaewoonCareerFlowResult getDaewoonCareerFlow(SajuResult saju) {
  final list = daewoonsWithTenGod(saju);
  final timeline = <String>[];
  final shifts = <String>[];
  for (final d in list) {
    final label = _label(d.luck);
    final stemHit = _officerGods.contains(d.stemTenGod);
    final branchHit = _officerGods.contains(d.branchTenGod);
    if (stemHit || branchHit) {
      final tag = stemHit ? d.stemTenGod : d.branchTenGod;
      timeline.add('$label — $tag 발동: 승진·이직·책임 확대 등 직업적 변화 가능성이 커지는 흐름');
      shifts.add(label);
    } else {
      timeline.add('$label — 관성 미발동: 현재 자리에서 안정적으로 다지는 시기');
    }
  }
  final summary = shifts.isEmpty
      ? '계산된 대운 범위 안에서는 관성이 뚜렷하게 발동하는 시기가 보이지 않아요. 큰 변화보다 내실을 다지는 흐름이에요.'
      : '${shifts.join(', ')} 시기에 관성이 발동해 직업·직책 변화 가능성이 커질 수 있어요.';
  return DaewoonCareerFlowResult(timeline: timeline, shiftPeriods: shifts, summary: summary);
}

// ============================================================
// B04 — 대운별 건강 변화(오행 편중, 생활 참고 정보)
// ============================================================

class DaewoonHealthFlowResult {
  const DaewoonHealthFlowResult({
    required this.timeline,
    required this.cautionPeriods,
    required this.summary,
  });

  final List<String> timeline;
  final List<String> cautionPeriods;
  final String summary;
}

/// 대운별로 원국의 오행 편중(이미 3개 이상인 오행)을 더 강화하는 시기를
/// 조회한다.
///
/// [표현 원칙] 의학적 진단이 아니라 "사주 오행의 균형을 기준으로 한 생활
/// 참고 정보"로만 안내한다(사용자 확정 지시 §7).
DaewoonHealthFlowResult getDaewoonHealthFlow(SajuResult saju) {
  final list = daewoonsWithTenGod(saju);
  final dominant = saju.fiveElementsCount.entries
      .where((e) => e.value >= 3)
      .map((e) => e.key)
      .toSet();

  final timeline = <String>[];
  final cautions = <String>[];
  for (final d in list) {
    final label = _label(d.luck);
    final elements = {d.stemElement, d.branchElement};
    final hit = elements.intersection(dominant);
    if (hit.isNotEmpty) {
      timeline.add('$label — ${hit.join('·')} 기운이 더해져 원국의 오행 편중이 더 강해질 수 있는 시기');
      cautions.add(label);
    } else {
      timeline.add('$label — 원국의 오행 균형에 큰 영향을 주지 않는 시기');
    }
  }

  final summary = cautions.isEmpty
      ? '계산된 대운 범위 안에서는 원국의 오행 편중을 더 강화하는 시기가 보이지 않아요. '
          '전반적으로 무난한 생활 관리가 가능한 흐름이에요.'
      : '${cautions.join(', ')} 시기에는 이미 원국에 많은 오행이 더욱 강해지는 흐름이에요. '
          '이 시기에는 평소보다 생활 관리(휴식·규칙적인 생활)에 조금 더 신경 쓰면 좋아요. '
          '(※ 사주 오행의 균형을 기준으로 한 생활 참고 정보이며, 의학적 진단이 아니에요.)';
  return DaewoonHealthFlowResult(timeline: timeline, cautionPeriods: cautions, summary: summary);
}

// ============================================================
// B05 — 대운별 애정 변화
// ============================================================

class DaewoonLoveFlowResult {
  const DaewoonLoveFlowResult({
    required this.timeline,
    required this.activePeriods,
    required this.summary,
  });

  final List<String> timeline;
  final List<String> activePeriods;
  final String summary;
}

/// 대운별로 배우자성(남=재성, 여=관성)이 발동하는 시기를 조회한다.
/// (getLifeLove()가 이미 채택한 "남=재성(처)/여=관성(부)" 배정과 동일.)
DaewoonLoveFlowResult getDaewoonLoveFlow(SajuResult saju) {
  final list = daewoonsWithTenGod(saju);
  final targetGods = saju.gender == 'male' ? _wealthGods : _officerGods;
  final godLabel = saju.gender == 'male' ? '재성(배우자성)' : '관성(배우자성)';

  final timeline = <String>[];
  final active = <String>[];
  for (final d in list) {
    final label = _label(d.luck);
    final stemHit = targetGods.contains(d.stemTenGod);
    final branchHit = targetGods.contains(d.branchTenGod);
    if (stemHit || branchHit) {
      timeline.add('$label — $godLabel 발동: 이성 인연·관계 변화가 활발해질 수 있는 흐름');
      active.add(label);
    } else {
      timeline.add('$label — $godLabel 미발동: 기존 관계가 안정적으로 이어지는 시기');
    }
  }

  final summary = active.isEmpty
      ? '계산된 대운 범위 안에서는 $godLabel이 뚜렷하게 발동하는 시기가 보이지 않아요.'
      : '${active.join(', ')} 시기에 $godLabel이 발동해 인연·관계에 변화가 생길 수 있어요.';
  return DaewoonLoveFlowResult(timeline: timeline, activePeriods: active, summary: summary);
}

// ============================================================
// B06 — 대운 전환기 주의사항
// ============================================================

class DaewoonTransitionResult {
  const DaewoonTransitionResult({
    required this.timeline,
    required this.cautionWindows,
    required this.summary,
  });

  final List<String> timeline;
  final List<String> cautionWindows;
  final String summary;
}

/// 대운이 바뀔 때 직전 대운과 오행이 상극(相剋) 관계인 전환기를 찾는다.
/// [sheng]/[ke]는 이미 검증된 고정 오행 상생상극표를 그대로 재사용한다.
DaewoonTransitionResult getDaewoonTransitionCautions(SajuResult saju) {
  final list = daewoonsWithTenGod(saju);
  final dayElement = ganElement[saju.dayMaster.gan]!.$1;

  final timeline = <String>[];
  final cautions = <String>[];
  String prevElement = dayElement; // 첫 대운 이전 기준선 = 일간 오행.
  for (final d in list) {
    final label = _label(d.luck);
    final nextElement = d.branchElement;
    final String relation;
    if (prevElement == nextElement) {
      relation = '직전 흐름과 오행이 같아 비교적 완만한 전환';
    } else if (ke[prevElement] == nextElement || ke[nextElement] == prevElement) {
      relation = '직전 흐름과 오행이 상극(剋) 관계 — 전환기 전후 3년은 변화 체감이 클 수 있음';
      cautions.add('$label 전후 3년');
    } else {
      relation = '직전 흐름과 오행이 상생(生) 관계 — 비교적 순조로운 전환';
    }
    timeline.add('$label — $relation');
    prevElement = nextElement;
  }

  final summary = cautions.isEmpty
      ? '대운 전환이 전반적으로 완만하게 이어지는 흐름이에요.'
      : '${cautions.join(', ')}는 오행 기운이 크게 바뀌는 전환기예요. 이 시기 전후로는 '
          '큰 결정보다 안정적인 관리에 집중하면 좋아요.';
  return DaewoonTransitionResult(timeline: timeline, cautionWindows: cautions, summary: summary);
}

// ============================================================
// B07 — 다음 대운 미리보기
// ============================================================

class DaewoonNextPreviewResult {
  const DaewoonNextPreviewResult({
    required this.hasNext,
    this.startAge,
    this.startYear,
    this.ganZhiKr,
    this.tenGods = const [],
    required this.message,
  });

  final bool hasNext;
  final int? startAge;
  final int? startYear;
  final String? ganZhiKr;
  final List<String> tenGods;
  final String message;
}

/// 현재 대운(saju.currentLuck) 다음에 오는 대운을 조회한다.
DaewoonNextPreviewResult getNextDaewoonPreview(SajuResult saju) {
  final list = daewoonsWithTenGod(saju);
  final currentStart = saju.currentLuck?.startAge;

  DaewoonWithTenGod? next;
  for (final d in list) {
    if (currentStart == null || d.luck.startAge > currentStart) {
      next = d;
      break;
    }
  }

  if (next == null) {
    return const DaewoonNextPreviewResult(
      hasNext: false,
      message: '다음 대운 정보가 없어요(이미 계산된 대운 범위의 마지막이에요).',
    );
  }

  final tags = [next.stemTenGod, next.branchTenGod];
  return DaewoonNextPreviewResult(
    hasNext: true,
    startAge: next.luck.startAge,
    startYear: next.luck.startYear,
    ganZhiKr: next.luck.ganZhiKr,
    tenGods: tags,
    message: '${next.luck.startAge}세(${next.luck.startYear}년)부터 ${next.luck.ganZhiKr} 대운이 시작돼요. '
        '이 대운의 십신은 ${tags.join('/')}이에요.',
  );
}

// ============================================================
// B08/B09 — 인생 최고/최악 대운 시기(용신/기신 기준)
// ============================================================

class DaewoonBestWorstResult {
  const DaewoonBestWorstResult({required this.periods, required this.summary});

  final List<String> periods;
  final String summary;
}

/// [profile]은 PHASE3([Phase3AnalysisEngine])가 이미 계산한 용신/기신을
/// 그대로 조회하기 위한 참조([JeontongCalcContext.profile]). 여기서 새로
/// 용신을 계산하지 않는다 — null이면(레거시 경로 등) 판단 불가로 안내한다.
DaewoonBestWorstResult getBestDaewoonPeriods(SajuResult saju, SajuProfile? profile) {
  final yongsinEl = profile?.yongsin?.yongsin;
  if (yongsinEl == null || yongsinEl.isEmpty) {
    return const DaewoonBestWorstResult(
      periods: [],
      summary: '용신 정보를 확인할 수 없어 최고 대운 시기를 판단하기 어려워요.',
    );
  }
  final list = daewoonsWithTenGod(saju);
  final matches = list.where(
    (d) => d.stemElement == yongsinEl || d.branchElement == yongsinEl,
  );
  final periods = matches.map((d) => _label(d.luck)).toList();
  final summary = periods.isEmpty
      ? '계산된 대운 범위 안에서는 용신($yongsinEl) 기운이 뚜렷하게 들어오는 시기가 보이지 않아요.'
      : '${periods.join(', ')} 시기는 용신($yongsinEl) 기운이 들어와 전반적으로 순조로운 흐름을 '
          '기대할 수 있는 대운이에요.';
  return DaewoonBestWorstResult(periods: periods, summary: summary);
}

DaewoonBestWorstResult getWorstDaewoonPeriods(SajuResult saju, SajuProfile? profile) {
  final gisinEl = profile?.yongsin?.gisin;
  if (gisinEl == null || gisinEl.isEmpty) {
    return const DaewoonBestWorstResult(
      periods: [],
      summary: '기신 정보를 확인할 수 없어 최악 대운 시기를 판단하기 어려워요.',
    );
  }
  final list = daewoonsWithTenGod(saju);
  final matches = list.where(
    (d) => d.stemElement == gisinEl || d.branchElement == gisinEl,
  );
  final periods = matches.map((d) => _label(d.luck)).toList();
  final summary = periods.isEmpty
      ? '계산된 대운 범위 안에서는 기신($gisinEl) 기운이 뚜렷하게 들어오는 시기가 보이지 않아요.'
      : '${periods.join(', ')} 시기는 기신($gisinEl) 기운이 들어와 다소 신중한 관리가 필요한 대운이에요. '
          '큰 결정보다는 안정에 무게를 두면 좋아요.';
  return DaewoonBestWorstResult(periods: periods, summary: summary);
}

// ============================================================
// B10 — 대운×세운 조합
// ============================================================

class DaewoonSewoonComboResult {
  const DaewoonSewoonComboResult({
    required this.daewoonGanZhiKr,
    required this.daewoonTenGods,
    required this.sewoonGanZhiKr,
    required this.sewoonTenGods,
    required this.synergy,
    required this.message,
  });

  final String daewoonGanZhiKr;
  final List<String> daewoonTenGods;
  final String sewoonGanZhiKr;
  final List<String> sewoonTenGods;
  final String synergy;
  final String message;
}

/// 현재 대운([saju.currentLuck])과 [year] 세운의 십신을 대조해 시너지를
/// 판정한다. 세운 간지는 `saju_fortune_modules.dart`의 `getYearFortune()`과
/// 동일한 방식(대표일 6/15 기준)으로 구한다 — 새 계산 방식 도입 아님.
DaewoonSewoonComboResult getDaewoonSewoonCombo(SajuResult saju, {required int year}) {
  final dayGan = saju.dayMaster.gan;
  final solar = Solar.fromYmd(year, 6, 15);
  final lunar = solar.getLunar();
  final yGan = lunar.getYearGan();
  final yZhi = lunar.getYearZhi();
  final sewoonStemGod = getTenGod(dayGan, yGan);
  final sewoonBranchGod = getTenGod(dayGan, yZhi);
  final sewoonGanZhiKr = '$yGan$yZhi (${ganKr[yGan]}${zhiKr[yZhi]})';

  final currentLuck = saju.currentLuck;
  if (currentLuck == null || currentLuck.ganZhi.length < 2) {
    return DaewoonSewoonComboResult(
      daewoonGanZhiKr: '',
      daewoonTenGods: const [],
      sewoonGanZhiKr: sewoonGanZhiKr,
      sewoonTenGods: [sewoonStemGod, sewoonBranchGod],
      synergy: '판단 불가',
      message: '현재 대운 정보가 없어 대운×세운 조합을 판단하기 어려워요.',
    );
  }

  final dStem = currentLuck.ganZhi.substring(0, 1);
  final dBranch = currentLuck.ganZhi.substring(1, 2);
  final daewoonStemGod = getTenGod(dayGan, dStem);
  final daewoonBranchGod = getTenGod(dayGan, dBranch);

  final overlap =
      {daewoonStemGod, daewoonBranchGod}.intersection({sewoonStemGod, sewoonBranchGod});
  final String synergy;
  final String message;
  if (overlap.isNotEmpty) {
    synergy = '십신 중첩(${overlap.join(', ')}) — 같은 기운이 두 배로 강조되는 해';
    message = '올해는 현재 대운의 기운과 같은 십신(${overlap.join(', ')})이 겹쳐서, '
        '대운이 상징하는 흐름이 더욱 뚜렷하게 나타날 수 있는 해예요.';
  } else {
    synergy = '십신 분산 — 대운과 세운이 서로 다른 기운을 더하는 해';
    message = '올해는 현재 대운($daewoonStemGod/$daewoonBranchGod)과는 다른 기운'
        '($sewoonStemGod/$sewoonBranchGod)이 함께 작용해, 다채로운 변화가 있을 수 있는 해예요.';
  }

  return DaewoonSewoonComboResult(
    daewoonGanZhiKr: currentLuck.ganZhiKr,
    daewoonTenGods: [daewoonStemGod, daewoonBranchGod],
    sewoonGanZhiKr: sewoonGanZhiKr,
    sewoonTenGods: [sewoonStemGod, sewoonBranchGod],
    synergy: synergy,
    message: message,
  );
}
