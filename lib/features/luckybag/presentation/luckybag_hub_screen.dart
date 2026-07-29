import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cosmic_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../attendance/application/attendance_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/grade_model.dart';
import '../application/luckybag_provider.dart';
import 'luckybag_shop_screen.dart';
import 'luckybag_history_screen.dart';
import '../../amulet/presentation/amulet_shop_screen.dart';
import '../../giftcard/presentation/giftcard_catalog_screen.dart';
import '../../mission/presentation/mission_screen.dart';
import '../../subscription/presentation/subscription_plans_screen.dart';

/// [Fortune Fusion UI 리뉴얼 프롬프트] §7 LuckyBagScreen - 복주머니 탭
/// 잔액 히어로 + 획득처/사용처/VIP/히스토리 섹션
///
/// [주의] 실제 기능(WalletProvider, AttendanceProvider, LuckyBagProvider 등)은
/// 기존 Provider/Repository를 그대로 재사용한다. 이미 완성된 화면(LuckyBagShopScreen,
/// LuckyBagHistoryScreen, AmuletShopScreen, GiftcardCatalogScreen, MissionScreen,
/// SubscriptionPlansScreen)은 재작성하지 않고 "바로가기 카드"로 진입시킨다.
class LuckyBagScreen extends StatefulWidget {
  const LuckyBagScreen({super.key});

  @override
  State<LuckyBagScreen> createState() => _LuckyBagScreenState();
}

class _LuckyBagScreenState extends State<LuckyBagScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().load();
      context.read<AttendanceProvider>().load();
      context.read<LuckyBagProvider>().load();
    });
  }

  Future<void> _handleAttendanceTap() async {
    final attendance = context.read<AttendanceProvider>();
    if (attendance.checkedToday) {
      AppToast.show(context, '오늘 출석을 이미 완료했어요. (연속 ${attendance.streak}일째)');
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: '오늘 출석하기',
      message: '출석체크를 하고 포인트를 받으시겠습니까?',
      confirmLabel: '출석하기',
    );
    if (!confirmed || !mounted) return;

    final earned = await attendance.checkIn();
    if (!mounted) return;
    if (earned > 0) {
      await context.read<WalletProvider>().earn(earned, '출석체크 보상');
      if (!mounted) return;
      AppToast.show(context, '출석 완료! +$earned P 지급되었습니다.');
    } else {
      AppToast.show(context, '출석 처리에 실패했습니다.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final attendance = context.watch<AttendanceProvider>();
    final luckyBag = context.watch<LuckyBagProvider>();
    final grade = context.watch<AuthProvider>().currentGrade;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: const Text(
          '복주머니',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.cosmicTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // §1 잔액 히어로
            _BalanceHero(
              balance: wallet.balance,
              pendingBags: luckyBag.summary?.pendingCount ?? 0,
              onWalletTap: () =>
                  Navigator.of(context).pushNamed('/reward/wallet'),
            ),
            const SizedBox(height: AppSpacing.xl),

            // §2 획득처
            const _SectionTitle(title: '✨ 포인트 획득처'),
            const SizedBox(height: AppSpacing.md),
            _ShortcutCard(
              emoji: '📅',
              title: '출석체크',
              subtitle: attendance.checkedToday
                  ? '오늘 출석 완료 · 연속 ${attendance.streak}일'
                  : '연속 ${attendance.streak}일째 · 오늘 출석하기',
              accentColor: AppColors.accentMint,
              onTap: _handleAttendanceTap,
            ),
            const SizedBox(height: AppSpacing.md),
            _ShortcutCard(
              emoji: '✅',
              title: '미션',
              subtitle: '일일/주간 미션을 완료하고 포인트 받기',
              accentColor: AppColors.accentBlue,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const MissionScreen())),
            ),
            const SizedBox(height: AppSpacing.xl),

            // §3 사용처
            const _SectionTitle(title: '🎁 포인트 사용처'),
            const SizedBox(height: AppSpacing.md),
            _ShortcutCard(
              emoji: '🍀',
              title: '복주머니 열기',
              subtitle: (luckyBag.summary?.pendingCount ?? 0) > 0
                  ? '받을 수 있는 복주머니 ${luckyBag.summary!.pendingCount}개'
                  : '오늘의 복주머니를 열어 행운을 확인해보세요',
              accentColor: AppColors.accentGold,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LuckyBagShopScreen()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _ShortcutCard(
              emoji: '🧧',
              title: '디지털 부적',
              subtitle: '나를 지켜주는 디지털 부적을 확인해보세요',
              accentColor: AppColors.accentPurple,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AmuletShopScreen()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _ShortcutCard(
              emoji: '💳',
              title: '상품권',
              subtitle: '포인트로 상품권을 교환해보세요',
              accentColor: AppColors.accentPink,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const GiftcardCatalogScreen(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // §4 VIP 섹션
            const _SectionTitle(title: '👑 VIP 등급'),
            const SizedBox(height: AppSpacing.md),
            _VipCard(
              grade: grade,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SubscriptionPlansScreen(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // §5 히스토리
            const _SectionTitle(title: '📜 히스토리'),
            const SizedBox(height: AppSpacing.md),
            _ShortcutCard(
              emoji: '📖',
              title: '복주머니 개봉 이력',
              subtitle: '지금까지 열어본 복주머니와 받은 보상 확인',
              accentColor: AppColors.accentBlue,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LuckyBagHistoryScreen(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _ShortcutCard(
              emoji: '🧾',
              title: '포인트 내역',
              subtitle: '적립·사용 전체 내역 확인하기',
              accentColor: AppColors.accentMint,
              onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.cosmicTextPrimary,
      ),
    );
  }
}

/// §1 잔액 히어로 카드
class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.balance,
    required this.pendingBags,
    required this.onWalletTap,
  });

  final int balance;
  final int pendingBags;
  final VoidCallback onWalletTap;

  @override
  Widget build(BuildContext context) {
    return CosmicCard(
      gradient: AppColors.gradientGold,
      onTap: onWalletTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🍀', style: TextStyle(fontSize: 22)),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                '내 포인트 잔액',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.bgPrimary,
                ),
              ),
              const Spacer(),
              if (pendingBags > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '받을 복주머니 $pendingBags개',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.bgPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${_formatBalance(balance)} P',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.bgPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Row(
            children: [
              Text(
                '포인트 지갑 바로가기',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.bgPrimary,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: AppColors.bgPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatBalance(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

/// 획득처/사용처/히스토리 공통 바로가기 카드
class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CosmicCard(
      showGlow: false,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cosmicTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.cosmicTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppColors.cosmicTextTertiary,
          ),
        ],
      ),
    );
  }
}

/// §4 VIP 등급 카드
class _VipCard extends StatelessWidget {
  const _VipCard({required this.grade, required this.onTap});

  final GradeModel? grade;
  final VoidCallback onTap;

  Color get _gradeColor {
    switch (grade?.code) {
      case 'vip':
        return AppColors.accentGold;
      case 'gold':
        return AppColors.accentGold;
      case 'silver':
        return AppColors.cosmicTextSecondary;
      default:
        return AppColors.accentPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _gradeColor;
    return CosmicCard(
      gradient: AppColors.gradientCosmic,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grade != null ? '${grade!.name} 등급' : '등급 정보 없음',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.cosmicTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  grade != null
                      ? '포인트 적립 ${grade!.pointEarnMultiplier}배 적용 중'
                      : '프리미엄 구독으로 등급을 올려보세요',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.cosmicTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppColors.cosmicTextTertiary,
          ),
        ],
      ),
    );
  }
}
