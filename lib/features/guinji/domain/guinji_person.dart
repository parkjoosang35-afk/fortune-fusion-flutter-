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

  /// [귀인지도 실구현] 서버 응답(GET /guinji/maps/me의 members+relationships)을
  /// [GuinjiPerson]으로 매핑한다.
  ///
  /// - [member]: `{memberId, name, solarLunar, birthDate, birthTime,
  ///   birthTimeMissing, joined}` — `birthDate`('YYYY-MM-DD')를 표시용
  ///   "YYYY·MM·DD" 형식으로 변환한다.
  /// - [relation]: `{relationType, chemistryScore, ohaengEvidence:{mine,
  ///   other, reason}}` (없으면 아직 판정 전 — 이론상 발생하지 않지만
  ///   방어적으로 'inyeon'/0/''로 폴백한다).
  /// - [ohaeng]은 서버 응답에 직접 없으므로, `ohaengEvidence.other`(상대
  ///   본인의 오행 카운트, 한글 목/화/토/금/수 키)에서 최댓값 오행을 찾아
  ///   화면 표시용 영문 키(mok/hwa/to/geum/su)로 변환한다.
  factory GuinjiPerson.fromServerJson({
    required Map<String, dynamic> member,
    Map<String, dynamic>? relation,
  }) {
    final memberId = member['memberId'] as String? ?? '';
    final name = member['name'] as String? ?? '이름 없음';
    final birthDate = member['birthDate'] as String? ?? '';
    final birthParts = birthDate.split('-');
    final birthLabel = birthParts.length == 3
        ? '${birthParts[0]}·${birthParts[1]}·${birthParts[2]}'
        : birthDate;

    final relationType = relation?['relationType'] as String? ?? 'inyeon';
    final chemistryScore = (relation?['chemistryScore'] as num?)?.toInt() ?? 0;
    final ohaengEvidence =
        relation?['ohaengEvidence'] as Map<String, dynamic>? ?? const {};
    final reason = ohaengEvidence['reason'] as String? ?? '';
    final otherElements =
        ohaengEvidence['other'] as Map<String, dynamic>? ?? const {};

    return GuinjiPerson(
      id: memberId,
      name: name,
      birth: birthLabel,
      ohaeng: _dominantOhaengKey(otherElements),
      relation: relationType,
      score: chemistryScore,
      note: reason,
    );
  }

  /// 한글 오행 카운트 맵(예: {'목': 2, '화': 1, ...})에서 최댓값 오행을 찾아
  /// 화면 표시용 영문 키(mok/hwa/to/geum/su)로 변환한다. 값이 모두 0이거나
  /// 비어 있으면 기본값 'to'(토)로 폴백한다.
  static String _dominantOhaengKey(Map<String, dynamic> koreanCounts) {
    const koreanToKey = {
      '목': 'mok',
      '화': 'hwa',
      '토': 'to',
      '금': 'geum',
      '수': 'su',
    };
    String bestKr = '토';
    int bestCount = -1;
    for (final entry in koreanToKey.keys) {
      final count = (koreanCounts[entry] as num?)?.toInt() ?? 0;
      if (count > bestCount) {
        bestCount = count;
        bestKr = entry;
      }
    }
    return koreanToKey[bestKr]!;
  }
}

/// 관계 유형 순서(12라벨, priority 내림차순) — admin_web
/// `GUINJI_RELATION_TYPE_ORDER`(`guinji-relation-judger.ts`)와 동일한
/// 순서. [2026-09 12라벨 전환] 기존 5라벨(guin/oreunpal/inyeon/salrim/
/// horang) 순서를 대체했다.
const List<String> guinjiRelationOrder = [
  'CHEON_GWII',
  'NA_SALRIDA',
  'JORYEOK',
  'GACHI_GA',
  'NA_SALJINDA',
  'CHANG_GYIM',
  'GAMJEONG',
  'DEUNGDEUNG',
  'KKEURIDA',
  'GACHI_BICH',
  'JAGEUKJE',
  'GINGJANG',
];

/// [Phase G-3] 목데이터 — `GuinjiScreens.jsx`의 `SAMPLE_PEOPLE`을 그대로
/// 이식. 후속 Phase에서 실제 API 응답으로 교체된다.
const List<GuinjiPerson> guinjiSamplePeople = [
  GuinjiPerson(
    id: 'p1',
    name: '수아',
    birth: '2003·05·14',
    ohaeng: 'hwa',
    relation: 'CHEON_GWII',
    score: 92,
    note: '천을귀인 · 인성',
  ),
  GuinjiPerson(
    id: 'p2',
    name: '민서',
    birth: '2002·11·03',
    ohaeng: 'mok',
    relation: 'CHEON_GWII',
    score: 88,
    note: '월덕귀인 · 인성',
  ),
  GuinjiPerson(
    id: 'p3',
    name: '유진',
    birth: '2003·02·27',
    ohaeng: 'su',
    relation: 'JORYEOK',
    score: 81,
    note: '비견 · 같은 오행',
  ),
  GuinjiPerson(
    id: 'p4',
    name: '서연',
    birth: '2001·08·19',
    ohaeng: 'to',
    relation: 'JORYEOK',
    score: 76,
    note: '겁재 · 협력',
  ),
  GuinjiPerson(
    id: 'p5',
    name: '도윤',
    birth: '2002·07·06',
    ohaeng: 'geum',
    relation: 'GACHI_GA',
    score: 84,
    note: '천간합 · 서로 끌림',
  ),
  GuinjiPerson(
    id: 'p6',
    name: '하늘',
    birth: '2004·01·22',
    ohaeng: 'mok',
    relation: 'GACHI_GA',
    score: 72,
    note: '지지육합',
  ),
  GuinjiPerson(
    id: 'p7',
    name: '예린',
    birth: '2003·10·11',
    ohaeng: 'hwa',
    relation: 'NA_SALJINDA',
    score: 67,
    note: '식신 · 내가 돌봄',
  ),
  GuinjiPerson(
    id: 'p8',
    name: '지호',
    birth: '2002·04·30',
    ohaeng: 'geum',
    relation: 'JAGEUKJE',
    score: 74,
    note: '정관 · 성장 자극',
  ),
  GuinjiPerson(
    id: 'p9',
    name: '은채',
    birth: '2001·12·05',
    ohaeng: 'su',
    relation: 'JAGEUKJE',
    score: 63,
    note: '편관 · 도전',
  ),
  GuinjiPerson(
    id: 'p10',
    name: '태오',
    birth: '2003·06·17',
    ohaeng: 'to',
    relation: 'NA_SALJINDA',
    score: 71,
    note: '상관',
  ),
  GuinjiPerson(
    id: 'p11',
    name: '나연',
    birth: '2002·09·08',
    ohaeng: 'hwa',
    relation: 'CHEON_GWII',
    score: 79,
    note: '정인',
  ),
  GuinjiPerson(
    id: 'p12',
    name: '연우',
    birth: '2004·03·25',
    ohaeng: 'mok',
    relation: 'JORYEOK',
    score: 69,
    note: '비견',
  ),
];
