/// 귀인지도(Guinji Map) 참여자(지인) 데이터 모델.
///
/// [Phase G-3] 아직 백엔드 신규 테이블(guinji_map/map_member/relationship
/// 등, §5)이 구현되지 않았으므로, 이 Phase에서는 화면 뼈대 확정을 위한
/// 목데이터 소스로만 사용한다. 실제 RelationJudger 판정 결과 연동은
/// 후속 Phase에서 이 모델의 필드 구조를 그대로 API 응답 매핑에 재사용할
/// 수 있도록 설계했다.
class GuinjiPerson {
  const GuinjiPerson({
    required this.id,
    required this.name,
    required this.birth,
    required this.ohaeng,
    required this.relation,
    required this.score,
    required this.note,
  });

  final String id;
  final String name;

  /// 생년월일 표시용 문자열(예: "2003·05·14").
  final String birth;

  /// 오행 키: mok/hwa/to/geum/su.
  final String ohaeng;

  /// 관계 유형 키: guin/oreunpal/inyeon/salrim/horang.
  final String relation;

  /// 케미 점수(0~100).
  final int score;

  /// 명리학적 근거 짧은 메모(예: "천을귀인 · 인성").
  final String note;
}

/// 관계 유형 순서(안쪽 궤도 → 바깥쪽 궤도): 貴 → 同 → 緣 → 養 → 師.
const List<String> guinjiRelationOrder = [
  'guin',
  'oreunpal',
  'inyeon',
  'salrim',
  'horang',
];

/// [Phase G-3] 목데이터 — `GuinjiScreens.jsx`의 `SAMPLE_PEOPLE`을 그대로
/// 이식. 후속 Phase에서 실제 API 응답으로 교체된다.
const List<GuinjiPerson> guinjiSamplePeople = [
  GuinjiPerson(
    id: 'p1',
    name: '수아',
    birth: '2003·05·14',
    ohaeng: 'hwa',
    relation: 'guin',
    score: 92,
    note: '천을귀인 · 인성',
  ),
  GuinjiPerson(
    id: 'p2',
    name: '민서',
    birth: '2002·11·03',
    ohaeng: 'mok',
    relation: 'guin',
    score: 88,
    note: '월덕귀인 · 인성',
  ),
  GuinjiPerson(
    id: 'p3',
    name: '유진',
    birth: '2003·02·27',
    ohaeng: 'su',
    relation: 'oreunpal',
    score: 81,
    note: '비견 · 같은 오행',
  ),
  GuinjiPerson(
    id: 'p4',
    name: '서연',
    birth: '2001·08·19',
    ohaeng: 'to',
    relation: 'oreunpal',
    score: 76,
    note: '겁재 · 협력',
  ),
  GuinjiPerson(
    id: 'p5',
    name: '도윤',
    birth: '2002·07·06',
    ohaeng: 'geum',
    relation: 'inyeon',
    score: 84,
    note: '천간합 · 서로 끌림',
  ),
  GuinjiPerson(
    id: 'p6',
    name: '하늘',
    birth: '2004·01·22',
    ohaeng: 'mok',
    relation: 'inyeon',
    score: 72,
    note: '지지육합',
  ),
  GuinjiPerson(
    id: 'p7',
    name: '예린',
    birth: '2003·10·11',
    ohaeng: 'hwa',
    relation: 'salrim',
    score: 67,
    note: '식신 · 내가 돌봄',
  ),
  GuinjiPerson(
    id: 'p8',
    name: '지호',
    birth: '2002·04·30',
    ohaeng: 'geum',
    relation: 'horang',
    score: 74,
    note: '정관 · 성장 자극',
  ),
  GuinjiPerson(
    id: 'p9',
    name: '은채',
    birth: '2001·12·05',
    ohaeng: 'su',
    relation: 'horang',
    score: 63,
    note: '편관 · 도전',
  ),
  GuinjiPerson(
    id: 'p10',
    name: '태오',
    birth: '2003·06·17',
    ohaeng: 'to',
    relation: 'salrim',
    score: 71,
    note: '상관',
  ),
  GuinjiPerson(
    id: 'p11',
    name: '나연',
    birth: '2002·09·08',
    ohaeng: 'hwa',
    relation: 'guin',
    score: 79,
    note: '정인',
  ),
  GuinjiPerson(
    id: 'p12',
    name: '연우',
    birth: '2004·03·25',
    ohaeng: 'mok',
    relation: 'oreunpal',
    score: 69,
    note: '비견',
  ),
];
