import 'dart:math';

import '../../fortune/shared/domain/fortune_report_model.dart';
import 'jeontong_eighty_calculator.dart';
import 'jeontong_eighty_matrix.dart';
import 'manseryeok/manseryeok_core_engine.dart';
import 'manseryeok/manseryeok_policy.dart';
import 'manseryeok/phase2_analysis_engine.dart';
import 'manseryeok/phase3_analysis_engine.dart';
import 'manseryeok/phase4_analysis_engine.dart';
import 'manseryeok/saju_result_adapter.dart';
import 'saju_engine.dart';
import 'saju_fortune_rules.dart';
import 'saju_interpreter.dart';

/// [정통사주 80종 개편] 정통사주 80종 전용 결정론적 콘텐츠 생성기.
///
/// [백엔드 결정 - A안] 사용자가 클라이언트 룰베이스(백엔드 미배포)를
/// 선택했으므로, 사용자가 업로드한 `saju_engine_v4_final.zip`의 실제 만세력
/// 계산 로직(일간/오행/십신/대운 등)은 이식하지 않는다. 대신 기존
/// `GenericFortuneReportBuilder`와 완전히 동일한 원칙 — "같은 입력(오늘 날짜
/// + 카테고리 id)이면 항상 같은 결과"(시드 기반 [Random]) — 을 따르는 전용
/// 빌더를 새로 둔다.
///
/// [신규 클래스를 만든 이유] 기존 [GenericFortuneReportBuilder]는
/// `FortuneCategoryEntry`(37종 매트릭스 전용 모델)를 직접 참조하므로, 80종을
/// 그 모델에 억지로 끼워 넣으려면 `FortuneGroupCode` enum을 8개 그룹만큼
/// 확장해야 하고, 그 enum을 배타적으로 switch하는 기존 파일들
/// (`fortune_matrix_section.dart`, `categories_grid_screen.dart`)까지 함께
/// 고쳐야 해 기존 37종 시스템에 회귀 위험을 만든다. 대신 동일한 "패턴"만
/// 재사용하고 입력 타입을 [JeontongCategoryEntry]로 분리해 완전히 독립적으로
/// 동작하게 한다(기존 코드 無변경).
///
/// [2026-08-13 개인화 배선] 기존 build() 는 (오늘 날짜 + 카테고리 id) 만으로
/// 결과가 결정되어, 같은 카테고리라면 어떤 사용자가 조회하든 항상 동일한
/// 결과를 반환했다. 아래 4개의 named 인자(userId/birthDateTimeUtc/gender/
/// isLunar)를 모두 default null 로 추가해 하위호환을 유지하면서, non-null
/// 값이 들어오면 결과의 "선택된 슬롯"(순서/인덱스)만 사용자별로 결정론적으로
/// 달라지게 한다. 문구·풀(pool) 데이터 자체는 이 변경에서 한 글자도
/// 수정하지 않는다 — [_buildBaseReport]가 곧 원래의 build() 본문 그대로다.
class JeontongReportBuilder {
  JeontongReportBuilder._();

  /// 기존 build() 시그니처를 유지하면서 개인화 4축을 추가한 공개 진입점.
  ///
  /// [2026-08-14 실계산 배선] `birthDateTimeUtc`가 주어지고, [SajuRules]/
  /// [SajuFortuneRules]의 프리로드가 이미 완료돼 있으면(둘 다
  /// `cachedOrNull`이 non-null) 실제 만세력 계산(`SajuEngine` →
  /// `SajuInterpreter.fullInterpretation` → `runJeontongCategory`)을 거쳐
  /// 실계산 기반 [FortuneReport]를 반환한다. 아래 경우에는 안전하게 기존
  /// 폴백 경로(같은 입력이면 같은 결과인 결정론적 랜덤 콘텐츠)로 떨어진다:
  ///   - `birthDateTimeUtc`가 null (아직 생년월일시를 모름)
  ///   - rules 프리로드가 아직 완료되지 않음(비동기 로딩 중)
  ///   - 해당 카테고리가 아직 플레이스홀더(원본 파이썬도 미구현)이거나
  ///     상대 사주가 필요한 궁합 카테고리(E01~E07)
  ///   - 계산 도중 예외 발생(방어적 안전망 — 결과 화면이 절대 깨지지 않게)
  ///
  /// 4축이 모두 null 이면 [_buildBaseReport]의 결과를 그대로 반환한다(완전
  /// 하위호환). 실계산도, personalization 도 적용되지 않는 경우 하나라도
  /// non-null 이면, base 결과의 텍스트 콘텐츠는 그대로 두고 "이미 base 가
  /// 골라둔 값들의 순서/인덱스"만 사용자별 seed로 회전한다.
  static FortuneReport build(
    JeontongCategoryEntry entry, {
    DateTime? date,
    String? userId,
    DateTime? birthDateTimeUtc,
    String? gender,
    bool? isLunar,
  }) {
    final base = _buildBaseReport(entry, date: date);

    if (birthDateTimeUtc != null) {
      final real = _tryBuildRealReport(
        entry,
        base: base,
        date: date,
        birthDateTimeUtc: birthDateTimeUtc,
        gender: gender,
        isLunar: isLunar,
      );
      if (real != null) return real;
    }

    if (userId == null &&
        birthDateTimeUtc == null &&
        gender == null &&
        isLunar == null) {
      return base;
    }

    final seed = _jeontongPersonalizationSeed(
      categoryCode: entry.id,
      userId: userId,
      birthDateTimeUtc: birthDateTimeUtc,
      gender: gender,
      isLunar: isLunar,
    );

    return _applyPersonalization(base, seed: seed);
  }

  /// 실계산 시도. 준비가 안 됐거나(rules 미로드) 실패하면 null을 반환해
  /// 호출부가 기존 폴백 경로를 타도록 한다 — 절대 throw 하지 않는다.
  static FortuneReport? _tryBuildRealReport(
    JeontongCategoryEntry entry, {
    required FortuneReport base,
    DateTime? date,
    required DateTime birthDateTimeUtc,
    String? gender,
    bool? isLunar,
  }) {
    try {
      final rules = SajuRules.cachedOrNull;
      final fortuneRules = SajuFortuneRules.cachedOrNull;
      if (rules == null || fortuneRules == null) return null;

      // birthDateTimeUtc 는 UTC 저장값이므로, KST(UTC+9) 벽시계 시각으로
      // 변환해 SajuEngine 에 넘긴다(테스트 픽스처 주석과 동일한 규약 —
      // 예: 1972-02-12 17:00Z == 1972-02-13 02:00 KST).
      final kst = birthDateTimeUtc.add(const Duration(hours: 9));
      final sajuGender = gender == 'F' || gender == 'female' ? 'female' : 'male';
      final referenceDate = date ?? DateTime.now();

      // [j7 · A01→B01→C01→D01→A02→A03→A04→A05→A06 신규 엔진 순차 이전 —
      // entry.id 기준 분기] 검증 완료된 카테고리(A01, B01, C01, D01, A02,
      // A03, A04, A05, A06)만 PHASE1~4(만세력 단일 기준 엔진) →
      // SajuProfile → sajuResultFromProfile() 어댑터 → 기존 해석 계층
      // 경로를 탄다. 아직 검증하지 않은 나머지 카테고리는 이번 단계에서
      // 동작을 변경하지 않기 위해 기존 `SajuEngine.calculate()` 경로를
      // 그대로 유지한다(사용자 지시 §1 "검증되지 않은 카테고리의 동작은
      // 이번 단계에서 변경하지 마세요"). 카테고리가 하나씩 검증될 때마다
      // 이 분기에 id를 추가해 나가는 방식으로 32개 전체를 순차 이전한다.
      const migratedCategoryIds = {
        'A01',
        'B01',
        'C01',
        'D01',
        'A02',
        'A03',
        'A04',
        'A05',
        'A06',
      };
      final SajuResult saju = migratedCategoryIds.contains(entry.id)
          ? _buildSajuResultViaPhase1to4(
              kst: kst,
              gender: sajuGender,
              isLunar: isLunar ?? false,
              referenceDate: referenceDate,
            )
          : SajuEngine.calculate(
              year: kst.year,
              month: kst.month,
              day: kst.day,
              hour: kst.hour,
              minute: kst.minute,
              gender: sajuGender,
              isLunar: isLunar ?? false,
              referenceDate: referenceDate,
            );

      final interp = SajuInterpreter.fullInterpretation(saju);
      final ctx = JeontongCalcContext(
        saju: saju,
        interp: interp,
        rules: fortuneRules,
        referenceDate: referenceDate,
      );

      final result = runJeontongCategory(entry.id, ctx);
      if (_isPlaceholderResult(result)) return null;

      return _mapCalculatedResultToReport(entry, result, base);
    } catch (_) {
      // 방어적 안전망 — 어떤 이유로든 실계산이 실패하면 폴백.
      return null;
    }
  }

  /// [j7 · A01 신규 엔진 경로] PHASE1(만세력 원국) → PHASE2(오행/십신/
  /// 지장간/십이운성/합충형파해/신살) → PHASE3(신강신약/용신희신기신구신)
  /// → PHASE4(대운/세운/월운) 순서로 검증 완료된 신규 엔진을 실행하고,
  /// [sajuResultFromProfile] 어댑터로 레거시 [SajuResult] 형태로 변환한다.
  /// 이 함수는 만세력 계산을 다시 하지 않는다 — PHASE1~4가 유일한 계산
  /// 기준이며, 어댑터는 이미 계산된 값을 옮기기만 한다(§2/§3/§7 원칙).
  ///
  /// [kst]는 이미 KST(UTC+9) 벽시계 시각으로 변환된 값(호출부에서 변환
  /// 완료). [isLunar]가 true 이면 [kst]를 음력 생년월일시로 해석한다.
  static SajuResult _buildSajuResultViaPhase1to4({
    required DateTime kst,
    required String gender,
    required bool isLunar,
    required DateTime referenceDate,
  }) {
    final withCore = ManseryeokCoreEngine.buildProfileWithCore(
      year: kst.year,
      month: kst.month,
      day: kst.day,
      hour: kst.hour,
      minute: kst.minute,
      gender: gender,
      calendarType: isLunar ? CalendarInputType.lunar : CalendarInputType.solar,
    );
    final p2 = Phase2AnalysisEngine.analyze(
      baseProfile: withCore.profile,
      core: withCore.core,
    );
    final p3 = Phase3AnalysisEngine.analyze(baseProfile: p2);
    final p4 = Phase4AnalysisEngine.analyze(
      baseProfile: p3,
      core: withCore.core,
      referenceDate: referenceDate,
    );
    return sajuResultFromProfile(p4, referenceDate: referenceDate);
  }

  /// 플레이스홀더/상대 사주 필요 결과 판정. 원본 파이썬도 이 경우
  /// `{"message": ...}` 또는 `{"note": "상대 사주 필요"}` 형태만 반환했다.
  static bool _isPlaceholderResult(JeontongCategoryResult result) {
    final keys = result.data.keys.toSet();
    if (keys.length == 1 && (keys.single == 'message' || keys.single == 'note')) {
      return true;
    }
    return false;
  }

  // ==========================================================
  // [2026-08-14 실계산 배선] JeontongCategoryResult → FortuneReport 매퍼.
  // ==========================================================

  static const Map<String, String> _aspectFieldLabels = {
    'overall': '총운',
    'work': '업무·직장운',
    'wealth': '재물운',
    'career': '직업운',
    'love': '애정운',
    'health': '건강운',
    'mood': '오늘의 기분',
  };

  static const Map<String, String> _listFieldLabels = {
    'recommended_jobs': '추천 직업',
    'activities': '추천 활동',
    'items': '추천 아이템',
    'food': '추천 음식',
    'strengths': '핵심 강점',
    'core_organs': '주요 관리 장기',
    'lifetime_warnings': '평생 건강 주의 신호',
    'weaknesses': '보완하면 좋은 점',
    'advice_food': '추천 음식',
  };

  static const List<String> _overviewFieldOrder = [
    'headline',
    'core_nature',
    'nature',
    'personality',
    'verdict',
    'structure',
    'style',
    'message',
    'summary',
    'year_theme',
    'title',
    'overall',
    'mood',
    'advice',
    'lifestyle',
    'marriage_timing',
    'growth_path',
    'peak_period',
  ];

  static FortuneReport _mapCalculatedResultToReport(
    JeontongCategoryEntry entry,
    JeontongCategoryResult result,
    FortuneReport base,
  ) {
    final data = result.data;

    String? asStr(String key) {
      final v = data[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    List<String> asStrList(String key) {
      final v = data[key];
      if (v is List) {
        return v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      }
      return const [];
    }

    // --- Hero: headline/subDescription 은 실계산 텍스트로 교체.
    // score/statusLabel/keywords 는 base(결정론적 시드) 값을 그대로 재사용
    // 한다 — 원본 파이썬도 0~100 숫자 점수를 산출하지 않으므로, 기존
    // 뷰(HeroSummaryCard)가 요구하는 숫자 스코어 표현은 base 로직을
        // 그대로 빌린다(콘텐츠는 실계산, 스코어 연출은 기존 결정론 유지).
    final headline = asStr('title') ??
        asStr('headline') ??
        asStr('verdict') ??
        asStr('structure') ??
        asStr('style') ??
        entry.title;
    final subDescription = asStr('message') ??
        asStr('overall') ??
        asStr('mood') ??
        asStr('summary') ??
        base.hero.subDescription;

    final hero = FortuneHero(
      score: base.hero.score,
      headline: headline,
      name: entry.title,
      date: base.hero.date,
      statusLabel: base.hero.statusLabel,
      keywords: base.hero.keywords,
      subDescription: subDescription,
    );

    // --- Overview 섹션: 서술형 필드를 순서대로 이어붙인다.
    final overviewParts = <String>[];
    for (final key in _overviewFieldOrder) {
      final v = asStr(key);
      if (v == null) continue;
      if (overviewParts.contains(v)) continue;
      overviewParts.add(v);
    }
    final overviewBody = overviewParts.isNotEmpty
        ? overviewParts.join(' ')
        : (base.sectionsOfType<OverviewSection>().firstOrNull?.body ?? '');

    // --- Aspect 섹션: wealth/career/love/health/work/overall/mood 등.
    final aspectSections = <AspectSection>[];
    for (final key in _aspectFieldLabels.keys) {
      final v = asStr(key);
      if (v == null) continue;
      // 이미 overview 첫머리에 흡수된 문자열(overall/mood)과 중복이면
      // 스킵하지 않는다 — 세부 카드로도 다시 보여주는 편이 사용자에게
      // 더 유용하다(원본 텍스트 무손상 원칙 유지).
      aspectSections.add(
        AspectSection(
          title: _aspectFieldLabels[key]!,
          index: _aspectIndexFor(key, base.hero.score),
          body: v,
        ),
      );
    }

    // --- List 섹션: 추천/강점/주의 등 목록형 필드 중 첫 번째로 존재하는 것.
    ListSection? listSection;
    final advice = asStr('advice');
    for (final key in _listFieldLabels.keys) {
      final items = asStrList(key);
      if (items.isEmpty) continue;
      final combined = <String>[
        if (advice != null && key == _listFieldLabels.keys.first) '조언: $advice',
        ...items,
      ];
      listSection = ListSection(
        title: _listFieldLabels[key]!,
        items: combined.take(5).toList(),
        listType: FortuneSectionType.recommend,
      );
      break;
    }
    listSection ??= advice != null
        ? ListSection(
            title: '오늘의 조언',
            items: [advice],
            listType: FortuneSectionType.recommend,
          )
        : base.sectionsOfType<ListSection>().firstOrNull;

    // --- Lucky 섹션: colors/directions/numbers (lucky_* 접두 포함).
    final colors = asStrList('colors').isNotEmpty
        ? asStrList('colors')
        : asStrList('lucky_color');
    final directions = asStrList('directions').isNotEmpty
        ? asStrList('directions')
        : asStrList('lucky_direction');
    final numbersRaw = data['numbers'] ?? data['lucky_number'];
    final numbers = numbersRaw is List
        ? numbersRaw.map((e) => e.toString()).toList()
        : const <String>[];

    LuckySection? luckySection;
    if (colors.isNotEmpty || directions.isNotEmpty || numbers.isNotEmpty) {
      luckySection = LuckySection(
        title: '함께 보면 좋은 행운 요소',
        items: [
          if (colors.isNotEmpty) LuckyItem(label: '색', value: colors.join(', ')),
          if (directions.isNotEmpty)
            LuckyItem(label: '방향', value: directions.join(', ')),
          if (numbers.isNotEmpty) LuckyItem(label: '숫자', value: numbers.join(', ')),
        ],
      );
    }
    luckySection ??= base.sectionsOfType<LuckySection>().firstOrNull;

    final sections = <FortuneSection>[
      OverviewSection(title: '핵심 해석', body: overviewBody),
      ...aspectSections,
      if (listSection != null) listSection,
      if (luckySection != null) luckySection,
    ];

    return FortuneReport(hero: hero, sections: sections);
  }

  static int _aspectIndexFor(String key, int baseScore) {
    final offset = (key.hashCode % 11) - 5; // -5..5, 결정론적
    return _clamp(baseScore + offset, 50, 96);
  }

  /// [기존 build() 본문 그대로 — 한 글자도 수정하지 않았다. 이름만 옮겼다.]
  static FortuneReport _buildBaseReport(
    JeontongCategoryEntry entry, {
    DateTime? date,
  }) {
    final today = date ?? DateTime.now();
    final seed =
        today.year * 10000 +
        today.month * 100 +
        today.day +
        entry.id.codeUnits.fold<int>(0, (a, b) => a + b);
    final rng = Random(seed);

    final overall = 58 + rng.nextInt(38); // 58~95
    final statusLabel = overall >= 78 ? '상승' : (overall >= 55 ? '보통' : '주의');
    final primaryTag = entry.resultSeedTags.isNotEmpty
        ? entry.resultSeedTags.first
        : entry.major.title;
    final keywords = <String>{primaryTag, _pickOne(rng, _keywordPool)}.toList();

    final hero = FortuneHero(
      score: overall,
      headline: _headline(rng, entry.title, overall),
      name: entry.title,
      date: today,
      statusLabel: statusLabel,
      keywords: keywords,
      subDescription: _pickOne(rng, _subDescriptionPool),
    );

    final sections = <FortuneSection>[
      OverviewSection(title: '핵심 해석', body: _overviewBody(rng, entry, overall)),
      AspectSection(
        title: '자세히 보면',
        index: _clamp(overall + _offset(rng), 50, 96),
        body: _pickOne(rng, _detailPool),
      ),
      AspectSection(
        title: '참고하면 좋을 점',
        index: _clamp(overall + _offset(rng), 50, 96),
        body: _pickOne(rng, _adviceDetailPool),
      ),
      ListSection(
        title: '이렇게 해보면 좋아요',
        items: _pickN(rng, _recommendPool, 3),
        listType: FortuneSectionType.recommend,
      ),
      LuckySection(
        title: '함께 보면 좋은 행운 요소',
        items: [
          LuckyItem(label: '색', value: _pickOne(rng, _luckyColorPool)),
          LuckyItem(label: '방향', value: _pickOne(rng, _luckyDirectionPool)),
          LuckyItem(label: '키워드', value: _pickOne(rng, _keywordPool)),
        ],
      ),
    ];

    return FortuneReport(hero: hero, sections: sections);
  }

  static int _clamp(int v, int min, int max) =>
      v < min ? min : (v > max ? max : v);
  static int _offset(Random rng) => rng.nextInt(11) - 5;
  static String _pickOne(Random rng, List<String> pool) =>
      pool[rng.nextInt(pool.length)];
  static List<String> _pickN(Random rng, List<String> pool, int n) {
    final shuffled = [...pool]..shuffle(rng);
    return shuffled.take(n).toList();
  }

  static String _headline(Random rng, String title, int score) {
    return score >= 80
        ? '$title, 흐름이 뚜렷하게 좋아지는 시기예요'
        : score >= 60
        ? '$title, 무난하게 안정적으로 흘러가는 흐름이에요'
        : '$title, 차분히 다지면서 가면 좋은 시기예요';
  }

  static String _overviewBody(
    Random rng,
    JeontongCategoryEntry entry,
    int score,
  ) {
    final tone = score >= 80
        ? '사주 전체의 기운이 맑고 순조로운 흐름을 보이고 있어요.'
        : score >= 60
        ? '무난한 흐름 속에서 노력한 만큼 결과가 따라오는 시기예요.'
        : '서두르기보다 하나씩 정리하며 다져가면 좋은 흐름이에요.';
    final closing = _pickOne(rng, _closingPool);
    return '${entry.major.title} 관점에서 본 「${entry.title}」이에요. $tone $closing';
  }

  static const _keywordPool = [
    '균형',
    '여유',
    '용기',
    '경청',
    '정리',
    '시작',
    '안정',
    '집중',
    '성장',
    '인내',
  ];

  static const _subDescriptionPool = [
    '무리하지 않고 흐름을 읽는 것이 중요해요.',
    '서두르지 않고 하나씩 정리해가면 좋아요.',
    '평소보다 조금 더 여유를 갖고 움직이면 좋겠어요.',
    '작은 신호에도 귀 기울이면 좋은 힌트를 얻을 수 있어요.',
    '지금까지 쌓아온 흐름이 서서히 드러나는 시기예요.',
  ];

  static const _closingPool = [
    '큰 욕심을 내지 않는다면 안정적으로 흘러갈 가능성이 높아요.',
    '작은 선택 하나가 전체 분위기를 좌우할 수 있으니 신중하게 움직여보세요.',
    '주변과의 교류에서 의외의 힌트를 얻을 수 있어요.',
    '지금 가진 것을 잘 지키는 데 집중하면 좋겠어요.',
    '멀리 보고 천천히 쌓아가는 태도가 특히 중요한 시기예요.',
  ];

  static const _detailPool = [
    '지금까지 쌓아온 흐름이 서서히 결과로 드러나는 시기예요. 조급해하지 않아도 괜찮아요.',
    '작은 변화가 감지되는 시점이에요. 평소와 다른 선택을 해봐도 나쁘지 않아요.',
    '주변의 도움이나 조언이 의외로 큰 힘이 되는 시기예요. 귀를 기울여보세요.',
    '스스로 정한 기준을 지키는 것이 무엇보다 중요한 시기예요.',
    '겉으로 드러나는 변화보다 내면의 준비가 더 중요한 흐름이에요.',
  ];

  static const _adviceDetailPool = [
    '무리한 결정은 잠시 미뤄두고, 지금 가진 정보를 다시 점검해보세요.',
    '가까운 사람과 이야기를 나누면 생각보다 좋은 힌트를 얻을 수 있어요.',
    '평소보다 여유 있는 일정을 잡아보는 것도 좋은 방법이에요.',
    '작은 것부터 하나씩 실천하면 전체 흐름이 자연스럽게 좋아져요.',
    '중요한 판단은 하루 정도 더 생각해보고 결정해도 늦지 않아요.',
  ];

  static const _recommendPool = [
    '오늘 할 일의 우선순위를 다시 점검해보기',
    '가까운 사람에게 먼저 안부 전하기',
    '짧은 산책이나 스트레칭으로 몸 풀기',
    '평소 미뤄둔 정리 해보기',
    '중요한 결정은 하루 정도 더 생각해보기',
    '작은 목표 하나를 정해 실천해보기',
    '오늘 하루 감사한 일 한 가지 떠올려보기',
  ];

  static const _luckyColorPool = [
    '화이트',
    '베이지',
    '네이비',
    '연그린',
    '라벤더',
    '옐로우',
    '골드',
  ];
  static const _luckyDirectionPool = ['동쪽', '남동쪽', '남쪽', '서쪽', '북서쪽', '북쪽'];
}

/// 정통사주 개인화 seed.
/// 같은 입력 → 같은 int. 다른 입력 → 다른 int (99.99% 이상 회피).
///
/// [웹 빌드 호환성 수정] 원래 FNV-1a 64bit 구현은 `0xcbf29ce484222325`,
/// `0xFFFFFFFFFFFFFFFF` 등 JavaScript가 정확히 표현할 수 없는(53bit 안전
/// 정수 범위 초과) 정수 리터럴을 사용해 `flutter build web`(dart2js)이
/// "The integer literal ... can't be represented exactly in JavaScript"
/// 오류로 컴파일 자체를 실패시켰다(Dart VM 기반 `flutter test`에서는 문제가
/// 드러나지 않아 지금까지 미발견 상태였음). 동일한 "같은 입력 → 같은 값,
/// 다른 입력 → 다른 값" 결정론 성질은 유지한 채, FNV-1a **32bit**(offset
/// basis 0x811c9dc5, prime 0x01000193, mask 0xFFFFFFFF — 전부 JS 안전 정수
/// 범위 내)로 교체한다. dart:core만 사용, 새 import 없음.
int _jeontongPersonalizationSeed({
  required String categoryCode,
  String? userId,
  DateTime? birthDateTimeUtc,
  String? gender,
  bool? isLunar,
}) {
  const int fnvPrime32 = 0x01000193;
  int hash = 0x811c9dc5;
  void mix(String s) {
    for (final code in s.codeUnits) {
      hash ^= code;
      hash = (hash * fnvPrime32) & 0xFFFFFFFF;
    }
    hash ^= 0x5c;
    hash = (hash * fnvPrime32) & 0xFFFFFFFF;
  }
  mix('cat:$categoryCode');
  mix('uid:${userId ?? ""}');
  mix('bdt:${birthDateTimeUtc?.toIso8601String() ?? ""}');
  mix('gen:${gender ?? ""}');
  mix('lun:${isLunar == null ? "" : (isLunar ? "1" : "0")}');
  return hash; // 0 ~ 0xFFFFFFFF, non-negative
}

/// base 결과의 문구(String) 콘텐츠는 한 글자도 바꾸지 않는다. base 가 이미
/// 골라둔 값들의 "순서"(keywords/list/lucky 아이템 회전)와 "인덱스"(aspect
/// index 소폭 이동, 기존 클램프 범위 50~96 유지)만 seed 로 결정론적으로
/// 다시 배열한다. 새 문자열 풀은 만들지 않는다 — copyWith 가 모델에 없으므로
/// (STEP 0-D 확인) 각 섹션의 기존 public 생성자로 새 인스턴스를 조립한다.
FortuneReport _applyPersonalization(FortuneReport base, {required int seed}) {
  final keywordShift = seed & 0xFF;
  final luckyShift = (seed >> 8) & 0xFF;
  final listShift = (seed >> 16) & 0xFF;
  final aspectOffset = ((seed >> 24) & 0xFF) % 11 - 5; // -5..5

  final oldHero = base.hero;
  final newHero = FortuneHero(
    score: oldHero.score,
    headline: oldHero.headline,
    name: oldHero.name,
    date: oldHero.date,
    statusLabel: oldHero.statusLabel,
    keywords: _rotateList(oldHero.keywords, keywordShift),
    subDescription: oldHero.subDescription,
  );

  final newSections = base.sections.map<FortuneSection>((section) {
    if (section is AspectSection) {
      return AspectSection(
        title: section.title,
        index: JeontongReportBuilder._clamp(
          section.index + aspectOffset,
          50,
          96,
        ),
        body: section.body,
      );
    }
    if (section is ListSection) {
      return ListSection(
        title: section.title,
        items: _rotateList(section.items, listShift),
        listType: section.type,
      );
    }
    if (section is LuckySection) {
      return LuckySection(
        title: section.title,
        items: _rotateList(section.items, luckyShift),
      );
    }
    // OverviewSection/TimelineSection 등 회전 대상이 없는 섹션은 그대로 둔다.
    return section;
  }).toList();

  return FortuneReport(hero: newHero, sections: newSections);
}

/// 리스트 원소를 새로 만들지 않고 순서만 회전한다(문구 무손상).
List<T> _rotateList<T>(List<T> list, int amount) {
  if (list.length < 2) return list;
  final k = amount % list.length;
  if (k == 0) return list;
  return [...list.sublist(k), ...list.sublist(0, k)];
}
