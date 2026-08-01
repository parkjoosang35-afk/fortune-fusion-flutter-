import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../application/palm_provider.dart';

class PalmHistoryScreen extends StatefulWidget {
  const PalmHistoryScreen({super.key});

  @override
  State<PalmHistoryScreen> createState() => _PalmHistoryScreenState();
}

class _PalmHistoryScreenState extends State<PalmHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<PalmProvider>().loadHistory(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<PalmProvider>().history;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('손금 히스토리', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: history.isEmpty
            ? const AppEmptyState(
                icon: Icons.back_hand_outlined,
                title: '아직 분석 기록이 없어요',
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
                    ).pushNamed('/ai-fortune/palm/result', arguments: item.id),
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
                            Icons.back_hand_rounded,
                            size: UnifiedTokens.iconLg,
                            color: UnifiedColors.textPrimary,
                          ),
                          SizedBox(width: UnifiedTokens.spaceMd),
                          Expanded(
                            child: Text(
                              '${item.createdAt.year}.${item.createdAt.month}.${item.createdAt.day} 손금 분석',
                              style: UnifiedText.bodyStrong(),
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
