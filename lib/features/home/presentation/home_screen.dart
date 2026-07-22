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
import '../../luckybag/application/luckybag_provider.dart';
import '../../amulet/application/amulet_provider.dart';

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
      // 07단계 §14 행운 경험(Luck Experience) 리추얼 데이터 로드
      context.read<LuckyBagProvider>().load();
      context.read<AmuletProvider>().load();
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
                onPressed: () =>
                    Navigator.of(context).pushNamed('/my/notifications'),
              ),
              if (notif.unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
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
            Text(
              '안녕하세요, $nickname님 👋',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            // ★07단계 §14 행운 경험(Luck Experience) 리추얼 배너 — 기존 요소는 그대로 두고 최상단에 추가
            const _LuckRitualBanner(),
            const SizedBox(height: AppSpacing.lg),
            const _AiRecommendationCard(),
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
      onTap: () =>
          Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
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
                Icon(
                  Icons.wb_twilight_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                SizedBox(width: 6),
                Text(
                  '오늘의 운세',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (provider.isLoading)
              const SizedBox(
                height: 40,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              Text(
                today?.summaryText ?? '오늘의 운세를 확인해보세요.',
                style: const TextStyle(
                  color: AppColors.onDeepSpace,
                  fontSize: 16,
                  height: 1.4,
                ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        '$label $score',
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '연속 출석 ${provider.streak}일째',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  provider.checkedToday
                      ? '오늘 출석을 완료했어요!'
                      : '오늘 출석하고 포인트를 받아보세요',
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
              backgroundColor: provider.checkedToday
                  ? AppColors.divider
                  : AppColors.primary,
              foregroundColor: provider.checkedToday
                  ? AppColors.textHint
                  : Colors.white,
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
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
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

/// 07단계 §6.4/§14 행운 경험(Luck Experience) 리추얼 배너
/// 홈 최상단에 배치, 가로 스와이프 5카드(행운메시지/행운색상/행운숫자/복주머니/디지털부적)
/// 앱 최초 진입(당일 1회) 시 자동 순환 하이라이트 후 정적 배너로 전환.
class _LuckRitualBanner extends StatefulWidget {
  const _LuckRitualBanner();

  @override
  State<_LuckRitualBanner> createState() => _LuckRitualBannerState();
}

class _LuckRitualBannerState extends State<_LuckRitualBanner> {
  final _controller = PageController(viewportFraction: 0.86);
  int _current = 0;
  bool _autoPlayed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoCycle());
  }

  Future<void> _autoCycle() async {
    if (_autoPlayed || !mounted) return;
    _autoPlayed = true;
    for (var i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      _controller.animateTo(
        i * (_controller.position.viewportDimension * 0.86 + AppSpacing.sm),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
      setState(() => _current = i);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _luckyColorMap = {
    '보라': Color(0xFF9C82FF),
    '골드': Color(0xFFFFC542),
    '블루': Color(0xFF4DA8FF),
    '그린': Color(0xFF2ECC71),
  };

  @override
  Widget build(BuildContext context) {
    final today = context.watch<DailyFortuneProvider>().today;
    final luckyBag = context.watch<LuckyBagProvider>().summary;
    final amulet = context.watch<AmuletProvider>().summary;

    final cards = <Widget>[
      _RitualCard(
        emoji: '🌅',
        title: '오늘의 행운 메시지',
        body: today?.summaryText ?? '오늘의 운세를 불러오는 중...',
        onTap: () =>
            Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
      ),
      _RitualCard(
        emoji: '🍀',
        title: '오늘의 행운 색상',
        body: today?.luckyColor ?? '-',
        swatch: today != null ? _luckyColorMap[today.luckyColor] : null,
        onTap: () =>
            Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
      ),
      _RitualCard(
        emoji: '🔢',
        title: '오늘의 행운 숫자',
        body: today != null ? '${today.luckyNumber}' : '-',
        onTap: () =>
            Navigator.of(context).pushNamed('/home/daily-fortune-detail'),
      ),
      _RitualCard(
        emoji: '🎁',
        title: '받을 수 있는 복주머니',
        body: (luckyBag?.pendingCount ?? 0) > 0
            ? '${luckyBag!.pendingCount}개 열어볼 수 있어요'
            : '오늘은 모두 열었어요',
        onTap: () => Navigator.of(context).pushNamed('/reward/luckybag'),
      ),
      _RitualCard(
        emoji: '🧧',
        title: '오늘의 디지털 부적',
        body: amulet?.hasActive == true
            ? '${amulet!.iconEmoji} ${amulet.name} 보유 중'
            : '보유한 부적이 없어요',
        onTap: () => Navigator.of(context).pushNamed('/reward/amulet'),
      ),
    ];

    return Semantics(
      label: '오늘의 행운 경험 배너, ${cards.length}개 카드 중 ${_current + 1}번째',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 132,
            child: PageView.builder(
              controller: _controller,
              itemCount: cards.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == cards.length - 1 ? 0 : AppSpacing.sm,
                  ),
                  child: cards[index],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              cards.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _current ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _current ? AppColors.primary : AppColors.divider,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RitualCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;
  final Color? swatch;
  final VoidCallback onTap;

  const _RitualCard({
    required this.emoji,
    required this.title,
    required this.body,
    required this.onTap,
    this.swatch,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title: $body',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: AppColors.primaryContainer.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (swatch != null)
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: swatch,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Text(
                  body,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 07단계 §14.2 "오늘의 AI 추천 행동" 카드
/// 1차는 클라이언트 측 간단 규칙(최근 미사용 AI기능 우선 추천)으로 구현, API 추가 없음(§14.5).
class _AiRecommendationCard extends StatelessWidget {
  const _AiRecommendationCard();

  static const _recommendations = [
    (
      'AI상담사에게 오늘의 고민을 이야기해보세요',
      Icons.chat_bubble_rounded,
      '/ai-fortune/consultation/type',
    ),
    ('오늘은 타로로 빠른 답을 확인해보세요', Icons.style_rounded, '/ai-fortune/tarot/question'),
    (
      '궁합을 확인하고 소중한 사람과의 인연을 알아보세요',
      Icons.favorite_rounded,
      '/ai-fortune/compatibility/input',
    ),
    (
      '관상 분석으로 나의 숨은 매력을 발견해보세요',
      Icons.face_retouching_natural_rounded,
      '/ai-fortune/face/capture',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final seed = DateTime.now().day;
    final (text, icon, route) =
        _recommendations[seed % _recommendations.length];

    return Semantics(
      button: true,
      label: '오늘의 AI 추천 행동: $text',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => Navigator.of(context).pushNamed(route),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 22)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '오늘의 AI 추천 행동',
                      style: TextStyle(
                        color: Color(0xFF6B4B00),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text,
                      style: const TextStyle(
                        color: Color(0xFF3D2900),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: const Color(0xFF6B4B00)),
            ],
          ),
        ),
      ),
    );
  }
}
