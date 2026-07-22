import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/point_badge.dart';
import '../../auth/application/auth_provider.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../attendance/application/attendance_provider.dart';
import '../../fortune/daily/application/daily_fortune_provider.dart';
import '../../notification/notification_provider.dart';

/// 03단계 §3.3 홈 탭 - HomeScreen
/// 구성: 오늘의 운세 카드, 출석체크 위젯, AI 기능 바로가기, 포인트 배지
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().load();
      context.read<AttendanceProvider>().load();
      context.read<DailyFortuneProvider>().loadToday();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wallet = context.watch<WalletProvider>();
    final notif = context.watch<NotificationProvider>();
    final nickname = auth.currentUser?.nickname ?? '게스트';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fortune Fusion'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () => Navigator.of(context).pushNamed('/my/notifications'),
              ),
              if (notif.unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
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
            Text('안녕하세요, $nickname님 👋', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            const _DailyFortuneCard(),
            const SizedBox(height: AppSpacing.lg),
            const _AttendanceWidget(),
            const SizedBox(height: AppSpacing.lg),
            Text('AI 운세 바로가기', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            const _AiShortcutGrid(),
          ],
        ),
      ),
    );
  }
}

class _DailyFortuneCard extends StatelessWidget {
  const _DailyFortuneCard();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DailyFortuneProvider>();
    final today = provider.today;

    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: AppColors.mysticGradient,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.wb_twilight_rounded, color: Colors.white70, size: 20),
                SizedBox(width: 6),
                Text('오늘의 운세', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (provider.isLoading)
              const SizedBox(
                height: 40,
                child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              )
            else
              Text(
                today?.summaryText ?? '오늘의 운세를 확인해보세요.',
                style: const TextStyle(color: AppColors.onDeepSpace, fontSize: 16, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: AppSpacing.md),
            if (today != null)
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  _miniScore('총운', today.categoryScores['총운'] ?? 0),
                  _miniScore('재물', today.categoryScores['재물'] ?? 0),
                  _miniScore('애정', today.categoryScores['애정'] ?? 0),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _miniScore(String label, int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text('$label $score', style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }
}

class _AttendanceWidget extends StatelessWidget {
  const _AttendanceWidget();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('연속 출석 ${provider.streak}일째', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  provider.checkedToday ? '오늘 출석을 완료했어요!' : '오늘 출석하고 포인트를 받아보세요',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: provider.checkedToday
                ? null
                : () async {
                    final earned = await provider.checkIn();
                    if (context.mounted) {
                      context.read<WalletProvider>().load();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('출석 완료! +$earned P 지급')),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: provider.checkedToday ? AppColors.divider : AppColors.primary,
              foregroundColor: provider.checkedToday ? AppColors.textHint : Colors.white,
            ),
            child: Text(provider.checkedToday ? '완료' : '출석'),
          ),
        ],
      ),
    );
  }
}

class _AiShortcutGrid extends StatelessWidget {
  const _AiShortcutGrid();

  static const _items = [
    (Icons.auto_stories_rounded, '사주', '/ai-fortune/saju/input'),
    (Icons.style_rounded, '타로', '/ai-fortune/tarot/question'),
    (Icons.face_retouching_natural_rounded, '관상', '/ai-fortune/face/capture'),
    (Icons.back_hand_rounded, '손금', '/ai-fortune/palm/capture'),
    (Icons.favorite_rounded, '궁합', '/ai-fortune/compatibility/input'),
    (Icons.chat_bubble_rounded, 'AI상담', '/ai-fortune/consultation/type'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final (icon, label, route) = _items[index];
        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => Navigator.of(context).pushNamed(route),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.card)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
                  child: Icon(icon, color: AppColors.primary, size: 24),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        );
      },
    );
  }
}
