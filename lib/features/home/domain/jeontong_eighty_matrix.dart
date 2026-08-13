/// [정통사주 80종 개편] 홈 화면 "운세" 카드를 탭했을 때 보여주는 정통사주
/// 80종 카테고리 카탈로그(대카테고리 A~H × 소카테고리 10개).
///
/// [배경] 기존 `jeontong_saju_section.dart`는 8종만 고정 노출하는 바텀시트였다.
/// 사용자 최종 확정 요구사항 — "ai관상 ai손금 ai타로 ai상담은 그대로 두고
/// 나머지 운세는 삭제 후 정통사주 80가지로 대체" + "운세섹션 클릭시 80종을
/// 대카테고리 소카테고리 나눠서 진열" — 에 따라, 사용자가 업로드한
/// `saju_engine_v4_final.zip`의 `modules/eighty_categories.py`에 정의된 실제
/// 80종 카테고리(A~H 8개 대카테고리 × 10개 소카테고리)를 이 파일의 단일
/// 소스로 옮겨온다.
///
/// [백엔드 결정 - A안] 사용자가 "a"(클라이언트 룰베이스, 백엔드 미배포)를
/// 선택했으므로, 이 80종은 실제 사주 계산(만세력)이나 AI 호출을 하지 않고
/// [JeontongReportBuilder]가 카테고리 메타데이터만으로 결정론적 콘텐츠를
/// 생성한다(기존 `GenericFortuneReportBuilder`와 동일한 원칙). AI
/// 사주/타로/관상/손금/상담 관련 코드는 이 작업에서 전혀 건드리지 않는다.
///
/// [게이트 정책] 80종 전부 프리패스 필요(균일 정책) — 기존 8종 바텀시트
/// 하단에 이미 "80가지 운세 · 프리패스 하나로 무제한"이라는 문구가 있었으므로
/// 이 정책과 일치한다. 무료/유료 구분이 카테고리별로 다르지 않으므로 별도
/// [GateResult] enum을 재사용하지 않고, 라우팅 시점에 기존
/// `navigateWithPassGate(requiresPass: true)`만으로 충분하다(신규
/// Provider/게이트 클래스 추가 없음).
library;

// disclaimers는 fortune_matrix.dart에 이미 정의된 [DisclaimerTag] enum을
// 그대로 재사용한다(신규 enum 추가 없음).
import 'fortune_matrix.dart' show DisclaimerTag;

/// 대카테고리 8종(A~H) 코드.
enum JeontongMajorCode { a, b, c, d, e, f, g, h }

extension JeontongMajorCodeMeta on JeontongMajorCode {
  /// 'A'~'H' — saju_engine `eighty_categories.py`의 그룹 접두어와 동일.
  String get letter => switch (this) {
    JeontongMajorCode.a => 'A',
    JeontongMajorCode.b => 'B',
    JeontongMajorCode.c => 'C',
    JeontongMajorCode.d => 'D',
    JeontongMajorCode.e => 'E',
    JeontongMajorCode.f => 'F',
    JeontongMajorCode.g => 'G',
    JeontongMajorCode.h => 'H',
  };

  String get title => switch (this) {
    JeontongMajorCode.a => '평생운',
    JeontongMajorCode.b => '대운',
    JeontongMajorCode.c => '세운(올해)',
    JeontongMajorCode.d => '이달·오늘',
    JeontongMajorCode.e => '궁합',
    JeontongMajorCode.f => '특수 주제',
    JeontongMajorCode.g => '건강',
    JeontongMajorCode.h => '개운·풍수',
  };

  String get hanja => switch (this) {
    JeontongMajorCode.a => '命',
    JeontongMajorCode.b => '運',
    JeontongMajorCode.c => '年',
    JeontongMajorCode.d => '今',
    JeontongMajorCode.e => '緣',
    JeontongMajorCode.f => '特',
    JeontongMajorCode.g => '壽',
    JeontongMajorCode.h => '福',
  };

  String get description => switch (this) {
    JeontongMajorCode.a => '타고난 사주로 보는 인생 전체의 흐름',
    JeontongMajorCode.b => '10년 단위로 찾아오는 인생의 큰 흐름',
    JeontongMajorCode.c => '올 한 해 전체를 관통하는 흐름',
    JeontongMajorCode.d => '가장 가까운 오늘과 이달의 흐름',
    JeontongMajorCode.e => '나와 상대방 사이의 인연을 유형별로',
    JeontongMajorCode.f => '재물·직업·이사 등 구체적인 주제별 풀이',
    JeontongMajorCode.g => '체질과 건강 전반을 살펴보기',
    JeontongMajorCode.h => '행운을 부르는 색·방향·아이템·습관',
  };
}

/// 80종 중 1개 소카테고리.
class JeontongCategoryEntry {
  const JeontongCategoryEntry({
    required this.id,
    required this.major,
    required this.title,
    this.disclaimers = const [],
    this.resultSeedTags = const [],
  });

  /// 예: 'A01', 'H10' — saju_engine CATEGORY_INDEX 코드와 동일.
  final String id;
  final JeontongMajorCode major;
  final String title;
  final List<DisclaimerTag> disclaimers;

  /// 결과 콘텐츠 생성 시 톤을 결정하는 키워드(선택).
  final List<String> resultSeedTags;
}

class JeontongMajorGroup {
  const JeontongMajorGroup({required this.code, required this.items});

  final JeontongMajorCode code;
  final List<JeontongCategoryEntry> items;
}

/// [JeontongEightyMatrix] — 정통사주 80종 전체 카탈로그(단일 소스).
class JeontongEightyMatrix {
  JeontongEightyMatrix._();

  /// 신규 80종 전용 결과 화면 라우트.
  static const String resultRoute = '/jeontong/eighty/result';

  /// 신규 80종 대/소카테고리 진열 화면 라우트.
  static const String browseRoute = '/jeontong/eighty';

  static final List<JeontongMajorGroup> groups = [
    _a,
    _b,
    _c,
    _d,
    _e,
    _f,
    _g,
    _h,
  ];

  static List<JeontongCategoryEntry> get all =>
      groups.expand((g) => g.items).toList();

  static JeontongCategoryEntry? byId(String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  // ── A. 평생운 (10) ──
  static final _a = JeontongMajorGroup(
    code: JeontongMajorCode.a,
    items: const [
      JeontongCategoryEntry(
        id: 'A01',
        major: JeontongMajorCode.a,
        title: '평생 총운',
      ),
      JeontongCategoryEntry(
        id: 'A02',
        major: JeontongMajorCode.a,
        title: '타고난 성격·기질',
      ),
      JeontongCategoryEntry(
        id: 'A03',
        major: JeontongMajorCode.a,
        title: '평생 재물운',
        disclaimers: [DisclaimerTag.finance],
      ),
      JeontongCategoryEntry(
        id: 'A04',
        major: JeontongMajorCode.a,
        title: '평생 직업·명예운',
      ),
      JeontongCategoryEntry(
        id: 'A05',
        major: JeontongMajorCode.a,
        title: '평생 건강운',
        disclaimers: [DisclaimerTag.medical],
      ),
      JeontongCategoryEntry(
        id: 'A06',
        major: JeontongMajorCode.a,
        title: '평생 배우자·결혼운',
        disclaimers: [DisclaimerTag.relationship],
      ),
      JeontongCategoryEntry(
        id: 'A07',
        major: JeontongMajorCode.a,
        title: '평생 자녀운',
      ),
      JeontongCategoryEntry(
        id: 'A08',
        major: JeontongMajorCode.a,
        title: '평생 부모·형제운',
      ),
      JeontongCategoryEntry(
        id: 'A09',
        major: JeontongMajorCode.a,
        title: '평생 학업·시험운',
      ),
      JeontongCategoryEntry(
        id: 'A10',
        major: JeontongMajorCode.a,
        title: '인생 5대 전환점',
      ),
    ],
  );

  // ── B. 대운 (10) ──
  static final _b = JeontongMajorGroup(
    code: JeontongMajorCode.b,
    items: const [
      JeontongCategoryEntry(
        id: 'B01',
        major: JeontongMajorCode.b,
        title: '현재 대운 총평',
      ),
      JeontongCategoryEntry(
        id: 'B02',
        major: JeontongMajorCode.b,
        title: '대운별 재물 흐름',
        disclaimers: [DisclaimerTag.finance],
      ),
      JeontongCategoryEntry(
        id: 'B03',
        major: JeontongMajorCode.b,
        title: '대운별 직업 변화',
      ),
      JeontongCategoryEntry(
        id: 'B04',
        major: JeontongMajorCode.b,
        title: '대운별 건강 변화',
        disclaimers: [DisclaimerTag.medical],
      ),
      JeontongCategoryEntry(
        id: 'B05',
        major: JeontongMajorCode.b,
        title: '대운별 애정 변화',
        disclaimers: [DisclaimerTag.relationship],
      ),
      JeontongCategoryEntry(
        id: 'B06',
        major: JeontongMajorCode.b,
        title: '대운 전환기 주의사항',
      ),
      JeontongCategoryEntry(
        id: 'B07',
        major: JeontongMajorCode.b,
        title: '다음 대운 미리보기',
      ),
      JeontongCategoryEntry(
        id: 'B08',
        major: JeontongMajorCode.b,
        title: '인생 최고 대운 시기',
      ),
      JeontongCategoryEntry(
        id: 'B09',
        major: JeontongMajorCode.b,
        title: '인생 최악 대운 시기',
      ),
      JeontongCategoryEntry(
        id: 'B10',
        major: JeontongMajorCode.b,
        title: '대운 vs 세운 조합',
      ),
    ],
  );

  // ── C. 세운(올해) (10) ──
  static final _c = JeontongMajorGroup(
    code: JeontongMajorCode.c,
    items: const [
      JeontongCategoryEntry(
        id: 'C01',
        major: JeontongMajorCode.c,
        title: '올해 총운',
      ),
      JeontongCategoryEntry(
        id: 'C02',
        major: JeontongMajorCode.c,
        title: '올해 재물운',
        disclaimers: [DisclaimerTag.finance],
      ),
      JeontongCategoryEntry(
        id: 'C03',
        major: JeontongMajorCode.c,
        title: '올해 직업운',
      ),
      JeontongCategoryEntry(
        id: 'C04',
        major: JeontongMajorCode.c,
        title: '올해 애정운',
        disclaimers: [DisclaimerTag.relationship],
      ),
      JeontongCategoryEntry(
        id: 'C05',
        major: JeontongMajorCode.c,
        title: '올해 건강운',
        disclaimers: [DisclaimerTag.medical],
      ),
      JeontongCategoryEntry(
        id: 'C06',
        major: JeontongMajorCode.c,
        title: '올해 이사·이동수',
      ),
      JeontongCategoryEntry(
        id: 'C07',
        major: JeontongMajorCode.c,
        title: '올해 시험·자격운',
      ),
      JeontongCategoryEntry(
        id: 'C08',
        major: JeontongMajorCode.c,
        title: '올해 소송·관재수',
        disclaimers: [DisclaimerTag.legalDate],
      ),
      JeontongCategoryEntry(
        id: 'C09',
        major: JeontongMajorCode.c,
        title: '올해 인간관계',
      ),
      JeontongCategoryEntry(
        id: 'C10',
        major: JeontongMajorCode.c,
        title: '올해 12개월 월별',
      ),
    ],
  );

  // ── D. 이달·오늘 (10) ──
  static final _d = JeontongMajorGroup(
    code: JeontongMajorCode.d,
    items: const [
      JeontongCategoryEntry(
        id: 'D01',
        major: JeontongMajorCode.d,
        title: '이달의 운세',
      ),
      JeontongCategoryEntry(
        id: 'D02',
        major: JeontongMajorCode.d,
        title: '오늘의 운세',
      ),
      JeontongCategoryEntry(
        id: 'D03',
        major: JeontongMajorCode.d,
        title: '내일의 운세',
      ),
      JeontongCategoryEntry(
        id: 'D04',
        major: JeontongMajorCode.d,
        title: '이번 주 운세',
      ),
      JeontongCategoryEntry(
        id: 'D05',
        major: JeontongMajorCode.d,
        title: '오늘의 재물운',
        disclaimers: [DisclaimerTag.finance],
      ),
      JeontongCategoryEntry(
        id: 'D06',
        major: JeontongMajorCode.d,
        title: '오늘의 애정운',
        disclaimers: [DisclaimerTag.relationship],
      ),
      JeontongCategoryEntry(
        id: 'D07',
        major: JeontongMajorCode.d,
        title: '오늘의 건강운',
        disclaimers: [DisclaimerTag.medical],
      ),
      JeontongCategoryEntry(
        id: 'D08',
        major: JeontongMajorCode.d,
        title: '오늘의 길흉 시간대',
      ),
      JeontongCategoryEntry(
        id: 'D09',
        major: JeontongMajorCode.d,
        title: '오늘 행운 색·숫자',
      ),
      JeontongCategoryEntry(
        id: 'D10',
        major: JeontongMajorCode.d,
        title: '오늘 피해야 할 일',
      ),
    ],
  );

  // ── E. 궁합 (10) ──
  static final _e = JeontongMajorGroup(
    code: JeontongMajorCode.e,
    items: const [
      JeontongCategoryEntry(
        id: 'E01',
        major: JeontongMajorCode.e,
        title: '부부 궁합',
        disclaimers: [DisclaimerTag.relationship],
      ),
      JeontongCategoryEntry(
        id: 'E02',
        major: JeontongMajorCode.e,
        title: '연인 궁합',
        disclaimers: [DisclaimerTag.relationship],
      ),
      JeontongCategoryEntry(
        id: 'E03',
        major: JeontongMajorCode.e,
        title: '결혼 궁합',
        disclaimers: [DisclaimerTag.relationship],
      ),
      JeontongCategoryEntry(
        id: 'E04',
        major: JeontongMajorCode.e,
        title: '사업 파트너 궁합',
        disclaimers: [DisclaimerTag.finance],
      ),
      JeontongCategoryEntry(
        id: 'E05',
        major: JeontongMajorCode.e,
        title: '상사·부하 궁합',
      ),
      JeontongCategoryEntry(
        id: 'E06',
        major: JeontongMajorCode.e,
        title: '부모·자녀 궁합',
      ),
      JeontongCategoryEntry(
        id: 'E07',
        major: JeontongMajorCode.e,
        title: '형제·친구 궁합',
      ),
      JeontongCategoryEntry(
        id: 'E08',
        major: JeontongMajorCode.e,
        title: '띠 궁합',
      ),
      JeontongCategoryEntry(
        id: 'E09',
        major: JeontongMajorCode.e,
        title: '오행 궁합',
      ),
      JeontongCategoryEntry(
        id: 'E10',
        major: JeontongMajorCode.e,
        title: '겉궁합 vs 속궁합',
      ),
    ],
  );

  // ── F. 특수 주제 (10) ──
  static final _f = JeontongMajorGroup(
    code: JeontongMajorCode.f,
    items: const [
      JeontongCategoryEntry(
        id: 'F01',
        major: JeontongMajorCode.f,
        title: '재물 축적 방법',
        disclaimers: [DisclaimerTag.finance],
      ),
      JeontongCategoryEntry(
        id: 'F02',
        major: JeontongMajorCode.f,
        title: '맞는 직업 Top 10',
      ),
      JeontongCategoryEntry(
        id: 'F03',
        major: JeontongMajorCode.f,
        title: '맞는 사업 아이템',
      ),
      JeontongCategoryEntry(
        id: 'F04',
        major: JeontongMajorCode.f,
        title: '창업 vs 직장',
      ),
      JeontongCategoryEntry(
        id: 'F05',
        major: JeontongMajorCode.f,
        title: '이직 타이밍',
      ),
      JeontongCategoryEntry(
        id: 'F06',
        major: JeontongMajorCode.f,
        title: '부동산 매매 타이밍',
        disclaimers: [DisclaimerTag.finance],
      ),
      JeontongCategoryEntry(
        id: 'F07',
        major: JeontongMajorCode.f,
        title: '투자 성향 분석',
        disclaimers: [DisclaimerTag.finance],
      ),
      JeontongCategoryEntry(
        id: 'F08',
        major: JeontongMajorCode.f,
        title: '결혼 적령기',
        disclaimers: [DisclaimerTag.relationship],
      ),
      JeontongCategoryEntry(
        id: 'F09',
        major: JeontongMajorCode.f,
        title: '자녀 출산 좋은 해',
      ),
      JeontongCategoryEntry(
        id: 'F10',
        major: JeontongMajorCode.f,
        title: '유학·해외 진출운',
      ),
    ],
  );

  // ── G. 건강 (10) ──
  static final _g = JeontongMajorGroup(
    code: JeontongMajorCode.g,
    items: const [
      JeontongCategoryEntry(
        id: 'G01',
        major: JeontongMajorCode.g,
        title: '오행별 취약 장기',
        disclaimers: [DisclaimerTag.medical],
      ),
      JeontongCategoryEntry(
        id: 'G02',
        major: JeontongMajorCode.g,
        title: '평생 조심할 병',
        disclaimers: [DisclaimerTag.medical],
      ),
      JeontongCategoryEntry(
        id: 'G03',
        major: JeontongMajorCode.g,
        title: '대운별 건강 주의',
        disclaimers: [DisclaimerTag.medical],
      ),
      JeontongCategoryEntry(
        id: 'G04',
        major: JeontongMajorCode.g,
        title: '나에게 좋은 음식',
      ),
      JeontongCategoryEntry(
        id: 'G05',
        major: JeontongMajorCode.g,
        title: '나에게 나쁜 음식',
      ),
      JeontongCategoryEntry(
        id: 'G06',
        major: JeontongMajorCode.g,
        title: '사주 체질',
        disclaimers: [DisclaimerTag.medical],
      ),
      JeontongCategoryEntry(
        id: 'G07',
        major: JeontongMajorCode.g,
        title: '정신 건강 취약도',
        disclaimers: [DisclaimerTag.medical],
      ),
      JeontongCategoryEntry(
        id: 'G08',
        major: JeontongMajorCode.g,
        title: '사고·수술수',
        disclaimers: [DisclaimerTag.medical],
      ),
      JeontongCategoryEntry(
        id: 'G09',
        major: JeontongMajorCode.g,
        title: '장수 가능성',
      ),
      JeontongCategoryEntry(
        id: 'G10',
        major: JeontongMajorCode.g,
        title: '회복력·면역',
      ),
    ],
  );

  // ── H. 개운·풍수 (10) ──
  static final _h = JeontongMajorGroup(
    code: JeontongMajorCode.h,
    items: const [
      JeontongCategoryEntry(
        id: 'H01',
        major: JeontongMajorCode.h,
        title: '행운의 색',
      ),
      JeontongCategoryEntry(
        id: 'H02',
        major: JeontongMajorCode.h,
        title: '행운의 방향',
      ),
      JeontongCategoryEntry(
        id: 'H03',
        major: JeontongMajorCode.h,
        title: '행운의 숫자',
      ),
      JeontongCategoryEntry(
        id: 'H04',
        major: JeontongMajorCode.h,
        title: '행운의 보석',
      ),
      JeontongCategoryEntry(
        id: 'H05',
        major: JeontongMajorCode.h,
        title: '부적·개운 아이템',
      ),
      JeontongCategoryEntry(
        id: 'H06',
        major: JeontongMajorCode.h,
        title: '좋은 이름(작명)',
      ),
      JeontongCategoryEntry(
        id: 'H07',
        major: JeontongMajorCode.h,
        title: '집·사무실 방향',
      ),
      JeontongCategoryEntry(
        id: 'H08',
        major: JeontongMajorCode.h,
        title: '침대·책상 배치',
      ),
      JeontongCategoryEntry(
        id: 'H09',
        major: JeontongMajorCode.h,
        title: '반려동물 궁합',
      ),
      JeontongCategoryEntry(
        id: 'H10',
        major: JeontongMajorCode.h,
        title: '개운 습관',
      ),
    ],
  );
}
