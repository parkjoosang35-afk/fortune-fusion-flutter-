import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/ranking_provider.dart';
import '../domain/ranking_model.dart';

/// 03단계 §3.3 - RankingScreen (리스트형 패턴)
/// 주간 포인트 랭킹 TOP 리스트 (내 순위 강조표시)
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final myPoints = context.read<WalletProvider>().balance;
      context.read<RankingProvider>().load(myPoints: myPoints);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RankingProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('랭킹')),
      body: SafeArea(
        child: provider.isLoading && provider.entries.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: provider.entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) => _RankTile(entry: provider.entries[index]),
              ),
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  final RankingEntryModel entry;
  const _RankTile({required this.entry});

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return AppColors.secondary;
      case 2:
        return AppColors.secondaryLight;
      case 3:
        return AppColors.secondaryLight;
      default:
        return AppColors.divider;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: entry.isMe ? AppColors.primaryContainer : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: entry.isMe ? Border.all(color: AppColors.primary, width: 1.5) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _rankColor(entry.rank), shape: BoxShape.circle),
            child: Text(
              '${entry.rank}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              entry.isMe ? '${entry.nickname} (나)' : entry.nickname,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: entry.isMe ? FontWeight.w800 : FontWeight.w600,
                  ),
            ),
          ),
          Text('${entry.points} P', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
