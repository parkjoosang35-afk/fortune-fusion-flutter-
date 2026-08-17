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
    this.hanja = '',
    required this.shortMeaning,
    required this.symbolicMeaning,
    required this.practicalMeaningByCategory,
    required this.plainKorean,
  });

  /// ① 전문 용어(예: '정재').
  final String term;

  /// 한자 표기(예: '正財'). 용어 첫 등장 시 괄호 안에 함께 표기한다.
  final String hanja;

  /// [신규 — 용어 첫 등장 시 괄호 안에 넣을 3~6어절 짧은 쉬운 의미.
  /// 사용자 최종 지시 §5 예시 문구와 동일하게 등록한다(예: 비견 →
  /// '나와 비슷한 성향, 경쟁과 협력'). symbolicMeaning/plainKorean보다
  /// 짧아서 문장 중간에 자연스럽게 삽입할 수 있다.
  final String shortMeaning;

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
    hanja: '比肩',
    shortMeaning: '나와 비슷한 성향, 경쟁과 협력',
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
    hanja: '劫財',
    shortMeaning: '경쟁, 공동자원, 추진력과 관계된 기운',
    symbolicMeaning: '일간과 오행은 같으나 음양이 다른 별 — 경쟁·쟁탈의 기운',
    practicalMeaningByCategory: {
      'wealth': '동업·보증·투자 동참 등에서 재물이 새어나갈 위험이 있는 구조',
      'career': '경쟁이 치열한 환경에서 오히려 저력을 발휘하는 성향',
    },
    plainKorean: '경쟁자이자 자극제가 되는 존재가 인생에 자주 등장해요.',
  ),
  '식신': TenGodMeaning(
    term: '식신',
    hanja: '食神',
    shortMeaning: '표현, 실행, 생산성과 관련된 기운',
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
    hanja: '傷官',
    shortMeaning: '자유로운 표현, 창의성, 기존 방식에서 벗어나는 힘',
    symbolicMeaning: '일간이 생하면서 음양이 다른 별 — 창의적이고 튀는 표현의 기운',
    practicalMeaningByCategory: {
      'wealth': '아이디어·창작물로 큰 수입을 만들 수 있으나 변동성이 큰 구조',
      'career': '틀에 박히지 않은 창의적인 일, 프리랜서·1인 사업에서 두각',
    },
    plainKorean: '남들과 다른 아이디어와 표현력으로 존재감을 드러내는 힘이에요.',
  ),
  '편재': TenGodMeaning(
    term: '편재',
    hanja: '偏財',
    shortMeaning: '기회형 수입, 거래, 사업적 기회',
    symbolicMeaning: '일간이 극하면서 음양이 같은 별 — 유동적이고 활동적인 재물의 기운',
    practicalMeaningByCategory: {
      'wealth': '큰돈이 오가는 사업·투자·유동자산에서 기회를 잡는 구조 — 변동성도 큼',
      'career': '사업·영업·활동 반경이 넓은 일에서 힘을 발휘하는 성향',
    },
    plainKorean: '큰 돈이 들어오고 나가는 활동적인 재물의 흐름을 타고나셨어요.',
  ),
  '정재': TenGodMeaning(
    term: '정재',
    hanja: '正財',
    shortMeaning: '안정적인 수입, 관리, 현실적인 재물',
    symbolicMeaning: '일간이 극하면서 음양이 다른 별 — 안정적이고 예측 가능한 재물의 기운',
    practicalMeaningByCategory: {
      'wealth': '매달 들어오는 월급처럼 예측 가능하고 꾸준히 쌓이는 수입 구조',
      'career': '예측 가능하고 안정적인 근무 형태·정규직을 선호하는 성향',
    },
    plainKorean: '꾸준히 모이고 예측 가능한, 성실한 축적형 재물운이에요.',
  ),
  '편관': TenGodMeaning(
    term: '편관',
    hanja: '偏官',
    shortMeaning: '도전, 압박, 경쟁, 강한 책임',
    symbolicMeaning: '일간을 극하면서 음양이 같은 별 — 강한 압박과 도전의 기운',
    practicalMeaningByCategory: {
      'career': '위기와 압박 속에서 오히려 카리스마와 리더십이 드러나는 성향',
      'health': '스트레스·긴장이 누적되기 쉬워 긴장 완화 관리가 필요한 성향',
    },
    plainKorean: '시련을 통해 단련되고 강해지는 힘이 함께 있어요.',
  ),
  '정관': TenGodMeaning(
    term: '정관',
    hanja: '正官',
    shortMeaning: '책임, 조직, 직업적 역할',
    symbolicMeaning: '일간을 극하면서 음양이 다른 별 — 질서와 명예를 지향하는 기운',
    practicalMeaningByCategory: {
      'career': '조직·규율 안에서 인정받고 승진하는 안정적인 경력 구조',
      'wealth': '직위나 신용에 기반한 안정적 수입 구조',
    },
    plainKorean: '규칙과 신뢰 속에서 인정받고 성장하는 힘이에요.',
  ),
  '편인': TenGodMeaning(
    term: '편인',
    hanja: '偏印',
    shortMeaning: '독창적인 지식, 연구, 특별한 관심',
    symbolicMeaning: '일간을 생하면서 음양이 같은 별 — 독특하고 깊이 있는 탐구의 기운',
    practicalMeaningByCategory: {
      'career': '남들이 가지 않는 전문·예술·연구 분야에서 독자적 성취를 이루는 성향',
      'personality': '직관이 발달하고 혼자만의 몰입을 즐기는 성향',
    },
    plainKorean: '남들과 다른 방식으로 깊이 파고드는 탐구심이 강점이에요.',
  ),
  '정인': TenGodMeaning(
    term: '정인',
    hanja: '正印',
    shortMeaning: '배움, 보호, 정보와 준비',
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
    this.hanja = '',
    required this.symbolicMeaning,
    required this.plainKorean,
  });

  final String verdict; // '신강' | '중화' | '신약'

  /// 한자 표기(예: '身强'). 용어 첫 등장 시 괄호 안에 함께 표기한다.
  final String hanja;
  final String symbolicMeaning;
  final String plainKorean;
}

const Map<String, StrengthMeaning> strengthMeanings = {
  '신강': StrengthMeaning(
    verdict: '신강',
    hanja: '身强',
    symbolicMeaning: '일간을 돕는 힘(비겁·인성)이 억누르는 힘보다 강한 상태',
    plainKorean: '스스로의 힘과 주관이 뚜렷해서, 밀어붙이는 추진력이 강한 편이에요.',
  ),
  '중화': StrengthMeaning(
    verdict: '중화',
    hanja: '中和',
    symbolicMeaning: '돕는 힘과 억누르는 힘이 균형을 이룬 상태',
    plainKorean: '한쪽으로 치우치지 않고 상황에 따라 유연하게 대응하는 균형감이 있어요.',
  ),
  '신약': StrengthMeaning(
    verdict: '신약',
    hanja: '身弱',
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

// ============================================================
// [신규 — 정통사주 결과 해석 방식 최종 수정 지시] 십신 5대 그룹
// (비겁/식상/재성/관살/인성) 용어 설명.
//
// CareerAnalyzer/WealthAnalyzer 등은 개별 십신이 아니라 "관살 3개",
// "재성 2개"처럼 5대 그룹 단위로 evidence를 만든다(예: A03의
// 'tenGods+hiddenStems(5대범주 집계)'). 사용자 지시 §3의 재성 예시가
// 바로 이 그룹 용어를 가리키므로, 개별 십신과 별도로 그룹 용어의
// 쉬운 의미를 등록한다.
// ============================================================

/// 십신 5대 그룹(비겁/식상/재성/관살/인성) 하나에 대한 쉬운 의미.
class TenGodGroupMeaning {
  const TenGodGroupMeaning({
    required this.term,
    required this.hanja,
    required this.shortMeaning,
  });

  final String term;
  final String hanja;
  final String shortMeaning;
}

/// [절대 원칙] 아래 5개 그룹명과 한자는 명리학 교과서 수준의 보편 정의
/// (비겁=비견+겁재, 식상=식신+상관, 재성=정재+편재, 관살=정관+편관,
/// 인성=정인+편인)를 그대로 쓴 것이며 개인별 랜덤 요소는 없다.
const Map<String, TenGodGroupMeaning> tenGodGroupMeanings = {
  '비겁': TenGodGroupMeaning(
    term: '비겁',
    hanja: '比劫',
    shortMeaning: '나와 같은 힘, 협력과 경쟁의 상대를 함께 보는 기운',
  ),
  '식상': TenGodGroupMeaning(
    term: '식상',
    hanja: '食傷',
    shortMeaning: '표현하고 만들어내는 능력과 관련된 기운',
  ),
  '재성': TenGodGroupMeaning(
    term: '재성',
    hanja: '財星',
    shortMeaning: '돈을 벌고 관리하는 방식과 관련된 기운',
  ),
  '관살': TenGodGroupMeaning(
    term: '관살',
    hanja: '官殺',
    shortMeaning: '책임, 조직, 규율과 관련된 기운',
  ),
  '인성': TenGodGroupMeaning(
    term: '인성',
    hanja: '印星',
    shortMeaning: '배움, 보호, 준비와 관련된 기운',
  ),
};

// ============================================================
// [신규] 용신(用神)/기신(忌神) — 개념 자체에 대한 쉬운 설명.
//
// 용신/기신은 오행(목화토금수) 중 하나로 판정되므로, "용어 자체의 쉬운
// 의미"와 "이 사주에서 어떤 오행으로 나타나는가"를 분리해서 다룬다.
// ============================================================

const String yongsinHanja = '用神';
const String yongsinGeneralMeaning = '사주 전체의 균형을 잡는 데 도움이 되는 기운';

const String gisinHanja = '忌神';
const String gisinGeneralMeaning = '지나치게 강해질 경우 전체 균형을 흐트러뜨릴 수 있는 기운';

// ============================================================
// [신규] 신살(神殺) — sinsal_engine.dart가 실제로 산출하는 20종 전체에
// 대한 "이 사람에게 어떻게 작용하는가" 설명.
//
// [출처] assets/jeontong/rules/sinsal_rules.json(30개 신살의 kr/easy/
// meaning/effect 순수 해석 콘텐츠)을 1차 소스로 재사용하고, json에
// 없는 신살(년살/반안살 — 12신살 고유 명칭이라 json에 별도 항목이
// 없음)은 명리학 문헌상 통용되는 의미로 보강한다. 계산 로직과는 무관한
// 순수 해석 문구 사전이다.
// ============================================================

class SinsalMeaning {
  const SinsalMeaning({
    required this.nameKr,
    required this.hanja,
    required this.easyMeaning,
    required this.generalMeaning,
    required this.personalEffect,
  });

  /// 신살 이름(한글, [SinsalEntry.nameKr]과 동일한 표기 — 예: '천을귀인').
  final String nameKr;

  /// 한자 표기(예: '天乙貴人').
  final String hanja;

  /// 용어 첫 등장 시 괄호 안에 넣을 짧은 쉬운 의미(sinsal_rules.json의
  /// 'easy' 필드 기반).
  final String easyMeaning;

  /// 이 신살의 전통적 의미(sinsal_rules.json의 'meaning' 필드 기반).
  final String generalMeaning;

  /// "이 사람에게 어떻게 작용하는가"를 풀어 쓸 때 쓰는 현실적 효과 요약
  /// (sinsal_rules.json의 'effect' 필드 기반).
  final String personalEffect;
}

const Map<String, SinsalMeaning> sinsalMeanings = {
  '천을귀인': SinsalMeaning(
    nameKr: '천을귀인',
    hanja: '天乙貴人',
    easyMeaning: '최고의 귀인',
    generalMeaning: '위기 때 반드시 도와줄 사람이 나타나는 최고의 길신',
    personalEffect: '인복, 위기 극복, 귀인 조력, 명예',
  ),
  '문창귀인': SinsalMeaning(
    nameKr: '문창귀인',
    hanja: '文昌貴人',
    easyMeaning: '공부·문서·시험의 별',
    generalMeaning: '학문·시험·저술·자격증에 유리한 길신',
    personalEffect: '학업, 시험합격, 저술, 문서운',
  ),
  '역마': SinsalMeaning(
    nameKr: '역마',
    hanja: '驛馬',
    easyMeaning: '이동·여행의 별',
    generalMeaning: '이동·해외·이사·유학·무역에 강한 활동성',
    personalEffect: '이동, 해외, 이사, 활동 반경 확대',
  ),
  '역마살': SinsalMeaning(
    nameKr: '역마살',
    hanja: '驛馬殺',
    easyMeaning: '이동·여행의 별',
    generalMeaning: '이동·해외·이사·유학·무역에 강한 활동성',
    personalEffect: '이동, 해외, 이사, 활동 반경 확대',
  ),
  '공망': SinsalMeaning(
    nameKr: '공망',
    hanja: '空亡',
    easyMeaning: '비어있음',
    generalMeaning: '화려해도 실속이 없는, 해당 자리의 기운이 빈 상태',
    personalEffect: '실속 부족, 노력 대비 결과가 적을 수 있음',
  ),
  '겁살': SinsalMeaning(
    nameKr: '겁살',
    hanja: '劫殺',
    easyMeaning: '빼앗기는 별',
    generalMeaning: '재물·건강 손실을 주의해야 하는, 급작스러운 변고의 별',
    personalEffect: '손재, 사고, 도난 주의',
  ),
  '재살': SinsalMeaning(
    nameKr: '재살',
    hanja: '災殺',
    easyMeaning: '재난의 별',
    generalMeaning: '감옥·재난·구설을 조심해야 하는 별',
    personalEffect: '관재, 구설, 재난 주의',
  ),
  '천살': SinsalMeaning(
    nameKr: '천살',
    hanja: '天殺',
    easyMeaning: '하늘의 형벌',
    generalMeaning: '천재지변이나 윗사람과의 갈등을 조심해야 하는 별',
    personalEffect: '상사·윗사람과의 갈등, 예기치 못한 변수 주의',
  ),
  '지살': SinsalMeaning(
    nameKr: '지살',
    hanja: '地殺',
    easyMeaning: '이동의 별',
    generalMeaning: '역마와 비슷하게 이동·변동이 잦은 별',
    personalEffect: '이사, 이동, 변동',
  ),
  '년살': SinsalMeaning(
    nameKr: '년살',
    hanja: '年殺',
    easyMeaning: '인기·매력의 별(도화)',
    generalMeaning: '이성에게 인기가 많고 매력·예술적 감각이 두드러지는 별',
    personalEffect: '인기, 매력, 예술적 감각, 과할 땐 이성 문제 주의',
  ),
  '월살': SinsalMeaning(
    nameKr: '월살',
    hanja: '月殺',
    easyMeaning: '고초의 별',
    generalMeaning: '고독하거나 경제적으로 어려워질 수 있음을 주의하는 별',
    personalEffect: '고독감, 경제적 어려움 주의',
  ),
  '망신살': SinsalMeaning(
    nameKr: '망신살',
    hanja: '亡神殺',
    easyMeaning: '체면 손상',
    generalMeaning: '체면·명예가 손상되거나 구설수에 오를 수 있는 별',
    personalEffect: '구설, 명예 손상, 실수 주의',
  ),
  '장성살': SinsalMeaning(
    nameKr: '장성살',
    hanja: '將星殺',
    easyMeaning: '리더의 별',
    generalMeaning: '장군·리더의 기질을 타고나 조직을 통솔하는 힘이 있는 별',
    personalEffect: '리더십, 권위, 통솔력',
  ),
  '반안살': SinsalMeaning(
    nameKr: '반안살',
    hanja: '攀鞍殺',
    easyMeaning: '말안장의 별',
    generalMeaning: '말안장에 올라탄 것처럼 자리를 잡고 안정과 명예를 누리는 별',
    personalEffect: '지위 상승, 명예, 안정적인 자리매김',
  ),
  '육해살': SinsalMeaning(
    nameKr: '육해살',
    hanja: '六害殺',
    easyMeaning: '질병의 별',
    generalMeaning: '만성 질환이나 인간관계 갈등을 조심해야 하는 별',
    personalEffect: '지병, 인간관계 갈등 주의',
  ),
  '화개살': SinsalMeaning(
    nameKr: '화개살',
    hanja: '華蓋殺',
    easyMeaning: '예술·종교·고독',
    generalMeaning: '종교·예술·철학에 심취하는, 고독한 학자·구도자 성향의 별',
    personalEffect: '예술, 종교, 학문, 고독한 몰입',
  ),
  '양인살': SinsalMeaning(
    nameKr: '양인살',
    hanja: '羊刃殺',
    easyMeaning: '칼날의 별',
    generalMeaning: '강한 힘과 추진력을 상징하되 양날의 검처럼 다룰 수 있는 별',
    personalEffect: '강한 추진력, 권력 지향, 사고·수술 주의',
  ),
  '괴강살': SinsalMeaning(
    nameKr: '괴강살',
    hanja: '魁罡殺',
    easyMeaning: '큰 그릇',
    generalMeaning: '극단적인 길흉을 오가는, 크게 성공하거나 크게 흔들릴 수 있는 별',
    personalEffect: '큰 성공 또는 큰 시련, 강한 카리스마',
  ),
  '백호대살': SinsalMeaning(
    nameKr: '백호대살',
    hanja: '白虎大殺',
    easyMeaning: '혈광의 별',
    generalMeaning: '사고·수술 등 혈광(血光)을 조심해야 하는 별',
    personalEffect: '사고, 수술, 건강 관리 주의',
  ),
  '원진살': SinsalMeaning(
    nameKr: '원진살',
    hanja: '元辰殺',
    easyMeaning: '미워하는 별',
    generalMeaning: '특정 지지 조합에서 발생하는 감정적 갈등의 별',
    personalEffect: '감정 갈등, 오해, 관계 마찰 주의',
  ),
};

/// 신살 이름 문자열로 [SinsalMeaning]을 조회한다(없으면 null).
SinsalMeaning? sinsalMeaningOf(String nameKr) => sinsalMeanings[nameKr];

// ============================================================
// [신규 — 핵심] "용어 첫 등장 추적(term-first-occurrence tracking)".
//
// 사용자 최종 지시 §7 "용어 반복 금지": 같은 결과(하나의 FortuneNarrative
// 생성 과정) 안에서 동일 용어의 긴 설명을 반복하지 않는다. 첫 등장에는
// "용어(쉬운 의미)" 형태로 풀어 쓰고, 두 번째 이후에는 축약형만 쓴다.
//
// [사용법] 각 NarrativeGenerator.generate() 호출마다 새 [TermTracker]를
// 하나 만들어 로컬 변수로 들고 있다가, 문장을 만들 때마다 아래 helper
// 함수(tenGodPhrase/tenGodGroupPhrase/strengthPhrase/yongsinPhrase/
// gisinPhrase/sinsalPhrase)에 넘겨서 쓴다. 같은 tracker 인스턴스를
// 재사용하는 한, 동일 용어가 두 번째 등장할 때 자동으로 축약형이
// 나온다. tracker는 순수 상태 보관 객체이며 어떤 계산도 하지 않는다.
// ============================================================
class TermTracker {
  final Set<String> _introduced = <String>{};

  /// [key]가 처음 등장하는 것이면 true를 반환하며 이후 등장으로 기록한다.
  /// 이미 등장한 적이 있으면 false.
  bool introduce(String key) {
    if (_introduced.contains(key)) return false;
    _introduced.add(key);
    return true;
  }

  /// [key]가 이미 등장했는지만 확인한다(기록하지 않음).
  bool hasIntroduced(String key) => _introduced.contains(key);
}

/// 개별 십신([tenGodMeanings] 키) 용어 문구 — 첫 등장이면
/// "정재(안정적인 수입, 관리, 현실적인 재물)", 이후엔 "정재의 힘".
String tenGodPhrase(TermTracker tracker, String term) {
  final meaning = tenGodMeanings[term];
  if (meaning == null) return term;
  if (tracker.introduce('tenGod:$term')) {
    return '$term(${meaning.shortMeaning})';
  }
  return '$term의 힘';
}

/// 십신 5대 그룹([tenGodGroupMeanings] 키) 용어 문구 — 첫 등장이면
/// "재성(돈을 벌고 관리하는 방식과 관련된 기운)", 이후엔 "재성의 힘".
String tenGodGroupPhrase(TermTracker tracker, String term) {
  final meaning = tenGodGroupMeanings[term];
  if (meaning == null) return term;
  if (tracker.introduce('group:$term')) {
    return '$term(${meaning.shortMeaning})';
  }
  return '$term의 힘';
}

/// 신강/중화/신약 문구 — 첫 등장이면 한자+쉬운 의미를 함께, 이후엔
/// 용어만.
String strengthPhrase(TermTracker tracker, String verdict) {
  final meaning = strengthMeanings[verdict];
  if (meaning == null) return verdict;
  if (tracker.introduce('strength:$verdict')) {
    return '$verdict(${meaning.hanja}), 즉 ${meaning.symbolicMeaning}';
  }
  return verdict;
}

/// 용신 문구 — 첫 등장이면 개념 설명 + 이 사주의 오행을 함께, 이후엔
/// "용신인 OO"만.
String yongsinPhrase(TermTracker tracker, String element) {
  if (element.isEmpty) return '';
  if (tracker.introduce('yongsin')) {
    return '용신($yongsinHanja, $yongsinGeneralMeaning)은 이 사주에서 $element 기운으로 나타나요';
  }
  return '용신인 $element 기운';
}

/// 기신 문구 — 첫 등장이면 개념 설명 + 이 사주의 오행을 함께, 이후엔
/// "기신인 OO"만.
String gisinPhrase(TermTracker tracker, String element) {
  if (element.isEmpty) return '';
  if (tracker.introduce('gisin')) {
    return '기신($gisinHanja, $gisinGeneralMeaning)은 이 사주에서 $element 기운으로 나타나요';
  }
  return '기신인 $element 기운';
}

/// 신살 문구 — 첫 등장이면 "OO(한자, 쉬운 의미)이 함께 나타나요. 이
/// 사주에서는 [전통적 의미]이기 때문에, [현실적 효과] 쪽으로 작용할
/// 가능성을 봅니다." 형태의 완전한 설명, 이후엔 "OO 기운"만.
String sinsalPhrase(TermTracker tracker, String nameKr) {
  final meaning = sinsalMeanings[nameKr];
  if (meaning == null) return nameKr;
  if (tracker.introduce('sinsal:$nameKr')) {
    return '$nameKr(${meaning.hanja}, ${meaning.easyMeaning})이(가) 함께 나타나요. '
        '이 사주에서는 ${meaning.generalMeaning}이기 때문에, '
        '${meaning.personalEffect} 쪽으로 작용할 가능성을 봅니다.';
  }
  return '$nameKr 기운';
}
