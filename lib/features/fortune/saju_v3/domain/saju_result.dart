// 신통방통 - 사주 원국 계산 결과 모델
// GET/POST /saju/calculate 응답

class Pillar {
  final String gan;      // 천간 (한자)
  final String zhi;      // 지지 (한자)
  final String kr;       // 한글 표기 (예: "임자")
  final String element;  // "수-수" 형식

  const Pillar({required this.gan, required this.zhi, required this.kr, required this.element});

  factory Pillar.fromJson(Map<String, dynamic> j) => Pillar(
        gan: j['gan'], zhi: j['zhi'], kr: j['kr'], element: j['element'],
      );
}

class DayMaster {
  final String gan;
  final String kr;
  final String element;
  final String yinYang;
  final String image;

  const DayMaster({required this.gan, required this.kr, required this.element,
                   required this.yinYang, required this.image});

  factory DayMaster.fromJson(Map<String, dynamic> j) => DayMaster(
        gan: j['gan'], kr: j['kr'], element: j['element'],
        yinYang: j['yin_yang'], image: j['image'],
      );
}

class LuckPillar {
  final int startAge;
  final int startYear;
  final String ganZhi;
  final String ganZhiKr;

  const LuckPillar({required this.startAge, required this.startYear,
                    required this.ganZhi, required this.ganZhiKr});

  factory LuckPillar.fromJson(Map<String, dynamic> j) => LuckPillar(
        startAge: j['start_age'], startYear: j['start_year'],
        ganZhi: j['gan_zhi'] ?? '', ganZhiKr: j['gan_zhi_kr'] ?? '',
      );
}

class SajuResult {
  final Map<String, dynamic> input;
  final Pillar year;
  final Pillar month;
  final Pillar day;
  final Pillar hour;
  final DayMaster dayMaster;
  final String dayMasterStrength;
  final Map<String, int> fiveElementsCount;
  final Map<String, String> tenGods;
  final List<String> sinsal;
  final String gongmang;
  final List<LuckPillar> luckPillars;
  final int currentAge;
  final LuckPillar? currentLuck;

  const SajuResult({
    required this.input, required this.year, required this.month,
    required this.day, required this.hour, required this.dayMaster,
    required this.dayMasterStrength, required this.fiveElementsCount,
    required this.tenGods, required this.sinsal, required this.gongmang,
    required this.luckPillars, required this.currentAge, this.currentLuck,
  });

  factory SajuResult.fromJson(Map<String, dynamic> j) {
    final p = j['pillars'];
    return SajuResult(
      input: Map<String, dynamic>.from(j['input']),
      year: Pillar.fromJson(p['year']),
      month: Pillar.fromJson(p['month']),
      day: Pillar.fromJson(p['day']),
      hour: Pillar.fromJson(p['hour']),
      dayMaster: DayMaster.fromJson(j['day_master']),
      dayMasterStrength: j['day_master_strength'],
      fiveElementsCount: Map<String, int>.from(j['five_elements_count']),
      tenGods: Map<String, String>.from(j['ten_gods']),
      sinsal: List<String>.from(j['sinsal']),
      gongmang: j['gongmang'],
      luckPillars: (j['luck_pillars'] as List)
          .map((e) => LuckPillar.fromJson(e)).toList(),
      currentAge: j['current_age'],
      currentLuck: j['current_luck'] != null
          ? LuckPillar.fromJson(j['current_luck']) : null,
    );
  }
}
