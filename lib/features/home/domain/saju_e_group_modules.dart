/// [정통사주 80종 · E그룹(궁합) 재검토] E08(띠 궁합)/E09(오행 궁합)/
/// E10(겉궁합 vs 속궁합) 계산 모듈.
///
/// [재검토 배경] E01~E07은 두 사람의 사주(생년월일시)를 모두 입력받아야
/// 계산 가능한 진짜 "상대방 궁합"이라 구현 불가(삭제 확정) — 현재 시스템은
/// 단일 사용자 사주만 입력받는다. 그러나 `jeontong_eighty_calculator.dart`의
/// `_categoryIndex`를 다시 확인한 결과, E08/E09/E10은 `_needsPartner`가
/// 아니라 `_placeholder`로 배선되어 있었고, 그 placeholder 안내 문구
/// 자체가 이미 "연지 기준 12띠 대조", "오행 상보성 대조", "연주(겉)·일주(속)
/// 분리 대조"라고 되어 있었다 — 즉 원래 설계 의도부터 **본인 사주 하나만
/// 으로 계산 가능한 자기참조형 카테고리**였다(E01~E07처럼 상대방 사주가
/// 필요한 유형이 아님). F09가 재검토 끝에 구현 대상으로 전환된 것과
/// 동일한 패턴(사용자 확정 지시 §4 "구현 불가능하면 즉시 삭제, 가능하면
/// 구현")에 따라 E08/E09/E10도 구현으로 전환한다.
///
/// [절대 원칙] 새로운 명리 판정 공식을 만들지 않는다. 여기서 쓰는 모든
/// 판정은 이미 검증된 순수 함수/고정 테이블(`saju_engine.dart`의
/// [zhiElement]/[ganImage], `compatibility_rules.json`의 `zhi_combos`)을
/// 조회·조합하는 것뿐이다.
///
/// - E08(띠 궁합): 연지(年支, 태어난 해의 12지지)로 정해지는 "띠"를
///   [compatibility_rules.json]의 `zhi_combos`(육합/삼합/충/형 — 이미
///   E01~E07 상대방 궁합에서 검증된 고정 표)에 12지지 전체를 대입해,
///   "내 띠와 합이 좋은 띠 / 충돌하는 띠"를 안내한다. 새 합충표가 아니라
///   기존 표를 자기 참조 방식으로 순회하는 것뿐이다.
/// - E09(오행 궁합): 일간(日干) 오행이 상생(生)·상극(剋) 관계인 다른
///   오행을 [sheng]/[ke](이미 B06/[getDaewoonTransitionCautions] 등에서
///   검증된 고정 오행 상생상극표)로 조회해, "나와 잘 맞는 오행 / 부딪히는
///   오행"을 안내한다.
/// - E10(겉궁합 vs 속궁합): 연주(年柱, 사회적으로 드러나는 "겉모습")와
///   일주(日柱, 본인 성향의 "속모습")가 오행상 같은 성질인지 다른 성질인지
///   대조한다. 새 개념이 아니라 명리학에서 통용되는 "연주=겉궁합, 일주=
///   속궁합" 통념을 [zhiElement]/[ganElement] 조회만으로 구현한 것이다.
library;

import 'saju_engine.dart';
import 'saju_fortune_rules.dart' show SajuFortuneRules;

Map<String, dynamic> _asMap(dynamic v) =>
    v == null ? const {} : Map<String, dynamic>.from(v as Map);

List<String> _asStrList(dynamic v) =>
    v == null ? const [] : (v as List).map((e) => e.toString()).toList();

/// 12지지 → 띠(동물) 고정 매핑(자평명리 표준, 새 판정 아님).
const Map<String, String> zhiAnimal = {
  '子': '쥐띠',
  '丑': '소띠',
  '寅': '호랑이띠',
  '卯': '토끼띠',
  '辰': '용띠',
  '巳': '뱀띠',
  '午': '말띠',
  '未': '양띠',
  '申': '원숭이띠',
  '酉': '닭띠',
  '戌': '개띠',
  '亥': '돼지띠',
};

// ============================================================
// E08 — 띠 궁합 (연지 기준 12띠 전체 대조)
// ============================================================

class ZodiacAnimalCompatibilityResult {
  const ZodiacAnimalCompatibilityResult({
    required this.myZhi,
    required this.myAnimal,
    required this.bestMatches,
    required this.worstMatches,
    required this.summary,
  });

  final String myZhi;
  final String myAnimal;
  final List<String> bestMatches;
  final List<String> worstMatches;
  final String summary;
}

/// `compatibility_rules.json`의 `zhi_combos`(육합/삼합/충/형 — E01~E07이
/// 이미 상대방 궁합에서 사용 중인 고정 표)를 내 연지 기준으로 12지지 전체에
/// 대입해 "잘 맞는 띠"(육합·삼합)와 "부딪히는 띠"(충·형)를 찾는다.
ZodiacAnimalCompatibilityResult getZodiacAnimalCompatibility(
  SajuResult saju,
  SajuFortuneRules rules,
) {
  final myZhi = saju.pillars['year']!.zhi;
  final zhiCombos = _asMap(rules.compatibility['zhi_combos']);

  final best = <String>{};
  final worst = <String>{};

  for (final otherZhi in zhiElement.keys) {
    if (otherZhi == myZhi) continue;
    for (final entry in zhiCombos.entries) {
      final info = _asMap(entry.value);
      final pairs = _asStrList(info['pairs']);
      for (final p in pairs) {
        // 육합/충은 2글자 쌍, 삼합/형은 3글자 조합 — 내 지지가 그 조합에
        // 포함되고 상대 지지도 포함되면 관계가 성립한다(기존 표 그대로).
        if (p.contains(myZhi) && p.contains(otherZhi)) {
          if (entry.key == '六合' || entry.key == '三合') {
            best.add(zhiAnimal[otherZhi]!);
          } else if (entry.key == '沖' || entry.key == '刑') {
            worst.add(zhiAnimal[otherZhi]!);
          }
        }
      }
    }
  }

  final myAnimal = zhiAnimal[myZhi]!;
  final bestList = best.toList();
  final worstList = worst.toList();

  final String summary;
  if (bestList.isEmpty && worstList.isEmpty) {
    summary = '$myAnimal는 12지지 합충표 안에서 뚜렷하게 부딪히거나 강하게 끌리는 띠가 '
        '없는 편이라, 띠보다는 다른 요소(오행·일간 궁합)를 함께 참고하는 것이 좋아요.';
  } else {
    final bestText = bestList.isEmpty ? '' : '${bestList.join(', ')}와는 합이 좋은 편이에요. ';
    final worstText = worstList.isEmpty
        ? ''
        : '${worstList.join(', ')}와는 부딪히는 기운이 있어 서로 배려가 필요해요.';
    summary = '$myAnimal 기준으로 볼 때, $bestText$worstText';
  }

  return ZodiacAnimalCompatibilityResult(
    myZhi: myZhi,
    myAnimal: myAnimal,
    bestMatches: bestList,
    worstMatches: worstList,
    summary: summary,
  );
}

// ============================================================
// E09 — 오행 궁합 (일간 오행 상생상극 전체 대조)
// ============================================================

class FiveElementCompatibilityResult {
  const FiveElementCompatibilityResult({
    required this.myElement,
    required this.supportiveElement,
    required this.supportedElement,
    required this.clashingElement,
    required this.clashedByElement,
    required this.summary,
  });

  final String myElement;

  /// 나를 생(生)해주는 오행 — 든든한 지원자 역할.
  final String supportiveElement;

  /// 내가 생(生)해주는 오행 — 내가 챙겨주는 역할.
  final String supportedElement;

  /// 내가 극(剋)하는 오행 — 내가 부담을 주는 관계.
  final String clashingElement;

  /// 나를 극(剋)하는 오행 — 나에게 부담을 주는 관계.
  final String clashedByElement;
  final String summary;
}

/// 일간(日干) 오행을 [sheng]/[ke](오행 상생상극 고정표, 이미 B06 등에서
/// 검증됨)로 조회해 "나를 생하는 오행/내가 생하는 오행/내가 극하는 오행/
/// 나를 극하는 오행" 4방향을 안내한다. 새 판정 공식이 아니라 고정표를
/// 역방향까지 포함해 전부 조회하는 것뿐이다.
FiveElementCompatibilityResult getFiveElementCompatibility(SajuResult saju) {
  final myElement = saju.dayMaster.element;

  // 나를 생하는 오행 = sheng 맵에서 값이 myElement인 키.
  final supportive = sheng.entries.firstWhere((e) => e.value == myElement).key;
  // 내가 생하는 오행 = sheng[myElement].
  final supported = sheng[myElement]!;
  // 내가 극하는 오행 = ke[myElement].
  final clashing = ke[myElement]!;
  // 나를 극하는 오행 = ke 맵에서 값이 myElement인 키.
  final clashedBy = ke.entries.firstWhere((e) => e.value == myElement).key;

  final summary =
      '일간 오행이 $myElement(이)라, $supportive 기운은 나를 든든하게 채워주고 '
      '$supported 기운은 내가 아끼며 챙기는 관계예요. 반면 $clashing 기운과는 '
      '내가 주도권을 쥐는 팽팽한 관계, $clashedBy 기운과는 내가 눌리기 쉬운 관계라 '
      '조금 더 배려가 필요해요.';

  return FiveElementCompatibilityResult(
    myElement: myElement,
    supportiveElement: supportive,
    supportedElement: supported,
    clashingElement: clashing,
    clashedByElement: clashedBy,
    summary: summary,
  );
}

// ============================================================
// E10 — 겉궁합 vs 속궁합 (연주=겉, 일주=속 오행 대조)
// ============================================================

class OuterInnerCompatibilityResult {
  const OuterInnerCompatibilityResult({
    required this.outerElement,
    required this.innerElement,
    required this.relation,
    required this.summary,
  });

  /// 연주(年柱) 오행 — 사회적으로 드러나는 "겉모습" 성향.
  final String outerElement;

  /// 일주(日柱, 일간) 오행 — 본인 내면의 "속모습" 성향.
  final String innerElement;

  /// 두 오행의 관계: '동일' | '상생(겉→속)' | '상생(속→겉)' | '상극(겉→속)' |
  /// '상극(속→겉)' | '무관'.
  final String relation;
  final String summary;
}

/// 명리학에서 통용되는 "연주=겉궁합(사회적 이미지), 일주=속궁합(본질
/// 성향)" 통념을 [zhiElement]/[dayMaster.element] 조회만으로 구현한다.
/// 새 개념을 만드는 것이 아니라, 이미 계산되어 있는 연지 오행과 일간
/// 오행을 [sheng]/[ke] 고정표로 대조하는 것뿐이다.
OuterInnerCompatibilityResult getOuterInnerCompatibility(SajuResult saju) {
  final yearZhi = saju.pillars['year']!.zhi;
  final outerElement = zhiElement[yearZhi]!.$1;
  final innerElement = saju.dayMaster.element;

  final String relation;
  final String summary;
  if (outerElement == innerElement) {
    relation = '동일';
    summary = '겉으로 보이는 이미지($outerElement)와 속마음의 본질($innerElement)이 같은 '
        '오행이라, 겉과 속이 일치하는 사람이에요. 꾸밈없이 진솔하게 보이는 편이에요.';
  } else if (sheng[outerElement] == innerElement) {
    relation = '상생(겉→속)';
    summary = '겉으로 보이는 이미지($outerElement)가 속마음의 본질($innerElement)을 북돋아주는 '
        '관계라, 사회적 이미지가 내면의 성향을 자연스럽게 살려주는 편이에요.';
  } else if (sheng[innerElement] == outerElement) {
    relation = '상생(속→겉)';
    summary = '속마음의 본질($innerElement)이 겉으로 보이는 이미지($outerElement)를 '
        '뒷받침해주는 관계라, 내면의 힘이 겉모습으로 잘 드러나는 편이에요.';
  } else if (ke[outerElement] == innerElement) {
    relation = '상극(겉→속)';
    summary = '겉으로 보이는 이미지($outerElement)와 속마음의 본질($innerElement)이 부딪히는 '
        '관계라, 남들이 보는 모습과 실제 성향 사이에 간극을 느낄 수 있어요.';
  } else if (ke[innerElement] == outerElement) {
    relation = '상극(속→겉)';
    summary = '속마음의 본질($innerElement)이 겉으로 보이는 이미지($outerElement)를 억누르는 '
        '관계라, 내면의 진짜 모습을 겉으로 잘 드러내지 못할 수 있어요.';
  } else {
    relation = '무관';
    summary = '겉으로 보이는 이미지($outerElement)와 속마음의 본질($innerElement)이 직접적인 '
        '상생상극 관계는 아니라, 비교적 독립적으로 각자의 색을 유지하는 편이에요.';
  }

  return OuterInnerCompatibilityResult(
    outerElement: outerElement,
    innerElement: innerElement,
    relation: relation,
    summary: summary,
  );
}
