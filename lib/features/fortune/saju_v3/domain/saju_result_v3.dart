// 신통방통 - 정통사주 v3 팩트/69종 모델
// POST /saju/v3/facts · POST /saju/v3/categories69 · GET /saju/v3/categories 응답
//
// L1(팩트) + L2(69종 분석) 계층 대응. 기존 SajuResult(saju_result.dart)와 별개 타입이며
// 기존 모델은 전혀 변경하지 않는다 (하위호환).

import 'saju_result.dart' show Pillar, DayMaster, LuckPillar;

/// 지지별 지장간 [본기, 중기, 여기]
class ZhiQigan {
  final List<String> year;
  final List<String> month;
  final List<String> day;
  final List<String> hour;

  const ZhiQigan({required this.year, required this.month, required this.day, required this.hour});

  factory ZhiQigan.fromJson(Map<String, dynamic> j) => ZhiQigan(
        year: List<String>.from(j['year'] ?? []),
        month: List<String>.from(j['month'] ?? []),
        day: List<String>.from(j['day'] ?? []),
        hour: List<String>.from(j['hour'] ?? []),
      );
}

/// 원국 지지·천간 관계 (합·충·형·파·해·원진)
class Relations {
  final List<String> liuhe;
  final List<String> sanhe;
  final List<String> sanheHalf;
  final List<String> chong;
  final List<String> xing;
  final List<String> xingSelf;
  final List<String> po;
  final List<String> hai;
  final List<String> yuanjin;
  final List<String> ganHe;

  const Relations({
    required this.liuhe, required this.sanhe, required this.sanheHalf,
    required this.chong, required this.xing, required this.xingSelf,
    required this.po, required this.hai, required this.yuanjin, required this.ganHe,
  });

  factory Relations.fromJson(Map<String, dynamic> j) => Relations(
        liuhe: List<String>.from(j['liuhe'] ?? []),
        sanhe: List<String>.from(j['sanhe'] ?? []),
        sanheHalf: List<String>.from(j['sanhe_half'] ?? []),
        chong: List<String>.from(j['chong'] ?? []),
        xing: List<String>.from(j['xing'] ?? []),
        xingSelf: List<String>.from(j['xing_self'] ?? []),
        po: List<String>.from(j['po'] ?? []),
        hai: List<String>.from(j['hai'] ?? []),
        yuanjin: List<String>.from(j['yuanjin'] ?? []),
        ganHe: List<String>.from(j['gan_he'] ?? []),
      );
}

/// 신강/신약 점수제 판정 (100점 환산)
class Strength {
  final int score;
  final String verdict;      // 예: "身强(신강)"
  final List<String> details;

  const Strength({required this.score, required this.verdict, required this.details});

  factory Strength.fromJson(Map<String, dynamic> j) {
    // details는 (a) 리스트 또는 (b) v3.1 점수제 맵 {항목: 배점} — 둘 다 수용.
    // 맵 분기 표기는 엔진 리스트 형식("… +40")과 동일하게 맞춘다(단위 표기 일관).
    final d = j['details'];
    final List<String> details;
    if (d is Map) {
      details = d.entries.map((e) => '${e.key} +${e.value}').toList();
    } else if (d is List) {
      details = d.map((e) => e.toString()).toList();
    } else {
      details = const [];
    }
    return Strength(score: j['score'] ?? 0, verdict: j['verdict'] ?? '', details: details);
  }
}

/// 용신/희신/기신/구신 + 판단 근거
class Yongshin {
  final String yong;        // 용신 오행
  final String yongGroup;   // 예: "식신·상관"
  final String? hee;        // 희신 오행 (부재 시 null)
  final String? heeGroup;
  final String gi;          // 기신 오행
  final String gu;          // 구신 오행
  final List<String> reasons;

  const Yongshin({required this.yong, required this.yongGroup, required this.hee,
                  required this.heeGroup, required this.gi, required this.gu, required this.reasons});

  factory Yongshin.fromJson(Map<String, dynamic> j) => Yongshin(
        yong: j['yong'] ?? '',
        yongGroup: j['yong_group'] ?? '',
        hee: j['hee'],
        heeGroup: j['hee_group'],
        gi: j['gi'] ?? '',
        gu: j['gu'] ?? '',
        reasons: List<String>.from(j['reasons'] ?? []),
      );
}

/// 산출 정책 (야자시 학파 등)
class PolicyV3 {
  final String zihour;      // "traditional" (23시 개일) | "legacy" (야자시 인정)
  final int currentYear;
  // v3.1 추가 정책 필드 (구버전 응답에서는 기본값으로 안전하게 채워짐)
  final bool trueSolar;
  final double? longitude;
  final String dayunMethod;
  final List<String> trueSolarWarnings;

  const PolicyV3({
    required this.zihour,
    required this.currentYear,
    this.trueSolar = false,
    this.longitude,
    this.dayunMethod = 'lunar_compat',
    this.trueSolarWarnings = const [],
  });

  factory PolicyV3.fromJson(Map<String, dynamic> j) => PolicyV3(
        zihour: j['zihour'] ?? 'traditional',
        currentYear: j['current_year'] ?? 2026,
        trueSolar: j['true_solar'] ?? false,
        longitude: j['longitude'] == null ? null : (j['longitude'] as num).toDouble(),
        dayunMethod: j['dayun_method'] ?? 'lunar_compat',
        trueSolarWarnings:
            ((j['true_solar_warnings'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
}

/// L1 팩트 계층 전체 — POST /saju/v3/facts 응답
class SajuResultV3 {
  final Map<String, dynamic> input;
  final Pillar year, month, day, hour;
  final DayMaster dayMaster;
  final String dayMasterStrength;         // 기존 호환 문자열
  final Strength strength;                // v3 점수 판정
  final Map<String, int> fiveElementsCount;
  final Map<String, double> fiveElementsWeighted;
  final Map<String, String> tenGods;
  final List<String> sinsal;
  final String gongmang;
  final List<LuckPillar> luckPillars;
  final LuckPillar? currentLuck;
  final ZhiQigan zhiQigan;
  final Map<String, String> twelveStages; // pillar위치 → 십이운성
  final Relations relations;
  final Yongshin yongshin;
  final Map<String, dynamic>? dayunPrecise; // v3.1 대운 정밀 산출 근거 (구버전 null)
  final PolicyV3 policy;

  const SajuResultV3({
    required this.input, required this.year, required this.month, required this.day,
    required this.hour, required this.dayMaster, required this.dayMasterStrength,
    required this.strength, required this.fiveElementsCount, required this.fiveElementsWeighted,
    required this.tenGods, required this.sinsal, required this.gongmang,
    required this.luckPillars, this.currentLuck, required this.zhiQigan,
    required this.twelveStages, required this.relations, required this.yongshin,
    required this.policy,
  });

  factory SajuResultV3.fromJson(Map<String, dynamic> j) {
    final p = j['pillars'] as Map<String, dynamic>;
    return SajuResultV3(
      input: Map<String, dynamic>.from(j['input'] ?? {}),
      year: Pillar.fromJson(p['year']),
      month: Pillar.fromJson(p['month']),
      day: Pillar.fromJson(p['day']),
      hour: Pillar.fromJson(p['hour']),
      dayMaster: DayMaster.fromJson(j['day_master']),
      dayMasterStrength: j['day_master_strength'] ?? '',
      strength: Strength.fromJson({
        'score': j['day_master_strength_score'] ?? 0,
        'verdict': j['day_master_strength'] ?? '',
        'details': j['strength_details'] ?? [],
      }),
      fiveElementsCount: Map<String, int>.from(j['five_elements_count'] ?? {}),
      fiveElementsWeighted: (j['five_elements_weighted'] ?? {})
          .map<String, double>((k, v) => MapEntry(k, (v as num).toDouble())),
      tenGods: Map<String, String>.from(j['ten_gods'] ?? {}),
      sinsal: List<String>.from(j['sinsal'] ?? []),
      gongmang: j['gongmang'] ?? '',
      luckPillars: (j['luck_pillars'] as List? ?? [])
          .map((e) => LuckPillar.fromJson(e)).toList(),
      currentLuck: j['current_luck'] != null ? LuckPillar.fromJson(j['current_luck']) : null,
      zhiQigan: ZhiQigan.fromJson(j['zhi_qigan'] ?? {}),
      twelveStages: Map<String, String>.from(j['twelve_stages'] ?? {}),
      relations: Relations.fromJson(j['relations'] ?? {}),
      yongshin: Yongshin.fromJson(j['yongshin'] ?? {}),
      dayunPrecise: j['dayun_precise'] == null ? null : Map<String, dynamic>.from(j['dayun_precise']),
      policy: PolicyV3.fromJson(j['policy'] ?? {}),
    );
  }
}

/// L2 69종 개별 결과 — 계산 데이터(data) + 사용한 계산값 근거(basis)
class CategoryResultV3 {
  final String code;
  final String name;
  final Map<String, dynamic> data;
  final List<String> basis;
  final String? error;

  const CategoryResultV3({required this.code, required this.name, required this.data,
                          required this.basis, this.error});

  bool get hasError => error != null;

  factory CategoryResultV3.fromJson(String code, Map<String, dynamic> j) => CategoryResultV3(
        code: code,
        name: j['name'] ?? '',
        data: Map<String, dynamic>.from(j['data'] ?? {}),
        basis: List<String>.from(j['basis'] ?? []),
        error: j['error'],
      );
}

/// POST /saju/v3/categories69 응답 전체
class SajuAll69 {
  final Map<String, dynamic> input;
  final Map<String, String> pillarsKr;
  final SajuResultV3 facts;
  final Map<String, CategoryResultV3> items;
  final int errorCount;

  const SajuAll69({required this.input, required this.pillarsKr, required this.facts,
                   required this.items, required this.errorCount});

  factory SajuAll69.fromJson(Map<String, dynamic> j) {
    final items = <String, CategoryResultV3>{};
    int errs = 0;
    (j['categories69'] as Map<String, dynamic>? ?? {}).forEach((code, v) {
      final r = CategoryResultV3.fromJson(code, Map<String, dynamic>.from(v));
      items[code] = r;
      if (r.hasError) errs++;
    });
    final factsRaw = Map<String, dynamic>.from(j['facts'] ?? {});
    return SajuAll69(
      input: Map<String, dynamic>.from(j['input'] ?? {}),
      pillarsKr: (j['pillars'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v is Map ? (v['kr'] ?? '') : v.toString())),
      facts: SajuResultV3.fromJson(factsRaw),
      items: items,
      errorCount: errs,
    );
  }
}
