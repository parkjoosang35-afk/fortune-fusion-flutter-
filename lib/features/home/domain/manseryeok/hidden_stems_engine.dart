/// [정통사주 80종 전용 신규 엔진] 지장간(地藏干) + 십신(十神) 엔진 —
/// PHASE 2 §8.
///
/// 37번 지시 §8 "지장간까지 포함한 10신과 각각의 위치 저장"에 대응한다.
///
/// [계산 로직 재사용] 십신 판정 자체는 기존 `saju_engine.dart`의
/// `getTenGod(dayGan, target)`을 그대로 재사용한다(재구현 금지 원칙).
/// 이 파일이 새로 하는 일은 "지장간 각 글자에도 십신을 적용하고, 그
/// 지장간이 정기/중기/여기 중 무엇인지 라벨링해 [HiddenStemEntry]로
/// 정리하는 것"뿐이다.
///
/// [지장간 role 순서] `lunar` 패키지 `LunarUtil.ZHI_HIDE_GAN`(및
/// [five_elements_engine.dart]의 `zhiHideGanOf()`)이 반환하는 리스트는
/// 항상 "정기(본기)를 첫 번째"로 정렬되어 있다(§7/§8 조사에서 丑/寅/辰/
/// 巳/未/戌 등 3원소 지지와 午/亥 등 2원소 지지를 전수 대조해 확인).
/// 따라서 role은 원소 개수에 따라 다음과 같이 고정 라벨링한다.
/// - 1개(子/卯/酉): [정기]
/// - 2개(午/亥): [정기, 중기]
/// - 3개(丑/寅/辰/巳/未/申/戌): [정기, 중기, 여기]
library;

import '../saju_engine.dart' show getTenGod;
import 'five_elements_engine.dart' show zhiHideGanOf;
import 'saju_profile.dart';

const Map<String, String> _ganKrLocal = {
  '甲': '갑', '乙': '을', '丙': '병', '丁': '정', '戊': '무',
  '己': '기', '庚': '경', '辛': '신', '壬': '임', '癸': '계',
};

const Map<int, List<String>> _roleLabelsByCount = {
  1: ['정기'],
  2: ['정기', '중기'],
  3: ['정기', '중기', '여기'],
};

class HiddenStemsEngine {
  HiddenStemsEngine._();

  /// [dayStemHanja](일간) 기준으로 년/월/일/시 4개 지지 각각의 지장간 +
  /// 십신을 계산한다.
  static Map<String, HiddenStemEntry> analyze({
    required String dayStemHanja,
    required Pillar yearPillar,
    required Pillar monthPillar,
    required Pillar dayPillar,
    required Pillar hourPillar,
  }) {
    HiddenStemEntry buildEntry(Pillar pillar) {
      final branch = pillar.branchHanja;
      final hideGans = zhiHideGanOf(branch);
      final roles = _roleLabelsByCount[hideGans.length]!;
      final stems = <HiddenStemDetail>[
        for (var i = 0; i < hideGans.length; i++)
          HiddenStemDetail(
            stemHanja: hideGans[i],
            stemKr: _ganKrLocal[hideGans[i]]!,
            role: roles[i],
            tenGod: getTenGod(dayStemHanja, hideGans[i]),
          ),
      ];
      return HiddenStemEntry(branch: branch, stems: stems);
    }

    return {
      'year': buildEntry(yearPillar),
      'month': buildEntry(monthPillar),
      'day': buildEntry(dayPillar),
      'hour': buildEntry(hourPillar),
    };
  }

  /// 기존 `saju_engine.dart`의 `tenGods` Map(천간/지지 본기 기준, 지장간
  /// 미포함)과 동일한 키 구조(`year_gan`/`month_gan`/`hour_gan`/`year_zhi`/
  /// `month_zhi`/`day_zhi`/`hour_zhi`, 총 7키 — 일간 자신은 '일주'라
  /// 십신이 없으므로 제외)로 십신을 계산한다(회귀 방지 — [SajuProfile.
  /// tenGods] 필드에 그대로 대입 가능).
  static Map<String, String> analyzeStemAndBranchTenGods({
    required String dayStemHanja,
    required Pillar yearPillar,
    required Pillar monthPillar,
    required Pillar dayPillar,
    required Pillar hourPillar,
  }) {
    return {
      'year_gan': getTenGod(dayStemHanja, yearPillar.stemHanja),
      'month_gan': getTenGod(dayStemHanja, monthPillar.stemHanja),
      'hour_gan': getTenGod(dayStemHanja, hourPillar.stemHanja),
      'year_zhi': getTenGod(dayStemHanja, yearPillar.branchHanja),
      'month_zhi': getTenGod(dayStemHanja, monthPillar.branchHanja),
      'day_zhi': getTenGod(dayStemHanja, dayPillar.branchHanja),
      'hour_zhi': getTenGod(dayStemHanja, hourPillar.branchHanja),
    };
  }
}
