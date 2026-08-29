/// [정통사주 69종 개인화 해석 엔진 — 1단계] SajuProfile 공통 조회 유틸.
///
/// 여러 [CategoryAnalyzer]가 반복적으로 필요로 하는 조회(십신 위치 전체
/// 나열, 특정 범주 개수, 특정 오행이 들어간 관계 찾기, 현재 대운/세운
/// 찾기 등)를 한 곳에 모아, 각 Analyzer가 매번 같은 순회 로직을 새로
/// 작성하지 않게 한다.
///
/// [절대 원칙] 이 파일은 새로운 계산을 하지 않는다 — [SajuProfile]에
/// 이미 채워진 값을 다른 형태로 "다시 읽는" 조회 헬퍼만 제공한다.
library;

import '../manseryeok/saju_profile.dart';
import '../saju_engine.dart' show ganElement;
import '../manseryeok/strength_engine.dart' show tenGodCategoryOf;

/// 십신 1개가 원국의 어느 위치에 있는지까지 포함한 조회 결과.
class TenGodOccurrence {
  const TenGodOccurrence({
    required this.tenGod,
    required this.category,
    required this.position,
    required this.characterHanja,
    required this.isHiddenStem,
    this.hiddenStemRole,
  });

  /// 십신 이름(비견/겁재/식신/상관/편재/정재/편관/정관/편인/정인).
  final String tenGod;

  /// 5대 범주(비겁/식상/재성/관살/인성).
  final String category;

  /// 위치(년간/월간/시간/년지/월지/일지/시지 — 일간 자신은 제외).
  final String position;

  /// 실제 글자(한자).
  final String characterHanja;

  /// 지장간에서 나온 것인지(vs 천간/지지 본기).
  final bool isHiddenStem;

  /// 지장간이면 '정기'|'중기'|'여기', 아니면 null.
  final String? hiddenStemRole;
}

/// [SajuProfile] 위에서 자주 쓰이는 조회를 제공하는 헬퍼.
class SajuProfileQuery {
  SajuProfileQuery(this.profile);

  final SajuProfile profile;

  /// 원국(천간 3개 + 지지 4개 본기) + 지장간(있으면) 전체의 십신을
  /// 위치 정보와 함께 나열한다. tenGods/hiddenStems가 모두 채워진(PHASE2
  /// 완료) 상태여야 완전한 결과가 나온다.
  List<TenGodOccurrence> allTenGodOccurrences() {
    final result = <TenGodOccurrence>[];
    final tenGods = profile.tenGods;
    if (tenGods != null) {
      const posLabel = {
        'year_gan': '년간',
        'month_gan': '월간',
        'hour_gan': '시간',
        'year_zhi': '년지',
        'month_zhi': '월지',
        'day_zhi': '일지',
        'hour_zhi': '시지',
      };
      final charByKey = <String, String>{
        'year_gan': profile.yearPillar.stemHanja,
        'month_gan': profile.monthPillar.stemHanja,
        'hour_gan': profile.hourPillar.stemHanja,
        'year_zhi': profile.yearPillar.branchHanja,
        'month_zhi': profile.monthPillar.branchHanja,
        'day_zhi': profile.dayPillar.branchHanja,
        'hour_zhi': profile.hourPillar.branchHanja,
      };
      for (final e in tenGods.entries) {
        final label = posLabel[e.key];
        if (label == null) continue;
        result.add(
          TenGodOccurrence(
            tenGod: e.value,
            category: tenGodCategoryOf(e.value),
            position: label,
            characterHanja: charByKey[e.key] ?? '',
            isHiddenStem: false,
          ),
        );
      }
    }

    final hidden = profile.hiddenStems;
    if (hidden != null) {
      const posLabel = {'year': '년지', 'month': '월지', 'day': '일지', 'hour': '시지'};
      for (final e in hidden.entries) {
        final label = posLabel[e.key];
        if (label == null) continue;
        for (final d in e.value.stems) {
          result.add(
            TenGodOccurrence(
              tenGod: d.tenGod,
              category: tenGodCategoryOf(d.tenGod),
              position: label,
              characterHanja: d.stemHanja,
              isHiddenStem: true,
              hiddenStemRole: d.role,
            ),
          );
        }
      }
    }
    return result;
  }

  /// 5대 범주(비겁/식상/재성/관살/인성) 각각의 개수(천간+지지 본기만,
  /// 지장간 제외 — [strength_engine.dart]의 [StrengthProfile] 산출과
  /// 동일 범위로 맞춰 일관성 유지).
  Map<String, int> tenGodCategoryCounts({bool includeHiddenStems = false}) {
    final counts = <String, int>{'비겁': 0, '식상': 0, '재성': 0, '관살': 0, '인성': 0};
    for (final occ in allTenGodOccurrences()) {
      if (!includeHiddenStems && occ.isHiddenStem) continue;
      counts[occ.category] = (counts[occ.category] ?? 0) + 1;
    }
    return counts;
  }

  /// 특정 범주(예: '재성')에 속하는 모든 occurrence.
  List<TenGodOccurrence> occurrencesOfCategory(
    String category, {
    bool includeHiddenStems = true,
  }) {
    return allTenGodOccurrences()
        .where(
          (o) =>
              o.category == category && (includeHiddenStems || !o.isHiddenStem),
        )
        .toList();
  }

  /// 특정 오행이 관련된 합충형파해 관계 전체.
  List<SajuRelationship> relationshipsInvolvingElement(String element) {
    final rels = profile.relationships ?? const [];
    return rels.where((r) {
      if (r.resultElement == element) return true;
      // resultElement가 없는 충/형/파/해/원진/귀문은 글자 오행으로 판정.
      for (final ch in r.characters) {
        final el = ganElement[ch]?.$1 ?? _zhiElementOf(ch);
        if (el == element) return true;
      }
      return false;
    }).toList();
  }

  /// 특정 타입(예: '지지충')의 관계 전체.
  List<SajuRelationship> relationshipsOfType(String type) {
    final rels = profile.relationships ?? const [];
    return rels.where((r) => r.type == type).toList();
  }

  /// 일간 오행.
  String get dayElement => ganElement[profile.dayPillar.stemHanja]!.$1;

  /// 용신 오행이 원국(천간+지지 본기)에 실제로 존재하는지.
  bool get yongsinRooted {
    final yongsin = profile.yongsin?.yongsin;
    if (yongsin == null || yongsin.isEmpty) return false;
    final total = profile.fiveElements?.totalCount[yongsin] ?? 0;
    return total > 0;
  }

  /// 기신 오행이 원국에 얼마나 강하게 존재하는지(개수).
  int get gisinCount {
    final gisin = profile.yongsin?.gisin;
    if (gisin == null || gisin.isEmpty) return 0;
    return profile.fiveElements?.totalCount[gisin] ?? 0;
  }

  /// [referenceDate]가 속한 대운 항목을 찾는다(Phase4AnalysisEngine과
  /// 동일한 탐색 로직 — 재구현이 아니라 조회 재사용).
  DaewoonEntry? currentDaewoon(DateTime referenceDate) {
    final list = profile.daewoon;
    if (list == null || list.isEmpty) return null;
    DaewoonEntry current = list.first;
    for (final d in list) {
      if (referenceDate.year >= d.startYear &&
          referenceDate.year < d.startYear + 10) {
        return d;
      }
      if (referenceDate.year >= d.startYear) {
        current = d;
      }
    }
    return current;
  }

  /// [referenceDate].year와 일치하는 세운 항목.
  SewoonEntry? currentSewoon(DateTime referenceDate) {
    final list = profile.sewoon;
    if (list == null) return null;
    for (final s in list) {
      if (s.year == referenceDate.year) return s;
    }
    return null;
  }

  /// 특정 대운 항목의 십신(천간/지지)이 [category](비겁/식상/재성/관살/
  /// 인성)에 속하는지.
  bool daewoonMatchesCategory(DaewoonEntry d, String category) {
    return tenGodCategoryOf(d.tenGodStem) == category ||
        tenGodCategoryOf(d.tenGodBranch) == category;
  }

  /// 용신 오행과 대운의 천간/지지 오행이 일치하는지(§ B08 getBestDaewoonPeriods
  /// 와 동일한 판정 방식 재사용).
  bool daewoonCarriesElement(DaewoonEntry d, String element) {
    if (element.isEmpty) return false;
    final stemEl = ganElement[d.pillar.stemHanja]?.$1;
    final branchEl = _zhiElementOf(d.pillar.branchHanja);
    return stemEl == element || branchEl == element;
  }
}

const Map<String, String> _zhiElementTable = {
  '子': '수',
  '丑': '토',
  '寅': '목',
  '卯': '목',
  '辰': '토',
  '巳': '화',
  '午': '화',
  '未': '토',
  '申': '금',
  '酉': '금',
  '戌': '토',
  '亥': '수',
};

String? _zhiElementOf(String zhi) => _zhiElementTable[zhi];
