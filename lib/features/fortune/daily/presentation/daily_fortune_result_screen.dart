import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/data/my_fortune_record_store.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../../../core/widgets/fortune/ai_consult_banner.dart';
import '../../../../core/widgets/fortune/fortune_share_card.dart';
import '../../../../core/widgets/fortune/hero_summary_card.dart';
import '../../../../core/widgets/fortune/list_card.dart';
import '../../../../core/widgets/fortune/lucky_elements_grid.dart';
import '../../../../core/widgets/fortune/lock_overlay_badge.dart';
import '../../../../core/widgets/fortune/primary_cta.dart';
import '../../../../core/widgets/fortune/result_bottom_actions.dart';
import '../../../../core/widgets/fortune/section_card.dart';
import '../../../../core/widgets/fortune/timeline_card.dart';
import '../../../consultation/application/consultation_provider.dart';
import '../../../pass/application/pass_provider.dart';
import '../../../../core/domain/access/access_checker.dart';
import '../../../pass/presentation/pass_time_format.dart';
import '../../../pass/presentation/pass_gate_helper.dart';
import '../application/daily_fortune_provider.dart';
import '../domain/daily_fortune_model.dart';
import '../domain/fortune_report_builder.dart';
import '../domain/fortune_report_model.dart';

/// [오늘의 운세 표준 플로우] §4 결과 리포트 화면 — /fortune/today/result
///
/// 12개 카드 스택(§4 섹션1~12)을 순서대로 렌더링한다. sections[] 기반 데이터를
/// 순회하며 타입별 위젯으로 매핑하므로, 사주/궁합/타로/관상/손금도 같은 방식으로
/// 이 화면을 그대로 재사용할 수 있다(§9).
class DailyFortuneResultScreen extends StatefulWidget {
  const DailyFortuneResultScreen({super.key, this.input});

  final FortuneInputModel? input;

  @override
  State<DailyFortuneResultScreen> createState() =>
      _DailyFortuneResultScreenState();
}

class _DailyFortuneResultScreenState extends State<DailyFortuneResultScreen> {
  final _shareCardKey = GlobalKey();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PassProvider>().load();
    });
  }

  String get _displayName =>
      widget.input?.name.trim().isNotEmpty == true ? widget.input!.name : '게스트';

  @override
  Widget build(BuildContext context) {
    final today = context.watch<DailyFortuneProvider>().today;
    // [열림패스/복주머니/복주머니 통합정책 §7] 화면이 직접 PassProvider의
    // 필드를 판단하지 않고, 공통 AccessChecker를 거쳐서만 잠금 여부를 정한다.
    final access = context.watch<AccessChecker>();
    final passActive = access.canAccessFortuneScope();

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              passActive: passActive,
              // [프리패스 단순화 - 쿠팡파트너스 전용] §6 — HH:MM:SS 형식으로 통일.
              remainingLabel: passActive
                  ? formatPassHms(access.openPassState.remaining)
                  : null,
              isSaved: _saved,
              onSave: today == null ? null : () => _onSave(today),
              onShare: today == null ? null : () => _onShare(today),
            ),
            Expanded(
              child: today == null
                  ? _InsufficientDataView(name: _displayName)
                  : _ResultBody(
                      report: FortuneReportBuilder.build(
                        today,
                        name: _displayName,
                      ),
                      passActive: passActive,
                      onSave: () => _onSave(today),
                      onShare: () => _onShare(today),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSave(DailyFortuneModel today) async {
    final report = FortuneReportBuilder.build(today, name: _displayName);
    await MyFortuneRecordStore.save(
      SavedFortuneRecord(
        id: 'daily_${today.date.toIso8601String().substring(0, 10)}',
        categoryLabel: '오늘의 운세',
        title: '${today.date.month}월 ${today.date.day}일의 운세',
        summary: report.hero.headline,
        score: report.hero.score,
        date: today.date,
        savedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    setState(() => _saved = true);
    AppToast.show(context, '마이 > 내 운세 기록에 저장되었어요');
  }

  Future<void> _onShare(DailyFortuneModel today) async {
    final report = FortuneReportBuilder.build(today, name: _displayName);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: UnifiedColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('오늘의 운세 공유하기', style: UnifiedText.title()),
              const SizedBox(height: UnifiedTokens.spaceLg),
              ClipRRect(
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
                child: RepaintBoundary(
                  key: _shareCardKey,
                  child: FortuneShareCard(
                    name: report.hero.name,
                    date: report.hero.date,
                    score: report.hero.score,
                    headline: report.hero.headline,
                  ),
                ),
              ),
              const SizedBox(height: UnifiedTokens.spaceLg),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: UnifiedColors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        UnifiedTokens.radiusPill,
                      ),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _captureAndShare();
                  },
                  child: Text(
                    '이미지로 공유하기',
                    style: UnifiedText.bodyStrong(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _captureAndShare() async {
    try {
      final boundary =
          _shareCardKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(
        pixelRatio: FortuneShareCard.capturePixelRatio,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = await File(
        '${dir.path}/fortune_share_${DateTime.now().millisecondsSinceEpoch}.png',
      ).writeAsBytes(bytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: '오늘의 운세를 확인해보세요! · Fortune Fusion');
    } catch (_) {
      if (!mounted) return;
      await Share.share('오늘의 운세를 확인해보세요! · Fortune Fusion');
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.passActive,
    required this.remainingLabel,
    required this.isSaved,
    required this.onSave,
    required this.onShare,
  });

  final bool passActive;
  final String? remainingLabel;
  final bool isSaved;
  final VoidCallback? onSave;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UnifiedTokens.spaceMd,
        vertical: UnifiedTokens.spaceXs,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: UnifiedTokens.iconLg,
                  color: UnifiedColors.textPrimary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(child: Text('오늘의 운세', style: UnifiedText.titleLarge())),
              IconButton(
                icon: Icon(
                  isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: UnifiedTokens.iconLg,
                  color: UnifiedColors.textPrimary,
                ),
                onPressed: onSave,
              ),
              IconButton(
                icon: const Icon(
                  Icons.ios_share_rounded,
                  size: UnifiedTokens.iconLg,
                  color: UnifiedColors.textPrimary,
                ),
                onPressed: onShare,
              ),
            ],
          ),
          if (passActive && remainingLabel != null)
            Padding(
              padding: const EdgeInsets.only(
                left: UnifiedTokens.spaceMd,
                bottom: UnifiedTokens.spaceXs,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_open_rounded,
                      size: UnifiedTokens.iconSm,
                      color: UnifiedColors.textCaption,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '프리패스 남은 시간 · $remainingLabel',
                      style: UnifiedText.caption(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InsufficientDataView extends StatelessWidget {
  const _InsufficientDataView({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
      child: HeroSummaryCard(
        name: name,
        date: DateTime.now(),
        score: 0,
        headline: '아직 결과를 준비하지 못했어요',
        notice: '정보를 다시 확인해주세요',
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({
    required this.report,
    required this.passActive,
    required this.onSave,
    required this.onShare,
  });

  final FortuneReport report;
  final bool passActive;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      // 섹션1: 히어로 요약(상태뱃지+키워드+보조설명 포함)
      HeroSummaryCard(
        name: report.hero.name,
        date: report.hero.date,
        score: report.hero.score,
        headline: report.hero.headline,
        statusLabel: report.hero.statusLabel,
        keywords: report.hero.keywords,
        subDescription: report.hero.subDescription,
      ),
    ];

    var unlockPromptInserted = passActive; // 이미 활성이면 안내 카드 자체를 넣지 않음
    for (final section in report.sections) {
      if (!unlockPromptInserted && section.requiresPass) {
        // [§5/§6-7 열림패스 정책] 잠금 유도 문구를 카드마다 반복하지 않고,
        // 첫 잠금 구간 바로 앞에 단 하나의 안내 카드로만 노출한다.
        cards.add(const _UnlockPassPromptCard());
        unlockPromptInserted = true;
      }
      cards.add(_buildSection(section));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        UnifiedTokens.spaceXl,
        UnifiedTokens.spaceMd,
        UnifiedTokens.spaceXl,
        UnifiedTokens.spaceXl,
      ),
      itemCount: cards.length + 1, // +1: 하단 CTA+배너 블록(섹션12)
      separatorBuilder: (context, i) => SizedBox(
        height: i == cards.length - 1
            ? UnifiedTokens.spaceXxl
            : UnifiedTokens.spaceMd,
      ),
      itemBuilder: (context, i) {
        if (i < cards.length) return cards[i];
        // 섹션12: 하단 CTA 4개 + AI 상담 배너
        return Column(
          children: [
            ResultBottomActions(
              actions: [
                ResultActionItem(
                  icon: Icons.bookmark_border_rounded,
                  label: '저장',
                  onTap: onSave,
                ),
                ResultActionItem(
                  icon: Icons.ios_share_rounded,
                  label: '공유',
                  onTap: onShare,
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
                  onTap: () => _openWorryConsultation(context),
                ),
              ],
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            AIConsultBanner(
              onTap: () => Navigator.of(
                context,
              ).pushNamed('/ai-fortune/consultation/type'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSection(FortuneSection section) {
    final isLocked = section.requiresPass && !passActive;

    switch (section.type) {
      case FortuneSectionType.overview:
        final s = section as OverviewSection;
        return SectionCard(title: s.title, body: s.body);

      case FortuneSectionType.timeline:
        final s = section as TimelineSection;
        return TimelineCard(
          title: s.title,
          isLocked: isLocked,
          slots: s.slots
              .map((e) => TimelineCardSlot(label: e.label, body: e.body))
              .toList(),
        );

      case FortuneSectionType.aspect:
        final s = section as AspectSection;
        return SectionCard(
          title: s.title,
          body: s.body,
          isLocked: isLocked,
          icon: _aspectIcon(s.title),
          trailing: _IndexBadge(index: s.index),
        );

      case FortuneSectionType.avoid:
        final s = section as ListSection;
        return ListCard(
          title: s.title,
          items: s.items,
          icon: Icons.block_rounded,
          isLocked: isLocked,
        );

      case FortuneSectionType.recommend:
        final s = section as ListSection;
        return ListCard(
          title: s.title,
          items: s.items,
          icon: Icons.check_circle_outline_rounded,
          isLocked: isLocked,
        );

      case FortuneSectionType.lucky:
        final s = section as LuckySection;
        return LuckElementsGrid(
          title: s.title,
          items: s.items
              .map(
                (e) => LuckyGridItem(
                  label: e.label,
                  value: e.value,
                  isLocked: e.requiresPass && !passActive,
                ),
              )
              .toList(),
        );
    }
  }
}

/// [§6-4] 세부 운세 5종 제목 → line-style 아이콘 매핑(20px, iconLg).
IconData _aspectIcon(String title) {
  if (title.contains('연애')) return Icons.favorite_border_rounded;
  if (title.contains('금전')) return Icons.payments_outlined;
  if (title.contains('인간관계')) return Icons.people_outline_rounded;
  if (title.contains('건강')) return Icons.monitor_heart_outlined;
  if (title.contains('일') || title.contains('학업')) {
    return Icons.school_outlined;
  }
  return Icons.auto_awesome_outlined;
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

/// [§5/§6-7 열림패스 정책] 첫 잠금 구간 앞에 딱 한 번만 노출하는 안내 카드.
///
/// 카드마다 "열림패스로 상세 보기"를 반복 노출하지 않기 위해, 잠금 섹션들이
/// 시작되는 지점에 이 카드 하나로 유도 문구를 모은다. 탭하면 기존
/// [showPassRequiredSheet](광고 시청/파트너 방문/구독)를 그대로 재사용한다
/// (새 패스 발급 UI를 다시 만들지 않음). 배경은 배너 계열(#F2F0FA)을 사용해
/// 결과 섹션 카드(#F6F5FA)와 구분되면서도 팔레트 밖 색상은 쓰지 않는다.
class _UnlockPassPromptCard extends StatelessWidget {
  const _UnlockPassPromptCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardBanner,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LockOverlayBadge.badge(),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Text(
            '지금 열면 연애운, 금전운, 행운 요소까지\n모두 볼 수 있어요',
            style: UnifiedText.title(),
          ),
          const SizedBox(height: 4),
          Text('프리패스로 오늘의 운세를 전체 확인해보세요', style: UnifiedText.caption()),
          const SizedBox(height: UnifiedTokens.spaceMd),
          PrimaryCTA(
            label: '프리패스로 전체 보기',
            height: 40,
            onPressed: () =>
                showPassRequiredSheet(context, categoryTitle: '오늘의 운세'),
          ),
        ],
      ),
    );
  }
}

/// [§6-8 결과 하단 액션] "고민상담" — 명칭만 다르게 노출하고, 기능은 기존
/// 일반상담(ConsultationProvider.startSession(type: 'general'))을 그대로
/// 재사용한다(홈 화면의 동일 패턴과 통일).
Future<void> _openWorryConsultation(BuildContext context) async {
  final provider = context.read<ConsultationProvider>();
  final navigator = Navigator.of(context);
  await provider.startSession('general');
  if (!context.mounted) return;
  navigator.pushNamed('/ai-fortune/consultation/chat');
}
