/// [운섹션 37 카테고리 정리 - 미연동 콘텐츠 삭제] Fortune Fusion(신통방통)
/// 운세 섹션 카테고리 매트릭스.
///
/// 타로(Ta-001~Ta-015, `/ai-fortune/tarot/*`, `/tarot/*`)는 별도로 이미
/// 완성되어 있으므로 이 매트릭스에는 절대 포함하지 않는다.
///
/// [자율 정리 기록 → 미연동 콘텐츠 50개 삭제] 원래 매트릭스에는 아직 전용
/// 화면/실제 콘텐츠 연동이 없는 카테고리(K/V/O/X/G/B/D/R 그룹 42개 +
/// T그룹의 기간 확장 6개)가 공용 결과 화면(시드 기반 더미 콘텐츠)으로만
/// 노출되고 있었다. 사용자 확인 결과 이들은 모두 삭제하고, 실제 화면이
/// 있거나(오늘의 운세/사주/이름/궁합) 실 API 연동 예정인 관상·손금(F그룹)
/// 카테고리만 유지하기로 확정했다. 이제 실제 구현·노출되는 카테고리는
/// 37개이며, 이 파일이 그 단일 소스다.
///
/// 그룹 구성(총 37개):
/// - T(오늘 운세) 15 · S(사주) 5 · N(이름) 5 · C(궁합) 7 · F(관상·손금) 5
///
/// [기존 화면 재사용 원칙] 이미 실제 화면/Provider가 있는 카테고리(오늘의 운세,
/// 사주, 이름, 관상, 손금)는 새 화면을 만들지 않고 기존 라우트를 그대로
/// 재사용한다([existingRoute]). 궁합(C)은 전용 화면이 있으므로 마찬가지로
/// 재사용한다.
library;

// 2026-08-13 결정: 궁합(compatibility)은 블랙리스트 19종에 포함되어 features/compatibility
// 모듈이 삭제되었다. 아래 원 import는 무효화한다.
// import '../../compatibility/domain/compatibility_model.dart';

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

/// 37개 카테고리 그룹 코드(궁합 C 그룹은 features/compatibility/ 모듈로
/// 신규 구현되어 편입되었다 - 위 파일 헤더 참고).
enum FortuneGroupCode { t, s, n, c, f }

extension FortuneGroupCodeLabel on FortuneGroupCode {
  String get label => switch (this) {
    FortuneGroupCode.t => '오늘 운세',
    FortuneGroupCode.s => '사주',
    FortuneGroupCode.n => '이름 운세',
    FortuneGroupCode.c => '궁합',
    FortuneGroupCode.f => '관상·손금',
  };

  String get description => switch (this) {
    FortuneGroupCode.t => '오늘 하루의 흐름을 다양한 항목으로 나눠 확인해보세요',
    FortuneGroupCode.s => '타고난 사주 기운을 재물·애정·건강·월별로 나눠 깊게 해석해보세요',
    FortuneGroupCode.n => '이름에 담긴 기운과 어울림을 풀이해보세요',
    FortuneGroupCode.c => '나와 상대방의 인연을 유형별로 풀이해보세요',
    FortuneGroupCode.f => '얼굴과 손에 담긴 이야기를 사진으로 확인해보세요',
  };
}

/// 37개 카테고리 중 1개 항목의 전체 메타데이터.
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

/// [FortuneMatrix] — 37개 카테고리 전체 카탈로그(단일 소스).
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
    // 2026-08-13 결정: 궁합(C그룹)은 블랙리스트 19종에 포함되어 제거됨.
    // _cGroup,
    _fGroup,
  ];

  static List<FortuneCategoryEntry> get all =>
      groups.expand((g) => g.items).toList();

  static FortuneCategoryEntry? byId(String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  // ── T: 오늘 운세 (15) ──
  // T-001~007, 014~021은 이미 완성된 오늘의 운세 표준 플로우
  // (DailyFortuneResultScreen 내부 섹션별 게이트)를 그대로 재사용한다.
  // [미연동 콘텐츠 삭제] 과거 T-008~013(내일/모레/주간/월간/신년/절기)은
  // 공용 결과 화면(더미 콘텐츠)으로만 노출되던 미연동 카테고리였으므로
  // 삭제했다.
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
  // 2026-08-13 결정: 궁합(compatibility)은 블랙리스트 19종에 포함되어
  // features/compatibility 모듈이 삭제되었다. CompatibilityType 참조가
  // 깨지므로 이 그룹 정의 전체를 무효화한다(groups 리스트에도 이미 미포함).
  /*
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
  */

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
}
