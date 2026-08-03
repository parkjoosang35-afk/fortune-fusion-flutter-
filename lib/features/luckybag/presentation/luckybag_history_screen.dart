import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../application/luckybag_provider.dart';
import '../domain/luckybag_open_log_model.dart';

/// 03단계 §3.3 리워드 탭 - LuckyBagHistoryScreen(개봉 이력/보상요약)
/// 06§4.9 `GET /v1/luckybags/history` + `GET /rewards/my` 대응 화면.
/// 03§9.2 재사용 패턴("내 보관함" 계열) - MyAmuletsScreen과 동일한 탭(이력/보상요약) 구조.
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
      appBar: AppBar(
        title: const Text('복주머니 이력'),
        bottom: TabBar(
          controller: _tabController,
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: logs.length,
        itemBuilder: (context, index) => _HistoryTile(log: logs[index]),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final LuckyBagOpenLogModel log;
  const _HistoryTile({required this.log});

  Color get _gradeColor {
    switch (log.grade.code) {
      case 'best':
        return AppColors.secondaryDark;
      case 'rare':
        return AppColors.info;
      case 'common':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  String get _dateLabel {
    final d = log.openedAt;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.year}.${d.month}.${d.day} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        ),
        child: Row(
          children: [
            Text(log.product.iconEmoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.product.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_dateLabel · ${log.rewardLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _gradeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                log.grade.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _gradeColor,
                ),
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

  Color _gradeColor(String code) {
    switch (code) {
      case 'best':
        return AppColors.secondaryDark;
      case 'rare':
        return AppColors.info;
      case 'common':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

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
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.mysticGradient,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SummaryStat(label: '총 개봉 횟수', value: '$totalCount회'),
              ),
              Container(width: 1, height: 32, color: Colors.white24),
              Expanded(
                child: _SummaryStat(label: '누적 복주머니 획득', value: '$totalPoint개'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('등급별 통계', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        ...entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(AppRadius.cardSmall),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _gradeColor(e.grade.code).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      e.grade.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _gradeColor(e.grade.code),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      '${e.count}회 획득',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (e.totalPointReward > 0)
                    Text(
                      '${e.totalPointReward}개',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryDark,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
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
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
