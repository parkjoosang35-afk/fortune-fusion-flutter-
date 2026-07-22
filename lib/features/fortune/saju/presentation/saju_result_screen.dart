import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/load_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_toast.dart';
import '../application/saju_provider.dart';
import '../domain/saju_model.dart';

/// 07단계 §6.1 SajuResultScreen (결과형 패턴 구체화 그대로 구현)
/// AppBar(공유아이콘) + SummaryCard + TabBar(종합/재물/애정/직업/건강) + ActionBar
class SajuResultScreen extends StatefulWidget {
  final String? resultId;
  const SajuResultScreen({super.key, this.resultId});

  @override
  State<SajuResultScreen> createState() => _SajuResultScreenState();
}

class _SajuResultScreenState extends State<SajuResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.resultId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SajuProvider>().selectFromHistory(widget.resultId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SajuProvider>();
    final state = provider.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('사주 결과'),
        actions: [
          if (state.isSuccess)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () => AppToast.show(context, '공유 링크가 복사되었습니다.'),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (state.status) {
          LoadStatus.loading => const Center(child: CircularProgressIndicator()),
          LoadStatus.error => AppErrorState(
              message: state.errorMessage ?? '분석에 실패했습니다.',
              onRetry: () => provider.retry(),
            ),
          LoadStatus.success => _SajuResultBody(result: state.data!),
          LoadStatus.initial => const AppErrorState(message: '입력 정보가 없습니다.'),
        },
      ),
      bottomNavigationBar: state.isSuccess
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pushNamed('/ai-fortune/saju/history'),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('히스토리'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pushNamed('/ai-fortune/saju/input'),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('다시 분석'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _SajuResultBody extends StatefulWidget {
  final SajuResultModel result;
  const _SajuResultBody({required this.result});

  @override
  State<_SajuResultBody> createState() => _SajuResultBodyState();
}

class _SajuResultBodyState extends State<_SajuResultBody> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final topics = widget.result.topicResults.keys.toList();
    _tabController = TabController(length: topics.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final topics = result.topicResults.keys.toList();

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _SummaryCard(result: result)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: topics.map((t) => Tab(text: t)).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: topics
                .map((t) => SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        result.topicResults[t] ?? '',
                        style: const TextStyle(fontSize: 15, height: 1.6),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final SajuResultModel result;
  const _SummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final p = result.pillars;
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(gradient: AppColors.mysticGradient, borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('나의 사주 명식', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _pillarBox('년주', p.year),
              _pillarBox('월주', p.month),
              _pillarBox('일주', p.day),
              _pillarBox('시주', p.hour ?? '-'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('오행 분포', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: result.fiveElements.entries
                .map((e) => Chip(
                      label: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      labelStyle: const TextStyle(color: Colors.white),
                      side: BorderSide.none,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _pillarBox(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Theme.of(context).scaffoldBackgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}
