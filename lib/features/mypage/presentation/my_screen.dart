import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/domain/assets/open_pass_state.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/app_shortcut_row.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/grade_model.dart';
import '../../pass/application/pass_provider.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../subscription/application/subscription_provider.dart';
import '../../community/presentation/community_hub_screen.dart';
import '../../pass/domain/pass_model.dart';
import '../../pass/presentation/pass_gate_helper.dart';
import '../../pass/presentation/pass_time_format.dart';
import '../../../core/widgets/luck_pouch_toast.dart';

/// [9단계 - 마이 탭 정리] MyScreen - 마이 탭
/// 프로필+등급뱃지 + [열림패스/복주머니/구독 요약(3축 정책 한눈에 보기)]
/// + 아카이브(사주/타로/관상/손금/궁합 히스토리) + 커뮤니티(내 글·소원) + 설정
///
/// [서브 디자인 통일 확산 프롬프트] §5 마이 탭 확산 규칙 적용. 기존 다크
/// "우주(Cosmic)" 톤(CosmicCard/AppColors.bgPrimary 등)을 홈 화면과 동일한
/// 화이트+라벤더 팔레트로 전면 전환한다. 화면 구조/섹션 순서는 그대로 유지.
///
/// [주의] AuthProvider/GradeModel/UserModel/PassProvider/WalletProvider/
/// SubscriptionProvider는 기존 것을 그대로 재사용하며, 아카이브·설정 메뉴는
/// 모두 기존 app_router.dart에 등록된 라우트로 이동한다.
class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  @override
  void initState() {
    super.initState();
    // [9단계] 마이 탭 진입 시 열림패스/복주머니/구독 요약을 최신화한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PassProvider>().load();
      context.read<PassProvider>().loadPurchaseOptions();
      context.read<WalletProvider>().load();
      context.read<SubscriptionProvider>().loadMySubscription();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final pass = context.watch<PassProvider>();
    final wallet = context.watch<WalletProvider>();
    final subscription = context.watch<SubscriptionProvider>();

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('마이', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(UnifiedTokens.screenPadding),
          children: [
            // §1 프로필 카드
            PremiumCard(
              backgroundColor: UnifiedColors.cardSection,
              borderColor: Colors.transparent,
              showShadow: false,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
              padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
              child: Row(
                children: [
                  Container(
                    width: UnifiedTokens.iconCircleLg + 24,
                    height: UnifiedTokens.iconCircleLg + 24,
                    decoration: const BoxDecoration(
                      color: UnifiedColors.cardAllMenu,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: UnifiedColors.textPrimary,
                      size: UnifiedTokens.iconXl,
                    ),
                  ),
                  const SizedBox(width: UnifiedTokens.spaceLg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user?.nickname ?? '게스트',
                                style: UnifiedText.title(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (auth.currentGrade != null) ...[
                              const SizedBox(width: UnifiedTokens.spaceSm),
                              _GradeBadge(grade: auth.currentGrade!),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '로그인이 필요합니다',
                          style: UnifiedText.caption(),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      color: UnifiedColors.textCaption,
                      size: UnifiedTokens.iconLg,
                    ),
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed('/signup/profile-check'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            // [9단계] §1.5 열림패스/복주머니/구독 요약 - 3축 정책을 한 화면에서
            // 확인할 수 있도록 마이 탭에 요약 카드 3개를 배치한다.
            const _SectionTitle(title: '내 혜택 요약'),
            const SizedBox(height: UnifiedTokens.spaceMd),
            _PassSummaryCard(
              pass: pass,
              isLoading: pass.isLoading,
              onAcquireTap: () =>
                  showPassRequiredSheet(context, categoryTitle: '마이페이지'),
              onPurchaseTap: () => _showPurchaseWithLuckPouchSheet(context),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            _WalletSummaryCard(
              balance: wallet.balance,
              isLoading: wallet.isLoading,
              onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
              onChargeTap: () =>
                  Navigator.of(context).pushNamed('/reward/wallet'),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            _SubscriptionSummaryCard(
              subscription: subscription,
              isLoading: subscription.isLoadingSubscription,
              onTap: () => Navigator.of(context).pushNamed('/my/subscription'),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            // §2 아카이브 섹션
            const _SectionTitle(title: '나의 운세 아카이브'),
            const SizedBox(height: UnifiedTokens.spaceMd),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: UnifiedTokens.spaceMd,
              crossAxisSpacing: UnifiedTokens.spaceMd,
              childAspectRatio: 2.2,
              children: [
                _ArchiveCard(
                  icon: Icons.auto_stories_outlined,
                  label: '사주 히스토리',
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/saju/history'),
                ),
                _ArchiveCard(
                  icon: Icons.style_outlined,
                  label: '타로 히스토리',
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/tarot/history'),
                ),
                _ArchiveCard(
                  icon: Icons.face_outlined,
                  label: '관상 히스토리',
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/face/history'),
                ),
                _ArchiveCard(
                  icon: Icons.back_hand_outlined,
                  label: '손금 히스토리',
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/palm/history'),
                ),
                // [오늘의 운세 표준 플로우 §6] 저장한 운세 카드 기록 진입점
                _ArchiveCard(
                  icon: Icons.bookmark_outline_rounded,
                  label: '내 운세 기록',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/my/fortune-records'),
                ),
              ],
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            // [9단계] §2.5 커뮤니티(내 글·내 소원) - 전용 "내 글 목록" API는
            // 아직 백엔드에 없으므로(mock 상태), 커뮤니티 허브로 진입시켜
            // 소원/게시판에서 직접 확인하도록 연결한다. 다음 턴에 "내 활동만
            // 필터링하는" 전용 API/화면으로 고도화할 수 있다.
            const _SectionTitle(title: '나의 커뮤니티'),
            const SizedBox(height: UnifiedTokens.spaceMd),
            _MenuTile(
              icon: Icons.forum_outlined,
              title: '내 글 · 내 소원 보러가기',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CommunityHubScreen()),
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            // §3 설정 섹션
            const _SectionTitle(title: '설정'),
            const SizedBox(height: UnifiedTokens.spaceMd),
            PremiumCard(
              backgroundColor: UnifiedColors.bg,
              borderColor: UnifiedColors.border,
              showShadow: false,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _MenuRow(
                    icon: Icons.workspace_premium_outlined,
                    title: '프리미엄 구독',
                    onTap: () =>
                        Navigator.of(context).pushNamed('/my/subscription'),
                  ),
                  _MenuRow(
                    icon: Icons.notifications_none_rounded,
                    title: '알림',
                    onTap: () =>
                        Navigator.of(context).pushNamed('/my/notifications'),
                  ),
                  _MenuRow(
                    icon: Icons.settings_outlined,
                    title: '설정',
                    onTap: () =>
                        Navigator.of(context).pushNamed('/my/settings'),
                  ),
                  _MenuRow(
                    icon: Icons.info_outline_rounded,
                    title: '앱 정보',
                    onTap: () {},
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),
            OutlinedButton(
              onPressed: () async {
                // [로그아웃 시 프리패스 서버측 강제 만료] 반드시 인증 토큰이
                // 살아있는 동안(= AuthProvider.logout()으로 토큰을 지우기 전에)
                // PassProvider.resetOnLogout()을 먼저 호출해야 한다. 이 메서드는
                // 서버 UserPass를 revoked 처리한 뒤 화면 상태도 초기화한다.
                // 순서를 바꾸면 userId를 얻을 수 없어 서버측 만료가 누락되고,
                // 재로그인 시 프리패스 잔여시간이 그대로 복원되는 문제가 재발한다.
                await context.read<PassProvider>().resetOnLogout();
                if (context.mounted) {
                  await context.read<AuthProvider>().logout();
                }
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: UnifiedColors.textSecondary,
                side: const BorderSide(color: UnifiedColors.border),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                ),
              ),
              child: Text('로그아웃', style: UnifiedText.bodyStrong()),
            ),
            // [열림패스/복주머니/복주머니 통합정책 §5/§7] "열림패스 테스트 모드
            // 구현: 강제 ON/OFF, 만료 상태 테스트, 남은 시간 표시 테스트"에
            // 대응하는 QA 전용 패널. 실 사용자에게는 노출되지 않도록
            // kDebugMode로 가드한다(릴리즈 빌드에서는 완전히 제거됨).
            if (kDebugMode) ...[
              const SizedBox(height: UnifiedTokens.spaceXxl),
              const _SectionTitle(title: '개발자 테스트'),
              const SizedBox(height: UnifiedTokens.spaceMd),
              const _OpenPassTestPanel(),
            ],
          ],
        ),
      ),
    );
  }
}

/// [9단계] §1.5 열림패스 요약 카드 - 활성 여부와 남은 시간을 한눈에 보여준다.
/// [서브 디자인 통일 확산 프롬프트] §5 "열림패스 요약은 잔여 시간만 담백하게".
class _PassSummaryCard extends StatelessWidget {
  const _PassSummaryCard({
    required this.pass,
    required this.isLoading,
    required this.onAcquireTap,
    required this.onPurchaseTap,
  });

  final PassProvider pass;
  final bool isLoading;
  final VoidCallback onAcquireTap;
  final VoidCallback onPurchaseTap;

  // [프리패스 단순화 - 쿠팡파트너스 전용] §6 — HH:MM:SS 형식으로 통일.
  String _formatRemaining(int sec) => formatPassHms(Duration(seconds: sec));

  String _formatExpiry(DateTime dt) {
    return '${dt.month}월 ${dt.day}일 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // [재잠금 정확도] pass.status(서버 스냅샷) 대신 OpenPassState.fromModel의
    // 실시간 계산값을 사용해 만료 시점 이후 즉시 잠금 상태로 반영된다.
    final liveState = OpenPassState.fromModel(pass.status);
    final status = pass.status;
    final isActive = liveState.isActive;
    final remainingSec = liveState.remaining.inSeconds;
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShortcutRow(
            emoji: '🔔',
            accentColor: UnifiedColors.textPrimary,
            icon: Icons.lock_clock_outlined,
            iconColor: UnifiedColors.textPrimary,
            circleColor: UnifiedColors.bg,
            circleSize: UnifiedTokens.iconCircleLg,
            spacing: UnifiedTokens.spaceMd,
            titleStyle: UnifiedText.bodyStrong(),
            subtitleStyle: UnifiedText.caption(),
            arrowColor: UnifiedColors.textCaption,
            arrowSize: UnifiedTokens.iconMd,
            title: '프리패스',
            subtitle: isLoading
                ? '불러오는 중...'
                : isActive
                ? '남은 시간 ${_formatRemaining(remainingSec)}'
                : '보유한 프리패스가 없어요',
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onAcquireTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: UnifiedColors.textPrimary,
                    side: const BorderSide(color: UnifiedColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        UnifiedTokens.radiusPill,
                      ),
                    ),
                  ),
                  child: const Text('획득방법 · 광고로 열기'),
                ),
              ),
              const SizedBox(width: UnifiedTokens.spaceSm),
              Expanded(
                child: OutlinedButton(
                  onPressed: onPurchaseTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: UnifiedColors.textPrimary,
                    side: const BorderSide(color: UnifiedColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        UnifiedTokens.radiusPill,
                      ),
                    ),
                  ),
                  child: const Text('복주머니로 구매'),
                ),
              ),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Text(
            isActive && status.expiresAt != null
                ? '만료 예정: ${_formatExpiry(status.expiresAt!)}'
                : '프리패스는 시간제 이용권이에요. 만료 후에는 다시 발급받아야 해요.',
            style: UnifiedText.caption(),
          ),
        ],
      ),
    );
  }
}

/// [9단계] §1.5 복주머니 요약 카드 - 현재 잔액을 한눈에 보여준다.
/// [서브 디자인 통일 확산 프롬프트] §5 "복주머니 요약은 잔액 + 짧은 안내".
class _WalletSummaryCard extends StatelessWidget {
  const _WalletSummaryCard({
    required this.balance,
    required this.isLoading,
    required this.onTap,
    required this.onChargeTap,
  });

  final int balance;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onChargeTap;

  String _formatBalance(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShortcutRow(
            emoji: '🍀',
            accentColor: UnifiedColors.textPrimary,
            icon: Icons.eco_outlined,
            iconColor: UnifiedColors.textPrimary,
            circleColor: UnifiedColors.bg,
            circleSize: UnifiedTokens.iconCircleLg,
            spacing: UnifiedTokens.spaceMd,
            titleStyle: UnifiedText.bodyStrong(),
            subtitleStyle: UnifiedText.caption(),
            arrowColor: UnifiedColors.textCaption,
            arrowSize: UnifiedTokens.iconMd,
            title: '복주머니',
            subtitle: isLoading
                ? '불러오는 중...'
                : '${_formatBalance(balance)}개 보유 중',
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onChargeTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: UnifiedColors.textPrimary,
                    side: const BorderSide(color: UnifiedColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        UnifiedTokens.radiusPill,
                      ),
                    ),
                  ),
                  child: const Text('충전'),
                ),
              ),
              const SizedBox(width: UnifiedTokens.spaceSm),
              Expanded(
                child: OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: UnifiedColors.textPrimary,
                    side: const BorderSide(color: UnifiedColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        UnifiedTokens.radiusPill,
                      ),
                    ),
                  ),
                  child: const Text('내역'),
                ),
              ),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Text(
            '출석, 커뮤니티 활동, 운세 이용 등으로 모을 수 있어요.',
            style: UnifiedText.caption(),
          ),
        ],
      ),
    );
  }
}

/// [재화 구조 정리] "복주머니로 구매" 바텀시트 — 프리패스 구매 옵션 목록을 보여주고
/// 선택 시 확인 다이얼로그 → 실제 구매 API 호출 → 지갑 갱신 + 토스트까지 처리한다.
void _showPurchaseWithLuckPouchSheet(BuildContext context) {
  final pass = context.read<PassProvider>();
  showModalBottomSheet(
    context: context,
    backgroundColor: UnifiedColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(UnifiedTokens.radiusLg),
      ),
    ),
    builder: (sheetContext) {
      return AnimatedBuilder(
        animation: pass,
        builder: (context, _) {
          final options = pass.purchaseOptions;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('복주머니로 프리패스 구매', style: UnifiedText.bodyStrong()),
                  const SizedBox(height: UnifiedTokens.spaceMd),
                  if (pass.isPurchaseLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: UnifiedTokens.spaceXl,
                      ),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (options.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: UnifiedTokens.spaceXl,
                      ),
                      child: Text(
                        '지금은 구매 가능한 프리패스 옵션이 없어요.',
                        style: UnifiedText.caption(),
                      ),
                    )
                  else
                    ...options.map(
                      (opt) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: UnifiedTokens.spaceSm,
                        ),
                        child: OutlinedButton(
                          onPressed: () =>
                              _confirmAndPurchasePass(context, opt),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: UnifiedColors.textPrimary,
                            side: const BorderSide(color: UnifiedColors.border),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                UnifiedTokens.radiusMd,
                              ),
                            ),
                          ),
                          child: Text(
                            '${opt.name} · 복주머니 ${opt.luckPouchPrice}개',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _confirmAndPurchasePass(
  BuildContext context,
  PassPurchaseOptionModel option,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('프리패스 구매'),
      content: Text('복주머니 ${option.luckPouchPrice}개로 ${option.name}을 구매할까요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('구매'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final pass = context.read<PassProvider>();
  final wallet = context.read<WalletProvider>();
  final ok = await pass.purchaseWithLuckPouch(policyId: option.id);
  if (ok) {
    await wallet.load();
    LuckPouchToastController.instance.showSpend(
      option.luckPouchPrice,
      '${option.name} 구매',
    );
    if (context.mounted) Navigator.of(context).pop();
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pass.lastError ?? '프리패스 구매에 실패했어요.')),
      );
    }
  }
}

/// [9단계] §1.5 구독 요약 카드 - 구독 활성 여부를 한눈에 보여준다.
class _SubscriptionSummaryCard extends StatelessWidget {
  const _SubscriptionSummaryCard({
    required this.subscription,
    required this.isLoading,
    required this.onTap,
  });

  final SubscriptionProvider subscription;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final my = subscription.mySubscription;
    final isActive = subscription.isPremium;
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      onTap: onTap,
      child: AppShortcutRow(
        emoji: '👑',
        accentColor: UnifiedColors.textPrimary,
        icon: Icons.workspace_premium_outlined,
        iconColor: UnifiedColors.textPrimary,
        circleColor: UnifiedColors.bg,
        circleSize: UnifiedTokens.iconCircleLg,
        spacing: UnifiedTokens.spaceMd,
        titleStyle: UnifiedText.bodyStrong(),
        subtitleStyle: UnifiedText.caption(),
        arrowColor: UnifiedColors.textCaption,
        arrowSize: UnifiedTokens.iconMd,
        title: '구독',
        subtitle: isLoading
            ? '불러오는 중...'
            : isActive
            ? '${my?.plan.name ?? '프리미엄'} 구독 중'
            : '구독하고 프리패스·복주머니 혜택 받기',
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: UnifiedText.titleLarge());
  }
}

/// Phase2-1: 04A §A-5 `user_grades` 등급 배지
class _GradeBadge extends StatelessWidget {
  final GradeModel grade;

  const _GradeBadge({required this.grade});

  @override
  Widget build(BuildContext context) {
    // [서브 디자인 통일 확산 프롬프트] §9 컬러 남용 금지 - 등급 색상 구분 대신
    // 블랙 텍스트 + 라벤더 배경 단일 톤으로 통일하고, 강조는 굵기로만 표현한다.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: UnifiedColors.cardAllMenu,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
      ),
      child: Text(grade.name, style: UnifiedText.chipLabel()),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.symmetric(
        horizontal: UnifiedTokens.spaceMd,
        vertical: UnifiedTokens.spaceSm,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: UnifiedTokens.iconCircleMd,
            height: UnifiedTokens.iconCircleMd,
            decoration: const BoxDecoration(
              color: UnifiedColors.bg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: UnifiedTokens.iconMd,
              color: UnifiedColors.textPrimary,
            ),
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          Expanded(
            child: Text(
              label,
              style: UnifiedText.bodyStrong(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: UnifiedColors.textPrimary,
            size: UnifiedTokens.iconLg,
          ),
          const SizedBox(width: UnifiedTokens.spaceMd),
          Expanded(child: Text(title, style: UnifiedText.bodyStrong())),
          Icon(
            Icons.chevron_right_rounded,
            color: UnifiedColors.textCaption,
            size: UnifiedTokens.iconMd,
          ),
        ],
      ),
    );
  }
}

/// [서브 디자인 통일 확산 프롬프트] §5 "리스트 아이템 높이 균일 48~56, 좌측
/// 아이콘 20(iconSize.lg), 우측 화살표 16(iconSize.md) 색상 #9A9AA2,
/// 라벨 BodyStrong14 SemiBold, 하단 구분선 #ECECEF" - 설정 리스트 전용 행.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: UnifiedTokens.spaceLg),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  bottom: BorderSide(color: UnifiedColors.border, width: 1),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: UnifiedColors.textPrimary,
              size: UnifiedTokens.iconLg,
            ),
            const SizedBox(width: UnifiedTokens.spaceMd),
            Expanded(child: Text(title, style: UnifiedText.bodyStrong())),
            Icon(
              Icons.chevron_right_rounded,
              color: UnifiedColors.textCaption,
              size: UnifiedTokens.iconMd,
            ),
          ],
        ),
      ),
    );
  }
}

/// [열림패스/복주머니/복주머니 통합정책 §5/§7] 열림패스 테스트 모드 패널.
/// 실 서버 호출 없이 PassProvider.debugForceState()로 강제 ON/OFF/만료
/// 상태를 만들고, 1초마다 남은 시간을 갱신해 카운트다운을 눈으로 QA할 수
/// 있게 한다. kDebugMode 빌드에서만 마이페이지에 노출된다.
class _OpenPassTestPanel extends StatefulWidget {
  const _OpenPassTestPanel();

  @override
  State<_OpenPassTestPanel> createState() => _OpenPassTestPanelState();
}

class _OpenPassTestPanelState extends State<_OpenPassTestPanel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // 남은 시간 라벨이 실시간으로 줄어드는 것을 QA 화면에서 바로 확인할 수
    // 있도록 1초마다 rebuild한다(PassProvider 자체 상태는 그대로).
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _statusLabel(OpenPassStatus status) => switch (status) {
    OpenPassStatus.inactive => '비활성(inactive)',
    OpenPassStatus.active => '활성(active)',
    OpenPassStatus.expired => '만료(expired)',
  };

  @override
  Widget build(BuildContext context) {
    final pass = context.watch<PassProvider>();
    final state = pass.openPassState;

    return PremiumCard(
      backgroundColor: UnifiedColors.cardSection,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.science_outlined,
                size: UnifiedTokens.iconMd,
                color: UnifiedColors.textSecondary,
              ),
              const SizedBox(width: UnifiedTokens.spaceSm),
              Text('프리패스 테스트 모드', style: UnifiedText.title()),
              if (pass.isDebugOverrideActive) ...[
                const SizedBox(width: UnifiedTokens.spaceSm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UnifiedTokens.spaceSm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: UnifiedColors.neon,
                    borderRadius: BorderRadius.circular(
                      UnifiedTokens.radiusPill,
                    ),
                  ),
                  child: Text(
                    'TEST',
                    style: UnifiedText.caption(
                      color: UnifiedColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Text(
            '상태: ${_statusLabel(state.status)}'
            '${state.remainingLabel != null ? ' · ${state.remainingLabel}' : ''}',
            style: UnifiedText.body(),
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          Wrap(
            spacing: UnifiedTokens.spaceSm,
            runSpacing: UnifiedTokens.spaceSm,
            children: [
              _TestButton(
                label: '강제 ON(60분)',
                onTap: () => pass.debugForceState(
                  OpenPassStatus.active,
                  remaining: const Duration(minutes: 60),
                ),
              ),
              _TestButton(
                label: '강제 ON(2분)',
                onTap: () => pass.debugForceState(
                  OpenPassStatus.active,
                  remaining: const Duration(minutes: 2),
                ),
              ),
              _TestButton(
                label: '강제 OFF',
                onTap: () => pass.debugForceState(OpenPassStatus.inactive),
              ),
              _TestButton(
                label: '강제 만료',
                onTap: () => pass.debugForceState(OpenPassStatus.expired),
              ),
              _TestButton(
                label: '테스트 해제(실서버)',
                onTap: () {
                  pass.clearDebugOverride();
                  pass.load();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: UnifiedColors.textPrimary,
        side: const BorderSide(color: UnifiedColors.border),
        padding: const EdgeInsets.symmetric(
          horizontal: UnifiedTokens.spaceMd,
          vertical: UnifiedTokens.spaceSm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
        ),
      ),
      child: Text(label, style: UnifiedText.caption()),
    );
  }
}
