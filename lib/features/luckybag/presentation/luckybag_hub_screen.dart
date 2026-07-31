import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_button.dart';
import '../../../core/widgets/premium_section_title.dart';
import '../../../core/widgets/premium_graphics.dart';
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
import '../../mission/presentation/mission_screen.dart';
import '../../subscription/presentation/subscription_plans_screen.dart';
import '../../community/presentation/community_hub_screen.dart';
import '../../community/presentation/community_screen.dart';
import '../../matching/presentation/matching_discover_screen.dart';

/// [Fortune Fusion 서브 디자인 통일 마스터 프롬프트] 행복머니 허브 화면 (v2)
///
/// 기준 시안 톤(화이트 배경, 소프트 퍼플 카드, 블랙 CTA, 네온 라임 포인트)으로
/// 자산 화면답게 "밝고 정돈된" 느낌을 준다. 잔액 히어로 카드 → 적립 방법 →
/// 사용처 → 구독 보너스 → 히스토리 순서를 유지하되, 전체 카드/버튼/타이포를
/// 공통 Premium* 위젯으로 통일한다.
///
/// [주의] 실제 기능(WalletProvider, AttendanceProvider, LuckyBagProvider 등)은
/// 기존 Provider/Repository를 그대로 재사용한다. 라우팅 구조도 무변경.
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
      await context.read<WalletProvider>().load();
      if (!mounted) return;
      AppToast.show(context, '출석 완료! +$earned P 지급되었습니다.');
    } else {
      AppToast.show(
        context,
        attendance.lastError ?? '출석 처리에 실패했습니다.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final attendance = context.watch<AttendanceProvider>();
    final luckyBag = context.watch<LuckyBagProvider>();
    final grade = context.watch<AuthProvider>().currentGrade;

    return Scaffold(
      backgroundColor: AppColors.premiumBgMain,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            Text('행복머니', style: AppTypography.heroTitle),
            const SizedBox(height: 4),
            Text('모으고, 나누고, 다시 행운으로 돌아와요', style: AppTypography.bodyMain),
            const SizedBox(height: AppSpacing.lg),

            FadeSlideIn(
              child: _BalanceHero(
                balance: wallet.balance,
                isLoading: wallet.isLoading,
                pendingBags: luckyBag.summary?.pendingCount ?? 0,
                onWalletTap: () =>
                    Navigator.of(context).pushNamed('/reward/wallet'),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            const PremiumSectionTitle(title: '✨ 적립 방법'),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: const Duration(milliseconds: 40),
              child: _ShortcutCard(
                emoji: '📅',
                title: '출석체크',
                subtitle: attendance.checkedToday
                    ? '오늘 출석 완료 · 연속 ${attendance.streak}일'
                    : '연속 ${attendance.streak}일째 · 오늘 출석하기',
                onTap: _handleAttendanceTap,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: _ShortcutCard(
                emoji: '✅',
                title: '미션',
                subtitle: '일일/주간 미션을 완료하고 포인트 받기',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MissionScreen()),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: _ShortcutCard(
                emoji: '✍️',
                title: '커뮤니티 활동',
                subtitle: '소원/게시글 작성 · 댓글 작성 시 행복머니 적립',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CommunityHubScreen()),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            const PremiumSectionTitle(title: '🎁 사용처'),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: const Duration(milliseconds: 160),
              child: _ShortcutCard(
                emoji: '🍀',
                title: '행복머니 열기',
                subtitle: (luckyBag.summary?.pendingCount ?? 0) > 0
                    ? '받을 수 있는 행복머니 ${luckyBag.summary!.pendingCount}개'
                    : '오늘의 행복머니를 열어 행운을 확인해보세요',
                highlight: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LuckyBagShopScreen()),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: _ShortcutCard(
                emoji: '💌',
                title: '소원 응원하기',
                subtitle: '다른 사람의 소원에 행복머니로 응원 보내기',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CommunityScreen()),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: const Duration(milliseconds: 240),
              child: _ShortcutCard(
                emoji: '🧧',
                title: '디지털 부적 만들기',
                subtitle: '나를 지켜주는 디지털 부적을 만들어보세요',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AmuletShopScreen()),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: const Duration(milliseconds: 280),
              child: _ShortcutCard(
                emoji: '💫',
                title: '운명의 동행',
                subtitle: '관심표시(좋아요) 1건당 행복머니 소비',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MatchingDiscoverScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: const Duration(milliseconds: 320),
              child: _ShortcutCard(
                emoji: '💳',
                title: '상품권',
                subtitle: '포인트로 상품권을 교환해보세요',
                onTap: () => Navigator.of(context).pushNamed('/reward/giftcard'),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            const PremiumSectionTitle(title: '👑 구독 보너스'),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: const Duration(milliseconds: 360),
              child: _VipCard(
                grade: grade,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionPlansScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            const PremiumSectionTitle(title: '📜 히스토리'),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: const Duration(milliseconds: 400),
              child: _ShortcutCard(
                emoji: '📖',
                title: '행복머니 개봉 이력',
                subtitle: '지금까지 열어본 행복머니와 받은 보상 확인',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LuckyBagHistoryScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              delay: const Duration(milliseconds: 440),
              child: _ShortcutCard(
                emoji: '🧾',
                title: '포인트 내역',
                subtitle: '적립·사용 전체 내역 확인하기',
                onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// §1 잔액 히어로 카드 - 딥네이비→퍼플 그라디언트(기존 premiumCtaGradient) 위에
/// 골드 톤 잔액 숫자를 크게 강조해 "자산" 느낌을 살린다.
class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.balance,
    required this.isLoading,
    required this.pendingBags,
    required this.onWalletTap,
  });

  final int balance;
  final bool isLoading;
  final int pendingBags;
  final VoidCallback onWalletTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: AppColors.premiumDeepNavy,
      borderColor: AppColors.premiumDeepNavy,
      onTap: onWalletTap,
      child: Stack(
        children: [
          const Positioned(top: -8, right: -4, child: DottedOrbit(size: 90)),
          const Positioned(top: 4, right: 40, child: SparkleDot(size: 12)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🍀', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '내 포인트 잔액',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (pendingBags > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.premiumNeonLime,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '받을 행복머니 $pendingBags개',
                        style: AppTypography.smallLabel.copyWith(
                          color: AppColors.premiumNeonLimeOnColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                isLoading ? '불러오는 중...' : '${_formatBalance(balance)} P',
                style: AppTypography.heroTitle.copyWith(
                  color: Colors.white,
                  fontSize: 30,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(
                    '포인트 지갑 바로가기',
                    style: AppTypography.smallLabel.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ],
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

/// 획득처/사용처/히스토리 공통 바로가기 카드. [highlight]가 true면 연골드
/// 배경으로 살짝 강조한다(예: "행복머니 열기").
class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      backgroundColor: highlight ? AppColors.premiumBgSubtle : AppColors.premiumBgSection,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: highlight
                  ? AppColors.premiumSoftGold.withValues(alpha: 0.22)
                  : AppColors.premiumSoftLavender,
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.cardTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppColors.premiumTextTertiary,
          ),
        ],
      ),
    );
  }
}

/// §4 VIP 등급 카드 - 블랙 CTA 버튼으로 구독 유도.
class _VipCard extends StatelessWidget {
  const _VipCard({required this.grade, required this.onTap});

  final GradeModel? grade;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      gradient: AppColors.premiumGoldGradient,
      borderColor: AppColors.premiumCardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('👑', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      grade != null ? '${grade!.name} 등급' : '등급 정보 없음',
                      style: AppTypography.cardTitle.copyWith(
                        fontSize: 15,
                        color: AppColors.premiumDeepNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      grade != null
                          ? '포인트 적립 ${grade!.pointEarnMultiplier}배 적용 중'
                          : '프리미엄 구독으로 등급을 올려보세요',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.premiumDeepNavy.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumButton.black(
            label: '구독 플랜 보기',
            height: 44,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
