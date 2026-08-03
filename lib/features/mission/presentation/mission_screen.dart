import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/mission_provider.dart';
import '../domain/mission_model.dart';

/// 03단계 §3.3 - MissionScreen (리스트형 패턴)
/// 일일/주간 미션 목록 + 진행률 표시
///
/// [Phase5 - 게임화 최소연동] 이전에는 "받기" 버튼을 눌러 로컬에서 완료 처리하는
/// Mock이었으나, 이제는 서버(admin_web)가 실제 행동(오늘의 운세 확인, 복 나누기 등)
/// 발생 시 진행률을 자동으로 갱신하고 목표 달성 즉시 보상까지 자동 지급한다.
/// 따라서 이 화면은 진행률(progressCount/targetCount)을 보여주는 조회 전용 화면으로
/// 전환하고, "다른 화면에서 활동하면 자동으로 반영된다"는 안내를 덧붙인다.
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

  Future<void> _refresh() => context.read<MissionProvider>().load();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MissionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('미션')),
      body: SafeArea(
        child: provider.isLoading && provider.missions.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Text(
                      '일일 미션',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '오늘의 운세 확인, 타로 리딩, 복 나누기 등 활동을 하면 자동으로 진행됩니다.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...provider.daily.map((m) => _MissionTile(mission: m)),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '주간 미션',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...provider.weekly.map((m) => _MissionTile(mission: m)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  final MissionModel mission;
  const _MissionTile({required this.mission});

  @override
  Widget build(BuildContext context) {
    final progress = mission.targetCount > 0
        ? (mission.progressCount / mission.targetCount).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
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
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppColors.divider,
                      color: mission.isCompleted
                          ? AppColors.textHint
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${mission.progressCount}/${mission.targetCount}  ·  +${mission.rewardPoints}개',
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
            Icon(
              mission.isCompleted
                  ? Icons.emoji_events_rounded
                  : Icons.hourglass_bottom_rounded,
              color: mission.isCompleted
                  ? AppColors.secondaryDark
                  : AppColors.textHint,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
