// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_data.dart
// [궁합지도 Star Map 디자인 적용] design_handoff_gunghap_map.zip
// `design_files/gunghap/gh-data.js` 포팅본 — 8개 대분류 · 세부
// 카테고리 · 보고서 9개 장 · (디자인 확인용) 더미 "최근 기록" 데이터.
//
// ⚠️ 이번 턴 구현 범위 안내: 이 파일의 데이터는 전부 "디자인 그대로
// 보여주기" 목적의 정적 콘텐츠다. 실제 서비스에서는 세부 카테고리는
// 관리자 CMS에서 편집되고, "최근 기록"은 실제 사용자별 궁합 결과
// DB에서 와야 한다(정식 개발 지시서 §6, §10 참고 — 이번 턴에서는
// 백엔드를 구현하지 않는다).
// ═══════════════════════════════════════════════════════════════
library;

class GHMajor {
  const GHMajor(this.id, this.name, this.hanja, this.icon, this.desc);
  final String id;
  final String name;
  final String hanja;
  final String icon;
  final String desc;

  /// "연애 궁합" → "연애" (홈 2열 타일에서 " 궁합" 접미사 제거)
  String get shortName => name.replaceAll(' 궁합', '');
}

const List<GHMajor> ghMajors = [
  GHMajor('love', '연애 궁합', '戀', 'heart', '설렘에서 깊은 사랑까지, 두 마음의 온도'),
  GHMajor('marriage', '결혼 궁합', '婚', 'ring', '함께 꾸려갈 삶의 결과 흐름'),
  GHMajor('intimacy', '속궁합', '親', 'linked', '몸과 마음이 가까워지는 방식'),
  GHMajor('persona', '성격 궁합', '性', 'moons', '기질과 대화가 맞물리는 방식'),
  GHMajor('wealth', '재물 궁합', '財', 'gem', '돈을 대하는 두 사람의 태도'),
  GHMajor('business', '사업 궁합', '業', 'rise', '함께 일할 때 드러나는 합'),
  GHMajor('friend', '친구 궁합', '友', 'friends', '오래 곁에 둘 인연의 결'),
  GHMajor('family', '가족 궁합', '家', 'family', '가장 가까운 사이의 이해'),
];

GHMajor ghMajorById(String? id) =>
    ghMajors.firstWhere((m) => m.id == id, orElse: () => ghMajors.first);

class GHSub {
  const GHSub(this.name, this.desc);
  final String name;
  final String desc;
}

const Map<String, List<GHSub>> ghSubs = {
  'love': [
    GHSub('썸 궁합', '마음이 닿는 타이밍과 다가가는 방식'),
    GHSub('연애 궁합', '연인으로서 서로에게 주는 힘'),
    GHSub('짝사랑 궁합', '한쪽의 마음이 닿을 수 있는 길'),
    GHSub('재회 궁합', '다시 이어질 인연의 흐름'),
    GHSub('장거리 연애 궁합', '거리를 넘어서는 두 사람의 방식'),
    GHSub('애정표현 궁합', '사랑을 말하고 받아들이는 언어'),
    GHSub('이상형 궁합', '서로가 그리던 모습과의 거리'),
  ],
  'marriage': [
    GHSub('결혼 궁합', '평생을 함께할 인연의 결'),
    GHSub('부부 궁합', '한 집에서 맞춰가는 두 사람'),
    GHSub('신혼 궁합', '함께 시작하는 첫 몇 해의 흐름'),
    GHSub('배우자 궁합', '서로에게 어떤 배우자가 되는지'),
    GHSub('결혼 시기 궁합', '두 사람의 운이 모이는 때'),
    GHSub('생활 궁합', '일상의 습관과 리듬의 조화'),
    GHSub('노후 궁합', '오래 함께 걸어갈 길'),
  ],
  'intimacy': [
    GHSub('스킨십 궁합', '몸으로 전하는 마음의 속도'),
    GHSub('감정 친밀감 궁합', '속마음을 나누는 깊이'),
    GHSub('애정 온도 궁합', '두 사람이 편안한 온도 차이'),
    GHSub('로맨틱 궁합', '특별한 순간을 만드는 방식'),
    GHSub('밀착형·독립형 궁합', '함께와 혼자 사이의 균형'),
    GHSub('친밀감 소통 궁합', '가까움을 말로 나누는 법'),
  ],
  'persona': [
    GHSub('성격 궁합', '타고난 기질이 만나는 모습'),
    GHSub('대화 궁합', '말이 통하는 결과 속도'),
    GHSub('감정 궁합', '감정을 느끼고 표현하는 방식'),
    GHSub('가치관 궁합', '중요하게 여기는 것의 차이'),
    GHSub('갈등 궁합', '부딪힐 때와 풀어갈 때'),
    GHSub('공감 궁합', '서로의 마음을 알아채는 힘'),
    GHSub('리더십 궁합', '누가, 언제 앞장서는지'),
  ],
  'wealth': [
    GHSub('돈 관리 궁합', '함께 돈을 다루는 방식'),
    GHSub('소비 궁합', '쓰는 기준과 즐거움의 차이'),
    GHSub('저축 궁합', '모으는 속도와 인내의 결'),
    GHSub('재산 형성 궁합', '함께 키워가는 재물의 흐름'),
    GHSub('경제관념 궁합', '돈에 대한 기본 생각'),
    GHSub('투자 성향 궁합', '위험과 기회를 보는 눈'),
  ],
  'business': [
    GHSub('동업 궁합', '함께 일을 꾸릴 때의 합'),
    GHSub('창업 궁합', '시작하는 힘과 버티는 힘'),
    GHSub('CEO·파트너 궁합', '이끄는 사람과 받쳐주는 사람'),
    GHSub('업무 궁합', '일하는 방식과 속도의 조화'),
    GHSub('의사결정 궁합', '결정을 내리는 두 사람의 방식'),
    GHSub('금전 사업 궁합', '사업 속 돈의 흐름'),
    GHSub('조직관리 궁합', '사람을 이끄는 두 가지 방식'),
  ],
  'friend': [
    GHSub('절친 궁합', '오래 곁에 남을 우정의 결'),
    GHSub('친구 궁합', '편안하게 어울리는 방식'),
    GHSub('여행 궁합', '함께 떠났을 때의 리듬'),
    GHSub('직장 동료 궁합', '일터에서 서로에게 주는 힘'),
    GHSub('취미 궁합', '함께 즐길 수 있는 것들'),
    GHSub('라이벌 궁합', '서로를 자라게 하는 경쟁'),
    GHSub('인간관계 궁합', '사람을 대하는 두 사람의 방식'),
  ],
  'family': [
    GHSub('부모·자녀 궁합', '서로를 이해하는 세대의 거리'),
    GHSub('아버지·자녀 궁합', '말보다 깊은 마음의 결'),
    GHSub('어머니·자녀 궁합', '가장 가까운 마음의 흐름'),
    GHSub('형제·자매 궁합', '함께 자란 두 별의 관계'),
    GHSub('시부모·며느리 궁합', '새로운 가족이 맞춰가는 법'),
    GHSub('장인·장모·사위 궁합', '존중으로 이어지는 인연'),
    GHSub('가족 생활 궁합', '한 지붕 아래의 리듬'),
  ],
};

class GHReportSection {
  const GHReportSection(this.no, this.title, this.desc);
  final String no;
  final String title;
  final String desc;
}

const List<GHReportSection> ghReportSections = [
  GHReportSection('I', '두 사람의 관계 종합 해석', '두 사람의 인연을 한눈에 담은 풀이'),
  GHReportSection('II', '오행 조화 분석', '목·화·토·금·수의 분포와 상생·상극'),
  GHReportSection('III', '성격 및 기질 분석', '일간으로 보는 타고난 기질'),
  GHReportSection('IV', '연애 및 감정 관계', '마음을 표현하고 받아들이는 방식'),
  GHReportSection('V', '결혼 및 장기 관계', '오래 함께할 때의 흐름'),
  GHReportSection('VI', '재물 및 경제적 관계', '돈을 대하는 두 사람의 태도'),
  GHReportSection('VII', '관계의 장점', '서로에게 주는 힘'),
  GHReportSection('VIII', '갈등 가능성 및 주의 사항', '부딪히기 쉬운 지점과 푸는 법'),
  GHReportSection('IX', '관계 발전을 위한 조언', '함께 키워갈 수 있는 방향'),
];

/// 12 지지 시간 (KST, 30분 보정) — (한자, 한글, 시간대)
const List<(String, String, String)> ghHours = [
  ('子', '자시', '23:30–01:29'),
  ('丑', '축시', '01:30–03:29'),
  ('寅', '인시', '03:30–05:29'),
  ('卯', '묘시', '05:30–07:29'),
  ('辰', '진시', '07:30–09:29'),
  ('巳', '사시', '09:30–11:29'),
  ('午', '오시', '11:30–13:29'),
  ('未', '미시', '13:30–15:29'),
  ('申', '신시', '15:30–17:29'),
  ('酉', '유시', '17:30–19:29'),
  ('戌', '술시', '19:30–21:29'),
  ('亥', '해시', '21:30–23:29'),
];

/// [디자인 미리보기 전용] 홈 "최근 살펴본 궁합" 섹션 표시용 더미.
/// 실제 서비스에서는 로그인 사용자의 실제 결과 기록으로 대체되어야 한다.
class GHHistoryItem {
  const GHHistoryItem({
    required this.id,
    required this.a,
    required this.b,
    required this.majorId,
    required this.sub,
    required this.date,
    required this.paid,
  });
  final String id;
  final String a;
  final String b;
  final String majorId;
  final String sub;
  final String date;
  final bool paid;
}

const List<GHHistoryItem> ghRecentHistory = [
  GHHistoryItem(
    id: 'h1', a: '김지현', b: '이민준', majorId: 'love', sub: '썸 궁합',
    date: '2026 · 11 · 02', paid: true,
  ),
  GHHistoryItem(
    id: 'h2', a: '김지현', b: '박서연', majorId: 'friend', sub: '여행 궁합',
    date: '2026 · 10 · 27', paid: false,
  ),
];
