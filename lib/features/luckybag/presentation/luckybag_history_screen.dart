import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../application/luckybag_provider.dart';
import '../domain/luckybag_open_log_model.dart';

/// 03단계 §3.3 리워드 탭 - LuckyBagHistoryScreen(개봉 이력/보상요약)
/// 06§4.9 `GET /v1/luckybags/history` + `GET /rewards/my` 대응 화면.
/// 03§9.2 재사용 패턴("내 보관함" 계열) - MyAmuletsScreen과 동일한 탭(이력/보상요약) 구조.
///
/// [복주머니 디자인 정합성 수정] 옛 다크 "신비로운 밤하늘" 그라디언트 배경
/// (AppColors.mysticGradient)과 화이트 하드코딩 텍스트를 걷어내고, 허브/상점과
/// 같은 화이트+라벤더 톤([UnifiedColors])으로 통일한다. 탭 구조·데이터 로딩
/// 로직은 그대로 유지 — 색과 컴포넌트만 교체.
class LuckyBagHistoryScreen extends StatefulWidget {
  const LuckyBagHistoryScreen({super.key});

  @override
  State<LuckyBagHistoryScreen> createState() => _LuckyBagHistoryScreenState();
}

class _LuckyBagHistoryScreenState extends State<LuckyBagHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LuckyBagProvider>().loadHistory();
      context.read<LuckyBagProvider>().loadRewardSummary();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LuckyBagProvider>();

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('복주머니 이력', style: UnifiedText.title()),
        iconTheme: IconThemeData(color: UnifiedColors.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          labelColor: UnifiedColors.black,
          unselectedLabelColor: UnifiedColors.textSecondary,
          indicatorColor: UnifiedColors.black,
          labelStyle: UnifiedText.bodyStrong(),
          unselectedLabelStyle: UnifiedText.body(),
          tabs: const [
            Tab(text: '개봉 이력'),
            Tab(text: '보상 요약'),
          ],
        ),
      ),
      body: SafeArea(
        child: provider.isHistoryLoading && provider.history.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _HistoryTab(
                    logs: provider.history,
                    onRefresh: provider.loadHistory,
                  ),
                  _RewardSummaryTab(entries: provider.rewardSummary),
                ],
              ),
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final List<LuckyBagOpenLogModel> logs;
  final Future<void> Function() onRefresh;

  const _HistoryTab({required this.logs, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const AppEmptyState(
        icon: Icons.card_giftcard_outlined,
        title: '아직 개봉한 복주머니가 없어요',
        description: '상점에서 복주머니를 열어보세요',
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(UnifiedTokens.screenPadding),
        itemCount: logs.length,
        itemBuilder: (context, index) => _HistoryTile(log: logs[index]),
      ),
    );
  }
}

Color _gradeColorOf(String code) {
  switch (code) {
    case 'best':
      return const Color(0xFFA9772F);
    case 'rare':
      return const Color(0xFF4DA8FF);
    case 'common':
      return const Color(0xFF5FE3B3);
    default:
      return UnifiedColors.textSecondary;
  }
}

class _HistoryTile extends StatelessWidget {
  final LuckyBagOpenLogModel log;
  const _HistoryTile({required this.log});

  String get _dateLabel {
    final d = log.openedAt;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.year}.${d.month}.${d.day} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final gradeColor = _gradeColorOf(log.grade.code);
    return Padding(
      padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceMd),
      child: Container(
        padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
        decoration: BoxDecoration(
          color: UnifiedColors.cardSection,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
          border: Border.all(color: UnifiedColors.border),
        ),
        child: Row(
          children: [
            Text(log.product.iconEmoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: UnifiedTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.product.name, style: UnifiedText.bodyStrong()),
                  const SizedBox(height: 2),
                  Text(
                    '$_dateLabel · ${log.rewardLabel}',
                    style: UnifiedText.bodySmall(),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: gradeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
              ),
              child: Text(
                log.grade.name,
                style: UnifiedText.chipLabel(color: gradeColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardSummaryTab extends StatelessWidget {
  final List<LuckyBagRewardSummaryEntry> entries;
  const _RewardSummaryTab({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const AppEmptyState(
        icon: Icons.bar_chart_rounded,
        title: '집계할 개봉 이력이 없어요',
        description: '복주머니를 열면 등급별 통계가 여기에 표시돼요',
      );
    }
    final totalCount = entries.fold<int>(0, (sum, e) => sum + e.count);
    final totalPoint = entries.fold<int>(
      0,
      (sum, e) => sum + e.totalPointReward,
    );

    return ListView(
      padding: const EdgeInsets.all(UnifiedTokens.screenPadding),
      children: [
        Container(
          padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
          decoration: BoxDecoration(
            color: UnifiedColors.cardAllMenu,
            borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
            border: Border.all(color: UnifiedColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SummaryStat(label: '총 개봉 횟수', value: '$totalCount회'),
              ),
              Container(width: 1, height: 32, color: UnifiedColors.border),
              Expanded(
                child: _SummaryStat(label: '누적 복주머니 획득', value: '$totalPoint개'),
              ),
            ],
          ),
        ),
        const SizedBox(height: UnifiedTokens.spaceXl),
        Text('등급별 통계', style: UnifiedText.bodyStrong()),
        const SizedBox(height: UnifiedTokens.spaceMd),
        ...entries.map((e) {
          final gradeColor = _gradeColorOf(e.grade.code);
          return Padding(
            padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceMd),
            child: Container(
              padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
              decoration: BoxDecoration(
                color: UnifiedColors.cardSection,
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
                border: Border.all(color: UnifiedColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: gradeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        UnifiedTokens.radiusPill,
                      ),
                    ),
                    child: Text(
                      e.grade.name,
                      style: UnifiedText.chipLabel(color: gradeColor),
                    ),
                  ),
                  const SizedBox(width: UnifiedTokens.spaceMd),
                  Expanded(
                    child: Text('${e.count}회 획득', style: UnifiedText.body()),
                  ),
                  if (e.totalPointReward > 0)
                    Text(
                      '${e.totalPointReward}개',
                      style: UnifiedText.bodyStrong(
                        color: UnifiedColors.black,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: UnifiedText.titleLarge()),
        const SizedBox(height: 4),
        Text(label, style: UnifiedText.caption()),
      ],
    );
  }
}
