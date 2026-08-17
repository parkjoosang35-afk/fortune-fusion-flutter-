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
import '../domain/interpretation/generators/career_narrative_generator.dart';
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
import 'jeontong_design/hanji_background.dart';
import 'jeontong_design/hanji_design_tokens.dart';
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

  Future<void> _loadProfileAndRecord() async {
    final profile = await jeontongProfileStore.get(_userId);
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
        referenceDate: DateTime.now(),
      );

      // [2026-08-17 A04 독립 Narrative Pipeline — §12/§21] A04(평생
      // 직업·명예운)만 우선 신규 CategoryAnalyzer → NarrativeGenerator →
      // FortuneNarrative 경로로 분기한다. 다른 카테고리(A01~A03/A05/A06
      // 등)는 기존 JeontongNarrativeInterpreter 경로를 그대로 사용한다
      // (§18 "기존 카테고리는 삭제하지 않는다" — A05/A06은 별도 STEP에서
      // 동일한 방식으로 전환 예정). FortuneNarrative.toParagraphs()는
      // 기존 JeontongNarrativeCard가 요구하는 List<String> 그대로이므로
      // 새 위젯 없이 재사용한다.
      if (entry.id == 'A04') {
        final analysis = const CareerAnalyzer().analyze(
          built.profile,
          referenceDate: DateTime.now(),
        );
        final narrative = const CareerNarrativeGenerator().generate(
          built.profile,
          analysis,
        );
        return JeontongNarrativeCard(paragraphs: narrative.toParagraphs());
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
      return JeontongNarrativeCard(paragraphs: paragraphs);
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
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
