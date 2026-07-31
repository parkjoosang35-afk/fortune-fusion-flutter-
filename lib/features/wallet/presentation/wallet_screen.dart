import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../application/wallet_provider.dart';
import '../domain/point_history_model.dart';

/// 03단계 §3.3 리워드 탭 - WalletScreen(행복머니 잔액/적립·차감 내역)
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<WalletProvider>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('행복머니 지갑')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<WalletProvider>().load(),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '보유 행복머니',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    wallet.isLoading
                        ? const SizedBox(
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            '${_comma(wallet.balance)} P',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('적립/사용 내역', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              if (wallet.history.isEmpty)
                const AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: '아직 행복머니 내역이 없어요',
                )
              else
                ...wallet.history.map((e) => _HistoryTile(item: e)),
            ],
          ),
        ),
      ),
    );
  }

  String _comma(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

class _HistoryTile extends StatelessWidget {
  final PointHistoryModel item;
  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isEarn = item.type == PointHistoryType.earn;
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
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isEarn
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEarn ? Icons.add_rounded : Icons.remove_rounded,
                size: 16,
                color: isEarn ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.reason,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${item.createdAt.month}.${item.createdAt.day} ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              '${isEarn ? '+' : '-'}${item.amount} P',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isEarn ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
