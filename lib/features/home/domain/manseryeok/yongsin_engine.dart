/// [정통사주 80종 전용 신규 엔진] 용신(用神)/희신(喜神)/기신(忌神)/
/// 구신(仇神) 분석 엔진 — PHASE 3 §13.
///
/// 37번 지시 §13 "임의공식 금지, 억부(抑扶)/조후(調候) 기준 분리 설계"에
/// 대응한다. 이 파일은 두 개의 전통 명리학 방법론을 **서로 다른 정적
/// 함수로 완전히 분리**해 구현하고, 마지막에 두 결과를 종합하는 함수를
/// 별도로 둔다 — 절대 하나의 뒤섞인 공식으로 합치지 않는다.
///
/// - [YongsinEngine.byEokbu] — 억부법(抑扶法): [StrengthProfile]의 신강/
///   신약 판정 결과를 바탕으로, 일간의 힘을 중화시키는 오행을 용신으로
///   삼는다(신강하면 설기/극제하는 오행, 신약하면 생조하는 오행).
/// - [YongsinEngine.byJohu] — 조후법(調候法): 월지(계절)의 한난조습
///   (寒暖燥濕)을 기준으로, 계절이 치우친 기후를 중화시키는 오행을
///   용신으로 삼는다(간이 조후법 — 아래 클래스 문서 참고).
/// - [YongsinEngine.combine] — 억부+조후 결과를 "조후 우선 원칙"(전통
///   명리학 정설: 극단적 계절 출생자는 조후가 억부보다 시급하다)에 따라
///   종합한다.
///
/// [절대 원칙 — 임의공식 아님] 이 엔진이 사용하는 모든 대응 관계
/// (희신=용신을 생하는 오행, 기신=용신을 극하는 오행, 구신=기신을 생하는
/// 오행)는 명리학 교과서에 정의된 **보편 고정 정의**이며, 개인별 생년월일
/// 해시나 랜덤과 무관하다. 조후법의 "겨울엔 火, 여름엔 水가 필요하다"는
/// 대응 역시 전통 명리학의 통상 원칙이다.
library;

import '../saju_engine.dart' show ganElement, sheng, ke;
import 'saju_profile.dart';

export 'strength_engine.dart' show relationCategoryOf, tenGodCategoryOf;

/// [sheng]의 역함수 — "누가 나를 생하는가". [strength_engine.dart]의
/// 동일 테이블을 중복 정의하지 않기 위해 여기서도 그대로 재선언(고정
/// 오행 상생표를 뒤집은 것으로, 재구현이 아니라 노출이다).
const Map<String, String> _invSheng = {
  '화': '목',
  '토': '화',
  '금': '토',
  '수': '금',
  '목': '수',
};

/// [ke]의 역함수 — "누가 나를 극하는가".
const Map<String, String> _invKe = {
  '토': '목',
  '수': '토',
  '화': '수',
  '금': '화',
  '목': '금',
};

/// 월지(月支) → 조후법 상 "특별히 보강이 필요한 오행"(간이 조후법).
///
/// [간이 조후법 명시] 정통 조후법(궁통보감/난강망)은 일간 10종 × 월지
/// 12종 = 120가지 조합마다 별도의 용신을 지정하는 매우 정교한 체계다.
/// 이번 PHASE 3에서는 "계절의 한난(寒暖)"만을 기준으로 하는 간이
/// 버전을 1차 구현하며(亥子丑 한겨울 → 火 필요, 巳午未 한여름 → 水
/// 필요, 그 외 봄/가을은 한난이 중화되어 조후 개입 불요), 일간별 세부
/// 정밀화는 후속 확장 과제로 남겨둔다 — 이는 계산 로직 누락이 아니라
/// 범위를 명시적으로 좁힌 설계 결정이며, 본 파일 상단 및 테스트에서
/// 명확히 문서화한다.
const Map<String, String> _johuNeedByMonthBranch = {
  '亥': '화', '子': '화', '丑': '화', // 한겨울 — 온난한 화 기운 필요
  '巳': '수', '午': '수', '未': '수', // 한여름 — 시원한 수 기운 필요
  // 寅卯辰(봄)/申酉戌(가을)은 한난이 중화되어 조후상 특별 요구 없음.
};

class YongsinEngine {
  YongsinEngine._();

  /// 억부법(抑扶法) — [strength]의 신강/신약 판정을 바탕으로 용신을
  /// 정한다.
  ///
  /// - 신강(身强): 일간의 힘이 넘치므로 이를 "설기(泄氣)하거나
  ///   극제(剋制)"하는 오행이 필요하다. 우선순위는 전통적으로 통용되는
  ///   "식상(설기) > 재성(설기+극) > 관살(직접 극제)" 순으로 두되,
  ///   [fiveElements]에 실제로 존재하는(개수>0) 오행을 우선 채택한다
  ///   (사주 원국에 이미 있는 기운을 용신으로 삼는 것이 "무근(無根)
  ///   용신"보다 안정적이라는 전통 원칙 — 8글자와 무관한 임의 선택이
  ///   아니라 실제 원국 구성에 근거한 결정이다).
  /// - 신약(身弱): 일간의 힘이 부족하므로 이를 "생조(生助)"하는
  ///   오행이 필요하다. 우선순위는 "인성 > 비겁" 순으로 두고 마찬가지로
  ///   실제 존재하는 오행을 우선 채택한다.
  static YongsinProfile byEokbu({
    required Pillar dayPillar,
    required StrengthProfile strength,
    required FiveElementsProfile fiveElements,
  }) {
    final dayElement = ganElement[dayPillar.stemHanja]!.$1;
    final reasoning = StringBuffer();
    reasoning.write(
      '억부법: 일간=${dayPillar.stemHanja}($dayElement), '
      '판정=${strength.verdict}(score=${strength.score.toStringAsFixed(2)}). ',
    );

    // 범주 → 오행 변환.
    String elementOfCategory(String category) {
      switch (category) {
        case '비겁':
          return dayElement;
        case '식상':
          return sheng[dayElement]!;
        case '재성':
          return ke[dayElement]!;
        case '관살':
          return _invKe[dayElement]!;
        case '인성':
          return _invSheng[dayElement]!;
        default:
          throw ArgumentError('알 수 없는 범주: $category');
      }
    }

    late final List<String> priority;
    if (strength.verdict == '신강') {
      priority = ['식상', '재성', '관살'];
    } else if (strength.verdict == '신약') {
      priority = ['인성', '비겁'];
    } else {
      // 중화: 이미 균형에 가까우므로, 신강 쪽에 더 가까운지(score>0.5)
      // 여부로 미세 조정 방향만 정한다 — 새 공식이 아니라 위 두 분기의
      // 재사용이다.
      priority = strength.score >= 0.5 ? ['식상', '재성', '관살'] : ['인성', '비겁'];
    }

    String? yongsinCategory;
    for (final cat in priority) {
      final el = elementOfCategory(cat);
      if ((fiveElements.totalCount[el] ?? 0) > 0) {
        yongsinCategory = cat;
        break;
      }
    }
    // 원국에 해당 오행이 하나도 없으면(무근) 우선순위 1순위를 그대로 채택.
    yongsinCategory ??= priority.first;
    final yongsinElement = elementOfCategory(yongsinCategory);
    reasoning.write(
      '우선순위=$priority 중 원국에 존재하는 첫 범주=$yongsinCategory'
      '(오행=$yongsinElement) 채택. ',
    );

    final heesinElement = _invSheng[yongsinElement]!; // 용신을 생하는 오행
    final gisinElement = _invKe[yongsinElement]!; // 용신을 극하는 오행
    final gusinElement = _invSheng[gisinElement]!; // 기신을 생하는 오행
    reasoning.write(
      '희신(용신을 생함)=$heesinElement, 기신(용신을 극함)=$gisinElement, '
      '구신(기신을 생함)=$gusinElement.',
    );

    return YongsinProfile(
      method: '억부',
      yongsin: yongsinElement,
      heesin: heesinElement,
      gisin: gisinElement,
      gusin: gusinElement,
      reasoning: reasoning.toString(),
    );
  }

  /// 조후법(調候法) — 월지(月支)의 계절 한난을 기준으로 용신을 정한다
  /// (간이 조후법 — 클래스 상단 [_johuNeedByMonthBranch] 문서 참고).
  ///
  /// 겨울(亥子丑)생이면 화(火)가, 여름(巳午未)생이면 수(水)가 필요하다.
  /// 봄(寅卯辰)/가을(申酉戌)생은 한난이 이미 중화되어 조후상 특별한
  /// 개입이 필요 없다고 보며, 이 경우 [YongsinProfile.yongsin]은 빈
  /// 문자열('')로 반환한다(= "조후 불요").
  static YongsinProfile byJohu({required Pillar monthPillar}) {
    final monthBranch = monthPillar.branchHanja;
    final need = _johuNeedByMonthBranch[monthBranch];
    final reasoning = StringBuffer('조후법(간이): 월지=$monthBranch. ');

    if (need == null) {
      reasoning.write('봄/가을철로 한난이 중화되어 조후상 특별한 용신이 필요 없다.');
      return YongsinProfile(
        method: '조후',
        yongsin: '',
        heesin: '',
        gisin: '',
        gusin: '',
        reasoning: reasoning.toString(),
      );
    }

    final heesinElement = _invSheng[need]!;
    final gisinElement = _invKe[need]!;
    final gusinElement = _invSheng[gisinElement]!;
    reasoning.write(
      '${need == '화' ? '한겨울(亥子丑)이므로 온난한 화(火)' : '한여름(巳午未)이므로 시원한 수(水)'}'
      '가 필요. 희신=$heesinElement, 기신=$gisinElement, 구신=$gusinElement.',
    );

    return YongsinProfile(
      method: '조후',
      yongsin: need,
      heesin: heesinElement,
      gisin: gisinElement,
      gusin: gusinElement,
      reasoning: reasoning.toString(),
    );
  }

  /// 억부+조후 종합 — "조후 우선 원칙"(전통 명리학 정설: 한겨울/한여름
  /// 출생자는 생존을 위협하는 극단적 기후를 조절하는 것이 일간의 힘을
  /// 조절하는 것보다 시급하다)에 따라 두 결과를 종합한다.
  ///
  /// - 조후법이 "불요"(빈 문자열)를 반환하면(봄/가을생) → 억부법 결과를
  ///   그대로 채택한다.
  /// - 조후법의 용신 오행이 억부법의 용신 오행과 같으면 → 두 방법이
  ///   일치하므로 그대로 채택(신뢰도가 더 높음을 reasoning에 명시).
  /// - 서로 다르면(겨울/여름생인데 억부법이 다른 오행을 요구) → 조후를
  ///   우선한다(전통 정설 적용).
  static YongsinProfile combine({
    required Pillar dayPillar,
    required Pillar monthPillar,
    required StrengthProfile strength,
    required FiveElementsProfile fiveElements,
  }) {
    final eokbu = byEokbu(
      dayPillar: dayPillar,
      strength: strength,
      fiveElements: fiveElements,
    );
    final johu = byJohu(monthPillar: monthPillar);

    if (johu.yongsin.isEmpty) {
      return YongsinProfile(
        method: '억부+조후',
        yongsin: eokbu.yongsin,
        heesin: eokbu.heesin,
        gisin: eokbu.gisin,
        gusin: eokbu.gusin,
        reasoning:
            '${eokbu.reasoning} / ${johu.reasoning} → '
            '조후 불요 계절이므로 억부법 결과를 채택.',
      );
    }

    if (johu.yongsin == eokbu.yongsin) {
      return YongsinProfile(
        method: '억부+조후',
        yongsin: eokbu.yongsin,
        heesin: eokbu.heesin,
        gisin: eokbu.gisin,
        gusin: eokbu.gusin,
        reasoning:
            '${eokbu.reasoning} / ${johu.reasoning} → '
            '억부법과 조후법의 용신이 일치(${eokbu.yongsin})하여 신뢰도 높음.',
      );
    }

    return YongsinProfile(
      method: '억부+조후',
      yongsin: johu.yongsin,
      heesin: johu.heesin,
      gisin: johu.gisin,
      gusin: johu.gusin,
      reasoning:
          '${eokbu.reasoning} / ${johu.reasoning} → '
          '억부법(${eokbu.yongsin})과 조후법(${johu.yongsin})이 불일치, '
          '전통 명리학의 "조후 우선 원칙"(극단적 계절 출생은 조후가 '
          '억부보다 시급)에 따라 조후법 결과(${johu.yongsin})를 채택.',
    );
  }
}
