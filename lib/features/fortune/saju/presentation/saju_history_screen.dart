import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../application/saju_provider.dart';

/// 03단계 §3.3 - SajuHistoryScreen (히스토리형 패턴)
class SajuHistoryScreen extends StatefulWidget {
  const SajuHistoryScreen({super.key});

  @override
  State<SajuHistoryScreen> createState() => _SajuHistoryScreenState();
}

class _SajuHistoryScreenState extends State<SajuHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<SajuProvider>().loadHistory(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<SajuProvider>().history;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('사주 히스토리', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: history.isEmpty
            ? const AppEmptyState(
                icon: Icons.auto_stories_outlined,
                title: '아직 분석 기록이 없어요',
                description: 'AI 사주를 분석해보세요',
              )
            : ListView.separated(
                padding: EdgeInsets.all(UnifiedTokens.screenPadding),
                itemCount: history.length,
                separatorBuilder: (_, __) =>
                    SizedBox(height: UnifiedTokens.spaceMd),
                itemBuilder: (context, index) {
                  final item = history[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed('/ai-fortune/saju/result', arguments: item.id),
                    child: Container(
                      padding: EdgeInsets.all(UnifiedTokens.screenPadding),
                      decoration: BoxDecoration(
                        color: UnifiedColors.cardSection,
                        borderRadius: BorderRadius.circular(
                          UnifiedTokens.radiusMd,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_stories_rounded,
                            size: UnifiedTokens.iconLg,
                            color: UnifiedColors.textPrimary,
                          ),
                          SizedBox(width: UnifiedTokens.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.pillars.year} ${item.pillars.month} ${item.pillars.day}',
                                  style: UnifiedText.bodyStrong(),
                                ),
                                Text(
                                  '${item.createdAt.year}.${item.createdAt.month}.${item.createdAt.day}',
                                  style: UnifiedText.bodySmall(
                                    color: UnifiedColors.textCaption,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: UnifiedColors.textCaption,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
