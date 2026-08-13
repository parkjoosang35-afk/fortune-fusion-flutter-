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
import '../../../core/data/my_fortune_record_store.dart';
import '../../fortune/shared/domain/fortune_report_model.dart';
import '../domain/jeontong_eighty_matrix.dart';
import '../domain/jeontong_eighty_report_builder.dart';
import '../domain/jeontong_report_cache.dart';

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

  @override
  Widget build(BuildContext context) {
    final entry = JeontongEightyMatrix.byId(widget.categoryId ?? '');
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: entry == null
            ? const _NotFoundView()
            : _ResultBody(
                entry: entry,
                saved: _saved,
                onSave: () => _onSave(entry),
                onOpenAiConsult: () => Navigator.of(
                  context,
                ).pushNamed('/ai-fortune/consultation/type'),
              ),
      ),
    );
  }

  Future<void> _onSave(JeontongCategoryEntry entry) async {
    final report = jeontongReportCache.getOrBuild(entry: entry);
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

class _ResultBody extends StatelessWidget {
  const _ResultBody({
    required this.entry,
    required this.saved,
    required this.onSave,
    required this.onOpenAiConsult,
  });

  final JeontongCategoryEntry entry;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onOpenAiConsult;

  @override
  Widget build(BuildContext context) {
    final report = jeontongReportCache.getOrBuild(entry: entry);
    return Column(
      children: [
        _Header(title: entry.title),
        _jeontongPersonalizationBadge(context,
          _jeontongSignatureFromInputs(
            categoryCode: entry.id,
            userId: null,
            birthDateTimeUtc: null,
            gender: null,
            isLunar: null,
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
  // FNV-1a 64bit — dart:core 만.
  const int fnvPrime = 0x100000001b3;
  int hash = 0xcbf29ce484222325;
  void mix(String s) {
    for (final code in s.codeUnits) {
      hash ^= code;
      hash = (hash * fnvPrime) & 0xFFFFFFFFFFFFFFFF;
    }
    hash ^= 0x5c;
    hash = (hash * fnvPrime) & 0xFFFFFFFFFFFFFFFF;
  }
  mix('cat:$categoryCode');
  mix('uid:${userId ?? ""}');
  mix('bdt:${birthDateTimeUtc?.toIso8601String() ?? ""}');
  mix('gen:${gender ?? ""}');
  mix('lun:${isLunar == null ? "" : (isLunar ? "1" : "0")}');
  final s = (hash & 0x7fffffffffffffff).toRadixString(16).padLeft(16, '0');
  return s.substring(s.length - 8);
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
