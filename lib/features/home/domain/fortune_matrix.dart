/// [운섹션 87 카테고리 통합 - 자율 정정] Fortune Fusion(신통방통) 운세 섹션
/// 카테고리 매트릭스.
///
/// 타로(Ta-001~Ta-015, `/ai-fortune/tarot/*`, `/tarot/*`)는 별도로 이미
/// 완성되어 있으므로 이 매트릭스에는 절대 포함하지 않는다.
///
/// [자율 정리 기록 → 궁합 신규 구현 완료] 원 스펙은 궁합(C) 7개를 포함한
/// 87개였으나, 정정 시점에는 궁합 카테고리가 실제로 구현된 적이 없었다
/// (전용 화면/Provider/매트릭스 엔트리 전무). 이후 조사 결과 admin_web
/// 백엔드(`/api/public/compatibility/request|result|history`,
/// CompatibilityRequest/CompatibilityResult 모델)는 이미 완전히 구현되어
/// 있었고 Flutter 클라이언트만 없던 상태임을 확인, features/compatibility/
/// 모듈(Model/Repository/Provider/입력·결과 화면)을 신규 구현하고 아래
/// [FortuneGroupCode.c] 그룹으로 편입했다. 이제 실제 구현·노출되는
/// 카테고리는 87개이며, 이 파일이 그 단일 소스다.
///
/// 그룹 구성(총 87개):
/// - T(오늘/기간 운세) 21 · S(사주) 5 · N(이름) 5 · C(궁합) 7 · K(택일) 8
/// - V(평생운) 3 · O(추천) 5 · F(관상·손금) 5 · X(교차분석) 4 · G(그래프) 2
/// - B(추천연계) 1 · D(해몽) 18 · R(리포트) 3
///
/// [기존 화면 재사용 원칙] 이미 실제 화면/Provider가 있는 카테고리(오늘의 운세,
/// 사주, 이름, 관상, 손금)는 새 화면을 만들지 않고 기존 라우트를 그대로
/// 재사용한다([existingRoute]). 아직 화면이 없는 카테고리는 공용
/// [GenericFortuneResultScreen](라우트 `/fortune/category`)에서 카테고리
/// 메타데이터를 시드로 결정론적 콘텐츠를 생성해 실제로 동작하는 결과를
/// 보여준다.
library;

import '../../compatibility/domain/compatibility_model.dart';

/// 게이트 판정 결과 6종.
///
/// - [openFree]: 완전 무료, 게이트 없이 항상 열람 가능.
/// - [freeOncePerDay]: 하루 1회는 무료, 이후 재열람 시 프리패스 필요.
/// - [lockedFreeFirst]: 최초 1회(평생)는 무료, 이후부터 프리패스 필요.
/// - [paidOnlyPassGate]: 항상 프리패스(또는 복주머니 구매)로만 열람.
/// - [cooldown]: 무료 열람 후 일정 시간 동안 재열람 자체가 잠김(과다 사용 방지).
/// - [granted]: 이벤트/보상 등으로 즉시 부여된 상태(내부적으로만 사용, 신규
///   카테고리 정책 설계에는 사용하지 않음 — 확장 대비용).
enum GateResult {
  openFree,
  freeOncePerDay,
  lockedFreeFirst,
  paidOnlyPassGate,
  cooldown,
  granted,
}

/// 카테고리 결과 화면 상단/본문에 붙는 면책 문구 태그.
/// 하나의 카테고리가 여러 태그를 가질 수 있다(예: 궁합+영아 = 아기 이름 + 궁합).
enum DisclaimerTag {
  medical,
  finance,
  legalDate,
  relationship,
  infant,
  camera,
  lottery,
  dream,
}

/// 87개 카테고리 그룹 코드(궁합 C 그룹은 features/compatibility/ 모듈로
/// 신규 구현되어 편입되었다 - 위 파일 헤더 참고).
enum FortuneGroupCode { t, s, n, c, k, v, o, f, x, g, b, d, r }

extension FortuneGroupCodeLabel on FortuneGroupCode {
  String get label => switch (this) {
    FortuneGroupCode.t => '오늘/기간 운세',
    FortuneGroupCode.s => '사주',
    FortuneGroupCode.n => '이름 운세',
    FortuneGroupCode.c => '궁합',
    FortuneGroupCode.k => '택일',
    FortuneGroupCode.v => '평생운',
    FortuneGroupCode.o => '오늘의 추천',
    FortuneGroupCode.f => '관상·손금',
    FortuneGroupCode.x => '교차분석',
    FortuneGroupCode.g => '운세 그래프',
    FortuneGroupCode.b => '추천 연계',
    FortuneGroupCode.d => '꿈해몽',
    FortuneGroupCode.r => '리포트',
  };

  String get description => switch (this) {
    FortuneGroupCode.t => '오늘 하루부터 신년까지, 시간의 흐름을 따라 흐름을 확인해보세요',
    FortuneGroupCode.s => '타고난 사주 기운을 재물·애정·건강·월별로 나눠 깊게 해석해보세요',
    FortuneGroupCode.n => '이름에 담긴 기운과 어울림을 풀이해보세요',
    FortuneGroupCode.c => '나와 상대방의 인연을 유형별로 풀이해보세요',
    FortuneGroupCode.k => '결혼·이사·개업 등 중요한 날짜를 고를 때 참고해보세요',
    FortuneGroupCode.v => '인생 전체를 관통하는 흐름을 큰 틀에서 살펴보세요',
    FortuneGroupCode.o => '오늘 하루를 가볍게 채워줄 추천 아이템을 만나보세요',
    FortuneGroupCode.f => '얼굴과 손에 담긴 이야기를 사진으로 확인해보세요',
    FortuneGroupCode.x => '여러 운세를 겹쳐서 보는 심층 교차 분석이에요',
    FortuneGroupCode.g => '운세 흐름을 그래프로 한눈에 확인해보세요',
    FortuneGroupCode.b => '지금 살펴본 결과와 어울리는 다음 기능을 추천해드려요',
    FortuneGroupCode.d => '지난밤 꾼 꿈이 무엇을 말하는지 풀이해보세요',
    FortuneGroupCode.r => '지금까지의 운세를 모아 리포트 형태로 정리해보세요',
  };
}

/// 87개 카테고리 중 1개 항목의 전체 메타데이터.
class FortuneCategoryEntry {
  const FortuneCategoryEntry({
    required this.id,
    required this.group,
    required this.title,
    required this.shortDescription,
    required this.gate,
    this.existingRoute,
    this.routeArguments,
    this.disclaimers = const [],
    this.resultSeedTags = const [],
  });

  /// 예: 'T-001', 'D-014'.
  final String id;
  final FortuneGroupCode group;
  final String title;
  final String shortDescription;

  /// 이 카테고리의 기본 게이트 정책(사용 이력에 따라 [CategoryGate]가 실제
  /// [GateResult]를 재계산할 때의 "정책 원본"이다).
  final GateResult gate;

  /// 이미 존재하는 화면으로 바로 연결하는 경우의 라우트(없으면 공용
  /// GenericFortuneResultScreen(`/fortune/category`)으로 이동).
  final String? existingRoute;

  /// [existingRoute]로 이동할 때 함께 전달할 인자(딥링크용, 선택).
  final Object? routeArguments;

  final List<DisclaimerTag> disclaimers;

  /// 공용 결과 화면에서 결정론적 콘텐츠 생성 시 톤을 결정하는 키워드 태그.
  final List<String> resultSeedTags;

  bool get usesGenericScreen => existingRoute == null;
}

class FortuneCategoryGroupEntry {
  const FortuneCategoryGroupEntry({required this.code, required this.items});

  final FortuneGroupCode code;
  final List<FortuneCategoryEntry> items;
}

/// [FortuneMatrix] — 87개 카테고리 전체 카탈로그(단일 소스).
class FortuneMatrix {
  FortuneMatrix._();

  static const String sajuInputRoute = '/ai-fortune/saju/input';
  static const String nameInputRoute = '/ai-fortune/name/input';
  static const String compatibilityInputRoute = '/compatibility/input';
  static const String faceCaptureRoute = '/ai-fortune/face/capture';
  static const String palmCaptureRoute = '/ai-fortune/palm/capture';
  static const String dailyIntroRoute = '/fortune/today/intro';

  /// 공용 결과 화면(신규 카테고리) 라우트.
  static const String genericCategoryRoute = '/fortune/category';

  static final List<FortuneCategoryGroupEntry> groups = [
    _tGroup,
    _sGroup,
    _nGroup,
    _cGroup,
    _kGroup,
    _vGroup,
    _oGroup,
    _fGroup,
    _xGroup,
    _gGroup,
    _bGroup,
    _dGroup,
    _rGroup,
  ];

  static List<FortuneCategoryEntry> get all =>
      groups.expand((g) => g.items).toList();

  static FortuneCategoryEntry? byId(String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  // ── T: 오늘/기간 운세 (21) ──
  // T-001~007, 014~021은 이미 완성된 오늘의 운세 표준 플로우
  // (DailyFortuneResultScreen 내부 섹션별 게이트)를 그대로 재사용한다.
  // T-008~013(내일/모레/주간/월간/신년/절기)은 아직 "오늘" 단일 모델로는
  // 다룰 수 없는 기간 확장 개념이라 공용 결과 화면으로 연결한다.
  static final _tGroup = FortuneCategoryGroupEntry(
    code: FortuneGroupCode.t,
    items: [
      FortuneCategoryEntry(
        id: 'T-001',
        group: FortuneGroupCode.t,
        title: '오늘의 총운',
        shortDescription: '오늘 하루 전체 흐름을 한눈에',
        // [프리패스 전체잠금 통일] 오늘의 운세 전체잠금(과거 openFree).
        gate: GateResult.paidOnlyPassGate,
        existingRoute: dailyIntroRoute,
      ),
      FortuneCategoryEntry(
        id: 'T-002',
        group: FortuneGroupCode.t,
        title: '오늘의 연애운',
        shortDescription: '오늘 마음이 향하는 방향',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: dailyIntroRoute,
        disclaimers: [DisclaimerTag.relationship],
      ),
      FortuneCategoryEntry(
        id: 'T-003',
        group: FortuneGroupCode.t,
        title: '오늘의 금전운',
        shortDescription: '오늘의 지출·재물 흐름',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: dailyIntroRoute,
        disclaimers: [DisclaimerTag.finance],
      ),
      FortuneCategoryEntry(
        id: 'T-004',
        group: FortuneGroupCode.t,
        title: '오늘의 건강운',
        shortDescription: '오늘 컨디션 관리 포인트',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: dailyIntroRoute,
        disclaimers: [DisclaimerTag.medical],
      ),
      FortuneCategoryEntry(
        id: 'T-005',
        group: FortuneGroupCode.t,
        title: '오늘의 인간관계운',
        shortDescription: '주변 사람들과의 흐름',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: dailyIntroRoute,
        disclaimers: [DisclaimerTag.relationship],
      ),
      FortuneCategoryEntry(
        id: 'T-006',
        group: FortuneGroupCode.t,
        title: '오늘의 학업·일운',
        shortDescription: '공부·업무 집중도 흐름',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: dailyIntroRoute,
      ),
      FortuneCategoryEntry(
        id: 'T-007',
        group: FortuneGroupCode.t,
        title: '오늘의 시간대별 운세',
        shortDescription: '오전·오후·저녁·밤 흐름',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: dailyIntroRoute,
      ),
      FortuneCategoryEntry(
        id: 'T-008',
        group: FortuneGroupCode.t,
        title: '내일의 운세',
        shortDescription: '하루 먼저 만나보는 내일',
        gate: GateResult.freeOncePerDay,
        resultSeedTags: ['내일', '기간운세'],
      ),
      FortuneCategoryEntry(
        id: 'T-009',
        group: FortuneGroupCode.t,
        title: '모레의 운세',
        shortDescription: '이틀 뒤 흐름 미리보기',
        gate: GateResult.lockedFreeFirst,
        resultSeedTags: ['모레', '기간운세'],
      ),
      FortuneCategoryEntry(
        id: 'T-010',
        group: FortuneGroupCode.t,
        title: '이번 주 운세',
        shortDescription: '한 주 전체 흐름 요약',
        gate: GateResult.lockedFreeFirst,
        resultSeedTags: ['주간', '기간운세'],
      ),
      FortuneCategoryEntry(
        id: 'T-011',
        group: FortuneGroupCode.t,
        title: '이번 달 운세',
        shortDescription: '한 달의 큰 흐름',
        gate: GateResult.paidOnlyPassGate,
        resultSeedTags: ['월간', '기간운세'],
      ),
      FortuneCategoryEntry(
        id: 'T-012',
        group: FortuneGroupCode.t,
        title: '신년 운세',
        shortDescription: '새해 전체를 관통하는 흐름',
        gate: GateResult.lockedFreeFirst,
        resultSeedTags: ['신년', '기간운세'],
      ),
      FortuneCategoryEntry(
        id: 'T-013',
        group: FortuneGroupCode.t,
        title: '절기 운세',
        shortDescription: '24절기에 따른 기운 변화',
        gate: GateResult.freeOncePerDay,
        resultSeedTags: ['절기', '기간운세'],
      ),
      FortuneCategoryEntry(
        id: 'T-014',
        group: FortuneGroupCode.t,
        title: '오늘의 행운의 색',
        shortDescription: '오늘 나에게 힘이 되는 색',
        // [프리패스 전체잠금 통일] 오늘의 운세 세부항목 전체 잠금(과거 openFree).
        gate: GateResult.paidOnlyPassGate,
        existingRoute: dailyIntroRoute,
      ),
      FortuneCategoryEntry(
        id: 'T-015',
        group: FortuneGroupCode.t,
        title: '오늘의 행운의 숫자',
        shortDescription: '오늘의 숫자 한 자리',
        // [프리패스 전체잠금 통일] 오늘의 운세 세부항목 전체 잠금(과거 openFree).
        gate: GateResult.paidOnlyPassGate,
        existingRoute: dailyIntroRoute,
      ),
      FortuneCategoryEntry(
        id: 'T-016',
        group: FortuneGroupCode.t,
        title: '오늘의 행운의 시간',
        shortDescription: '오늘 흐름이 가장 좋은 시간대',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: dailyIntroRoute,
      ),
      FortuneCategoryEntry(
        id: 'T-017',
        group: FortuneGroupCode.t,
        title: '오늘의 행운의 방향',
        shortDescription: '오늘 움직이면 좋은 방향',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: dailyIntroRoute,
      ),
      FortuneCategoryEntry(
        id: 'T-018',
        group: FortuneGroupCode.t,
        title: '오늘의 행운의 아이템',
        shortDescription: '오늘 곁에 두면 좋은 아이템',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: dailyIntroRoute,
      ),
      FortuneCategoryEntry(
        id: 'T-019',
        group: FortuneGroupCode.t,
        title: '오늘의 행운 키워드',
        shortDescription: '오늘 하루를 담은 한 단어',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: dailyIntroRoute,
      ),
      FortuneCategoryEntry(
        id: 'T-020',
        group: FortuneGroupCode.t,
        title: '오늘 피해야 할 것',
        shortDescription: '오늘 조심하면 좋은 것들',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: dailyIntroRoute,
      ),
      FortuneCategoryEntry(
        id: 'T-021',
        group: FortuneGroupCode.t,
        title: '오늘의 추천 행동',
        shortDescription: '오늘 해보면 좋은 행동들',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: dailyIntroRoute,
      ),
    ],
  );

  // ── S: 사주 (5) — 기존 SajuInputScreen 딥링크 매핑(_sajuTopicByCategoryKey)과
  // 동일한 토픽을 그대로 재사용한다.
  static final _sGroup = FortuneCategoryGroupEntry(
    code: FortuneGroupCode.s,
    items: [
      FortuneCategoryEntry(
        id: 'S-001',
        group: FortuneGroupCode.s,
        title: '오늘의 사주(종합)',
        shortDescription: '타고난 사주 전체 흐름',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: sajuInputRoute,
      ),
      FortuneCategoryEntry(
        id: 'S-002',
        group: FortuneGroupCode.s,
        title: '재물운 사주',
        shortDescription: '사주로 보는 재물의 흐름',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: sajuInputRoute,
        routeArguments: {
          'initialTopics': ['재물'],
        },
        disclaimers: [DisclaimerTag.finance],
      ),
      FortuneCategoryEntry(
        id: 'S-003',
        group: FortuneGroupCode.s,
        title: '애정운 사주',
        shortDescription: '사주로 보는 인연의 흐름',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: sajuInputRoute,
        routeArguments: {
          'initialTopics': ['애정'],
        },
        disclaimers: [DisclaimerTag.relationship],
      ),
      FortuneCategoryEntry(
        id: 'S-004',
        group: FortuneGroupCode.s,
        title: '건강운 사주',
        shortDescription: '사주로 보는 몸의 기운',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: sajuInputRoute,
        routeArguments: {
          'initialTopics': ['건강'],
        },
        disclaimers: [DisclaimerTag.medical],
      ),
      FortuneCategoryEntry(
        id: 'S-005',
        group: FortuneGroupCode.s,
        title: '월별 사주',
        shortDescription: '한 해 열두 달의 흐름',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: sajuInputRoute,
        routeArguments: {
          'initialTopics': ['월별'],
        },
      ),
    ],
  );

  // ── N: 이름 운세 (5) ──
  static final _nGroup = FortuneCategoryGroupEntry(
    code: FortuneGroupCode.n,
    items: [
      FortuneCategoryEntry(
        id: 'N-001',
        group: FortuneGroupCode.n,
        title: '내 이름 풀이',
        shortDescription: '이름에 담긴 기운 해석',
        gate: GateResult.lockedFreeFirst,
        existingRoute: nameInputRoute,
      ),
      FortuneCategoryEntry(
        id: 'N-002',
        group: FortuneGroupCode.n,
        title: '개명 추천',
        shortDescription: '지금 이름과 어울리는 대안',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: nameInputRoute,
      ),
      FortuneCategoryEntry(
        id: 'N-003',
        group: FortuneGroupCode.n,
        title: '아기 이름 추천',
        shortDescription: '태명·아기 이름 풀이',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: nameInputRoute,
        disclaimers: [DisclaimerTag.infant],
      ),
      FortuneCategoryEntry(
        id: 'N-004',
        group: FortuneGroupCode.n,
        title: '이름 궁합',
        shortDescription: '두 이름 사이의 어울림',
        gate: GateResult.freeOncePerDay,
        existingRoute: nameInputRoute,
        disclaimers: [DisclaimerTag.relationship],
      ),
      FortuneCategoryEntry(
        id: 'N-005',
        group: FortuneGroupCode.n,
        title: '브랜드·상호명 풀이',
        shortDescription: '사업체 이름의 기운',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: nameInputRoute,
        disclaimers: [DisclaimerTag.finance],
      ),
    ],
  );

  // ── C: 궁합 (7) [궁합(C그룹) 신규 구현] ──
  // admin_web 백엔드(`/api/public/compatibility/*`, CompatibilityRequest/
  // CompatibilityResult 모델)는 이미 완전히 구현되어 있었고(무료 정책까지
  // 반영) Flutter 클라이언트만 없던 상태였다. features/compatibility/
  // 모듈(입력 화면 `/compatibility/input`)을 신규 구현해 연결한다. 유형별로
  // routeArguments에 [CompatibilityType]을 전달해 입력 화면 진입 시 해당
  // 유형이 미리 선택되게 한다.
  static final _cGroup = FortuneCategoryGroupEntry(
    code: FortuneGroupCode.c,
    items: [
      FortuneCategoryEntry(
        id: 'C-001',
        group: FortuneGroupCode.c,
        title: '연인 궁합',
        shortDescription: '서로를 향한 마음의 결을 살펴보기',
        gate: GateResult.freeOncePerDay,
        existingRoute: compatibilityInputRoute,
        routeArguments: CompatibilityType.love,
        disclaimers: [DisclaimerTag.relationship],
      ),
      FortuneCategoryEntry(
        id: 'C-002',
        group: FortuneGroupCode.c,
        title: '짝사랑 궁합',
        shortDescription: '마음에 둔 상대와의 인연 흐름',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: compatibilityInputRoute,
        routeArguments: CompatibilityType.love,
        disclaimers: [DisclaimerTag.relationship],
      ),
      FortuneCategoryEntry(
        id: 'C-003',
        group: FortuneGroupCode.c,
        title: '친구 궁합',
        shortDescription: '오래갈 인연인지 가볍게 확인',
        gate: GateResult.freeOncePerDay,
        existingRoute: compatibilityInputRoute,
        routeArguments: CompatibilityType.friend,
      ),
      FortuneCategoryEntry(
        id: 'C-004',
        group: FortuneGroupCode.c,
        title: '동업·사업 파트너 궁합',
        shortDescription: '함께 일하기 좋은 상대인지 확인',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: compatibilityInputRoute,
        routeArguments: CompatibilityType.business,
        disclaimers: [DisclaimerTag.finance],
      ),
      FortuneCategoryEntry(
        id: 'C-005',
        group: FortuneGroupCode.c,
        title: '가족·부모자녀 궁합',
        shortDescription: '가까운 가족과의 관계 흐름',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: compatibilityInputRoute,
        routeArguments: CompatibilityType.family,
      ),
      FortuneCategoryEntry(
        id: 'C-006',
        group: FortuneGroupCode.c,
        title: '결혼 궁합',
        shortDescription: '평생을 함께할 인연인지 깊게 보기',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: compatibilityInputRoute,
        routeArguments: CompatibilityType.love,
        disclaimers: [DisclaimerTag.relationship],
      ),
      FortuneCategoryEntry(
        id: 'C-007',
        group: FortuneGroupCode.c,
        title: '전 연인과의 재회운',
        shortDescription: '헤어진 인연의 현재 흐름 확인',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: compatibilityInputRoute,
        routeArguments: CompatibilityType.love,
        disclaimers: [DisclaimerTag.relationship],
      ),
    ],
  );

  // ── K: 택일 (8) — 아직 화면이 없어 공용 결과 화면으로 연결.
  static final _kGroup = FortuneCategoryGroupEntry(
    code: FortuneGroupCode.k,
    items: [
      FortuneCategoryEntry(
        id: 'K-001',
        group: FortuneGroupCode.k,
        title: '결혼식 좋은 날',
        shortDescription: '결혼식에 어울리는 날짜',
        gate: GateResult.lockedFreeFirst,
        disclaimers: [DisclaimerTag.legalDate, DisclaimerTag.relationship],
        resultSeedTags: ['택일', '결혼'],
      ),
      FortuneCategoryEntry(
        id: 'K-002',
        group: FortuneGroupCode.k,
        title: '이사하기 좋은 날',
        shortDescription: '이사에 어울리는 날짜',
        gate: GateResult.paidOnlyPassGate,
        disclaimers: [DisclaimerTag.legalDate],
        resultSeedTags: ['택일', '이사'],
      ),
      FortuneCategoryEntry(
        id: 'K-003',
        group: FortuneGroupCode.k,
        title: '개업하기 좋은 날',
        shortDescription: '가게·사업 시작에 좋은 날짜',
        gate: GateResult.paidOnlyPassGate,
        disclaimers: [DisclaimerTag.legalDate, DisclaimerTag.finance],
        resultSeedTags: ['택일', '개업'],
      ),
      FortuneCategoryEntry(
        id: 'K-004',
        group: FortuneGroupCode.k,
        title: '계약하기 좋은 날',
        shortDescription: '중요한 계약에 어울리는 날짜',
        gate: GateResult.paidOnlyPassGate,
        disclaimers: [DisclaimerTag.legalDate, DisclaimerTag.finance],
        resultSeedTags: ['택일', '계약'],
      ),
      FortuneCategoryEntry(
        id: 'K-005',
        group: FortuneGroupCode.k,
        title: '수술·병원 좋은 날',
        shortDescription: '컨디션 관리에 참고할 날짜',
        gate: GateResult.paidOnlyPassGate,
        disclaimers: [DisclaimerTag.legalDate, DisclaimerTag.medical],
        resultSeedTags: ['택일', '건강'],
      ),
      FortuneCategoryEntry(
        id: 'K-006',
        group: FortuneGroupCode.k,
        title: '여행 출발 좋은 날',
        shortDescription: '여행 출발에 어울리는 날짜',
        gate: GateResult.freeOncePerDay,
        disclaimers: [DisclaimerTag.legalDate],
        resultSeedTags: ['택일', '여행'],
      ),
      FortuneCategoryEntry(
        id: 'K-007',
        group: FortuneGroupCode.k,
        title: '시험·면접 좋은 날',
        shortDescription: '중요한 시험·면접 날짜 참고',
        gate: GateResult.lockedFreeFirst,
        disclaimers: [DisclaimerTag.legalDate],
        resultSeedTags: ['택일', '시험'],
      ),
      FortuneCategoryEntry(
        id: 'K-008',
        group: FortuneGroupCode.k,
        title: '이장·제사 좋은 날',
        shortDescription: '전통 의례에 참고할 날짜',
        gate: GateResult.paidOnlyPassGate,
        disclaimers: [DisclaimerTag.legalDate],
        resultSeedTags: ['택일', '의례'],
      ),
    ],
  );

  // ── V: 평생운 (3) ──
  static final _vGroup = FortuneCategoryGroupEntry(
    code: FortuneGroupCode.v,
    items: [
      FortuneCategoryEntry(
        id: 'V-001',
        group: FortuneGroupCode.v,
        title: '평생 총운',
        shortDescription: '인생 전체를 관통하는 흐름',
        gate: GateResult.lockedFreeFirst,
        resultSeedTags: ['평생운'],
      ),
      FortuneCategoryEntry(
        id: 'V-002',
        group: FortuneGroupCode.v,
        title: '평생 재물운',
        shortDescription: '인생 전체의 재물 그릇',
        gate: GateResult.paidOnlyPassGate,
        disclaimers: [DisclaimerTag.finance],
        resultSeedTags: ['평생운', '재물'],
      ),
      FortuneCategoryEntry(
        id: 'V-003',
        group: FortuneGroupCode.v,
        title: '평생 직업운',
        shortDescription: '인생 전체의 직업·적성 흐름',
        gate: GateResult.paidOnlyPassGate,
        resultSeedTags: ['평생운', '직업'],
      ),
    ],
  );

  // ── O: 오늘의 추천 (5) — 가벼운 캐주얼 콘텐츠.
  static final _oGroup = FortuneCategoryGroupEntry(
    code: FortuneGroupCode.o,
    items: [
      FortuneCategoryEntry(
        id: 'O-001',
        group: FortuneGroupCode.o,
        title: '오늘의 추천 음식',
        shortDescription: '기운을 채워주는 음식 추천',
        gate: GateResult.openFree,
        resultSeedTags: ['추천', '음식'],
      ),
      FortuneCategoryEntry(
        id: 'O-002',
        group: FortuneGroupCode.o,
        title: '오늘의 추천 컬러 코디',
        shortDescription: '오늘 어울리는 색 조합',
        gate: GateResult.openFree,
        resultSeedTags: ['추천', '색'],
      ),
      FortuneCategoryEntry(
        id: 'O-003',
        group: FortuneGroupCode.o,
        title: '오늘의 추천 플레이리스트',
        shortDescription: '기분에 맞는 음악 분위기',
        gate: GateResult.freeOncePerDay,
        resultSeedTags: ['추천', '음악'],
      ),
      FortuneCategoryEntry(
        id: 'O-004',
        group: FortuneGroupCode.o,
        title: '오늘의 행운 번호',
        shortDescription: '가볍게 참고하는 번호 조합',
        gate: GateResult.freeOncePerDay,
        disclaimers: [DisclaimerTag.lottery],
        resultSeedTags: ['추천', '번호'],
      ),
      FortuneCategoryEntry(
        id: 'O-005',
        group: FortuneGroupCode.o,
        title: '오늘의 추천 활동 코스',
        shortDescription: '기운에 맞는 하루 동선 추천',
        gate: GateResult.paidOnlyPassGate,
        resultSeedTags: ['추천', '활동'],
      ),
    ],
  );

  // ── F: 관상·손금(카메라) (5) — 기존 face/palm capture 화면 재사용.
  static final _fGroup = FortuneCategoryGroupEntry(
    code: FortuneGroupCode.f,
    items: [
      FortuneCategoryEntry(
        id: 'F-001',
        group: FortuneGroupCode.f,
        title: '오늘의 관상',
        shortDescription: '얼굴에 담긴 오늘의 기운',
        gate: GateResult.lockedFreeFirst,
        existingRoute: faceCaptureRoute,
        disclaimers: [DisclaimerTag.camera],
      ),
      FortuneCategoryEntry(
        id: 'F-002',
        group: FortuneGroupCode.f,
        title: '관상 종합 분석',
        shortDescription: '9구역 비율로 보는 인상 풀이',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: faceCaptureRoute,
        disclaimers: [DisclaimerTag.camera],
      ),
      FortuneCategoryEntry(
        id: 'F-003',
        group: FortuneGroupCode.f,
        title: '오늘의 손금',
        shortDescription: '손금에 담긴 오늘의 기운',
        gate: GateResult.lockedFreeFirst,
        existingRoute: palmCaptureRoute,
        disclaimers: [DisclaimerTag.camera],
      ),
      FortuneCategoryEntry(
        id: 'F-004',
        group: FortuneGroupCode.f,
        title: '손금 재물선 분석',
        shortDescription: '재물선 중심 심층 풀이',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: palmCaptureRoute,
        disclaimers: [DisclaimerTag.camera, DisclaimerTag.finance],
      ),
      FortuneCategoryEntry(
        id: 'F-005',
        group: FortuneGroupCode.f,
        title: '관상+손금 종합',
        shortDescription: '얼굴과 손을 함께 보는 종합 풀이',
        gate: GateResult.paidOnlyPassGate,
        existingRoute: faceCaptureRoute,
        disclaimers: [DisclaimerTag.camera],
      ),
    ],
  );

  // ── X: 교차분석 (4) ──
  static final _xGroup = FortuneCategoryGroupEntry(
    code: FortuneGroupCode.x,
    items: [
      FortuneCategoryEntry(
        id: 'X-001',
        group: FortuneGroupCode.x,
        title: '사주 × 오늘의 운세 교차분석',
        shortDescription: '타고난 기운과 오늘의 흐름을 겹쳐보기',
        gate: GateResult.paidOnlyPassGate,
        resultSeedTags: ['교차분석'],
      ),
      FortuneCategoryEntry(
        id: 'X-002',
        group: FortuneGroupCode.x,
        title: '사주 × 궁합 교차분석',
        shortDescription: '나의 사주와 관계 궁합을 함께 보기',
        gate: GateResult.paidOnlyPassGate,
        disclaimers: [DisclaimerTag.relationship],
        resultSeedTags: ['교차분석'],
      ),
      FortuneCategoryEntry(
        id: 'X-003',
        group: FortuneGroupCode.x,
        title: '관상 × 사주 교차분석',
        shortDescription: '얼굴에 담긴 기운과 사주를 함께 보기',
        gate: GateResult.paidOnlyPassGate,
        disclaimers: [DisclaimerTag.camera],
        resultSeedTags: ['교차분석'],
      ),
      FortuneCategoryEntry(
        id: 'X-004',
        group: FortuneGroupCode.x,
        title: '이름 × 사주 교차분석',
        shortDescription: '이름의 기운과 사주를 함께 보기',
        gate: GateResult.paidOnlyPassGate,
        resultSeedTags: ['교차분석'],
      ),
    ],
  );

  // ── G: 운세 그래프 (2) ──
  static final _gGroup = FortuneCategoryGroupEntry(
    code: FortuneGroupCode.g,
    items: [
      FortuneCategoryEntry(
        id: 'G-001',
        group: FortuneGroupCode.g,
        title: '인생 그래프',
        shortDescription: '연령대별 기운 흐름 시각화',
        gate: GateResult.lockedFreeFirst,
        resultSeedTags: ['그래프'],
      ),
      FortuneCategoryEntry(
        id: 'G-002',
        group: FortuneGroupCode.g,
        title: '오행 균형 그래프',
        shortDescription: '목화토금수 기운의 균형 시각화',
        gate: GateResult.paidOnlyPassGate,
        resultSeedTags: ['그래프'],
      ),
    ],
  );

  // ── B: 추천 연계 (1) — 진입 장벽 없이 다음 기능으로 안내하는 브릿지.
  static final _bGroup = FortuneCategoryGroupEntry(
    code: FortuneGroupCode.b,
    items: [
      FortuneCategoryEntry(
        id: 'B-001',
        group: FortuneGroupCode.b,
        title: '나에게 맞는 다음 운세 추천',
        shortDescription: '방금 본 결과와 어울리는 다음 카테고리',
        gate: GateResult.openFree,
        resultSeedTags: ['추천연계'],
      ),
    ],
  );

  // ── D: 꿈해몽 (18) ──
  static final _dGroup = FortuneCategoryGroupEntry(
    code: FortuneGroupCode.d,
    items: [
      FortuneCategoryEntry(
        id: 'D-001',
        group: FortuneGroupCode.d,
        title: '물 꿈해몽',
        shortDescription: '물이 나오는 꿈의 의미',
        gate: GateResult.freeOncePerDay,
        disclaimers: [DisclaimerTag.dream],
        resultSeedTags: ['해몽', '물'],
      ),
      FortuneCategoryEntry(
        id: 'D-002',
        group: FortuneGroupCode.d,
        title: '불 꿈해몽',
        shortDescription: '불이 나오는 꿈의 의미',
        gate: GateResult.freeOncePerDay,
        disclaimers: [DisclaimerTag.dream],
        resultSeedTags: ['해몽', '불'],
      ),
      FortuneCategoryEntry(
        id: 'D-003',
        group: FortuneGroupCode.d,
        title: '뱀 꿈해몽',
        shortDescription: '뱀이 나오는 꿈의 의미',
        gate: GateResult.freeOncePerDay,
        disclaimers: [DisclaimerTag.dream],
        resultSeedTags: ['해몽', '뱀'],
      ),
      FortuneCategoryEntry(
        id: 'D-004',
        group: FortuneGroupCode.d,
        title: '돈 꿈해몽',
        shortDescription: '돈이 나오는 꿈의 의미',
        gate: GateResult.freeOncePerDay,
        disclaimers: [DisclaimerTag.dream, DisclaimerTag.finance],
        resultSeedTags: ['해몽', '돈'],
      ),
      FortuneCategoryEntry(
        id: 'D-005',
        group: FortuneGroupCode.d,
        title: '죽음 꿈해몽',
        shortDescription: '죽음과 관련된 꿈의 의미',
        gate: GateResult.freeOncePerDay,
        disclaimers: [DisclaimerTag.dream],
        resultSeedTags: ['해몽', '죽음'],
      ),
      FortuneCategoryEntry(
        id: 'D-006',
        group: FortuneGroupCode.d,
        title: '결혼 꿈해몽',
        shortDescription: '결혼식이 나오는 꿈의 의미',
        gate: GateResult.freeOncePerDay,
        disclaimers: [DisclaimerTag.dream, DisclaimerTag.relationship],
        resultSeedTags: ['해몽', '결혼'],
      ),
      FortuneCategoryEntry(
        id: 'D-007',
        group: FortuneGroupCode.d,
        title: '아기 꿈해몽',
        shortDescription: '아기가 나오는 꿈의 의미',
        gate: GateResult.freeOncePerDay,
        disclaimers: [DisclaimerTag.dream, DisclaimerTag.infant],
        resultSeedTags: ['해몽', '아기'],
      ),
      FortuneCategoryEntry(
        id: 'D-008',
        group: FortuneGroupCode.d,
        title: '동물 꿈해몽',
        shortDescription: '동물이 나오는 꿈의 의미',
        gate: GateResult.freeOncePerDay,
        disclaimers: [DisclaimerTag.dream],
        resultSeedTags: ['해몽', '동물'],
      ),
      FortuneCategoryEntry(
        id: 'D-009',
        group: FortuneGroupCode.d,
        title: '교통사고 꿈해몽',
        shortDescription: '사고가 나오는 꿈의 의미',
        gate: GateResult.freeOncePerDay,
        disclaimers: [DisclaimerTag.dream, DisclaimerTag.medical],
        resultSeedTags: ['해몽', '사고'],
      ),
      FortuneCategoryEntry(
        id: 'D-010',
        group: FortuneGroupCode.d,
        title: '시험 꿈해몽',
        shortDescription: '시험이 나오는 꿈의 의미',
        gate: GateResult.freeOncePerDay,
        disclaimers: [DisclaimerTag.dream],
        resultSeedTags: ['해몽', '시험'],
      ),
      FortuneCategoryEntry(
        id: 'D-011',
        group: FortuneGroupCode.d,
        title: '연인 꿈해몽',
        shortDescription: '연인이 나오는 꿈의 의미',
        gate: GateResult.freeOncePerDay,
        disclaimers: [DisclaimerTag.dream, DisclaimerTag.relationship],
        resultSeedTags: ['해몽', '연인'],
      ),
      FortuneCategoryEntry(
        id: 'D-012',
        group: FortuneGroupCode.d,
        title: '조상 꿈해몽',
        shortDescription: '조상이 나오는 꿈의 의미',
        gate: GateResult.freeOncePerDay,
        disclaimers: [DisclaimerTag.dream],
        resultSeedTags: ['해몽', '조상'],
      ),
      FortuneCategoryEntry(
        id: 'D-013',
        group: FortuneGroupCode.d,
        title: '비행·추락 꿈해몽',
        shortDescription: '날거나 떨어지는 꿈의 의미',
        gate: GateResult.freeOncePerDay,
        disclaimers: [DisclaimerTag.dream],
        resultSeedTags: ['해몽', '비행'],
      ),
      FortuneCategoryEntry(
        id: 'D-014',
        group: FortuneGroupCode.d,
        title: '화재 꿈해몽',
        shortDescription: '불이 나는 꿈의 의미',
        gate: GateResult.freeOncePerDay,
        disclaimers: [DisclaimerTag.dream],
        resultSeedTags: ['해몽', '화재'],
      ),
      FortuneCategoryEntry(
        id: 'D-015',
        group: FortuneGroupCode.d,
        title: '이빨 꿈해몽',
        shortDescription: '이가 빠지는 꿈의 의미',
        gate: GateResult.freeOncePerDay,
        disclaimers: [DisclaimerTag.dream, DisclaimerTag.medical],
        resultSeedTags: ['해몽', '이빨'],
      ),
      FortuneCategoryEntry(
        id: 'D-016',
        group: FortuneGroupCode.d,
        title: '종합 해몽 리포트',
        shortDescription: '여러 꿈 요소를 모아 종합 풀이',
        gate: GateResult.paidOnlyPassGate,
        disclaimers: [DisclaimerTag.dream],
        resultSeedTags: ['해몽', '종합'],
      ),
      FortuneCategoryEntry(
        id: 'D-017',
        group: FortuneGroupCode.d,
        title: '반복되는 꿈 분석',
        shortDescription: '자꾸 꾸는 꿈의 패턴 분석',
        gate: GateResult.paidOnlyPassGate,
        disclaimers: [DisclaimerTag.dream],
        resultSeedTags: ['해몽', '반복'],
      ),
      FortuneCategoryEntry(
        id: 'D-018',
        group: FortuneGroupCode.d,
        title: '재물꿈 특별 해몽',
        shortDescription: '재물과 관련된 꿈 심층 풀이',
        gate: GateResult.paidOnlyPassGate,
        disclaimers: [DisclaimerTag.dream, DisclaimerTag.finance],
        resultSeedTags: ['해몽', '재물'],
      ),
    ],
  );

  // ── R: 리포트 (3) ──
  static final _rGroup = FortuneCategoryGroupEntry(
    code: FortuneGroupCode.r,
    items: [
      FortuneCategoryEntry(
        id: 'R-001',
        group: FortuneGroupCode.r,
        title: '이번 주 요약 리포트',
        shortDescription: '한 주간 확인한 운세 요약',
        gate: GateResult.openFree,
        resultSeedTags: ['리포트'],
      ),
      FortuneCategoryEntry(
        id: 'R-002',
        group: FortuneGroupCode.r,
        title: 'PDF 공유 리포트',
        shortDescription: '결과를 정리해 저장·공유',
        gate: GateResult.paidOnlyPassGate,
        resultSeedTags: ['리포트'],
      ),
      FortuneCategoryEntry(
        id: 'R-003',
        group: FortuneGroupCode.r,
        title: '월간 프리미엄 리포트',
        shortDescription: '한 달 흐름을 모아보는 심층 리포트',
        gate: GateResult.paidOnlyPassGate,
        resultSeedTags: ['리포트'],
      ),
    ],
  );
}
