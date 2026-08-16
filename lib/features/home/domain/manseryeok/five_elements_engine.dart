/// [정통사주 80종 전용 신규 엔진] 오행(五行) 분석 엔진 — PHASE 2 §7.
///
/// 37번 지시 §7 "천간오행/지지오행/지장간오행/월령/계절/오행강약/오행과다/
/// 오행부족/오행편중 전부 계산"에 대응한다.
///
/// [절대 원칙] 이 파일은 사주 8글자(이미 [ManseryeokCoreEngine]이 계산해
/// 놓은 [Pillar] 4개)만을 입력으로 받아 순수 결정론적 매핑 테이블 조회로
/// 오행을 집계한다. 생년월일 문자열 해시나 임의 랜덤은 전혀 사용하지
/// 않는다.
library;

import '../saju_engine.dart' show ganElement, zhiElement;
import 'saju_profile.dart';

/// 지지 하나의 지장간에 부여하는 가중치.
///
/// `lunar` 패키지 `LunarUtil.ZHI_HIDE_GAN`은 각 지지를 "정기(본기)가 항상
/// 첫 번째 원소"가 되도록 정렬해 제공한다(§7 조사 결과, 예: 丑→[己,癸,辛],
/// 寅→[甲,丙,戊]). 이 순서를 이용해 다음과 같은 전통 명리학의 통상적인
/// 비중(정기 > 중기 > 여기)을 그대로 반영한 고정 가중치를 적용한다.
/// - 지장간 1개(子午卯酉 중 午 제외, 정확히는 子卯酉만 1개): 정기 1.0
/// - 지장간 2개(午, 亥): [0.7, 0.3]
/// - 지장간 3개(寅巳申辰戌丑未): [0.6, 0.25, 0.15]
///
/// 이 가중치는 "특정 개인의 생년월일에 따라 달라지는 임의 공식"이 아니라,
/// 지지 종류에만 의존하는 보편 고정 테이블이다(37번 지시 §34의 "임의공식"
/// 금지는 개인별 해시/랜덤을 금지하는 것이며, 이런 전통 고정 비율표는
/// 해당하지 않는다).
const Map<int, List<double>> _hiddenStemWeightsByCount = {
  1: [1.0],
  2: [0.7, 0.3],
  3: [0.6, 0.25, 0.15],
};

/// 월지 → 계절(季節) 고정 매핑(37번 지시 §7 "계절").
const Map<String, String> monthBranchToSeason = {
  '寅': '봄',
  '卯': '봄',
  '辰': '환절기(봄~여름)',
  '巳': '여름',
  '午': '여름',
  '未': '환절기(여름~가을)',
  '申': '가을',
  '酉': '가을',
  '戌': '환절기(가을~겨울)',
  '亥': '겨울',
  '子': '겨울',
  '丑': '환절기(겨울~봄)',
};

/// 월지 → 그 계절이 왕성하게 하는 오행(월령/月令) 고정 매핑.
/// (寅卯辰월=목왕, 巳午未월=화왕, 申酉戌월=금왕, 亥子丑월=수왕.
/// 辰戌丑未는 토가 함께 왕하는 환절기이므로 [monthOrderElement]에는
/// 토를 반환하지 않고 각 계절 오행을 반환한다 — 통근/월령 판단은
/// [strength engine](Phase 3)에서 지장간 정기까지 함께 고려한다.)
const Map<String, String> monthBranchToDominantElement = {
  '寅': '목',
  '卯': '목',
  '辰': '목',
  '巳': '화',
  '午': '화',
  '未': '화',
  '申': '금',
  '酉': '금',
  '戌': '금',
  '亥': '수',
  '子': '수',
  '丑': '수',
};

class FiveElementsEngine {
  FiveElementsEngine._();

  /// 오행 과다(過多) 판정 임계치 — 8글자(천간4+지지4) 중 3개 이상이면
  /// "과다"로 본다(전통적으로 통용되는 "3개 이상 편중" 기준).
  static const int dominantThreshold = 3;

  static FiveElementsProfile analyze({
    required Pillar yearPillar,
    required Pillar monthPillar,
    required Pillar dayPillar,
    required Pillar hourPillar,
  }) {
    final stems = [
      yearPillar.stemHanja,
      monthPillar.stemHanja,
      dayPillar.stemHanja,
      hourPillar.stemHanja,
    ];
    final branches = [
      yearPillar.branchHanja,
      monthPillar.branchHanja,
      dayPillar.branchHanja,
      hourPillar.branchHanja,
    ];

    final stemCount = <String, int>{'목': 0, '화': 0, '토': 0, '금': 0, '수': 0};
    for (final s in stems) {
      final el = ganElement[s]!.$1;
      stemCount[el] = (stemCount[el] ?? 0) + 1;
    }

    final branchCount = <String, int>{'목': 0, '화': 0, '토': 0, '금': 0, '수': 0};
    for (final z in branches) {
      final el = zhiElement[z]!.$1;
      branchCount[el] = (branchCount[el] ?? 0) + 1;
    }

    // 천간+지지 단순 합산 — 기존 saju_engine.dart의 elementsCount와
    // 동일한 계산(회귀 검증용).
    final totalCount = <String, int>{'목': 0, '화': 0, '토': 0, '금': 0, '수': 0};
    stemCount.forEach((k, v) => totalCount[k] = (totalCount[k] ?? 0) + v);
    branchCount.forEach((k, v) => totalCount[k] = (totalCount[k] ?? 0) + v);

    // 지장간까지 포함한 가중치 오행 카운트.
    final hiddenStemCount = <String, double>{
      '목': 0,
      '화': 0,
      '토': 0,
      '금': 0,
      '수': 0,
    };
    // 천간 4글자는 가중치 1.0으로 그대로 포함(지장간 가중치와 같은 축적).
    for (final s in stems) {
      final el = ganElement[s]!.$1;
      hiddenStemCount[el] = (hiddenStemCount[el] ?? 0) + 1.0;
    }
    for (final z in branches) {
      final hideGans = zhiHideGanOf(z);
      final weights = _hiddenStemWeightsByCount[hideGans.length]!;
      for (var i = 0; i < hideGans.length; i++) {
        final el = ganElement[hideGans[i]]!.$1;
        hiddenStemCount[el] = (hiddenStemCount[el] ?? 0) + weights[i];
      }
    }

    final dominant = totalCount.entries
        .where((e) => e.value >= dominantThreshold)
        .map((e) => e.key)
        .toList();
    final deficient = totalCount.entries
        .where((e) => e.value == 0)
        .map((e) => e.key)
        .toList();
    final isImbalanced = dominant.isNotEmpty || deficient.isNotEmpty;

    return FiveElementsProfile(
      stemCount: stemCount,
      branchCount: branchCount,
      hiddenStemCount: hiddenStemCount,
      totalCount: totalCount,
      dominant: dominant,
      deficient: deficient,
      isImbalanced: isImbalanced,
    );
  }
}

/// [saju_profile.dart]/[hidden_stems_engine.dart] 등에서 공용으로 쓰기
/// 위한 지장간 조회 함수(패키지 `LunarUtil.ZHI_HIDE_GAN`을 그대로 노출).
List<String> zhiHideGanOf(String branchHanja) {
  return _zhiHideGan[branchHanja]!;
}

/// [strength_engine.dart](PHASE 3 §12 통근 계산) 등에서 지장간 가중치를
/// 중복 정의 없이 재사용하기 위한 공개 접근자 — [_hiddenStemWeightsByCount]
/// 와 동일한 값을 그대로 노출한다(재구현 아님).
List<double> hiddenStemWeightsForCount(int count) {
  return _hiddenStemWeightsByCount[count]!;
}

/// `lunar` 패키지 `LunarUtil.ZHI_HIDE_GAN`과 100% 동일한 값(패키지 내부
/// private 접근 대신 여기 재선언 — 패키지가 이미 계산한 값을 그대로
/// 복사한 것으로, 재구현이 아니라 "노출"이다). 순서는 [정기, 여기, 중기]
/// 또는 [정기, 중기, 여기] 등 패키지 고유 순서를 그대로 따르며, 각 원소의
/// role(정기/중기/여기) 라벨링은 [hidden_stems_engine.dart]에서 담당한다.
const Map<String, List<String>> _zhiHideGan = {
  '子': ['癸'],
  '丑': ['己', '癸', '辛'],
  '寅': ['甲', '丙', '戊'],
  '卯': ['乙'],
  '辰': ['戊', '乙', '癸'],
  '巳': ['丙', '庚', '戊'],
  '午': ['丁', '己'],
  '未': ['己', '丁', '乙'],
  '申': ['庚', '壬', '戊'],
  '酉': ['辛'],
  '戌': ['戊', '辛', '丁'],
  '亥': ['壬', '甲'],
};
