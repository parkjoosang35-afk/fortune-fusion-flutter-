import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_section_title.dart';
import '../../../core/widgets/premium_graphics.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../attendance/application/attendance_provider.dart';
import '../application/luckybag_provider.dart';
import 'luckybag_shop_screen.dart';
import 'luckybag_history_screen.dart';
import '../../mission/presentation/mission_screen.dart';
import '../../community/presentation/community_hub_screen.dart';

/// [Fortune Fusion 서브 디자인 통일 마스터 프롬프트] 복주머니 허브 화면 (v2)
///
/// 기준 시안 톤(화이트 배경, 소프트 퍼플 카드, 블랙 CTA, 네온 라임 복주머니)으로
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
      message: '출석체크를 하고 복주머니를 받으시겠습니까?',
      confirmLabel: '출석하기',
    );
    if (!confirmed || !mounted) return;

    final earned = await attendance.checkIn();
    if (!mounted) return;
    if (earned > 0) {
      await context.read<WalletProvider>().load();
      if (!mounted) return;
      AppToast.show(context, '출석 완료! 복주머니 $earned개 지급되었습니다.');
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

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            UnifiedTokens.screenPadding,
            UnifiedTokens.spaceMd,
            UnifiedTokens.screenPadding,
            UnifiedTokens.spaceXxl,
          ),
          children: [
            Text('복주머니', style: UnifiedText.titleLarge()),
            const SizedBox(height: 4),
            Text('모으고, 나누고, 다시 행운으로 돌아와요', style: UnifiedText.body()),
            const SizedBox(height: UnifiedTokens.spaceLg),

            FadeSlideIn(
              child: _BalanceHero(
                balance: wallet.balance,
                isLoading: wallet.isLoading,
                pendingBags: luckyBag.summary?.pendingCount ?? 0,
                onWalletTap: () =>
                    Navigator.of(context).pushNamed('/reward/wallet'),
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            const PremiumSectionTitle(title: '적립 방법'),
            const SizedBox(height: UnifiedTokens.spaceMd),
            FadeSlideIn(
              delay: const Duration(milliseconds: 40),
              child: _ShortcutCard(
                icon: Icons.calendar_today_outlined,
                title: '출석체크',
                subtitle: attendance.checkedToday
                    ? '오늘 출석 완료 · 연속 ${attendance.streak}일'
                    : '연속 ${attendance.streak}일째 · 오늘 출석하기',
                onTap: _handleAttendanceTap,
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: _ShortcutCard(
                icon: Icons.task_alt_outlined,
                title: '미션',
                subtitle: '일일/주간 미션을 완료하고 복주머니 받기',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MissionScreen()),
                ),
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: _ShortcutCard(
                icon: Icons.edit_outlined,
                title: '커뮤니티 활동',
                subtitle: '소원/게시글 작성 · 댓글 작성 시 복주머니 적립',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CommunityHubScreen()),
                ),
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            const PremiumSectionTitle(title: '사용처'),
            const SizedBox(height: UnifiedTokens.spaceMd),
            FadeSlideIn(
              delay: const Duration(milliseconds: 160),
              child: _ShortcutCard(
                icon: Icons.redeem_outlined,
                title: '복주머니 열기',
                subtitle: (luckyBag.summary?.pendingCount ?? 0) > 0
                    ? '받을 수 있는 복주머니 ${luckyBag.summary!.pendingCount}개'
                    : '오늘의 복주머니를 열어 행운을 확인해보세요',
                highlight: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LuckyBagShopScreen()),
                ),
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: _ShortcutCard(
                icon: Icons.volunteer_activism_outlined,
                title: '신통방통 소원방',
                subtitle: '나만의 소원을 밝히고 복주머니를 모아보세요',
                onTap: () => Navigator.of(context).pushNamed('/wish-room'),
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            const PremiumSectionTitle(title: '히스토리'),
            const SizedBox(height: UnifiedTokens.spaceMd),
            FadeSlideIn(
              delay: const Duration(milliseconds: 400),
              child: _ShortcutCard(
                icon: Icons.history_outlined,
                title: '복주머니 개봉 이력',
                subtitle: '지금까지 열어본 복주머니와 받은 보상 확인',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LuckyBagHistoryScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            FadeSlideIn(
              delay: const Duration(milliseconds: 440),
              child: _ShortcutCard(
                icon: Icons.receipt_long_outlined,
                title: '복주머니 내역',
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

/// §1 잔액 히어로 카드 - 연라벤더 플랫 카드 위에 잔액 숫자를 담백하게 보여준다.
/// [주의] 포인트 컬러(네온)는 원형 CTA에만 사용하므로 여기서는 사용하지 않는다.
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
      backgroundColor: UnifiedColors.cardMain,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      onTap: onWalletTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: UnifiedTokens.iconMd,
                color: UnifiedColors.textSecondary,
              ),
              const SizedBox(width: UnifiedTokens.spaceSm),
              Text('내 복주머니 잔액', style: UnifiedText.caption()),
              const Spacer(),
              if (pendingBags > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UnifiedTokens.spaceSm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: UnifiedColors.black,
                    borderRadius: BorderRadius.circular(
                      UnifiedTokens.radiusPill,
                    ),
                  ),
                  child: Text(
                    '받을 복주머니 $pendingBags개',
                    style: UnifiedText.chipLabel(color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          Text(
            isLoading ? '불러오는 중...' : '${_formatBalance(balance)}개',
            style: UnifiedText.titleLarge(),
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Row(
            children: [
              Text('복주머니 지갑 바로가기', style: UnifiedText.caption()),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: UnifiedTokens.iconSm,
                color: UnifiedColors.textCaption,
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

/// 획득처/사용처/히스토리 공통 바로가기 카드. [highlight]는 판매성 강조를 넣지
/// 않고 동일한 톤을 유지한다(구조만 재사용, 시각적 차이는 두지 않음).
class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Row(
        children: [
          Container(
            width: UnifiedTokens.iconCircleLg,
            height: UnifiedTokens.iconCircleLg,
            decoration: BoxDecoration(
              color: UnifiedColors.bg,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
            ),
            child: Icon(
              icon,
              size: UnifiedTokens.iconLg,
              color: UnifiedColors.textPrimary,
            ),
          ),
          const SizedBox(width: UnifiedTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: UnifiedText.bodyStrong()),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UnifiedText.caption(),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: UnifiedTokens.iconSm,
            color: UnifiedColors.textCaption,
          ),
        ],
      ),
    );
  }
}


