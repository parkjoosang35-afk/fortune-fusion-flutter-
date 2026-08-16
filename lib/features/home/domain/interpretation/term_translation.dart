/// [정통사주 69종 개인화 해석 엔진 — 1단계] "사주 용어 → 사용자 언어"
/// 4단계 변환 계층.
///
/// 사용자 최종 지시 §8 대응:
///   1단계 전문용어(예: '정재')
///   2단계 역학적 의미(예: '고정적이고 안정적인 재물 기운')
///   3단계 현실적 의미(예: '월급, 정기적인 수입, 저축형 자산')
///   4단계 쉬운 한국어(예: "매달 꼬박꼬박 들어오는 돈에 강한 편이에요")
///
/// [기존 easy_terms.json과의 차이] 기존 `assets/jeontong/easy_terms.json`
/// 은 "용어 툴팁"용 1행 사전(전문용어 → 쉬운말 1개)이라 이 4단계 요구를
/// 충족하지 못한다. 이 파일은 그 사전을 대체하지 않고, 새 목적(카테고리
/// 분석 결과를 문장으로 바꿀 때 쓰는 "의미 사슬")에 맞춰 별도로 둔다.
///
/// [절대 원칙] 여기 정의된 모든 대응은 명리학 교과서 수준의 보편 고정
/// 의미다 — 개인별 생년월일이나 랜덤과 무관하다. 개인화는 "어떤 용어가
/// 선택되는지"(Analyzer가 결정)에서 나오고, "그 용어가 무슨 뜻인지"는
/// 모든 사람에게 동일한 사전을 사용한다.
library;

/// 십신 하나에 대한 4단계 의미 사슬.
class TenGodMeaningChain {
  const TenGodMeaningChain({
    required this.term,
    required this.astrologicalMeaning,
    required this.practicalMeaning,
    required this.plainKorean,
  });

  /// 1단계: 전문용어(예: '정재').
  final String term;

  /// 2단계: 역학적 의미(예: '내가 극하면서 음양이 다른 오행 — 고정적
  /// 재물 기운').
  final String astrologicalMeaning;

  /// 3단계: 현실적 의미(예: '월급, 정기적인 수입, 저축형 자산').
  final String practicalMeaning;

  /// 4단계: 쉬운 한국어 서술(예: '매달 꼬박꼬박 들어오는 돈에 강한
  /// 편이에요').
  final String plainKorean;
}

/// 십신(정재/편재/정관/편관/식신/상관/정인/편인/비견/겁재) 4단계 사전.
const Map<String, TenGodMeaningChain> tenGodMeaningDictionary = {
  '정재': TenGodMeaningChain(
    term: '정재',
    astrologicalMeaning: '일간이 극(剋)하면서 음양이 다른 오행 — 고정적이고 안정적인 재물 기운',
    practicalMeaning: '월급, 정기적인 수입, 예금·저축형 자산, 성실하게 모은 재산',
    plainKorean: '매달 꾸준히 들어오는 돈이나 착실하게 모으는 재산 쪽에 강한 편이에요',
  ),
  '편재': TenGodMeaningChain(
    term: '편재',
    astrologicalMeaning: '일간이 극(剋)하면서 음양이 같은 오행 — 유동적이고 활동적인 재물 기운',
    practicalMeaning: '사업 수익, 투자, 유동자산, 큰 돈이 오가는 활동성 재물',
    plainKorean: '한 번에 크게 들어오고 나가는 돈, 사업이나 투자 쪽 흐름에 강한 편이에요',
  ),
  '정관': TenGodMeaningChain(
    term: '정관',
    astrologicalMeaning: '일간을 극(剋)하면서 음양이 다른 오행 — 질서와 명예의 기운',
    practicalMeaning: '공직, 조직 내 지위, 안정적인 직장, 사회적 신용',
    plainKorean: '조직 안에서 인정받고 자리를 잡아가는 흐름이 잘 맞는 편이에요',
  ),
  '편관': TenGodMeaningChain(
    term: '편관',
    astrologicalMeaning: '일간을 극(剋)하면서 음양이 같은 오행 — 도전과 시련, 통제의 기운',
    practicalMeaning: '강한 압박, 경쟁, 위기 상황에서의 돌파력, 카리스마',
    plainKorean: '힘든 상황을 정면으로 뚫고 나가는 힘이 있고, 위기에서 오히려 두각을 드러내는 편이에요',
  ),
  '식신': TenGodMeaningChain(
    term: '식신',
    astrologicalMeaning: '일간이 생(生)하면서 음양이 같은 오행 — 여유롭게 재능을 펼치는 기운',
    practicalMeaning: '표현력, 손재주, 의식주(먹고사는 복), 여유 있는 재능 활용',
    plainKorean: '자기 재능을 편안하게 풀어내면서 먹고사는 복이 따르는 편이에요',
  ),
  '상관': TenGodMeaningChain(
    term: '상관',
    astrologicalMeaning: '일간이 생(生)하면서 음양이 다른 오행 — 자유롭고 창의적인 표현 기운',
    practicalMeaning: '창의력, 언변, 자기주장, 틀을 깨는 재능',
    plainKorean: '남들과 다른 시각으로 표현하고 창의적인 아이디어를 내는 데 강한 편이에요',
  ),
  '정인': TenGodMeaningChain(
    term: '정인',
    astrologicalMeaning: '일간을 생(生)하면서 음양이 다른 오행 — 안정적으로 나를 돕는 기운',
    practicalMeaning: '학문, 자격증, 후원, 인복, 문서운',
    plainKorean: '배움과 주변의 도움을 받아 차근차근 성장하는 흐름이 강한 편이에요',
  ),
  '편인': TenGodMeaningChain(
    term: '편인',
    astrologicalMeaning: '일간을 생(生)하면서 음양이 같은 오행 — 독특하게 나를 돕는 기운',
    practicalMeaning: '독학, 특수 기술, 예술·종교적 감각, 남다른 시각',
    plainKorean: '정해진 길보다 자기만의 방식으로 배우고 익히는 데 강한 편이에요',
  ),
  '비견': TenGodMeaningChain(
    term: '비견',
    astrologicalMeaning: '일간과 오행·음양이 모두 같은 기운 — 동등한 협력자·경쟁자',
    practicalMeaning: '동료, 형제, 협업, 대등한 관계에서의 힘',
    plainKorean: '동료나 형제 같은 대등한 관계에서 힘을 얻는 편이에요',
  ),
  '겁재': TenGodMeaningChain(
    term: '겁재',
    astrologicalMeaning: '일간과 오행이 같고 음양만 다른 기운 — 경쟁과 나눔의 기운',
    practicalMeaning: '경쟁자, 동업, 재물 분산, 승부욕',
    plainKorean: '경쟁 속에서 오히려 자극을 받고, 나누고 함께하는 관계에서 힘이 나는 편이에요',
  ),
};

/// 신강/중화/신약 4단계 사전.
class StrengthMeaningChain {
  const StrengthMeaningChain({
    required this.astrologicalMeaning,
    required this.practicalMeaning,
    required this.plainKorean,
  });

  final String astrologicalMeaning;
  final String practicalMeaning;
  final String plainKorean;
}

const Map<String, StrengthMeaningChain> strengthMeaningDictionary = {
  '신강': StrengthMeaningChain(
    astrologicalMeaning: '일간을 돕는 비겁·인성의 힘이 극제·설기하는 힘보다 강한 상태',
    practicalMeaning: '주도적으로 상황을 끌고 가는 힘, 강한 추진력, 자기 확신',
    plainKorean: '기운 자체가 강해서 스스로 상황을 이끌어가는 힘이 좋은 편이에요',
  ),
  '중화': StrengthMeaningChain(
    astrologicalMeaning: '일간을 돕는 힘과 억누르는 힘이 균형을 이룬 상태',
    practicalMeaning: '유연한 대처력, 상황에 맞춰 강약을 조절하는 균형 감각',
    plainKorean: '한쪽으로 치우치지 않고 상황에 맞춰 균형 있게 대처하는 편이에요',
  ),
  '신약': StrengthMeaningChain(
    astrologicalMeaning: '일간을 억누르는 관살·식상·재성의 힘이 돕는 힘보다 강한 상태',
    practicalMeaning: '주변의 도움과 지지가 있을 때 더 힘을 내는 성향, 신중한 판단력',
    plainKorean: '혼자 밀어붙이기보다 주변의 도움을 받을 때 훨씬 힘을 내는 편이에요',
  ),
};

/// 오행 하나의 4단계 사전(용신/기신 등에서 재사용).
class ElementMeaningChain {
  const ElementMeaningChain({
    required this.astrologicalMeaning,
    required this.plainKorean,
  });

  final String astrologicalMeaning;
  final String plainKorean;
}

const Map<String, ElementMeaningChain> elementMeaningDictionary = {
  '목': ElementMeaningChain(
    astrologicalMeaning: '성장·확장의 기운',
    plainKorean: '새로운 것을 시작하고 뻗어나가는 기운',
  ),
  '화': ElementMeaningChain(
    astrologicalMeaning: '표현·확산의 기운',
    plainKorean: '적극적으로 드러내고 활발하게 움직이는 기운',
  ),
  '토': ElementMeaningChain(
    astrologicalMeaning: '중재·축적의 기운',
    plainKorean: '차분히 중심을 잡고 쌓아가는 기운',
  ),
  '금': ElementMeaningChain(
    astrologicalMeaning: '결단·정리의 기운',
    plainKorean: '분명하게 정리하고 결단을 내리는 기운',
  ),
  '수': ElementMeaningChain(
    astrologicalMeaning: '지혜·유연함의 기운',
    plainKorean: '유연하게 흐르며 지혜롭게 대응하는 기운',
  ),
};

/// 십신 이름 → 5대 범주(비겁/식상/재성/관살/인성) 및 그 범주의 의미.
class TenGodCategoryMeaning {
  const TenGodCategoryMeaning({
    required this.category,
    required this.astrologicalMeaning,
    required this.practicalMeaning,
    required this.plainKorean,
  });

  /// 1단계: 범주명(비겁/식상/재성/관살/인성).
  final String category;

  /// 2단계: 역학적 의미.
  final String astrologicalMeaning;

  /// 3단계: 현실적 의미.
  final String practicalMeaning;

  /// 4단계: 쉬운 한국어.
  final String plainKorean;
}

/// 5대 범주(비겁/식상/재성/관살/인성) 4단계 사전.
/// [strength_engine.dart]/[yongsin_engine.dart]가 사용하는 범주 이름과
/// 정확히 일치해야 한다(범주 이름 불일치 시 조회 실패).
const Map<String, TenGodCategoryMeaning> tenGodCategoryMeaningDictionary = {
  '비겁': TenGodCategoryMeaning(
    category: '비겁',
    astrologicalMeaning: '일간과 오행이 같은 기운 — 나 자신과 동류(비견/겁재)의 힘',
    practicalMeaning: '자립심, 협업·경쟁 관계, 형제·동료 운, 재물을 나누는 힘',
    plainKorean: '스스로 힘을 내고, 동료·형제 같은 대등한 관계에서 에너지를 얻는 편이에요',
  ),
  '식상': TenGodCategoryMeaning(
    category: '식상',
    astrologicalMeaning: '일간이 생(生)하는 오행 — 내가 밖으로 표현하는 힘(식신/상관)',
    practicalMeaning: '재능 표현, 언변, 창의력, 의식주(먹고사는 활동), 자녀운',
    plainKorean: '자기 재능이나 생각을 밖으로 표현하는 힘이 강한 편이에요',
  ),
  '재성': TenGodCategoryMeaning(
    category: '재성',
    astrologicalMeaning: '일간이 극(剋)하는 오행 — 내가 다루고 소유하는 힘(정재/편재)',
    practicalMeaning: '재물, 수입, 소유욕, 현실적 성취, 배우자운(남성 기준)',
    plainKorean: '돈이나 실질적인 성과를 만들고 관리하는 힘이 있는 편이에요',
  ),
  '관살': TenGodCategoryMeaning(
    category: '관살',
    astrologicalMeaning: '일간을 극(剋)하는 오행 — 나를 통제·시험하는 힘(정관/편관)',
    practicalMeaning: '조직·규율, 책임감, 압박과 시련, 명예, 배우자운(여성 기준)',
    plainKorean: '책임과 규율 속에서 단련되고, 시련을 통해 성장하는 흐름이 있는 편이에요',
  ),
  '인성': TenGodCategoryMeaning(
    category: '인성',
    astrologicalMeaning: '일간을 생(生)하는 오행 — 나를 돕고 채워주는 힘(정인/편인)',
    practicalMeaning: '학문, 후원, 인복, 문서·자격증운, 정신적 안정',
    plainKorean: '배움과 주변의 도움을 받으며 채워지고 성장하는 힘이 있는 편이에요',
  ),
};

/// [문장 생성 유틸] 용신/기신 오행을 받아 "쉬운 한국어" 설명을 만든다.
/// Analyzer가 아니라 NarrativeGenerator 계층에서 호출하는 순수 함수다.
String describeElementPlain(String element) {
  final chain = elementMeaningDictionary[element];
  if (chain == null) return element;
  return chain.plainKorean;
}

String describeTenGodPlain(String tenGod) {
  final chain = tenGodMeaningDictionary[tenGod];
  if (chain == null) return tenGod;
  return chain.plainKorean;
}

String describeStrengthPlain(String verdict) {
  final chain = strengthMeaningDictionary[verdict];
  if (chain == null) return verdict;
  return chain.plainKorean;
}

String describeTenGodCategoryPlain(String category) {
  final chain = tenGodCategoryMeaningDictionary[category];
  if (chain == null) return category;
  return chain.plainKorean;
}
