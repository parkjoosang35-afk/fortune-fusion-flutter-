/// [정통사주 80종 · 로컬 만세력 엔진] saju_engine_v4_final.zip 의
/// `saju_calculator.py` 를 Dart로 완전 이식한 파일.
///
/// - AI/LLM 호출 없음. 외부 서버 호출 없음.
/// - `lunar`(pub.dev, 원저자 6tail — Python `lunar_python`과 동일 알고리즘)
///   패키지로 실제 만세력(사주팔자)을 계산한다.
/// - 계산 로직(오행/음양 매핑, 십신 판정, 신강신약 판정, 신살, 공망, 대운)은
///   원본 파이썬과 1:1 대응되도록 이식했다 — 박주상님(1972-02-13 02:00 남)
///   샘플로 Python 기준값과 대조 검증 완료.
library;

import 'package:lunar/lunar.dart';

// ============================================================
// 매핑 테이블 (한자 → 한글 / 오행) — saju_calculator.py 그대로 이식
// ============================================================

const Map<String, String> ganKr = {
  '甲': '갑',
  '乙': '을',
  '丙': '병',
  '丁': '정',
  '戊': '무',
  '己': '기',
  '庚': '경',
  '辛': '신',
  '壬': '임',
  '癸': '계',
};

const Map<String, String> zhiKr = {
  '子': '자',
  '丑': '축',
  '寅': '인',
  '卯': '묘',
  '辰': '진',
  '巳': '사',
  '午': '오',
  '未': '미',
  '申': '신',
  '酉': '유',
  '戌': '술',
  '亥': '해',
};

/// (오행, 음양) 튜플 — Dart 는 튜플이 record 문법으로 가능(Dart 3.x).
const Map<String, (String, String)> ganElement = {
  '甲': ('목', '양'),
  '乙': ('목', '음'),
  '丙': ('화', '양'),
  '丁': ('화', '음'),
  '戊': ('토', '양'),
  '己': ('토', '음'),
  '庚': ('금', '양'),
  '辛': ('금', '음'),
  '壬': ('수', '양'),
  '癸': ('수', '음'),
};

const Map<String, (String, String)> zhiElement = {
  '子': ('수', '양'),
  '丑': ('토', '음'),
  '寅': ('목', '양'),
  '卯': ('목', '음'),
  '辰': ('토', '양'),
  '巳': ('화', '음'),
  '午': ('화', '양'),
  '未': ('토', '음'),
  '申': ('금', '양'),
  '酉': ('금', '음'),
  '戌': ('토', '양'),
  '亥': ('수', '음'),
};

const Map<String, String> ganImage = {
  '甲': '큰 나무',
  '乙': '풀·덩굴',
  '丙': '태양',
  '丁': '촛불·별빛',
  '戊': '큰 산',
  '己': '밭 흙',
  '庚': '큰 쇠·도끼',
  '辛': '보석·칼',
  '壬': '바다',
  '癸': '이슬·비',
};

/// 십신 매핑: (오행관계, 음양동일여부) -> 십신
const Map<(String, bool), String> tenGodsTable = {
  ('same', true): '비견',
  ('same', false): '겁재',
  ('生out', true): '식신',
  ('生out', false): '상관',
  ('克out', true): '편재',
  ('克out', false): '정재',
  ('克in', true): '편관',
  ('克in', false): '정관',
  ('生in', true): '편인',
  ('生in', false): '정인',
};

/// 오행 상생 관계 (내가 생하는 것)
const Map<String, String> sheng = {
  '목': '화',
  '화': '토',
  '토': '금',
  '금': '수',
  '수': '목',
};

/// 오행 상극 관계 (내가 극하는 것)
const Map<String, String> ke = {
  '목': '토',
  '토': '수',
  '수': '화',
  '화': '금',
  '금': '목',
};

/// 일간 대비 십신 계산 — get_ten_god() 이식
String getTenGod(String dayGan, String targetGanOrZhi) {
  final (dayEl, dayYy) = ganElement[dayGan]!;
  final (tgtEl, tgtYy) =
      ganElement[targetGanOrZhi] ?? zhiElement[targetGanOrZhi]!;

  final sameYy = dayYy == tgtYy;

  String rel;
  if (dayEl == tgtEl) {
    rel = 'same';
  } else if (sheng[dayEl] == tgtEl) {
    rel = '生out';
  } else if (ke[dayEl] == tgtEl) {
    rel = '克out';
  } else if (ke[tgtEl] == dayEl) {
    rel = '克in';
  } else if (sheng[tgtEl] == dayEl) {
    rel = '生in';
  } else {
    rel = 'same';
  }

  return tenGodsTable[(rel, sameYy)]!;
}

// ============================================================
// 신살(神殺) — 대표 3종 (원본과 동일 범위)
// ============================================================

const Map<String, List<String>> cheoneulGwiin = {
  '甲': ['丑', '未'],
  '戊': ['丑', '未'],
  '庚': ['丑', '未'],
  '乙': ['子', '申'],
  '己': ['子', '申'],
  '丙': ['亥', '酉'],
  '丁': ['亥', '酉'],
  '壬': ['卯', '巳'],
  '癸': ['卯', '巳'],
  '辛': ['寅', '午'],
};

const Map<String, String> munchangGwiin = {
  '甲': '巳',
  '乙': '午',
  '丙': '申',
  '丁': '酉',
  '戊': '申',
  '己': '酉',
  '庚': '亥',
  '辛': '子',
  '壬': '寅',
  '癸': '卯',
};

const Map<String, String> yeokma = {
  '寅': '申',
  '午': '申',
  '戌': '申',
  '申': '寅',
  '子': '寅',
  '辰': '寅',
  '巳': '亥',
  '酉': '亥',
  '丑': '亥',
  '亥': '巳',
  '卯': '巳',
  '未': '巳',
};

/// 대표 신살 검출 — find_sinsal() 이식
List<String> findSinsal(String dayGan, List<String> zhiList) {
  final found = <String>[];
  if (zhiList.any((z) => (cheoneulGwiin[dayGan] ?? const []).contains(z))) {
    found.add('天乙貴人(천을귀인)');
  }
  if (zhiList.contains(munchangGwiin[dayGan])) {
    found.add('文昌貴人(문창귀인)');
  }
  final dayZhi = zhiList[2]; // 일지 기준
  if (zhiList.contains(yeokma[dayZhi])) {
    found.add('驛馬(역마)');
  }
  return found;
}

// ============================================================
// 공망 계산 — get_gongmang() 이식
// ============================================================

String getGongmang(String dayGan, String dayZhi) {
  const ganOrder = '甲乙丙丁戊己庚辛壬癸';
  const zhiOrder = '子丑寅卯辰巳午未申酉戌亥';
  final gIdx = ganOrder.indexOf(dayGan);
  final zIdx = zhiOrder.indexOf(dayZhi);
  final start = zIdx - gIdx; // 순 시작 오프셋
  final gmStart = ((start + 10) % 12 + 12) % 12;
  final gmEnd = ((start + 11) % 12 + 12) % 12;
  final c1 = zhiOrder[gmStart];
  final c2 = zhiOrder[gmEnd];
  return '$c1$c2 (${zhiKr[c1]}${zhiKr[c2]})';
}

// ============================================================
// 신강/신약 판정 (간이 버전) — judge_strength() 이식
// ============================================================

/// '身强(신강)' | '中和(중화)' | '身弱(신약)'
String judgeStrength(String dayGan, Map<String, int> elementsCount) {
  final dayEl = ganElement[dayGan]!.$1;
  String? helperEl;
  for (final entry in sheng.entries) {
    if (entry.value == dayEl) {
      helperEl = entry.key;
      break;
    }
  }
  final helperCount =
      (elementsCount[dayEl] ?? 0) +
      (helperEl != null ? (elementsCount[helperEl] ?? 0) : 0);
  final total = elementsCount.values.fold<int>(0, (a, b) => a + b);
  final ratio = total == 0 ? 0.0 : helperCount / total;

  if (ratio >= 0.5) {
    return '身强(신강)';
  } else if (ratio >= 0.35) {
    return '中和(중화)';
  } else {
    return '身弱(신약)';
  }
}

// ============================================================
// 결과 모델
// ============================================================

class SajuPillar {
  const SajuPillar({
    required this.gan,
    required this.zhi,
    required this.kr,
    required this.element,
  });

  final String gan;
  final String zhi;
  final String kr; // 예: "임자"
  final String element; // 예: "수-수"
}

class SajuDayMaster {
  const SajuDayMaster({
    required this.gan,
    required this.kr,
    required this.element,
    required this.yinYang,
    required this.image,
  });

  final String gan;
  final String kr;
  final String element;
  final String yinYang;
  final String image;
}

class SajuLuckPillar {
  const SajuLuckPillar({
    required this.startAge,
    required this.startYear,
    required this.ganZhi,
    required this.ganZhiKr,
  });

  final int startAge;
  final int startYear;
  final String ganZhi;
  final String ganZhiKr;
}

/// calculate_saju() 의 리턴값(dict)을 그대로 옮긴 Dart 모델.
class SajuResult {
  const SajuResult({
    required this.gender,
    required this.birthSolar,
    required this.birthLunar,
    required this.pillars,
    required this.dayMaster,
    required this.dayMasterStrength,
    required this.fiveElementsCount,
    required this.tenGods,
    required this.sinsal,
    required this.gongmang,
    required this.luckPillars,
    required this.currentAge,
    required this.currentLuck,
  });

  final String gender; // 'male' | 'female'
  final String birthSolar;
  final String birthLunar;

  /// key: 'year' | 'month' | 'day' | 'hour'
  final Map<String, SajuPillar> pillars;

  final SajuDayMaster dayMaster;
  final String dayMasterStrength;
  final Map<String, int> fiveElementsCount;

  /// key: 'year_gan'|'month_gan'|'hour_gan'|'year_zhi'|'month_zhi'|'day_zhi'|'hour_zhi'
  final Map<String, String> tenGods;

  final List<String> sinsal;
  final String gongmang;
  final List<SajuLuckPillar> luckPillars;
  final int currentAge;
  final SajuLuckPillar? currentLuck;
}

// ============================================================
// 메인 계산 엔진 — calculate_saju() 이식
// ============================================================

class SajuEngine {
  SajuEngine._();

  /// 사주 원국 계산.
  /// [year]/[month]/[day]/[hour]/[minute] 는 [isLunar]=false 이면 양력,
  /// true 이면 음력 기준. [gender] 는 'male' | 'female'.
  /// [referenceDate] 는 "현재 대운"을 판정할 기준 시점(기본값: DateTime.now()).
  static SajuResult calculate({
    required int year,
    required int month,
    required int day,
    required int hour,
    int minute = 0,
    String gender = 'male',
    bool isLunar = false,
    DateTime? referenceDate,
  }) {
    late final Solar solar;
    late final Lunar lunar;
    if (isLunar) {
      lunar = Lunar.fromYmdHms(year, month, day, hour, minute, 0);
      solar = lunar.getSolar();
    } else {
      solar = Solar.fromYmdHms(year, month, day, hour, minute, 0);
      lunar = solar.getLunar();
    }

    final eightChar = lunar.getEightChar();

    final yGan = eightChar.getYearGan();
    final yZhi = eightChar.getYearZhi();
    final mGan = eightChar.getMonthGan();
    final mZhi = eightChar.getMonthZhi();
    final dGan = eightChar.getDayGan();
    final dZhi = eightChar.getDayZhi();
    final hGan = eightChar.getTimeGan();
    final hZhi = eightChar.getTimeZhi();

    final ganList = [yGan, mGan, dGan, hGan];
    final zhiList = [yZhi, mZhi, dZhi, hZhi];

    final elementsCount = {'목': 0, '화': 0, '토': 0, '금': 0, '수': 0};
    for (final g in ganList) {
      final el = ganElement[g]!.$1;
      elementsCount[el] = (elementsCount[el] ?? 0) + 1;
    }
    for (final z in zhiList) {
      final el = zhiElement[z]!.$1;
      elementsCount[el] = (elementsCount[el] ?? 0) + 1;
    }

    final tenGods = <String, String>{
      'year_gan': getTenGod(dGan, yGan),
      'month_gan': getTenGod(dGan, mGan),
      'hour_gan': getTenGod(dGan, hGan),
      'year_zhi': getTenGod(dGan, yZhi),
      'month_zhi': getTenGod(dGan, mZhi),
      'day_zhi': getTenGod(dGan, dZhi),
      'hour_zhi': getTenGod(dGan, hZhi),
    };

    final strength = judgeStrength(dGan, elementsCount);
    final sinsal = findSinsal(dGan, zhiList);
    final gongmang = getGongmang(dGan, dZhi);

    // 대운 (10년 단위) — 첫 9개
    final yun = eightChar.getYun(gender == 'male' ? 1 : 0);
    final daYunList = yun.getDaYun();
    final luckPillars = <SajuLuckPillar>[];
    for (final dy in daYunList.take(9)) {
      final gz = dy.getGanZhi();
      final gzKr = gz.length >= 2
          ? '${ganKr[gz.substring(0, 1)] ?? ''}${zhiKr[gz.substring(1, 2)] ?? ''}'
          : '';
      luckPillars.add(
        SajuLuckPillar(
          startAge: dy.getStartAge(),
          startYear: dy.getStartYear(),
          ganZhi: gz,
          ganZhiKr: gzKr,
        ),
      );
    }

    // 현재 대운 찾기 (세는 나이 기준)
    final ref = referenceDate ?? DateTime.now();
    final currentYear = ref.year;
    final birthYear = year;
    final currentAge = currentYear - birthYear + 1;
    SajuLuckPillar? currentLuck;
    for (final lp in luckPillars) {
      if (lp.startAge <= currentAge && currentAge < lp.startAge + 10) {
        currentLuck = lp;
        break;
      }
    }

    SajuPillar buildPillar(String gan, String zhi) => SajuPillar(
      gan: gan,
      zhi: zhi,
      kr: '${ganKr[gan]}${zhiKr[zhi]}',
      element: '${ganElement[gan]!.$1}-${zhiElement[zhi]!.$1}',
    );

    final dm = SajuDayMaster(
      gan: dGan,
      kr: ganKr[dGan]!,
      element: ganElement[dGan]!.$1,
      yinYang: ganElement[dGan]!.$2,
      image: ganImage[dGan]!,
    );

    return SajuResult(
      gender: gender,
      birthSolar:
          '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')} '
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      birthLunar: lunar.toString(),
      pillars: {
        'year': buildPillar(yGan, yZhi),
        'month': buildPillar(mGan, mZhi),
        'day': buildPillar(dGan, dZhi),
        'hour': buildPillar(hGan, hZhi),
      },
      dayMaster: dm,
      dayMasterStrength: strength,
      fiveElementsCount: elementsCount,
      tenGods: tenGods,
      sinsal: sinsal,
      gongmang: gongmang,
      luckPillars: luckPillars,
      currentAge: currentAge,
      currentLuck: currentLuck,
    );
  }
}
