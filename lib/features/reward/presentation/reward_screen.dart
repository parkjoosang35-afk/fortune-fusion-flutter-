import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/point_badge.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../attendance/application/attendance_provider.dart';

/// 03단계 §3.3 리워드 탭 - RewardScreen(지갑/출석체크/미션/랭킹 허브)
class RewardScreen extends StatefulWidget {
  const RewardScreen({super.key});

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().load();
      context.read<AttendanceProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final attendance = context.watch<AttendanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('리워드'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Center(
              child: PointBadge(
                balance: wallet.balance,
                onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _MenuCard(
              icon: Icons.wallet_rounded,
              title: '포인트 지갑',
              subtitle: '보유 ${wallet.balance} P · 내역 확인',
              onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
            ),
            const SizedBox(height: AppSpacing.md),
            _MenuCard(
              icon: Icons.calendar_month_rounded,
              title: '출석체크',
              subtitle: attendance.checkedToday
                  ? '오늘 출석 완료 · 연속 ${attendance.streak}일'
                  : '연속 ${attendance.streak}일째 · 오늘 출석하기',
              onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
            ),
            const SizedBox(height: AppSpacing.md),
            _MenuCard(
              icon: Icons.checklist_rounded,
              title: '미션',
              subtitle: '일일/주간 미션을 완료하고 포인트 받기',
              onTap: () => Navigator.of(context).pushNamed('/reward/missions'),
            ),
            const SizedBox(height: AppSpacing.md),
            _MenuCard(
              icon: Icons.leaderboard_rounded,
              title: '랭킹',
              subtitle: '포인트 랭킹 TOP 유저 확인하기',
              onTap: () => Navigator.of(context).pushNamed('/reward/ranking'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
