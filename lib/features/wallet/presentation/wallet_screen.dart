import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../application/wallet_provider.dart';
import '../domain/point_history_model.dart';

/// 03단계 §3.3 리워드 탭 - WalletScreen(복주머니 잔액/적립·차감 내역)
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
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(title: const Text('복주머니 지갑')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<WalletProvider>().load(),
          child: ListView(
            padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
                decoration: BoxDecoration(
                  color: UnifiedColors.cardMain,
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('보유 복주머니', style: UnifiedText.caption()),
                    const SizedBox(height: UnifiedTokens.spaceSm),
                    wallet.isLoading
                        ? const SizedBox(
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            '${_comma(wallet.balance)}개',
                            style: UnifiedText.titleLarge(),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: UnifiedTokens.spaceXxl),
              Text('적립/사용 내역', style: UnifiedText.title()),
              const SizedBox(height: UnifiedTokens.spaceMd),
              if (wallet.history.isEmpty)
                const AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: '아직 복주머니 내역이 없어요',
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
      padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceMd),
      child: Container(
        padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
        decoration: BoxDecoration(
          color: UnifiedColors.cardSection,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(UnifiedTokens.spaceSm),
              decoration: const BoxDecoration(
                color: UnifiedColors.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEarn ? Icons.add_rounded : Icons.remove_rounded,
                size: UnifiedTokens.iconMd,
                color: UnifiedColors.textSecondary,
              ),
            ),
            const SizedBox(width: UnifiedTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.reason, style: UnifiedText.bodyStrong()),
                  Text(
                    '${item.createdAt.month}.${item.createdAt.day} ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                    style: UnifiedText.bodySmall(),
                  ),
                ],
              ),
            ),
            Text(
              '${isEarn ? '+' : '-'}${item.amount}개',
              style: UnifiedText.bodyStrong(),
            ),
          ],
        ),
      ),
    );
  }
}
