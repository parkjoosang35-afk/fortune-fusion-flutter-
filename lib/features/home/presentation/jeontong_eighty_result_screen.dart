import 'package:flutter/material.dart';

import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/fortune/ai_consult_banner.dart';
import '../../../core/widgets/fortune/disclaimer_banner.dart';
import '../../../core/widgets/fortune/hero_summary_card.dart';
import '../../../core/widgets/fortune/list_card.dart';
import '../../../core/widgets/fortune/lucky_elements_grid.dart';
import '../../../core/widgets/fortune/result_bottom_actions.dart';
import '../../../core/widgets/fortune/section_card.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/data/my_fortune_record_store.dart';
import '../../fortune/shared/domain/fortune_report_model.dart';
import '../data/jeontong_bookmark_store.dart';
import '../data/jeontong_history_store.dart';
import '../data/jeontong_profile_store.dart';
import '../domain/interpretation/analyzers/career_analyzer.dart';
import '../domain/interpretation/analyzers/children_analyzer.dart';
import '../domain/interpretation/analyzers/parents_siblings_analyzer.dart';
import '../domain/interpretation/analyzers/health_analyzer.dart';
import '../domain/interpretation/analyzers/life_overall_analyzer.dart';
import '../domain/interpretation/analyzers/love_analyzer.dart';
import '../domain/interpretation/analyzers/wealth_analyzer.dart';
import '../domain/interpretation/generators/career_narrative_generator.dart';
import '../domain/interpretation/generators/children_narrative_generator.dart';
import '../domain/interpretation/generators/health_narrative_generator.dart';
import '../domain/interpretation/generators/life_overall_narrative_generator.dart';
import '../domain/interpretation/generators/love_narrative_generator.dart';
import '../domain/interpretation/generators/parents_siblings_narrative_generator.dart';
import '../domain/interpretation/generators/wealth_narrative_generator.dart';
import '../domain/jeontong_eighty_calculator.dart'
    show
        JeontongCalcContext,
        kJeontongPlaceholderCategoryIds,
        runJeontongCategory;
import '../domain/jeontong_eighty_matrix.dart';
import '../domain/jeontong_eighty_report_builder.dart'
    show JeontongReportBuilder;
import '../domain/jeontong_input.dart';
import '../domain/jeontong_narrative_interpreter.dart';
import '../domain/jeontong_report_cache.dart';
import '../domain/saju_fortune_rules.dart' show SajuFortuneRules;
import '../domain/saju_interpreter.dart' show SajuInterpreter, SajuRules;
import '../domain/user_profile_to_jeontong_adapter.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/user_model.dart';
import 'package:provider/provider.dart';
import 'jeontong_design/hanji_background.dart';
import 'jeontong_design/hanji_design_tokens.dart';
import 'jeontong_design/jeontong_deep_report_card.dart';
import 'jeontong_design/jeontong_narrative_card.dart';
import 'jeontong_design/jeontong_saju_detail_section.dart';
import 'jeontong_design/saju_seal.dart';
import 'widgets/jeontong_easy_term_toggle.dart';
import 'widgets/jeontong_result_text_extractor.dart';

/// [정통사주 80종 개편] 80종 전용 결과 화면 — 라우트 `/jeontong/eighty/result`.
///
/// arguments로 [JeontongCategoryEntry.id](String, 예: 'A01')를 받는다. 이미
/// [JeontongEightyScreen]에서 탭 시 `navigateWithPassGate`로 게이트 체크를
/// 마치고서야 이 화면으로 들어오므로, 이 화면 자체는 별도 게이트 재검증 없이
/// 바로 결과를 그려준다(기존 SajuResultScreen/TarotResultScreen 등과 동일한
/// "게이트는 진입 전에, 결과 화면은 결과만" 원칙).
///
/// 기존 [GenericFortuneResultScreen]과 동일한 공용 위젯(HeroSummaryCard/
/// SectionCard/ListCard/LuckElementsGrid/ResultBottomActions/AIConsultBanner)을
/// 그대로 재사용해 새 UI 컴포넌트를 만들지 않는다.
/// [2026 무당식 단정 확장 — 그룹①(이진판정형) 사용자 승인 "선택지 B"]
/// "좋다/주의"를 단정할 수 있는 15종(카드 UI는 강행하지 않고, 기존
/// [JeontongNarrativeCard] 줄글 앞에 [buildDeclarativeVerdict] 문장만
/// prepend). F04(창업 vs 직장)는 유형분류에 가까워 이번 1차 구현에서는
/// 제외하고(그룹③ 취급), 나머지는 재검토 없이 확정된 15종 중 F04를 뺀
/// 14종만 포함한다.
const Set<String> kJeontongGroup1BinaryCategoryIds = {
  'A02', 'B04', 'B06', 'B08', 'B09',
  'C08', 'D10',
  'G01', 'G02', 'G03', 'G05', 'G07', 'G08', 'G10',
};

/// [2026 무당식 단정 확장 — 그룹②(타이밍형) 사용자 승인 "선택지 B"]
/// "이미 좋은 시기다/아직 때가 아니다"를 단정할 수 있는 카테고리
/// ([buildTimingVerdict] 사용).
///
/// [재검토 완료 — B03/B07/B10/F10]
/// - B03(대운별 직업 변화): `shift_periods`(관성 발동 대운 목록)가 B02
///   (`peak_periods`)/B05(`active_periods`)와 완전히 동일한
///   "리스트 존재 여부로 발동 시기를 판정"하는 구조라, 그룹②에 편입한다.
/// - B07(다음 대운 미리보기): `hasNext`는 좋다/나쁘다가 아니라 "다음 대운
///   정보가 있는지"만 알려주는 순수 정보 전달형이라 그룹③(줄글 유지)으로
///   남긴다.
/// - B10(대운×세운 조합): `synergy`가 "십신 중첩/분산" 2가지 유형
///   분류일 뿐 좋음/나쁨 판정이 아니라 그룹③으로 남긴다.
/// - F10(유학·해외 진출운): `score`(0~3) 4단계는 "지금이 적기인지"가
///   아니라 "해외 진출에 얼마나 유리한 성향인지"를 나타내는 정도·유형
///   분류에 가까워 그룹③으로 남긴다.
const Set<String> kJeontongGroup2TimingCategoryIds = {
  'B02', 'B03', 'B05',
  'C06', 'C07',
  'F05', 'F06', 'F08', 'F09',
};

class JeontongEightyResultScreen extends StatefulWidget {
  const JeontongEightyResultScreen({super.key, required this.categoryId});

  final String? categoryId;

  @override
  State<JeontongEightyResultScreen> createState() =>
      _JeontongEightyResultScreenState();
}

class _JeontongEightyResultScreenState
    extends State<JeontongEightyResultScreen> {
  bool _saved = false;

  // [정통사주 즐겨찾기] 새 Provider/Repository/Service 를 만들지 않고, 기존
  // JeontongHistoryStore.record() 호출부와 동일한 패턴으로
  // AuthTokenStore.cachedUserIdOrNull ?? fallbackUserId 를 userId 로 사용한다.
  final JeontongBookmarkStore _bookmarks = JeontongBookmarkStore();
  bool _isBookmarked = false;

  // [미션 2 · 4축 관통 배선 + 사주 로딩] 입력 화면(JeontongInputScreen)에서
  // 저장한 프로필을 비동기로 조회해 실제 계산(4축: userId/birthDateTimeUtc/
  // gender/isLunar)에 그대로 전달한다. 조회가 끝나기 전까지는 로딩 화면을
  // 보여준다("사주 로딩" — 사용자 명시 요구사항). 프로필이 아예 없으면(아직
  // 입력 전) 4축을 전부 null로 두어 기존 폴백(결정론적 샘플) 경로를 그대로
  // 탄다 — 이 화면 자체가 입력을 강제하지는 않는다(입력 유도는
  // openJeontongEntry()가 이미 분기 처리).
  bool _profileLoading = true;
  JeontongInput? _profile;

  String get _userId =>
      (AuthTokenStore.cachedUserIdOrNull ?? AuthTokenStore.fallbackUserId)
          .toString();

  @override
  void initState() {
    super.initState();
    // [정통사주 쉬운 설명 토글] 전문 용어 → 쉬운말 룰 JSON을 fire-and-forget
    // 으로 미리 로드해둔다. 실패해도 예외를 삼키고 토글은 폴백 문구를
    // 보여주므로(위젯 자체 문서 참고) await 하지 않는다.
    JeontongEasyTermToggle.preload();
    _loadProfileAndRecord();
  }

  // [신통방통 2단계] 로그인 회원은 서버 UserProfile을 기준으로 사용한다.
  // 로그인 상태면 AuthProvider.currentUser를 우선 사용하고(어댑터로 변환),
  // 비로그인이거나 서버 프로필에 생년월일이 없으면 기존 로컬
  // JeontongProfileStore 폴백 경로를 그대로 탄다(회귀 없음).
  //
  // [회귀 방지] 이 화면을 단독으로(AuthProvider 없이) pump하는 기존 위젯
  // 테스트들이 있으므로, Provider가 트리에 없는 환경에서도 예외 없이 기존
  // 로컬 폴백 경로로 안전하게 넘어가야 한다 — context.read가 던지는
  // ProviderNotFoundException을 흡수한다.
  UserModel? _currentUserOrNull() {
    try {
      return context.read<AuthProvider>().currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadProfileAndRecord() async {
    JeontongInput? profile;
    final user = mounted ? _currentUserOrNull() : null;
    if (user != null) {
      profile = userModelToJeontongInput(user);
    }
    profile ??= await jeontongProfileStore.get(_userId);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _profileLoading = false;
    });

    // [STEP 1-D] 결과 열람 이력 1회 기록. 결정론 골든/체크섬과는 무관한
    // 별도 부수효과이므로 build()가 아닌 여기서 1회만 실행한다.
    // dart:core 전용 in-memory store — HTTP/AI 호출 없음.
    final entry = JeontongEightyMatrix.byId(widget.categoryId ?? '');
    if (entry != null) {
      final hasProfile = profile != null;
      final report = jeontongReportCache.getOrBuild(
        entry: entry,
        userId: hasProfile ? _userId : null,
        birthDateTimeUtc: profile?.birthDateTimeUtc,
        gender: profile?.gender,
        isLunar: profile?.isLunar,
        isLeapMonth: profile?.effectiveIsLeapMonth ?? false,
      );
      JeontongHistoryStore.instance.record(
        userId: _userId,
        categoryId: entry.id,
        title: report.hero.headline,
        subtitle: report.hero.subDescription ?? report.hero.headline,
        createdAtUtc: DateTime.now().toUtc(),
      );
      // [정통사주 즐겨찾기] 화면 진입 시 현재 즐겨찾기 상태를 비동기로
      // 1회 조회한다. SharedPreferences 접근 실패 시에도 store 내부에서
      // in-memory 폴백으로 처리되므로 여기서는 결과만 반영한다.
      _refreshBookmarkFlag(entry.id);
    }
  }

  Future<void> _refreshBookmarkFlag(String categoryId) async {
    final has = await _bookmarks.contains(_userId, categoryId);
    if (mounted) setState(() => _isBookmarked = has);
  }

  Future<void> _onTapBookmark(String categoryId) async {
    final r = await _bookmarks.toggle(_userId, categoryId);
    if (!mounted) return;
    if (r == null) {
      AppToast.show(
        context,
        JeontongBookmarkStore.kSnackFullMessage,
        isError: true,
      );
      return;
    }
    setState(() => _isBookmarked = r);
    AppToast.show(
      context,
      r
          ? JeontongBookmarkStore.kSnackAddedMessage
          : JeontongBookmarkStore.kSnackRemovedMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = JeontongEightyMatrix.byId(widget.categoryId ?? '');
    return Scaffold(
      body: HanjiBackground(
        sigilOpacity: 0.12,
        child: SafeArea(
          child: entry == null
              ? const _NotFoundView()
              : _profileLoading
              ? const _JeontongLoadingView()
              : _ResultBody(
                  entry: entry,
                  profile: _profile,
                  userId: _userId,
                  saved: _saved,
                  isBookmarked: _isBookmarked,
                  onSave: () => _onSave(entry),
                  onToggleBookmark: () => _onTapBookmark(entry.id),
                  onOpenAiConsult: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/consultation/type'),
                ),
        ),
      ),
    );
  }

  Future<void> _onSave(JeontongCategoryEntry entry) async {
    final hasProfile = _profile != null;
    final report = jeontongReportCache.getOrBuild(
      entry: entry,
      userId: hasProfile ? _userId : null,
      birthDateTimeUtc: _profile?.birthDateTimeUtc,
      gender: _profile?.gender,
      isLunar: _profile?.isLunar,
      isLeapMonth: _profile?.effectiveIsLeapMonth ?? false,
    );
    await MyFortuneRecordStore.save(
      SavedFortuneRecord(
        id: 'jeontong80_${entry.id}_${DateTime.now().toIso8601String().substring(0, 10)}',
        categoryLabel: entry.title,
        title: report.hero.headline,
        summary: report.hero.subDescription ?? report.hero.headline,
        score: report.hero.score,
        date: report.hero.date,
        savedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    setState(() => _saved = true);
    AppToast.show(context, '마이 > 내 운세 기록에 저장되었어요');
  }
}

/// [미션 2 · 사주 로딩] 저장된 프로필(생년월일시 등) 조회가 끝날 때까지
/// 보여주는 로딩 화면. 실제 계산은 대부분 마이크로초 단위로 끝나지만,
/// SharedPreferences 접근이 비동기이므로 그 사이 빈 화면 대신 명시적인
/// 로딩 상태를 보여줘 "서비스답게" 만든다(사용자 명시 요구사항).
class _JeontongLoadingView extends StatelessWidget {
  const _JeontongLoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Header(title: '정통사주'),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: HanjiColors.accent),
                const SizedBox(height: HanjiSpacing.md),
                Text(
                  '사주를 풀이하고 있어요...',
                  style: HanjiTextStyles.body(color: HanjiColors.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// [정통사주 · Dawn Hanji 디자인 통합] 결과 화면 상단 헤더 —
/// [SajuCtxBar]를 감싸되, 즐겨찾기 별 아이콘 같은 우측 액션 슬롯
/// (`trailing`)을 그대로 지원한다. `ValueKey('jeontong_bookmark_toggle')`
/// 계약(테스트: jeontong_eighty_result_bookmark_toggle_test.dart)은
/// 호출부(_ResultBody)에서 그대로 유지된다 — 이 위젯은 배치만 담당.
class _Header extends StatelessWidget {
  const _Header({required this.title, this.trailing});
  final String title;
  // [정통사주 즐겨찾기] 결과 화면 헤더 우측에 별 아이콘을 얹기 위한 선택적
  // 슬롯. null 이면 기존과 완전히 동일(회귀 없음) — _NotFoundView 등 다른
  // 호출부는 이 인자를 넘기지 않는다.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SajuCtxBar(
            tag: 'SAJU · 결과',
            code: '解',
            title: title,
            onBack: () => Navigator.of(context).pop(),
          ),
        ),
        if (trailing != null) ...[
          Padding(
            padding: const EdgeInsets.only(right: HanjiSpacing.xl),
            child: trailing!,
          ),
        ],
      ],
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Header(title: '정통사주'),
        Expanded(
          child: Center(
            child: Text('아직 준비 중인 카테고리예요', style: UnifiedText.body()),
          ),
        ),
      ],
    );
  }
}

/// [미션 3 · 48종 플레이스홀더 UX 안전장치] "일반 풀이 참고용" 톤다운 배너.
///
/// [DisclaimerBanner]와 시각적으로 구분하기 위해(면책 문구와는 성격이
/// 다른 "콘텐츠 상태 고지"이므로) 별도의 옅은 카드로 둔다. 차단·잠금 없이
/// 결과는 그대로 보여주고, 상단에 이 안내만 얹는다.
class _JeontongPlaceholderNotice extends StatelessWidget {
  const _JeontongPlaceholderNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(UnifiedTokens.spaceMd),
      decoration: BoxDecoration(
        color: UnifiedColors.cardBanner,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
        border: Border.all(color: UnifiedColors.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_stories_rounded,
            size: UnifiedTokens.iconMd,
            color: UnifiedColors.textCaption,
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          Expanded(
            child: Text(
              '이 항목은 아직 상세 만세력 계산 대신 일반적인 명리 풀이를 참고용으로 담고 있어요. '
              '더 정확한 내 사주 반영은 순차적으로 추가될 예정이에요.',
              style: UnifiedText.caption(),
            ),
          ),
        ],
      ),
    );
  }
}

/// [신통방통 2단계 · 반영사항 1] 출생시간을 모른다고 표시한 회원/로컬
/// 프로필에게만 노출되는 안내 배지. 계산 자체는 기존과 동일하게 12:00
/// 관례값을 사용하지만, 정확도가 낮을 수 있음을 사용자에게 알려준다.
class _BirthTimeUnknownNotice extends StatelessWidget {
  const _BirthTimeUnknownNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(UnifiedTokens.spaceMd),
      decoration: BoxDecoration(
        color: UnifiedColors.cardBanner,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
        border: Border.all(color: UnifiedColors.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.access_time_rounded,
            size: UnifiedTokens.iconMd,
            color: UnifiedColors.textCaption,
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          Expanded(
            child: Text(
              '정확한 출생시간 미입력으로 사주 관련 해석의 정확도가 낮을 수 있습니다. '
              '(현재 정오 12:00 기준으로 계산되고 있어요)',
              style: UnifiedText.caption(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({
    required this.entry,
    required this.profile,
    required this.userId,
    required this.saved,
    required this.isBookmarked,
    required this.onSave,
    required this.onToggleBookmark,
    required this.onOpenAiConsult,
  });

  final JeontongCategoryEntry entry;
  // [미션 2 · 4축 관통 배선] 저장된 프로필. null이면(아직 입력 전) 4축을
  // 전부 null로 두어 기존 폴백(결정론적 샘플) 경로를 그대로 탄다.
  final JeontongInput? profile;
  final String userId;
  final bool saved;
  final bool isBookmarked;
  final VoidCallback onSave;
  final VoidCallback onToggleBookmark;
  final VoidCallback onOpenAiConsult;

  @override
  Widget build(BuildContext context) {
    final hasProfile = profile != null;
    final report = jeontongReportCache.getOrBuild(
      entry: entry,
      userId: hasProfile ? userId : null,
      birthDateTimeUtc: profile?.birthDateTimeUtc,
      gender: profile?.gender,
      isLunar: profile?.isLunar,
      isLeapMonth: profile?.effectiveIsLeapMonth ?? false,
    );
    return Column(
      children: [
        _Header(
          title: entry.title,
          trailing: IconButton(
            key: const ValueKey('jeontong_bookmark_toggle'),
            icon: Icon(
              isBookmarked ? Icons.star_rounded : Icons.star_border_rounded,
              color: isBookmarked ? HanjiColors.accent : HanjiColors.muted,
            ),
            tooltip: isBookmarked ? '즐겨찾기 해제' : '즐겨찾기 추가',
            onPressed: onToggleBookmark,
          ),
        ),
        _jeontongPersonalizationBadge(
          context,
          _jeontongSignatureFromInputs(
            categoryCode: entry.id,
            userId: hasProfile ? userId : null,
            birthDateTimeUtc: profile?.birthDateTimeUtc,
            gender: profile?.gender,
            isLunar: profile?.isLunar,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              UnifiedTokens.spaceXl,
              UnifiedTokens.spaceMd,
              UnifiedTokens.spaceXl,
              UnifiedTokens.spaceXl,
            ),
            children: [
              // [미션 3 · 48종 플레이스홀더 UX 안전장치] 이 카테고리가 아직
              // 상세 만세력 계산 대신 일반 명리 해설을 담고 있으면, 차단하지
              // 않고 정직한 톤다운 안내만 추가로 보여준다("일반 풀이 참고용"
              // — 사용자 확정 지시). 32종 실계산 카테고리는 아무것도
              // 렌더링하지 않는다(회귀 없음).
              if (kJeontongPlaceholderCategoryIds.contains(entry.id)) ...[
                const _JeontongPlaceholderNotice(),
                const SizedBox(height: UnifiedTokens.spaceMd),
              ],
              const DisclaimerBanner.common(),
              const SizedBox(height: UnifiedTokens.spaceMd),
              if (entry.disclaimers.isNotEmpty) ...[
                DisclaimerBanner.forTags(entry.disclaimers),
                const SizedBox(height: UnifiedTokens.spaceMd),
              ],
              // [신통방통 2단계 · 반영사항 1] 출생시간을 모른다고 표시한
              // 회원/로컬 프로필은 계산엔진에 관례값(12:00)을 전달하지만,
              // 결과 화면에는 정확도 저하 가능성을 별도로 안내한다.
              if (profile?.birthTimeUnknown ?? false) ...[
                const _BirthTimeUnknownNotice(),
                const SizedBox(height: UnifiedTokens.spaceMd),
              ],
              HeroSummaryCard(
                name: report.hero.name,
                date: report.hero.date,
                score: report.hero.score,
                headline: report.hero.headline,
                statusLabel: report.hero.statusLabel,
                keywords: report.hero.keywords,
                subDescription: report.hero.subDescription,
              ),
              const SizedBox(height: UnifiedTokens.spaceMd),
              // [사용자 요청 · 2026 결과 화면 개편] "결과 화면이 너무
              // 어지러워 사주를 알아볼 수 없다"는 지적에 따라, 전문
              // 원국판보다 먼저 소비자용 "진솔한 이야기체" 해석을 최상단에
              // 배치한다. 재계산 없음 — PHASE1~4 실계산 결과(SajuFullInterpretation)를
              // JeontongNarrativeInterpreter가 문단으로 조합만 한다.
              // 프로필이 없거나 계산 실패 시 SizedBox.shrink()로 방어되어
              // 기존 report.sections 렌더링만 그대로 보인다(회귀 없음).
              _buildNarrativeSection(entry, profile),
              const SizedBox(height: UnifiedTokens.spaceMd),
              // [정통사주 69종 · Dawn Hanji 디자인 연동] 프로필이 있을 때만
              // PHASE1~4 실계산 원국(사주판/일간/오행/십신/대운/월운/조언)을
              // 추가로 렌더링한다. 재계산 없음 — 이미 검증된 파이프라인을
              // 호출해 결과만 그린다. 프로필이 없거나 계산 실패 시
              // SizedBox.shrink()로 방어되어 기존 report.sections 렌더링만
              // 그대로 보인다(회귀 없음).
              //
              // [사용자 요청 · 2026 결과 화면 개편] 전문 용어·한자 위주의
              // 원국판은 소비자에게 첫인상부터 "어지럽다"는 지적을 받아,
              // 접이식(ExpansionTile) 섹션으로 감싸 화면 하단으로 내린다.
              // 내부 렌더링 로직(JeontongSajuDetailSection)은 절대 변경하지
              // 않는다 — jeontong_pillar_board_layout_regression_test.dart의
              // "ListView 안에서도 레이아웃 예외 없이 렌더링" 계약이 그대로
              // 유지되는지는 ExpansionTile.children 안에서도 PillarBoard가
              // 동일하게 IntrinsicHeight로 보호되므로 영향 없다.
              if (profile != null)
                _JeontongDetailExpansion(entry: entry, profile: profile!),
              const SizedBox(height: UnifiedTokens.spaceMd),
              for (final section in report.sections) ...[
                _buildSection(section),
                const SizedBox(height: UnifiedTokens.spaceMd),
              ],
              // [정통사주 결과 콘텐츠 안전 추출] report(FortuneReport, 강타입)
              // 필드들을 JeontongResultTextExtractor 가 이해하는 어댑터
              // dict 로 얇게 변환해, 스키마가 무엇이든(카테고리별로 섹션
              // 구성이 비어 있어도) title ≥1줄 + body ≥2줄 + 쉬운 설명 힌트
              // 1줄을 항상 보장하는 안전망 카드를 추가한다(never-touch:
              // 위 report.sections 렌더링/HeroSummaryCard/아래 고정 4개
              // JeontongEasyTermToggle 토글 섹션은 그대로 둔다).
              Builder(
                builder: (context) {
                  final overviewBody = report
                      .sectionsOfType<OverviewSection>()
                      .map((s) => s.body)
                      .firstOrNull;
                  final aspectBodies = report
                      .sectionsOfType<AspectSection>()
                      .map((s) => s.body)
                      .toList(growable: false);
                  final ext = JeontongResultTextExtractor({
                    'category': entry.title,
                    'headline': report.hero.headline,
                    'summary': report.hero.subDescription,
                    'overall': overviewBody,
                    'analysis': aspectBodies,
                  });
                  final hints = ext.easyTermHints();
                  final lines = [
                    ...ext.body(),
                    if (hints.isNotEmpty) '쉬운 설명 가능 키워드: ${hints.join(', ')}',
                  ];
                  return SectionCard(
                    title: ext.title(),
                    body: lines.join('\n'),
                  );
                },
              ),
              const SizedBox(height: UnifiedTokens.spaceMd),
              // [정통사주 쉬운 설명 토글] report.sections 본문은 순수 한글
              // 프로즈로 구성돼 있어(jeontong_eighty_report_builder.dart
              // 확인 완료) "일간/신강/신약/식신" 같은 한자 전문 용어가 문장
              // 안에 리터럴 토큰으로 등장하지 않는다. 대신 사주에서 자주
              // 쓰이는 대표 용어 4개를 고정 목록으로 두고, 결과 하단에
              // "이런 용어, 쉽게 알아보기" 보충 섹션으로 노출한다. 탭하면
              // 같은 자리에서 펼쳐지고, 다시 탭하면 접힌다(요구사항 그대로).
              SectionCard(title: '이런 용어, 쉽게 알아보기', body: '탭하면 쉬운 설명이 펼쳐져요'),
              const JeontongEasyTermToggle(token: '일간'),
              const JeontongEasyTermToggle(token: '신강'),
              const JeontongEasyTermToggle(token: '신약'),
              const JeontongEasyTermToggle(token: '식신'),
              const SizedBox(height: UnifiedTokens.spaceMd),
              ResultBottomActions(
                actions: [
                  ResultActionItem(
                    icon: Icons.bookmark_border_rounded,
                    label: '저장',
                    onTap: onSave,
                  ),
                  ResultActionItem(
                    icon: Icons.grid_view_rounded,
                    label: '다른 운세',
                    onTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
                      JeontongEightyMatrix.browseRoute,
                      (route) => route.settings.name == '/home',
                    ),
                  ),
                  ResultActionItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: '고민상담',
                    onTap: onOpenAiConsult,
                  ),
                ],
              ),
              const SizedBox(height: UnifiedTokens.spaceMd),
              AIConsultBanner(onTap: onOpenAiConsult),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(FortuneSection section) {
    switch (section.type) {
      case FortuneSectionType.overview:
        final s = section as OverviewSection;
        return SectionCard(title: s.title, body: s.body);

      case FortuneSectionType.aspect:
        final s = section as AspectSection;
        return SectionCard(
          title: s.title,
          body: s.body,
          trailing: _IndexBadge(index: s.index),
        );

      case FortuneSectionType.recommend:
        final s = section as ListSection;
        return ListCard(
          title: s.title,
          items: s.items,
          icon: Icons.check_circle_outline_rounded,
        );

      case FortuneSectionType.lucky:
        final s = section as LuckySection;
        return LuckElementsGrid(
          title: s.title,
          items: s.items
              .map((e) => LuckyGridItem(label: e.label, value: e.value))
              .toList(),
        );

      case FortuneSectionType.timeline:
      case FortuneSectionType.avoid:
        // JeontongReportBuilder는 이 두 타입을 사용하지 않는다(안전망).
        return const SizedBox.shrink();
    }
  }

  /// [사용자 요청 · 2026 결과 화면 개편] 소비자용 이야기체 해석 카드를
  /// 만든다. PHASE1~4 실계산(JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4)
  /// → SajuInterpreter.fullInterpretation() 결과만 조회해 문단을 조합하는
  /// JeontongSajuDetailSection._tryBuild()와 동일한 방어적 패턴을 그대로
  /// 따른다 — 재계산 없음, 실패 시 SizedBox.shrink().
  ///
  /// [모가 틀리다는거야 — 사용자 재지적 대응] 기존엔 interp(9종 공통
  /// 데이터)만 넘겨 A/B/E/F/G/H 대카테고리가 major 단위로 문단을 공유해
  /// "건강운을 봐도 건강 얘기가 없다"는 문제가 재발했다. `runJeontongCategory`
  /// (이미 각 소카테고리 전용 실계산을 담당하는 검증된 함수 — 위
  /// report.sections 렌더링이 쓰는 것과 동일 함수)를 한 번 더 호출해, 그
  /// 결과 data map을 [JeontongNarrativeInterpreter.paragraphs]에 함께
  /// 전달한다. 재계산이 아니라 이미 존재하는 계산 경로를 그대로 재사용하는
  /// 것뿐이다(§2/§7 원칙).
  Widget _buildNarrativeSection(
    JeontongCategoryEntry entry,
    JeontongInput? profile,
  ) {
    if (profile == null) return const SizedBox.shrink();
    try {
      final rules = SajuRules.cachedOrNull;
      if (rules == null) return const SizedBox.shrink();
      final kst = profile.birthDateTimeUtc.add(const Duration(hours: 9));
      final sajuGender = profile.gender == 'F' || profile.gender == 'female'
          ? 'female'
          : 'male';
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: sajuGender,
        isLunar: profile.isLunar,
        // [신통방통 2단계] 서버/로컬 프로필의 윤달 정보를 실제로 반영한다.
        isLeapMonth: profile.effectiveIsLeapMonth,
        referenceDate: DateTime.now(),
      );

      // [2026-08-17 A01/A03/A04/A05/A06 독립 Narrative Pipeline — §12/§21/분기점A]
      // A01/A03/A04/A05/A06은 신규 CategoryAnalyzer → NarrativeGenerator →
      // FortuneNarrative 경로로 분기한다(A04가 먼저 완성·검증되었고, 이후
      // A01/A03/A05/A06도 동일 구조로 통일했다 — 사용자 최종 지시
      // "A01/A03/A05/A06도 신규 구조에 맞춰 동일한 독립 Narrative Generator
      // 구조로 정리"). 다른 카테고리(A02 등)는 기존
      // JeontongNarrativeInterpreter 경로를 그대로 사용한다(§18 "기존
      // 카테고리는 삭제하지 않는다"). FortuneNarrative.toParagraphs()는
      // 기존 JeontongNarrativeCard가 요구하는 List<String> 그대로이므로 새
      // 위젯 없이 재사용한다.
      if (entry.id == 'A01') {
        final analysis = const LifeOverallAnalyzer().analyze(
          built.profile,
          referenceDate: DateTime.now(),
        );
        final narrative = const LifeOverallNarrativeGenerator().generate(
          built.profile,
          analysis,
        );
        // [2026 무당식 단정 총평] A01은 별도 riskPattern 필드가 없어
        // weaknesses 리스트의 고정 문구("특별히 두드러진 위험 신호는
        // 확인되지 않음") 존재 여부로 판정한다(새 계산 없음, 이미 산출된
        // weaknesses/strengths 재사용).
        const noRiskFixed = '특별히 두드러진 위험 신호는 확인되지 않음';
        final a01HasRisk = !(analysis.weaknesses.length == 1 &&
            analysis.weaknesses.first == noRiskFixed);
        final a01Verdict = buildDeclarativeVerdict(
          categoryLabel: '전체적인 삶',
          hasRisk: a01HasRisk,
          reasonSentence: a01HasRisk
              ? analysis.weaknesses.first
              : analysis.strengths.isNotEmpty
                  ? analysis.strengths.first
                  : analysis.lifeTheme,
          actionSentence: narrative.practicalGuidance?.isNotEmpty == true
              ? narrative.practicalGuidance!.first
              : null,
        );
        return JeontongDeepReportCard(
          profile: built.profile,
          data: JeontongDeepReportData(
            oneLineSummary: a01Verdict.summary,
            isFortunate: a01Verdict.isFortunate,
            characteristicsTitle: '② 타고난 성격',
            personalitySentences: [
              analysis.coreNatureDescription,
              ...narrative.characteristics,
            ],
            strengths: analysis.strengths,
            cautions: analysis.weaknesses,
            generalGuidance: narrative.practicalGuidance ?? const [],
            finalSummary: narrative.finalSummary,
          ),
        );
      }
      if (entry.id == 'A03') {
        final analysis = const WealthAnalyzer().analyze(
          built.profile,
          referenceDate: DateTime.now(),
        );
        final narrative = const WealthNarrativeGenerator().generate(
          built.profile,
          analysis,
        );
        // [2026 무당식 단정 총평] riskPattern이 고정 "확인되지 않음" 문구가
        // 아니면 실제 계산된 리스크가 있다는 뜻(겁재 개수·기신=재성 여부 등
        // 사람마다 다른 수치로 이미 산출됨) — 이 유무로만 좋음/주의를
        // 판정한다(새 계산 없음).
        const noRiskFixed = '두드러진 재물 리스크 신호는 확인되지 않음';
        final a03HasRisk = analysis.riskPattern != noRiskFixed;
        final a03Verdict = buildDeclarativeVerdict(
          categoryLabel: '재물',
          hasRisk: a03HasRisk,
          reasonSentence: a03HasRisk
              ? analysis.riskPattern.split(' / ').first
              : (narrative.favorableFlows.isNotEmpty
                  ? narrative.favorableFlows.first
                  : analysis.wealthPattern),
          actionSentence: narrative.practicalGuidance?.isNotEmpty == true
              ? narrative.practicalGuidance!.first
              : null,
        );
        return JeontongDeepReportCard(
          profile: built.profile,
          data: JeontongDeepReportData(
            oneLineSummary: a03Verdict.summary,
            isFortunate: a03Verdict.isFortunate,
            characteristicsTitle: '② 재물 스타일',
            personalitySentences: narrative.characteristics,
            strengths: narrative.favorableFlows,
            cautions: narrative.cautionFlows,
            practicalAdvice: {'돈': analysis.assetManagementStyle},
            generalGuidance: narrative.practicalGuidance ?? const [],
            daewoonFlow: narrative.timingSection ?? const [],
            finalSummary: narrative.finalSummary,
          ),
        );
      }
      if (entry.id == 'A04') {
        final analysis = const CareerAnalyzer().analyze(
          built.profile,
          referenceDate: DateTime.now(),
        );
        final narrative = const CareerNarrativeGenerator().generate(
          built.profile,
          analysis,
        );
        const noRiskFixed = '두드러진 직업상 리스크 신호는 확인되지 않음';
        final a04HasRisk = analysis.careerRiskPattern != noRiskFixed;
        final a04Verdict = buildDeclarativeVerdict(
          categoryLabel: '직업·일',
          hasRisk: a04HasRisk,
          reasonSentence: a04HasRisk
              ? analysis.careerRiskPattern.split(' / ').first
              : (narrative.favorableFlows.isNotEmpty
                  ? narrative.favorableFlows.first
                  : analysis.careerPattern),
          actionSentence: narrative.practicalGuidance?.isNotEmpty == true
              ? narrative.practicalGuidance!.first
              : null,
        );
        return JeontongDeepReportCard(
          profile: built.profile,
          data: JeontongDeepReportData(
            oneLineSummary: a04Verdict.summary,
            isFortunate: a04Verdict.isFortunate,
            characteristicsTitle: '② 일하는 방식',
            personalitySentences: narrative.characteristics,
            strengths: narrative.favorableFlows,
            cautions: narrative.cautionFlows,
            practicalAdvice: {'일': analysis.workStyle},
            generalGuidance: narrative.practicalGuidance ?? const [],
            daewoonFlow: narrative.timingSection ?? const [],
            finalSummary: narrative.finalSummary,
          ),
        );
      }
      if (entry.id == 'A05') {
        final analysis = const HealthAnalyzer().analyze(
          built.profile,
          referenceDate: DateTime.now(),
        );
        final narrative = const HealthNarrativeGenerator().generate(
          built.profile,
          analysis,
        );
        const noRiskFixed = '두드러진 건강상 리스크 신호는 확인되지 않음';
        final a05HasRisk = analysis.healthRiskPattern != noRiskFixed;
        final a05Verdict = buildDeclarativeVerdict(
          categoryLabel: '건강',
          hasRisk: a05HasRisk,
          reasonSentence: a05HasRisk
              ? analysis.healthRiskPattern.split(' / ').first
              : (narrative.favorableFlows.isNotEmpty
                  ? narrative.favorableFlows.first
                  : analysis.healthConstitutionPattern),
          actionSentence: narrative.practicalGuidance?.isNotEmpty == true
              ? narrative.practicalGuidance!.first
              : null,
        );
        return JeontongDeepReportCard(
          profile: built.profile,
          data: JeontongDeepReportData(
            oneLineSummary: a05Verdict.summary,
            isFortunate: a05Verdict.isFortunate,
            characteristicsTitle: '② 타고난 체질',
            personalitySentences: narrative.characteristics,
            strengths: narrative.favorableFlows,
            cautions: narrative.cautionFlows,
            practicalAdvice: {'건강': analysis.healthVitality},
            generalGuidance: narrative.practicalGuidance ?? const [],
            daewoonFlow: narrative.timingSection ?? const [],
            finalSummary: narrative.finalSummary,
          ),
        );
      }
      if (entry.id == 'A06') {
        final analysis = const LoveAnalyzer().analyze(
          built.profile,
          referenceDate: DateTime.now(),
        );
        final narrative = const LoveNarrativeGenerator().generate(
          built.profile,
          analysis,
        );
        const noRiskFixed = '두드러진 애정상 리스크 신호는 확인되지 않음';
        final a06HasRisk = analysis.romanceRiskPattern != noRiskFixed;
        final a06Verdict = buildDeclarativeVerdict(
          categoryLabel: '애정·인연',
          hasRisk: a06HasRisk,
          reasonSentence: a06HasRisk
              ? analysis.romanceRiskPattern.split(' / ').first
              : (narrative.favorableFlows.isNotEmpty
                  ? narrative.favorableFlows.first
                  : analysis.spousePattern),
          actionSentence: narrative.practicalGuidance?.isNotEmpty == true
              ? narrative.practicalGuidance!.first
              : null,
        );
        return JeontongDeepReportCard(
          profile: built.profile,
          data: JeontongDeepReportData(
            oneLineSummary: a06Verdict.summary,
            isFortunate: a06Verdict.isFortunate,
            characteristicsTitle: '② 연애·결혼 성향',
            personalitySentences: narrative.characteristics,
            strengths: narrative.favorableFlows,
            cautions: narrative.cautionFlows,
            practicalAdvice: {'관계': analysis.recommendedApproach},
            generalGuidance: narrative.practicalGuidance ?? const [],
            daewoonFlow: narrative.timingSection ?? const [],
            finalSummary: narrative.finalSummary,
          ),
        );
      }
      if (entry.id == 'A07') {
        final analysis = const ChildrenAnalyzer().analyze(
          built.profile,
          referenceDate: DateTime.now(),
        );
        final narrative = const ChildrenNarrativeGenerator().generate(
          built.profile,
          analysis,
        );
        const noRiskFixed = '두드러진 자녀운 리스크 신호는 확인되지 않음';
        final a07HasRisk = analysis.childRiskPattern != noRiskFixed;
        final a07Verdict = buildDeclarativeVerdict(
          categoryLabel: '자녀운',
          hasRisk: a07HasRisk,
          reasonSentence: a07HasRisk
              ? analysis.childRiskPattern.split(' / ').first
              : (narrative.favorableFlows.isNotEmpty
                  ? narrative.favorableFlows.first
                  : analysis.childPattern),
          actionSentence: narrative.practicalGuidance?.isNotEmpty == true
              ? narrative.practicalGuidance!.first
              : null,
        );
        return JeontongDeepReportCard(
          profile: built.profile,
          data: JeontongDeepReportData(
            oneLineSummary: a07Verdict.summary,
            isFortunate: a07Verdict.isFortunate,
            characteristicsTitle: '② 자녀 인연 성향',
            personalitySentences: narrative.characteristics,
            strengths: narrative.favorableFlows,
            cautions: narrative.cautionFlows,
            practicalAdvice: {'관계': analysis.childRearingApproach},
            generalGuidance: narrative.practicalGuidance ?? const [],
            daewoonFlow: narrative.timingSection ?? const [],
            finalSummary: narrative.finalSummary,
          ),
        );
      }
      if (entry.id == 'A08') {
        final analysis = const ParentsSiblingsAnalyzer().analyze(
          built.profile,
          referenceDate: DateTime.now(),
        );
        final narrative = const ParentsSiblingsNarrativeGenerator().generate(
          built.profile,
          analysis,
        );
        const noRiskFixed = '두드러진 부모·형제운 리스크 신호는 확인되지 않음';
        final a08HasRisk = analysis.familyRiskPattern != noRiskFixed;
        final a08Verdict = buildDeclarativeVerdict(
          categoryLabel: '부모·형제운',
          hasRisk: a08HasRisk,
          reasonSentence: a08HasRisk
              ? analysis.familyRiskPattern.split(' / ').first
              : (narrative.favorableFlows.isNotEmpty
                  ? narrative.favorableFlows.first
                  : analysis.parentPattern),
          actionSentence: narrative.practicalGuidance?.isNotEmpty == true
              ? narrative.practicalGuidance!.first
              : null,
        );
        return JeontongDeepReportCard(
          profile: built.profile,
          data: JeontongDeepReportData(
            oneLineSummary: a08Verdict.summary,
            isFortunate: a08Verdict.isFortunate,
            characteristicsTitle: '② 부모·형제 인연 성향',
            personalitySentences: narrative.characteristics,
            strengths: narrative.favorableFlows,
            cautions: narrative.cautionFlows,
            practicalAdvice: {'관계': analysis.familyRelationApproach},
            generalGuidance: narrative.practicalGuidance ?? const [],
            daewoonFlow: narrative.timingSection ?? const [],
            finalSummary: narrative.finalSummary,
          ),
        );
      }

      final interp = SajuInterpreter.fullInterpretation(built.saju);
      Map<String, dynamic>? categoryData;
      final fortuneRules = SajuFortuneRules.cachedOrNull;
      if (fortuneRules != null) {
        final ctx = JeontongCalcContext(
          saju: built.saju,
          interp: interp,
          rules: fortuneRules,
          referenceDate: DateTime.now(),
          profile: built.profile,
        );
        categoryData = runJeontongCategory(entry.id, ctx).data;
      }
      final paragraphs = JeontongNarrativeInterpreter.paragraphs(
        interp,
        entry,
        name: profile.normalizedName,
        data: categoryData,
      );

      // [2026 무당식 단정 확장 — 그룹①(이진판정형)/②(타이밍형) · 사용자
      // 승인 "선택지 B"] 5종(A01/A03~A06)처럼 카드 UI(JeontongDeepReportCard)
      // 를 강행 적용하지 않고, 기존 JeontongNarrativeCard(줄글) 그대로
      // 유지하면서 paragraphs 리스트 맨 앞에 [buildDeclarativeVerdict]
      // (그룹①) 또는 [buildTimingVerdict](그룹②)로 조합한 단정 문장 1문단만
      // prepend한다. verdict 생성이 실패하면(방어적으로 null 반환, 예:
      // categoryData가 예상 키를 갖지 않는 경우) 기존 동작(줄글만 표시)으로
      // 안전하게 폴백한다 — 새 판단 없음, 이미 계산된 값의 문장 조합만.
      if (categoryData != null) {
        DeclarativeVerdict? verdict;
        if (kJeontongGroup1BinaryCategoryIds.contains(entry.id)) {
          verdict = _buildGroup1Verdict(entry.id, categoryData, entry.title);
        } else if (kJeontongGroup2TimingCategoryIds.contains(entry.id)) {
          verdict = _buildGroup2Verdict(entry.id, categoryData, entry.title);
        }
        if (verdict != null) {
          return JeontongNarrativeCard(
            paragraphs: [verdict.summary, ...paragraphs],
          );
        }
      }
      return JeontongNarrativeCard(paragraphs: paragraphs);
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

/// [2026 무당식 단정 확장 — 그룹①(이진판정형) 15종 중 F04 제외 14종]
/// [kJeontongGroup1BinaryCategoryIds]에 속한 카테고리 각각의
/// `JeontongCategoryResult.data`(이미 [runJeontongCategory]가 계산해 둔
/// 값)에서 hasRisk/reasonSentence/actionSentence를 뽑아
/// [buildDeclarativeVerdict]를 호출한다. 새 판단 없음 — 각 case는 이미
/// `jeontong_eighty_calculator.dart`/`saju_*_group_modules.dart`가 계산해
/// 둔 verdict·periods·excess 등의 필드를 조회해 문장을 재배열할 뿐이다.
/// 예상 키가 없거나 타입이 다르면(방어적 상황) null을 반환해 호출부가
/// 기존 줄글만 표시하도록 안전하게 폴백한다.
DeclarativeVerdict? _buildGroup1Verdict(
  String id,
  Map<String, dynamic> data,
  String categoryLabel,
) {
  try {
    switch (id) {
      case 'A02':
        {
          // A02는 A01과 완전히 동일한 data(_a01 재사용)를 쓴다 —
          // jeontong_eighty_calculator.dart `_a02()` 참조.
          final weaknesses =
              (data['weaknesses'] as List?)?.cast<String>() ?? const [];
          final strengths =
              (data['strengths'] as List?)?.cast<String>() ?? const [];
          final lifeTheme = data['life_theme'] as String? ?? '';
          const noRiskFixed = '특별히 두드러진 위험 신호는 확인되지 않음';
          final hasRisk = !(weaknesses.length == 1 &&
              weaknesses.first == noRiskFixed);
          return buildDeclarativeVerdict(
            categoryLabel: categoryLabel,
            hasRisk: hasRisk,
            reasonSentence: hasRisk
                ? weaknesses.first
                : (strengths.isNotEmpty ? strengths.first : lifeTheme),
          );
        }
      case 'B04':
        {
          final cautionPeriods =
              (data['caution_periods'] as List?) ?? const [];
          final summary = data['summary'] as String? ?? '';
          final parts = _jeontongSentenceSplit(summary);
          return buildDeclarativeVerdict(
            categoryLabel: categoryLabel,
            hasRisk: cautionPeriods.isNotEmpty,
            reasonSentence: parts.isNotEmpty ? parts.first : summary,
            actionSentence:
                parts.length > 1 ? parts.sublist(1).join(' ') : null,
          );
        }
      case 'B06':
        {
          final cautionWindows =
              (data['caution_windows'] as List?) ?? const [];
          final summary = data['summary'] as String? ?? '';
          final parts = _jeontongSentenceSplit(summary);
          return buildDeclarativeVerdict(
            categoryLabel: categoryLabel,
            hasRisk: cautionWindows.isNotEmpty,
            reasonSentence: parts.isNotEmpty ? parts.first : summary,
            actionSentence:
                parts.length > 1 ? parts.sublist(1).join(' ') : null,
          );
        }
      case 'B08':
        {
          // [인생 최고 대운 시기] periods가 비어있으면(용신 미확정 포함)
          // 뚜렷한 황금기를 짚어줄 수 없다는 뜻이라 주의 쪽으로 처리한다
          // — B09(최악 시기, 아래)와 정반대 극성.
          final periods = (data['periods'] as List?) ?? const [];
          final summary = data['summary'] as String? ?? '';
          final parts = _jeontongSentenceSplit(summary);
          return buildDeclarativeVerdict(
            categoryLabel: categoryLabel,
            hasRisk: periods.isEmpty,
            reasonSentence: parts.isNotEmpty ? parts.first : summary,
            actionSentence:
                parts.length > 1 ? parts.sublist(1).join(' ') : null,
          );
        }
      case 'B09':
        {
          // [인생 최악 대운 시기] periods가 존재해야(기신 발동 시기 발견)
          // 주의가 필요하다는 뜻 — B08과 정반대 극성.
          final periods = (data['periods'] as List?) ?? const [];
          final summary = data['summary'] as String? ?? '';
          final parts = _jeontongSentenceSplit(summary);
          return buildDeclarativeVerdict(
            categoryLabel: categoryLabel,
            hasRisk: periods.isNotEmpty,
            reasonSentence: parts.isNotEmpty ? parts.first : summary,
            actionSentence:
                parts.length > 1 ? parts.sublist(1).join(' ') : null,
          );
        }
      case 'C08':
        {
          final title = data['title'] as String? ?? '';
          final overall = data['overall'] as String? ?? '';
          final advice = data['advice'] as String? ?? '';
          final hasRisk = title != '법적 분쟁 위험이 낮은 해';
          return buildDeclarativeVerdict(
            categoryLabel: categoryLabel,
            hasRisk: hasRisk,
            reasonSentence: overall,
            actionSentence: advice.isNotEmpty ? advice : null,
          );
        }
      case 'D10':
        {
          final title = data['title'] as String? ?? '';
          final overall = data['overall'] as String? ?? '';
          final advice = data['advice'] as String? ?? '';
          final hasRisk = title == '오늘은 신중함이 필요한 날';
          return buildDeclarativeVerdict(
            categoryLabel: categoryLabel,
            hasRisk: hasRisk,
            reasonSentence: overall,
            actionSentence: advice.isNotEmpty ? advice : null,
          );
        }
      case 'G01':
      case 'G02':
        {
          // G01/G02는 A05와 완전히 동일한 data(_a05 재사용)를 쓴다 —
          // jeontong_eighty_calculator.dart `_categoryIndex['G01'/'G02']`
          // 참조.
          const noRiskFixed = '두드러진 건강상 리스크 신호는 확인되지 않음';
          final riskPattern = data['healthRiskPattern'] as String? ?? '';
          final favorable =
              (data['favorableConditions'] as List?)?.cast<String>() ??
                  const [];
          final constitution =
              data['healthConstitutionPattern'] as String? ?? '';
          final adviceFood =
              (data['advice_food'] as List?)?.cast<String>() ?? const [];
          final hasRisk = riskPattern.isNotEmpty && riskPattern != noRiskFixed;
          return buildDeclarativeVerdict(
            categoryLabel: categoryLabel,
            hasRisk: hasRisk,
            reasonSentence: hasRisk
                ? riskPattern.split(' / ').first
                : (favorable.isNotEmpty ? favorable.first : constitution),
            actionSentence: adviceFood.isNotEmpty ? adviceFood.first : null,
          );
        }
      case 'G03':
        {
          final cautionPeriods =
              (data['caution_periods'] as List?) ?? const [];
          final summary = data['summary'] as String? ?? '';
          final parts = _jeontongSentenceSplit(summary);
          return buildDeclarativeVerdict(
            categoryLabel: categoryLabel,
            hasRisk: cautionPeriods.isNotEmpty,
            reasonSentence: parts.isNotEmpty ? parts.first : summary,
            actionSentence:
                parts.length > 1 ? parts.sublist(1).join(' ') : null,
          );
        }
      case 'G05':
        {
          final excess = (data['excess_elements'] as List?) ?? const [];
          final message = data['message'] as String? ?? '';
          final parts = _jeontongSentenceSplit(message);
          return buildDeclarativeVerdict(
            categoryLabel: categoryLabel,
            hasRisk: excess.isNotEmpty,
            reasonSentence: parts.isNotEmpty ? parts.first : message,
            actionSentence:
                parts.length > 1 ? parts.sublist(1).join(' ') : null,
          );
        }
      case 'G07':
        {
          final verdict = data['verdict'] as String? ?? '';
          final message = data['message'] as String? ?? '';
          final parts = _jeontongSentenceSplit(message);
          final hasRisk = verdict.contains('예민');
          return buildDeclarativeVerdict(
            categoryLabel: categoryLabel,
            hasRisk: hasRisk,
            reasonSentence: parts.isNotEmpty ? parts.first : message,
            actionSentence:
                parts.length > 1 ? parts.sublist(1).join(' ') : null,
          );
        }
      case 'G08':
        {
          final verdict = data['verdict'] as String? ?? '';
          final message = data['message'] as String? ?? '';
          final parts = _jeontongSentenceSplit(message);
          final hasRisk = verdict.contains('주의');
          return buildDeclarativeVerdict(
            categoryLabel: categoryLabel,
            hasRisk: hasRisk,
            reasonSentence: parts.isNotEmpty ? parts.first : message,
            actionSentence:
                parts.length > 1 ? parts.sublist(1).join(' ') : null,
          );
        }
      case 'G10':
        {
          final verdict = data['verdict'] as String? ?? '';
          final message = data['message'] as String? ?? '';
          final parts = _jeontongSentenceSplit(message);
          final hasRisk = verdict == '꾸준한 관리 필요형' ||
              verdict == '컨디션 관리 신경 써야 하는 편';
          return buildDeclarativeVerdict(
            categoryLabel: categoryLabel,
            hasRisk: hasRisk,
            reasonSentence: parts.isNotEmpty ? parts.first : message,
            actionSentence:
                parts.length > 1 ? parts.sublist(1).join(' ') : null,
          );
        }
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// [2026 무당식 단정 확장 — 그룹②(타이밍형) 재검토 완료 9종, B07/B10/F10
/// 제외] [kJeontongGroup2TimingCategoryIds]에 속한 카테고리 각각의
/// `JeontongCategoryResult.data`에서 isActiveNow/reasonSentence/
/// actionSentence를 뽑아 [buildTimingVerdict]를 호출한다. [_buildGroup1Verdict]
/// 와 동일한 원칙(새 판단 없음, 방어적 null 폴백).
DeclarativeVerdict? _buildGroup2Verdict(
  String id,
  Map<String, dynamic> data,
  String categoryLabel,
) {
  try {
    switch (id) {
      case 'B02':
        {
          final peaks = (data['peak_periods'] as List?) ?? const [];
          final summary = data['summary'] as String? ?? '';
          final parts = _jeontongSentenceSplit(summary);
          return buildTimingVerdict(
            categoryLabel: categoryLabel,
            isActiveNow: peaks.isNotEmpty,
            reasonSentence: parts.isNotEmpty ? parts.first : summary,
            actionSentence:
                parts.length > 1 ? parts.sublist(1).join(' ') : null,
          );
        }
      case 'B05':
        {
          final active = (data['active_periods'] as List?) ?? const [];
          final summary = data['summary'] as String? ?? '';
          final parts = _jeontongSentenceSplit(summary);
          return buildTimingVerdict(
            categoryLabel: categoryLabel,
            isActiveNow: active.isNotEmpty,
            reasonSentence: parts.isNotEmpty ? parts.first : summary,
            actionSentence:
                parts.length > 1 ? parts.sublist(1).join(' ') : null,
          );
        }
      case 'B03':
        {
          // [재검토 완료 — 그룹②편입] B02/B05와 동일 패턴: shift_periods
          // (관성 발동 대운 목록) 존재 여부로 "지금 직업 변화 흐름이
          // 활성화됐는지"를 판정한다 — jeontong_eighty_calculator.dart
          // `_b03()`/saju_daewoon_modules.dart `getDaewoonCareerFlow()` 참조.
          final shiftPeriods = (data['shift_periods'] as List?) ?? const [];
          final summary = data['summary'] as String? ?? '';
          final parts = _jeontongSentenceSplit(summary);
          return buildTimingVerdict(
            categoryLabel: categoryLabel,
            isActiveNow: shiftPeriods.isNotEmpty,
            reasonSentence: parts.isNotEmpty ? parts.first : summary,
            actionSentence:
                parts.length > 1 ? parts.sublist(1).join(' ') : null,
          );
        }
      case 'C06':
        {
          final title = data['title'] as String? ?? '';
          final overall = data['overall'] as String? ?? '';
          final advice = data['advice'] as String? ?? '';
          return buildTimingVerdict(
            categoryLabel: categoryLabel,
            isActiveNow: title == '이동수가 들어오는 해',
            reasonSentence: overall,
            actionSentence: advice.isNotEmpty ? advice : null,
          );
        }
      case 'C07':
        {
          final title = data['title'] as String? ?? '';
          final overall = data['overall'] as String? ?? '';
          final advice = data['advice'] as String? ?? '';
          final isActiveNow = title == '문창귀인이 들어오는 해' ||
              title == '학습운이 양호한 해';
          return buildTimingVerdict(
            categoryLabel: categoryLabel,
            isActiveNow: isActiveNow,
            reasonSentence: overall,
            actionSentence: advice.isNotEmpty ? advice : null,
          );
        }
      case 'F05':
        {
          final daewoonHit = data['current_daewoon_hit'] as bool? ?? false;
          final yearHit = data['current_year_hit'] as bool? ?? false;
          final message = data['message'] as String? ?? '';
          final parts = _jeontongSentenceSplit(message);
          return buildTimingVerdict(
            categoryLabel: categoryLabel,
            isActiveNow: daewoonHit && yearHit,
            reasonSentence: parts.isNotEmpty ? parts.first : message,
            actionSentence:
                parts.length > 1 ? parts.sublist(1).join(' ') : null,
          );
        }
      case 'F06':
        {
          final peaks = (data['peak_periods'] as List?) ?? const [];
          final summary = data['summary'] as String? ?? '';
          final parts = _jeontongSentenceSplit(summary);
          return buildTimingVerdict(
            categoryLabel: categoryLabel,
            isActiveNow: peaks.isNotEmpty,
            reasonSentence: parts.isNotEmpty ? parts.first : summary,
            actionSentence:
                parts.length > 1 ? parts.sublist(1).join(' ') : null,
          );
        }
      case 'F08':
        {
          final message = data['message'] as String? ?? '';
          final isActiveNow = message.contains('무르익기 좋은 흐름');
          return buildTimingVerdict(
            categoryLabel: categoryLabel,
            isActiveNow: isActiveNow,
            reasonSentence: message,
          );
        }
      case 'F09':
        {
          final active = (data['active_periods'] as List?) ?? const [];
          final summary = data['summary'] as String? ?? '';
          final parts = _jeontongSentenceSplit(summary);
          return buildTimingVerdict(
            categoryLabel: categoryLabel,
            isActiveNow: active.isNotEmpty,
            reasonSentence: parts.isNotEmpty ? parts.first : summary,
            actionSentence:
                parts.length > 1 ? parts.sublist(1).join(' ') : null,
          );
        }
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// [보조 유틸] "요약+행동지침"이 한 문자열(summary/message 등)에 함께
/// 담긴 카테고리를 위해, 문장 종결부호(.!?) 뒤 공백 기준으로 문단을
/// 나눈다. 첫 문장을 reasonSentence로, 나머지를 actionSentence로 쓰기
/// 위한 것뿐이며 새로운 텍스트를 생성하지 않는다(원문 그대로 분할).
List<String> _jeontongSentenceSplit(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];
  final parts = trimmed.split(RegExp(r'(?<=[.!?])\s+'));
  return parts.where((p) => p.trim().isNotEmpty).toList();
}

/// [사용자 요청 · 2026 결과 화면 개편] 전문 원국판(PillarBoard 등)을
/// 접이식 섹션으로 감싸는 위젯. `jeontong_easy_term_toggle.dart`의
/// ExpansionTile 패턴을 그대로 재사용한다(프로젝트 관례).
///
/// [프레임 예산 보호] 이 위젯은 StatelessWidget이며 자체 setState가
/// 전혀 없다 — ExpansionTile 자체의 펼침/접힘 애니메이션은 사용자가
/// 실제로 탭했을 때만 발생하므로, 화면 최초 진입 시의 안정화 프레임
/// 수(jeontong_eighty_result_frame_bench_test.dart 계약)에는 영향을
/// 주지 않는다(닫힌 상태로 시작 — initiallyExpanded: false).
class _JeontongDetailExpansion extends StatelessWidget {
  const _JeontongDetailExpansion({required this.entry, required this.profile});

  final JeontongCategoryEntry entry;
  final JeontongInput profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: HanjiColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HanjiRadii.card),
        side: const BorderSide(color: HanjiColors.line),
      ),
      child: ExpansionTile(
        key: const PageStorageKey<String>('jeontong_saju_detail_expansion'),
        initiallyExpanded: false,
        title: Text('◈ 사주 원국 · 실계산 상세 보기', style: HanjiTextStyles.bodyTitle()),
        subtitle: Text(
          '천간·지지·오행·십신·대운 등 전문 계산 결과를 직접 확인해보세요',
          style: HanjiTextStyles.bodySmall(),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          HanjiSpacing.lg,
          0,
          HanjiSpacing.lg,
          HanjiSpacing.lg,
        ),
        children: [
          JeontongSajuDetailSection(
            categoryLabel: entry.title,
            birthDateTimeUtc: profile.birthDateTimeUtc,
            gender: profile.gender,
            isLunar: profile.isLunar,
            // [신통방통 2단계] 서버/로컬 프로필의 윤달 정보를 실제로 반영한다.
            isLeapMonth: profile.effectiveIsLeapMonth,
            referenceDate: DateTime.now(),
          ),
        ],
      ),
    );
  }
}

/// 2026-08-13 결정. 화면 진입 시점에 이미 갖고 있는 4축을 그대로 해싱해
/// 8자 hex 서명 생성. 어떤 축이라도 null 이면 null 반환 → 뱃지는
/// "샘플 결과" 로 노출된다. 모델(fortune_report_model.dart) 무손상 —
/// signature 필드에 의존하지 않는다.
String? _jeontongSignatureFromInputs({
  required String categoryCode,
  String? userId,
  DateTime? birthDateTimeUtc,
  String? gender,
  bool? isLunar,
}) {
  if (userId == null &&
      birthDateTimeUtc == null &&
      gender == null &&
      isLunar == null) {
    return null;
  }
  // [웹 빌드 호환성 수정] 원래 FNV-1a 64bit 구현은 JavaScript가 정확히
  // 표현할 수 없는 정수 리터럴(0xcbf29ce484222325 등, 53bit 안전 정수 범위
  // 초과)을 사용해 `flutter build web`(dart2js) 컴파일 자체를 실패시켰다
  // (jeontong_eighty_report_builder.dart의 _jeontongPersonalizationSeed와
  // 동일 문제 — 그쪽과 동일하게 FNV-1a 32bit로 교체). dart:core만 사용.
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
  return hash.toRadixString(16).padLeft(8, '0');
}

Widget _jeontongPersonalizationBadge(BuildContext context, String? signature) {
  final cs = Theme.of(context).colorScheme;
  final has = signature != null && signature.isNotEmpty;
  final text = has ? '내 사주 반영 · #$signature' : '샘플 결과';
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: has ? cs.primaryContainer : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant, width: 0.5),
          ),
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: has ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: UnifiedColors.bg,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
        border: Border.all(color: UnifiedColors.border, width: 1),
      ),
      child: Text('$index점', style: UnifiedText.chipLabel()),
    );
  }
}
