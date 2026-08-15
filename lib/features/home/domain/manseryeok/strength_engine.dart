/// [정통사주 80종 전용 신규 엔진] 신강/신약(身强身弱) 정밀 분석 엔진 —
/// PHASE 3 §12.
///
/// 37번 지시 §12 "월령/일간/통근/생조/극제/설기/천간/지지/지장간/계절
/// 종합"에 대응한다.
///
/// [계산 로직 재사용] 이 엔진은 새로운 오행/십신 판정 로직을 재구현하지
/// 않는다 — PHASE 2에서 이미 계산된 [HiddenStemsEngine]의 지장간 십신
/// 결과와 [HiddenStemsEngine.analyzeStemAndBranchTenGods]의 천간/지지
/// (본기) 십신 결과를 그대로 입력받아, 그 십신들을 5가지 관계 범주
/// (비겁/식상/재성/관살/인성)로 재분류하고 전통 억부법(抑扶法) 가중치를
/// 적용해 점수화하는 역할만 한다.
///
/// [절대 원칙 — 임의공식 금지 해당 없음] 여기서 사용하는 가중치(월령
/// 2배, 관살 1.0배, 설기 0.5배 등)는 "특정 개인의 생년월일에 따라
/// 달라지는 임의 공식"이 아니라, 억부법 이론에서 통용되는 "월령이 가장
/// 중요하고 그 다음이 통근, 관살이 설기보다 일간을 더 강하게 억제한다"는
/// 정성적 원칙을 수치화한 고정 가중치다. 모든 사주에 동일하게 적용되며,
/// 생년월일 문자열 해시나 랜덤과는 무관하다.
library;

import '../saju_engine.dart' show ganElement, sheng, ke;
import 'five_elements_engine.dart'
    show hiddenStemWeightsForCount, monthBranchToDominantElement;
import 'saju_profile.dart';

/// [sheng]의 역함수 — "누가 나(Y)를 생하는가"(Y를 생하는 X를 찾는다).
/// `saju_engine.dart`의 [sheng] 맵을 그대로 뒤집은 고정 테이블이며,
/// 재구현이 아니라 역방향 조회를 위한 노출이다.
const Map<String, String> _invSheng = {
  '화': '목', '토': '화', '금': '토', '수': '금', '목': '수',
};

/// [ke]의 역함수 — "누가 나(Y)를 극하는가"(Y를 극하는 X를 찾는다).
const Map<String, String> _invKe = {
  '토': '목', '수': '토', '화': '수', '금': '화', '목': '금',
};

/// 일간 오행([dayElement]) 대비 임의의 오행([targetElement])이 어떤
/// 관계(십신 5대 범주)인지 판정한다.
///
/// 반환값: '비겁' | '식상' | '재성' | '관살' | '인성'.
String relationCategoryOf(String dayElement, String targetElement) {
  if (targetElement == dayElement) return '비겁';
  if (sheng[dayElement] == targetElement) return '식상';
  if (ke[dayElement] == targetElement) return '재성';
  if (_invKe[dayElement] == targetElement) return '관살';
  if (_invSheng[dayElement] == targetElement) return '인성';
  throw ArgumentError('알 수 없는 오행 관계: $dayElement vs $targetElement');
}

/// 십신 이름(비견/겁재/식신/상관/편재/정재/편관/정관/편인/정인) →
/// 5대 범주(비겁/식상/재성/관살/인성) 축약.
String tenGodCategoryOf(String tenGod) {
  const map = {
    '비견': '비겁', '겁재': '비겁',
    '식신': '식상', '상관': '식상',
    '편재': '재성', '정재': '재성',
    '편관': '관살', '정관': '관살',
    '편인': '인성', '정인': '인성',
  };
  return map[tenGod] ?? tenGod;
}

class StrengthEngine {
  StrengthEngine._();

  /// 월령(月令) 가중치 — 억부법에서 가장 비중이 큰 단일 요소이므로
  /// 다른 위치 대비 2배로 계산한다(전통적으로 통용되는 원칙, 개인별
  /// 임의 조정 아님).
  static const double _monthWeight = 2.0;

  /// 설기(泄氣, 식상+재성)는 극제(剋制, 관살)보다 일간을 약화시키는
  /// 힘이 약하다고 보는 전통 억부법 관점을 반영한 감쇠 계수.
  static const double _drainDamping = 0.5;

  /// 신강/중화/신약 판정 임계치. score(0.0~1.0)가 0.6 이상이면 신강,
  /// 0.4 이하이면 신약, 그 사이는 중화로 본다(억부법에서 통상 사용하는
  /// 3분류 임계치 — 정확히 0.5를 중간으로 ±0.1 구간을 중화로 둔다).
  static const double _strongThreshold = 0.6;
  static const double _weakThreshold = 0.4;

  /// PHASE 2 결과([tenGods], [hiddenStems])를 재사용해 신강/신약을
  /// 정밀 분석한다.
  static StrengthProfile analyze({
    required Pillar dayPillar,
    required Pillar monthPillar,
    required Map<String, String> tenGods,
    required Map<String, HiddenStemEntry> hiddenStems,
  }) {
    final detail = <String>[];
    final dayElement = ganElement[dayPillar.stemHanja]!.$1;
    detail.add('일간=${dayPillar.stemHanja}($dayElement)');

    // ── ① 월령(月令) 득실 — 계절이 일간을 돕는지 판정 ──
    final monthDominantElement =
        monthBranchToDominantElement[monthPillar.branchHanja]!;
    final monthRelation = relationCategoryOf(dayElement, monthDominantElement);
    double monthOrderScore;
    switch (monthRelation) {
      case '비겁':
      case '인성':
        monthOrderScore = 1.0;
        break;
      case '관살':
        monthOrderScore = -1.0;
        break;
      default: // 식상 | 재성
        monthOrderScore = -0.5;
    }
    detail.add(
      '월령: 월지(${monthPillar.branchHanja})의 계절 오행=$monthDominantElement, '
      '일간 대비 관계=$monthRelation → monthOrderScore=$monthOrderScore',
    );

    // ── 위치별 가중치(월지/월지 지장간만 2배, 나머지는 1배) ──
    double posWeight(String key) => key == 'month_zhi' ? _monthWeight : 1.0;

    // ── ② 통근(通根) — 지장간 중 비겁/인성 가중 합산 ──
    double rootScore = 0;
    for (final entry in hiddenStems.entries) {
      final posKey = '${entry.key}_zhi'; // year_zhi | month_zhi | ...
      final weights = hiddenStemWeightsForCount(entry.value.stems.length);
      for (var i = 0; i < entry.value.stems.length; i++) {
        final cat = tenGodCategoryOf(entry.value.stems[i].tenGod);
        if (cat == '비겁' || cat == '인성') {
          final w = weights[i] * posWeight(posKey);
          rootScore += w;
          detail.add(
            '통근: ${entry.key}지 지장간 ${entry.value.stems[i].stemHanja}'
            '(${entry.value.stems[i].role}, $cat) 가중치=$w',
          );
        }
      }
    }

    // ── ③ 생조(比劫+印星)/④ 극제(官殺)/⑤ 설기(食傷+財星) —
    //     천간(일간 제외 3개) + 지지 본기(4개), tenGods 맵 재사용 ──
    double supportScore = 0;
    double controlScore = 0;
    double drainScore = 0;
    for (final e in tenGods.entries) {
      final cat = tenGodCategoryOf(e.value);
      final w = posWeight(e.key);
      switch (cat) {
        case '비겁':
        case '인성':
          supportScore += w;
          break;
        case '관살':
          controlScore += w;
          break;
        case '식상':
        case '재성':
          drainScore += w;
          break;
      }
      detail.add('${e.key}=${e.value}($cat) 가중치=$w');
    }

    // ── 종합 점수화 ──
    final positiveMonth = monthOrderScore > 0 ? monthOrderScore * _monthWeight : 0.0;
    final negativeMonth = monthOrderScore < 0 ? -monthOrderScore * _monthWeight : 0.0;

    final totalPositive = supportScore + rootScore + positiveMonth;
    final totalNegative = controlScore + drainScore * _drainDamping + negativeMonth;

    final score = (totalPositive + totalNegative) == 0
        ? 0.5
        : totalPositive / (totalPositive + totalNegative);

    String verdict;
    if (score >= _strongThreshold) {
      verdict = '신강';
    } else if (score <= _weakThreshold) {
      verdict = '신약';
    } else {
      verdict = '중화';
    }

    detail.add(
      '종합: support=$supportScore root=$rootScore control=$controlScore '
      'drain=$drainScore monthOrder=$monthOrderScore → score=$score → $verdict',
    );

    return StrengthProfile(
      verdict: verdict,
      score: score,
      monthOrderScore: monthOrderScore,
      rootScore: rootScore,
      supportScore: supportScore,
      controlScore: controlScore,
      drainScore: drainScore,
      detail: detail,
    );
  }
}
