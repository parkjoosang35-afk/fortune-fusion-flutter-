import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../application/tarot_provider.dart';

/// 03단계 §3.3 - TarotHistoryScreen (히스토리형 패턴)
class TarotHistoryScreen extends StatefulWidget {
  const TarotHistoryScreen({super.key});

  @override
  State<TarotHistoryScreen> createState() => _TarotHistoryScreenState();
}

class _TarotHistoryScreenState extends State<TarotHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<TarotProvider>().loadHistory(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<TarotProvider>().history;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('타로 히스토리', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: history.isEmpty
            ? const AppEmptyState(
                icon: Icons.style_outlined,
                title: '아직 타로 기록이 없어요',
                description: 'AI 타로를 뽑아보세요',
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
                    ).pushNamed('/ai-fortune/tarot/result', arguments: item.id),
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
                            Icons.style_rounded,
                            size: UnifiedTokens.iconLg,
                            color: UnifiedColors.textPrimary,
                          ),
                          SizedBox(width: UnifiedTokens.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.question,
                                  style: UnifiedText.bodyStrong(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
