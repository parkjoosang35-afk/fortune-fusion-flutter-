import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/data/my_fortune_record_store.dart';
import '../../../../core/domain/access/access_checker.dart';
import '../../../../core/domain/gate/category_gate.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/fortune/ai_consult_banner.dart';
import '../../../../core/widgets/fortune/disclaimer_banner.dart';
import '../../../../core/widgets/fortune/hero_summary_card.dart';
import '../../../../core/widgets/fortune/list_card.dart';
import '../../../../core/widgets/fortune/lucky_elements_grid.dart';
import '../../../../core/widgets/fortune/primary_cta.dart';
import '../../../../core/widgets/fortune/result_bottom_actions.dart';
import '../../../../core/widgets/fortune/section_card.dart';
import '../../../home/domain/fortune_matrix.dart';
import '../../../pass/presentation/pass_gate_helper.dart';
import '../../shared/domain/fortune_report_model.dart';
import '../domain/generic_fortune_report_builder.dart';

/// [운섹션 87 카테고리 통합] 공용 결과 화면 — 라우트 `/fortune/category`.
///
/// 아직 전용 입력/결과 화면이 없는 카테고리(K/V/O 일부/X/G/B/D/R, 약 45개)를
/// 위한 단일 화면이다. arguments로 [FortuneCategoryEntry.id](String, 예:
/// 'K-001')를 받아 [FortuneMatrix.byId]로 메타데이터를 조회하고,
/// [CategoryGate.decide]로 게이트 판정을 한 번 더 확인한 뒤(전체보기에서 이미
/// 판정했더라도 딥링크로 직접 들어온 경우를 대비한 안전망) 결과를 그려준다.
///
/// 새 화면/네비게이션 스택을 추가하지 않고, 기존 [DailyFortuneResultScreen]과
/// 동일한 공용 위젯(HeroSummaryCard/SectionCard/ListCard/LuckElementsGrid/
/// ResultBottomActions/AIConsultBanner)을 그대로 재사용한다.
class GenericFortuneResultScreen extends StatefulWidget {
  const GenericFortuneResultScreen({super.key, required this.categoryId});

  final String? categoryId;

  @override
  State<GenericFortuneResultScreen> createState() =>
      _GenericFortuneResultScreenState();
}

class _GenericFortuneResultScreenState
    extends State<GenericFortuneResultScreen> {
  bool _saved = false;
  bool _loading = true;
  bool _allowed = false;
  String? _reasonLabel;
  FortuneCategoryEntry? _entry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final entry = FortuneMatrix.byId(widget.categoryId ?? '');
    if (entry == null) {
      setState(() => _loading = false);
      return;
    }
    final access = context.read<AccessChecker>();
    final decision = await CategoryGate.decide(entry, access);
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _allowed = decision.allowed;
      _reasonLabel = decision.reasonLabel;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _entry == null
            ? const _NotFoundView()
            : _allowed
            ? _ResultBody(
                entry: _entry!,
                saved: _saved,
                onSave: () => _onSave(_entry!),
                onOpenAiConsult: () => Navigator.of(
                  context,
                ).pushNamed('/ai-fortune/consultation/type'),
              )
            : _LockedView(entry: _entry!, reasonLabel: _reasonLabel),
      ),
    );
  }

  Future<void> _onSave(FortuneCategoryEntry entry) async {
    final report = GenericFortuneReportBuilder.build(entry);
    await MyFortuneRecordStore.save(
      SavedFortuneRecord(
        id: 'category_${entry.id}_${DateTime.now().toIso8601String().substring(0, 10)}',
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

class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UnifiedTokens.spaceMd,
        vertical: UnifiedTokens.spaceXs,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: UnifiedTokens.iconLg,
              color: UnifiedColors.textPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              title,
              style: UnifiedText.titleLarge(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Header(title: '운세'),
        Expanded(
          child: Center(
            child: Text('아직 준비 중인 카테고리예요', style: UnifiedText.body()),
          ),
        ),
      ],
    );
  }
}

/// 게이트에 막힌 경우(무료 소진/프리패스 전용) — 프리패스 유도.
class _LockedView extends StatelessWidget {
  const _LockedView({required this.entry, this.reasonLabel});

  final FortuneCategoryEntry entry;
  final String? reasonLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(title: entry.title),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 40,
                  color: UnifiedColors.textCaption,
                ),
                const SizedBox(height: UnifiedTokens.spaceLg),
                Text(
                  reasonLabel ?? '프리패스로 열람할 수 있는 콘텐츠예요.',
                  textAlign: TextAlign.center,
                  style: UnifiedText.body(),
                ),
                const SizedBox(height: UnifiedTokens.spaceXl),
                PrimaryCTA(
                  label: '프리패스로 보기',
                  onPressed: () => showPassRequiredSheet(
                    context,
                    categoryTitle: entry.title,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({
    required this.entry,
    required this.saved,
    required this.onSave,
    required this.onOpenAiConsult,
  });

  final FortuneCategoryEntry entry;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onOpenAiConsult;

  @override
  Widget build(BuildContext context) {
    final report = GenericFortuneReportBuilder.build(entry);
    return Column(
      children: [
        _Header(title: entry.title),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              UnifiedTokens.spaceXl,
              UnifiedTokens.spaceMd,
              UnifiedTokens.spaceXl,
              UnifiedTokens.spaceXl,
            ),
            children: [
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
              for (final section in report.sections) ...[
                _buildSection(section),
                const SizedBox(height: UnifiedTokens.spaceMd),
              ],
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
                    onTap: () =>
                        Navigator.of(context).pushNamed('/home/all-categories'),
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

  /// report.sections는 항상 OverviewSection/AspectSection/ListSection/
  /// LuckySection 중 하나이며(GenericFortuneReportBuilder 참고), 잠금 여부는
  /// 이미 [CategoryGate]에서 판정을 마쳤으므로 이 화면 내부 섹션들은 잠금
  /// 표시 없이 항상 펼쳐서 보여준다.
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
        // GenericFortuneReportBuilder는 이 두 타입을 사용하지 않는다(안전망).
        return const SizedBox.shrink();
    }
  }
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
