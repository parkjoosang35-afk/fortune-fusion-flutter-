/// [정통사주 69종 개인화 해석 엔진 — 1단계] "사주 용어 → 사용자 언어"
/// 4단계 변환 계층.
///
/// 사용자 최종 지시 §8에 대응한다:
///   전문 용어 → 역학적 의미 → 현실적인 의미 → 쉬운 한국어
///
/// [설계 원칙] 이 파일은 "십신/오행/신살 같은 명리학 전문 개념 하나"를
/// 문장 조각으로 바꾸는 순수 변환 유틸리티만 제공한다. 어떤 계산도 하지
/// 않고, 카테고리별 관점(재물/직업/건강 등)에 따라 같은 개념이라도 다른
/// "현실적 의미"를 붙일 수 있도록 [TermMeaningView]를 카테고리 관점별로
/// 등록하는 구조로 만든다 — 사용자 최종 지시 §9 "같은 데이터라도
/// 카테고리에 따라 해석이 달라야 한다"를 용어 차원에서도 보장한다.
///
/// [기존 easy_terms.json과의 관계] 기존 사전은 "단어 하나 = 짧은 한글
/// 뜻"만 제공하는 툴팁용 사전이라(예: '정재' → '안정된 돈') 4단계 요구를
/// 만족하지 못한다. 이 파일은 그 사전을 완전히 대체하지 않고, 1단계
/// (전문용어) 표기값의 참고 소스로만 재사용할 수 있게 설계하되, 실제
/// 4단계(역학적 의미/현실적 의미/쉬운 한국어)는 이 파일에서 새로
/// 정의한다.
library;

/// 십신(十神) 하나에 대한 4단계 변환 결과.
class TenGodMeaning {
  const TenGodMeaning({
    required this.term,
    required this.symbolicMeaning,
    required this.practicalMeaningByCategory,
    required this.plainKorean,
  });

  /// ① 전문 용어(예: '정재').
  final String term;

  /// ② 역학적 의미(예: '일간이 극하면서 음양이 다른 오행 — 내가 다스릴
  /// 수 있는 안정적인 재물의 별').
  final String symbolicMeaning;

  /// ③ 현실적인 의미 — 카테고리 관점(예: 'wealth' | 'career' | 'health')
  /// 별로 다르게 등록한다. 예: wealth 관점 정재 → "매달 들어오는 월급처럼
  /// 예측 가능한 수입", career 관점 정재 → "예측 가능한 정규직·안정적
  /// 근무 형태 선호".
  final Map<String, String> practicalMeaningByCategory;

  /// ④ 쉬운 한국어 한 문장(카테고리 관점 지정 없이 범용으로 쓸 수 있는
  /// 기본 표현).
  final String plainKorean;

  /// [category]에 해당하는 현실적 의미가 없으면 plainKorean으로 대체한다.
  String practicalMeaningFor(String category) =>
      practicalMeaningByCategory[category] ?? plainKorean;
}

/// 십신 4단계 변환 사전 — 10천간 십신 전체를 등록한다.
///
/// [절대 원칙] 여기 등록된 모든 대응 관계는 명리학 교과서 수준의 보편
/// 정의(예: 정재=재성+음양 다름)를 문장으로 풀어쓴 것이며, 개인별 랜덤
/// 요소는 없다. 카테고리 관점(practicalMeaningByCategory)이 다르면 문장이
/// 달라지는 것은 "관점 차이"이지 "무작위"가 아니다.
const Map<String, TenGodMeaning> tenGodMeanings = {
  '비견': TenGodMeaning(
    term: '비견',
    symbolicMeaning: '일간과 오행·음양이 모두 같은 별 — 나와 대등한 동료·형제의 기운',
    practicalMeaningByCategory: {
      'wealth': '내 힘으로 버는 돈은 늘지만, 동업·형제간 재산 분쟁으로 나눠질 여지가 있는 구조',
      'career': '독립적으로 일하거나 동료와 협업할 때 힘을 발휘하는 성향',
      'personality': '자존심이 강하고 남에게 기대기보다 스스로 해내려는 성향',
    },
    plainKorean: '나와 대등한 동료·형제 같은 존재가 힘이 되기도 하고 경쟁이 되기도 해요.',
  ),
  '겁재': TenGodMeaning(
    term: '겁재',
    symbolicMeaning: '일간과 오행은 같으나 음양이 다른 별 — 경쟁·쟁탈의 기운',
    practicalMeaningByCategory: {
      'wealth': '동업·보증·투자 동참 등에서 재물이 새어나갈 위험이 있는 구조',
      'career': '경쟁이 치열한 환경에서 오히려 저력을 발휘하는 성향',
    },
    plainKorean: '경쟁자이자 자극제가 되는 존재가 인생에 자주 등장해요.',
  ),
  '식신': TenGodMeaning(
    term: '식신',
    symbolicMeaning: '일간이 생하면서 음양이 같은 별 — 재능을 안정적으로 표현하는 기운',
    practicalMeaningByCategory: {
      'wealth': '내 능력·재능을 꾸준히 활용해 안정적인 수입으로 연결하는 구조',
      'career': '전문성·기술을 살려 롱런하는 직업에서 유리한 성향',
      'health': '식생활을 즐기고 여유를 챙기는 성향 — 과식 관리가 필요할 수 있음',
    },
    plainKorean: '내 재능이나 취미가 자연스럽게 밥벌이로 이어지는 흐름이에요.',
  ),
  '상관': TenGodMeaning(
    term: '상관',
    symbolicMeaning: '일간이 생하면서 음양이 다른 별 — 창의적이고 튀는 표현의 기운',
    practicalMeaningByCategory: {
      'wealth': '아이디어·창작물로 큰 수입을 만들 수 있으나 변동성이 큰 구조',
      'career': '틀에 박히지 않은 창의적인 일, 프리랜서·1인 사업에서 두각',
    },
    plainKorean: '남들과 다른 아이디어와 표현력으로 존재감을 드러내는 힘이에요.',
  ),
  '편재': TenGodMeaning(
    term: '편재',
    symbolicMeaning: '일간이 극하면서 음양이 같은 별 — 유동적이고 활동적인 재물의 기운',
    practicalMeaningByCategory: {
      'wealth': '큰돈이 오가는 사업·투자·유동자산에서 기회를 잡는 구조 — 변동성도 큼',
      'career': '사업·영업·활동 반경이 넓은 일에서 힘을 발휘하는 성향',
    },
    plainKorean: '큰 돈이 들어오고 나가는 활동적인 재물의 흐름을 타고나셨어요.',
  ),
  '정재': TenGodMeaning(
    term: '정재',
    symbolicMeaning: '일간이 극하면서 음양이 다른 별 — 안정적이고 예측 가능한 재물의 기운',
    practicalMeaningByCategory: {
      'wealth': '매달 들어오는 월급처럼 예측 가능하고 꾸준히 쌓이는 수입 구조',
      'career': '예측 가능하고 안정적인 근무 형태·정규직을 선호하는 성향',
    },
    plainKorean: '꾸준히 모이고 예측 가능한, 성실한 축적형 재물운이에요.',
  ),
  '편관': TenGodMeaning(
    term: '편관',
    symbolicMeaning: '일간을 극하면서 음양이 같은 별 — 강한 압박과 도전의 기운',
    practicalMeaningByCategory: {
      'career': '위기와 압박 속에서 오히려 카리스마와 리더십이 드러나는 성향',
      'health': '스트레스·긴장이 누적되기 쉬워 긴장 완화 관리가 필요한 성향',
    },
    plainKorean: '시련을 통해 단련되고 강해지는 힘이 함께 있어요.',
  ),
  '정관': TenGodMeaning(
    term: '정관',
    symbolicMeaning: '일간을 극하면서 음양이 다른 별 — 질서와 명예를 지향하는 기운',
    practicalMeaningByCategory: {
      'career': '조직·규율 안에서 인정받고 승진하는 안정적인 경력 구조',
      'wealth': '직위나 신용에 기반한 안정적 수입 구조',
    },
    plainKorean: '규칙과 신뢰 속에서 인정받고 성장하는 힘이에요.',
  ),
  '편인': TenGodMeaning(
    term: '편인',
    symbolicMeaning: '일간을 생하면서 음양이 같은 별 — 독특하고 깊이 있는 탐구의 기운',
    practicalMeaningByCategory: {
      'career': '남들이 가지 않는 전문·예술·연구 분야에서 독자적 성취를 이루는 성향',
      'personality': '직관이 발달하고 혼자만의 몰입을 즐기는 성향',
    },
    plainKorean: '남들과 다른 방식으로 깊이 파고드는 탐구심이 강점이에요.',
  ),
  '정인': TenGodMeaning(
    term: '정인',
    symbolicMeaning: '일간을 생하면서 음양이 다른 별 — 배움과 보살핌을 받는 기운',
    practicalMeaningByCategory: {
      'career': '학업·자격증·연구 등 배움을 통한 경력 성장에 유리한 성향',
      'personality': '주변의 도움과 인복을 잘 받아들이는 성향',
    },
    plainKorean: '배움과 인복이 든든하게 뒷받침해 주는 흐름이에요.',
  ),
};

/// 신강/신약/중화 판정에 대한 4단계 변환.
class StrengthMeaning {
  const StrengthMeaning({
    required this.verdict,
    required this.symbolicMeaning,
    required this.plainKorean,
  });

  final String verdict; // '신강' | '중화' | '신약'
  final String symbolicMeaning;
  final String plainKorean;
}

const Map<String, StrengthMeaning> strengthMeanings = {
  '신강': StrengthMeaning(
    verdict: '신강',
    symbolicMeaning: '일간을 돕는 힘(비겁·인성)이 억누르는 힘보다 강한 상태',
    plainKorean: '스스로의 힘과 주관이 뚜렷해서, 밀어붙이는 추진력이 강한 편이에요.',
  ),
  '중화': StrengthMeaning(
    verdict: '중화',
    symbolicMeaning: '돕는 힘과 억누르는 힘이 균형을 이룬 상태',
    plainKorean: '한쪽으로 치우치지 않고 상황에 따라 유연하게 대응하는 균형감이 있어요.',
  ),
  '신약': StrengthMeaning(
    verdict: '신약',
    symbolicMeaning: '일간을 억누르는 힘(관살·식상·재성)이 돕는 힘보다 강한 상태',
    plainKorean: '주변 환경과 사람의 도움을 받을 때 힘이 배가되는 편이에요.',
  ),
};

/// 오행 하나에 대한 쉬운 한국어 표현(방향/색/속성 등 카테고리 무관 공통).
const Map<String, String> elementPlainKorean = {
  '목': '나무처럼 뻗어나가고 성장하려는 기운',
  '화': '불처럼 뜨겁고 표현하려는 기운',
  '토': '흙처럼 안정적이고 중재하는 기운',
  '금': '쇠처럼 단단하고 결단력 있는 기운',
  '수': '물처럼 유연하고 지혜로운 기운',
};

/// 십신 이름 문자열로 [TenGodMeaning]을 조회한다(없으면 null).
TenGodMeaning? tenGodMeaningOf(String tenGod) => tenGodMeanings[tenGod];
