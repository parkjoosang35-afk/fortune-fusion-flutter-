import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_toast.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/mission_provider.dart';
import '../domain/mission_model.dart';

/// 03단계 §3.3 - MissionScreen (리스트형 패턴)
/// 일일/주간 미션 목록 + 완료 처리 → WalletProvider.earn 연계
class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key});

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<MissionProvider>().load(),
    );
  }

  Future<void> _complete(MissionModel mission) async {
    final reward = await context.read<MissionProvider>().complete(mission.id);
    if (!mounted) return;
    if (reward != null) {
      await context.read<WalletProvider>().earn(reward, '${mission.title} 완료');
      if (mounted) AppToast.show(context, '미션 완료! +$reward P 지급되었습니다.');
    } else {
      AppToast.show(context, '미션 처리에 실패했습니다.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MissionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('미션')),
      body: SafeArea(
        child: provider.isLoading && provider.missions.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text('일일 미션', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  ...provider.daily.map(
                    (m) => _MissionTile(
                      mission: m,
                      onComplete: () => _complete(m),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('주간 미션', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  ...provider.weekly.map(
                    (m) => _MissionTile(
                      mission: m,
                      onComplete: () => _complete(m),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  final MissionModel mission;
  final VoidCallback onComplete;
  const _MissionTile({required this.mission, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
              decoration: BoxDecoration(
                color: mission.isCompleted
                    ? AppColors.divider
                    : AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                mission.isCompleted
                    ? Icons.check_rounded
                    : Icons.checklist_rounded,
                color: mission.isCompleted
                    ? AppColors.textHint
                    : AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mission.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+${mission.rewardPoints} P',
                    style: const TextStyle(
                      color: AppColors.secondaryDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 76,
              child: ElevatedButton(
                onPressed: mission.isCompleted ? null : onComplete,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(
                  mission.isCompleted ? '완료' : '받기',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
