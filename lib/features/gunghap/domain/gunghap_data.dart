// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_data.dart
// [궁합지도 전면 리디자인 v4] design_handoff_gunghap_map_v4
// `00_DEV_MAPPING.md` §2-3·§2-4·§5·§6·§7 + `flutter_starter/lib/
// gunghap/model/gunghap_models.dart`(v3 참고 구현) 포팅.
//
// [하위 호환] `GHMajor.shortName` getter(5곳 호출), `GHSub(name, desc)`
// 2-인자 생성(관리자 전용 코드가 있을 수 있음), `ghMajorById`,
// `ghReportSections`(과거 9장 고정 리스트 — 어디서도 참조되지 않음을
// grep으로 확인했으므로 v4의 6장 동적 함수로 안전하게 교체) 전부 이름을
// 유지한다. `GHSub`는 v4 `SubCat`과 동일한 필드(name/desc/axes)를 갖도록
// 확장하고, `axes`를 생략 가능한 선택 인자로 둬 기존 2-인자 리터럴과
// 호환시킨다 — `SubCat`은 `GHSub`의 typedef 별칭으로 제공해 v4 포팅
// 코드(§5 S22 등)가 `SubCat`이라는 이름을 그대로 써도 동작하게 한다.
// ═══════════════════════════════════════════════════════════════
library;

import 'gunghap_map_models.dart' show MapPerson;

// ─── 대분류 8 ───────────────────────────────────────────
class GHMajor {
  const GHMajor(this.id, this.name, this.short, this.hanja, this.icon, this.desc);
  final String id;
  final String name;

  /// "연애 궁합" → "연애" (v4 Major.short과 동일 — 홈 칩/2열 타일 표기).
  final String short;
  final String hanja;
  final String icon;
  final String desc;

  /// 하위 호환 별칭 — 기존 코드가 `major.shortName`으로 호출하던 것을
  /// 그대로 지원한다(§2-3 `short` 필드와 동일 값).
  String get shortName => short;
}

const List<GHMajor> ghMajors = [
  GHMajor('love', '연애 궁합', '연애', '戀', 'heart', '설렘에서 깊은 사랑까지, 두 마음의 온도'),
  GHMajor('marriage', '결혼 궁합', '결혼', '婚', 'ring', '함께 꾸려갈 삶의 결과 흐름'),
  GHMajor('intimacy', '속궁합', '속궁합', '親', 'linked', '몸과 마음이 가까워지는 방식'),
  GHMajor('persona', '성격 궁합', '성격', '性', 'moons', '기질과 대화가 맞물리는 방식'),
  GHMajor('wealth', '재물 궁합', '재물', '財', 'gem', '돈을 대하는 두 사람의 태도'),
  GHMajor('business', '사업 궁합', '사업', '業', 'rise', '함께 일할 때 드러나는 합'),
  GHMajor('friend', '친구 궁합', '친구', '友', 'friends', '오래 곁에 둘 인연의 결'),
  GHMajor('family', '가족 궁합', '가족', '家', 'family', '가장 가까운 사이의 이해'),
];

GHMajor ghMajorById(String? id) =>
    ghMajors.firstWhere((m) => m.id == id, orElse: () => ghMajors.first);

// ─── 세부 54 · 보고서 3축 ───────────────────────────────
const ghDefaultAxes = ['관계의 흐름', '서로에게 주는 힘', '함께 넘어야 할 지점'];

class GHSub {
  const GHSub(this.name, this.desc, [this.axes = ghDefaultAxes]);
  final String name;
  final String desc;

  /// 보고서 II·III·IV 장 제목 = 결과 항목별 점수 3행 제목(§5 S22).
  final List<String> axes;
}

/// v4 참고 코드가 쓰는 이름(`SubCat`)의 하위 호환 별칭 — 동일 타입.
typedef SubCat = GHSub;

const Map<String, List<GHSub>> ghSubs = {
  'love': [
    GHSub('썸 궁합', '마음이 닿는 타이밍과 다가가는 방식', [
      '마음이 닿는 타이밍',
      '먼저 다가가는 사람',
      '연인으로 넘어가는 시점',
    ]),
    GHSub('연애 궁합', '연인으로서 서로에게 주는 힘', [
      '연인으로서의 끌림',
      '데이트의 리듬',
      '오래 가는 연애의 조건',
    ]),
    GHSub('짝사랑 궁합', '한쪽의 마음이 닿을 수 있는 길', [
      '상대가 느끼는 나의 인상',
      '마음이 전해지는 방식',
      '다가가기 좋은 때',
    ]),
    GHSub('재회 궁합', '다시 이어질 인연의 흐름', [
      '헤어짐의 원인이 된 기운',
      '다시 이어질 흐름',
      '같은 갈등을 피하는 법',
    ]),
    GHSub('장거리 연애 궁합', '거리를 넘어서는 두 사람의 방식', [
      '거리가 주는 영향',
      '연락의 온도',
      '다시 만나는 날의 흐름',
    ]),
    GHSub('애정표현 궁합', '사랑을 말하고 받아들이는 언어', [
      '사랑을 말하는 언어',
      '받고 싶은 표현',
      '표현의 엇갈림 풀기',
    ]),
    GHSub('이상형 궁합', '서로가 그리던 모습과의 거리', [
      '내가 그리던 모습과의 거리',
      '상대가 그리던 모습과의 거리',
      '서로를 이상형으로 만드는 점',
    ]),
  ],
  'marriage': [
    GHSub('결혼 궁합', '평생을 함께할 인연의 결', [
      '평생 인연의 결',
      '함께 꾸릴 가정의 모습',
      '결혼 후 달라지는 흐름',
    ]),
    GHSub('부부 궁합', '한 집에서 맞춰가는 두 사람', ['한 집의 역할 나눔', '부부 대화의 결', '위기를 넘기는 힘']),
    GHSub('신혼 궁합', '함께 시작하는 첫 몇 해의 흐름', [
      '첫 몇 해의 생활 리듬',
      '맞춰 가야 할 습관',
      '신혼의 갈등 지점',
    ]),
    GHSub('배우자 궁합', '서로에게 어떤 배우자가 되는지', [
      '나는 어떤 배우자인가',
      '상대는 어떤 배우자인가',
      '서로에게 바라는 배우자상',
    ]),
    GHSub('결혼 시기 궁합', '두 사람의 운이 모이는 때', [
      '두 사람의 운이 모이는 해',
      '서두르지 않아야 할 때',
      '준비가 무르익는 신호',
    ]),
    GHSub('생활 궁합', '일상의 습관과 리듬의 조화', ['하루의 리듬', '공간과 살림의 취향', '쉬는 방식의 차이']),
    GHSub('노후 궁합', '오래 함께 걸어갈 길', ['오래 함께 걷는 힘', '건강과 돌봄의 흐름', '노년의 대화']),
  ],
  'intimacy': [
    GHSub('스킨십 궁합', '몸으로 전하는 마음의 속도', ['다가가는 속도', '편안함을 느끼는 거리', '몸으로 전하는 마음']),
    GHSub('감정 친밀감 궁합', '속마음을 나누는 깊이', ['속마음을 여는 깊이', '감정을 나누는 방식', '가까워지는 계기']),
    GHSub('애정 온도 궁합', '두 사람이 편안한 온도 차이', [
      '두 사람의 애정 온도',
      '온도 차가 생기는 때',
      '온도를 맞추는 법',
    ]),
    GHSub('로맨틱 궁합', '특별한 순간을 만드는 방식', ['설렘을 만드는 방식', '특별한 날의 취향', '일상 속 로맨스']),
    GHSub('밀착형·독립형 궁합', '함께와 혼자 사이의 균형', [
      '함께와 혼자의 균형',
      '서운함이 생기는 지점',
      '서로의 공간 존중',
    ]),
    GHSub('친밀감 소통 궁합', '가까움을 말로 나누는 법', ['가까움을 말로 나누기', '원하는 것을 묻는 법', '어긋날 때의 대화']),
  ],
  'persona': [
    GHSub('성격 궁합', '타고난 기질이 만나는 모습', ['타고난 기질의 만남', '서로를 편하게 하는 점', '부딪히는 기질']),
    GHSub('대화 궁합', '말이 통하는 결과 속도', ['말이 통하는 결', '대화의 속도', '오해가 생기는 말버릇']),
    GHSub('감정 궁합', '감정을 느끼고 표현하는 방식', [
      '감정을 느끼는 방식',
      '감정을 표현하는 방식',
      '감정이 엇갈릴 때',
    ]),
    GHSub('가치관 궁합', '중요하게 여기는 것의 차이', ['중요하게 여기는 것', '양보하기 어려운 것', '함께 지킬 가치']),
    GHSub('갈등 궁합', '부딪힐 때와 풀어갈 때', ['부딪히는 주제', '싸우는 방식', '화해의 방식']),
    GHSub('공감 궁합', '서로의 마음을 알아채는 힘', ['마음을 알아채는 힘', '위로하는 방식', '공감이 엇갈리는 때']),
    GHSub('리더십 궁합', '누가, 언제 앞장서는지', ['누가 앞장서는가', '결정의 주도권', '따라가는 사람의 힘']),
  ],
  'wealth': [
    GHSub('돈 관리 궁합', '함께 돈을 다루는 방식', ['돈을 다루는 방식', '공동 관리의 역할', '지출 결정의 기준']),
    GHSub('소비 궁합', '쓰는 기준과 즐거움의 차이', ['쓰는 즐거움의 차이', '충동과 절제', '함께 쓰는 돈']),
    GHSub('저축 궁합', '모으는 속도와 인내의 결', ['모으는 속도', '목표를 세우는 방식', '함께 모으는 힘']),
    GHSub('재산 형성 궁합', '함께 키워가는 재물의 흐름', [
      '재물이 모이는 흐름',
      '함께 키우는 자산',
      '재물운이 강한 시기',
    ]),
    GHSub('경제관념 궁합', '돈에 대한 기본 생각', ['돈에 대한 기본 생각', '안정과 도전의 균형', '돈 이야기의 온도']),
    GHSub('투자 성향 궁합', '위험과 기회를 보는 눈', ['위험을 보는 눈', '기회를 잡는 속도', '함께 투자할 때의 역할']),
  ],
  'business': [
    GHSub('동업 궁합', '함께 일을 꾸릴 때의 합', ['함께 일할 때의 합', '지분과 역할', '동업이 흔들리는 때']),
    GHSub('창업 궁합', '시작하는 힘과 버티는 힘', ['시작하는 힘', '버티는 힘', '창업에 좋은 시기']),
    GHSub('CEO·파트너 궁합', '이끄는 사람과 받쳐주는 사람', [
      '이끄는 사람과 받치는 사람',
      '결정과 실행의 분담',
      '신뢰가 쌓이는 방식',
    ]),
    GHSub('업무 궁합', '일하는 방식과 속도의 조화', ['일하는 방식', '속도와 꼼꼼함', '협업의 시너지']),
    GHSub('의사결정 궁합', '결정을 내리는 두 사람의 방식', [
      '결정을 내리는 방식',
      '판단이 갈릴 때',
      '최종 결정의 원칙',
    ]),
    GHSub('금전 사업 궁합', '사업 속 돈의 흐름', ['사업 속 돈의 흐름', '수익과 투자 판단', '금전 갈등 예방']),
    GHSub('조직관리 궁합', '사람을 이끄는 두 가지 방식', ['사람을 이끄는 방식', '조직 속 역할', '갈등 관리']),
  ],
  'friend': [
    GHSub('절친 궁합', '오래 곁에 남을 우정의 결', ['오래 가는 우정의 결', '속마음을 나누는 깊이', '멀어지지 않는 법']),
    GHSub('친구 궁합', '편안하게 어울리는 방식', ['편안하게 어울리는 방식', '서로에게 주는 힘', '서운함이 생기는 때']),
    GHSub('여행 궁합', '함께 떠났을 때의 리듬', ['여행의 리듬', '계획형과 즉흥형', '여행지에서의 갈등']),
    GHSub('직장 동료 궁합', '일터에서 서로에게 주는 힘', ['일터에서의 합', '서로에게 주는 도움', '거리 조절']),
    GHSub('취미 궁합', '함께 즐길 수 있는 것들', ['함께 즐길 수 있는 것', '즐기는 방식의 차이', '새로 시작하기 좋은 것']),
    GHSub('라이벌 궁합', '서로를 자라게 하는 경쟁', ['서로를 자라게 하는 경쟁', '경쟁이 상처가 될 때', '선의의 경쟁 방법']),
    GHSub('인간관계 궁합', '사람을 대하는 두 사람의 방식', ['사람을 대하는 방식', '함께 있는 모임의 분위기', '서로의 인맥']),
  ],
  'family': [
    GHSub('부모·자녀 궁합', '서로를 이해하는 세대의 거리', ['세대의 거리', '기대와 부담', '서로를 이해하는 법']),
    GHSub('아버지·자녀 궁합', '말보다 깊은 마음의 결', ['말보다 깊은 마음', '표현의 방식', '가까워지는 계기']),
    GHSub('어머니·자녀 궁합', '가장 가까운 마음의 흐름', ['가장 가까운 마음', '간섭과 걱정의 경계', '서로를 놓아주는 법']),
    GHSub('형제·자매 궁합', '함께 자란 두 별의 관계', ['함께 자란 기운', '비교와 경쟁', '어른이 된 뒤의 관계']),
    GHSub('시부모·며느리 궁합', '새로운 가족이 맞춰가는 법', [
      '새 가족의 첫 결',
      '기대의 차이',
      '존중의 거리',
    ]),
    GHSub('장인·장모·사위 궁합', '존중으로 이어지는 인연', ['신뢰가 쌓이는 방식', '어려워하는 지점', '편해지는 계기']),
    GHSub('가족 생활 궁합', '한 지붕 아래의 리듬', ['한 지붕 아래의 리듬', '가족 안의 역할', '함께하는 시간']),
  ],
};

/// 세부 축약 (점수 원 라벨 「{축약} 점수」) — '썸 궁합' → '썸'
String ghSubShort(String sub) => sub.replaceAll(' 궁합', '');

List<String> ghAxesOf(String sub) {
  for (final list in ghSubs.values) {
    for (final s in list) {
      if (s.name == sub) return s.axes;
    }
  }
  return ghDefaultAxes;
}

// ─── 이미지 경로(§8) ────────────────────────────────────
const ghArtBase = 'assets/gunghap/art/web/';

String ghArtSquare(String majorId) => '${ghArtBase}sq/$majorId.jpg';

String ghArtSub(String majorId, String sub) {
  final i = (ghSubs[majorId] ?? const []).indexWhere((s) => s.name == sub);
  return i < 0 ? ghArtSquare(majorId) : '${ghArtBase}sub/$majorId-${i + 1}.jpg';
}

/// BoxFit.cover + Alignment(0, y). 기본 0.5 (세로 75%)
const ghArtAlignY = {'intimacy-1': -0.1, 'family-7': 0.24, 'friend-1': 0.36, 'love-7': 0.28};

double ghArtAlign(String majorId, String sub) {
  final i = (ghSubs[majorId] ?? const []).indexWhere((s) => s.name == sub);
  return ghArtAlignY['$majorId-${i + 1}'] ?? 0.5;
}

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

// ─── 보고서 6장(§5 S22 · 선택 세부 전용) ───────────────────
// [교체 사유] 과거 9장 고정 `ghReportSections`(const List) 는 grep 결과
// 코드베이스 어디에서도 참조되지 않음(실제 보고서는
// `gunghap_result_screen.dart`의 서버 응답 동적 필드로 렌더링) —
// v4 사양대로 세부(axes) 기반 6장 동적 생성 함수로 안전하게 교체한다.
class GHReportSection {
  const GHReportSection(this.no, this.title, this.desc);
  final String no;
  final String title;
  final String desc;
}

List<GHReportSection> ghReportSections(String sub) {
  final a = ghAxesOf(sub);
  return [
    GHReportSection('I', '$sub 한눈에', '이 궁합의 핵심과 세 가지 질문'),
    GHReportSection('II', a[0], '첫 번째 축 깊이 보기'),
    GHReportSection('III', a[1], '두 번째 축 깊이 보기'),
    GHReportSection('IV', a[2], '세 번째 축 깊이 보기'),
    const GHReportSection('V', '이 풀이의 사주 근거', '오행 분포 · 일간 · 지지 · 세운'),
    GHReportSection('VI', '${ghSubShort(sub)} 조언과 좋은 시기', '지금 하면 좋은 것 · 피할 것 · 흐름이 열리는 때'),
  ];
}

// ─── 생성 8단계(게이트 generating · 서버 job.stage 1..8) ────
const ghGenStages = [
  ('charge', '복주머니 사용', '차감 확인 · 중복 요청 잠금'),
  ('pillars', '두 사람의 사주 원국 세우기', '년·월·일·시 4주 8자'),
  ('elements', '오행 분포와 강약 계산', '木火土金水 비율 · 신강/신약'),
  ('stems', '일간 관계 분석', '생 · 비화 · 극 / 천간합'),
  ('branches', '지지 합 · 충 · 형 · 해', '두 사람 지지의 맞물림'),
  ('luck', '대운 · 세운 흐름 겹치기', '함께 걷는 10년 · 올해의 기운'),
  ('topic', '선택 궁합 3축 풀이', '세부 카테고리 전용 해석 규칙 적용'),
  ('compose', '6개 장 보고서 엮기', 'FACT 근거 연결 · 문장 검수 · 저장'),
];

// ─── 빈 자리 8(§5 S03 · DestinyBurst 빈 슬롯) ──────────────
class Slot {
  const Slot(this.id, this.label, this.majorId, this.subs, this.hint);
  final String id;
  final String label;
  final String majorId;
  final List<String> subs;
  final String hint;
}

/// 디자인 표시 순서(`gh-home-map2.jsx` GH_SLOTS). 인연 n명 → 앞에서부터
/// (8 − n)개 표시, 이름이 슬롯 라벨과 같은 사람이 있으면 그 슬롯 제외.
const ghSlots = [
  Slot('lover', '연인', 'love', ['연애 궁합', '썸 궁합', '애정표현 궁합'], '마음이 가는 사람'),
  Slot('mom', '엄마', 'family', ['어머니·자녀 궁합', '가족 생활 궁합'], '가장 가까운 사람'),
  Slot('bestfriend', '절친', 'friend', ['절친 궁합', '여행 궁합', '취미 궁합'], '오래 곁에 있을 사람'),
  Slot('colleague', '동료', 'business', ['직장 동료 궁합', '업무 궁합'], '매일 마주치는 사람'),
  Slot('spouse', '배우자', 'marriage', ['부부 궁합', '결혼 궁합', '생활 궁합'], '평생을 함께할 사람'),
  Slot('dad', '아빠', 'family', ['아버지·자녀 궁합'], '말보다 마음인 사람'),
  Slot('sibling', '형제·자매', 'family', ['형제·자매 궁합'], '함께 자란 사람'),
  Slot('crush', '썸', 'love', ['썸 궁합', '짝사랑 궁합'], '요즘 신경 쓰이는 사람'),
];

List<Slot> ghVisibleSlots(List<MapPerson> people) {
  final names = people.map((p) => p.name).toSet();
  return ghSlots
      .where((s) => !names.contains(s.label))
      .take((8 - people.length).clamp(0, 8))
      .toList();
}

// [제거됨] 과거 "디자인 미리보기 전용" 더미였던 GHHistoryItem/ghRecentHistory는
// Phase 4(궁합스토리) 작업에서 실제 서버 결과 기반 구현(GunghapStoryScreen,
// gunghap_home_screen.dart의 _RecentGunghapPreview/_HistoryRow)으로 완전히
// 대체되어 더 이상 어디에서도 참조되지 않으므로 삭제했다.
// 실제 데이터는 GunghapProvider.fetchMyResults() → GET /api/public/gunghap/my-results
// 를 통해서만 가져온다.
