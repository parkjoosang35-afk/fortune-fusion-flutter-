import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/premium_card.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/pass_provider.dart';
import '../domain/pass_model.dart';

/// [6단계 운세 탭 정리] 열림패스 기반 이용 구조 공통화.
///
/// 홈 화면(운세 카테고리 그리드)과 FortuneHubScreen(운세 탭) 양쪽에서 동일하게
/// 사용하는 공통 진입 흐름. "각 카테고리 상세 흐름에 공통 패스 체크를 붙인다 /
/// 중복된 진입 흐름이 있으면 공통화한다"는 요구사항에 따라 단일 함수로 통합한다.
///
/// - [requiresPass]가 false면 게이트체크 없이 즉시 라우팅한다(무료 콘텐츠).
/// - PassProvider.isActive가 이미 true면 서버 재검증 없이 즉시 통과시킨다.
/// - 그 외에는 PassProvider.consume()으로 서버 게이트체크 후, 실패 시(유효한
///   열림패스 없음) 발급 유도 바텀시트를 노출한다.
Future<void> navigateWithPassGate(
  BuildContext context, {
  required String title,
  required String route,
  required bool requiresPass,
}) async {
  if (!requiresPass) {
    Navigator.of(context).pushNamed(route);
    return;
  }

  final pass = context.read<PassProvider>();
  if (pass.isActive) {
    Navigator.of(context).pushNamed(route);
    return;
  }

  final ok = await pass.consume(contentType: 'fortune_category', contentId: title);
  if (!context.mounted) return;

  if (ok) {
    Navigator.of(context).pushNamed(route);
    return;
  }

  await showPassRequiredSheet(context, categoryTitle: title);
}

/// 열림패스 발급 유도 바텀시트 — 광고 시청 / 파트너 방문 / 구독 안내.
/// [6단계] "패스없으면요약만·상세는패스유도" 요구사항의 공통 진입점.
Future<void> showPassRequiredSheet(
  BuildContext context, {
  required String categoryTitle,
}) async {
  final pass = context.read<PassProvider>();
  final actionablePolicies = pass.policies
      .where((p) => p.passType == PassType.ad || p.passType == PassType.partner)
      .toList();

  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: UnifiedColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          UnifiedTokens.spaceXl,
          UnifiedTokens.spaceMd,
          UnifiedTokens.spaceXl,
          UnifiedTokens.spaceXl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 핸들바
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: UnifiedTokens.spaceLg),
                decoration: BoxDecoration(
                  color: UnifiedColors.border,
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                ),
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: UnifiedColors.textPrimary,
                  size: UnifiedTokens.iconLg,
                ),
                const SizedBox(width: UnifiedTokens.spaceSm),
                Text('열림패스가 필요해요', style: UnifiedText.title()),
              ],
            ),
            const SizedBox(height: UnifiedTokens.spaceSm),
            Text(
              '"$categoryTitle" 상세 결과는 열림패스로 열람할 수 있어요.\n광고 시청, 파트너 방문 또는 구독으로 열림패스를 받아보세요.',
              style: UnifiedText.body(),
            ),
            const SizedBox(height: UnifiedTokens.spaceLg),
            ...actionablePolicies.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceMd),
                child: _PassCtaTile(
                  policy: p,
                  onTap: () => Navigator.of(ctx).pop(p.passType.name),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceMd),
              child: _SubscriptionCtaTile(
                onTap: () => Navigator.of(ctx).pop('subscription'),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('나중에 할게요', style: UnifiedText.caption()),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  if (!context.mounted || action == null) return;

  if (action == 'subscription') {
    Navigator.of(context).pushNamed('/my/subscription/plans');
    return;
  }

  final policy = actionablePolicies.firstWhere(
    (p) => p.passType.name == action,
    orElse: () => actionablePolicies.first,
  );
  await _claimFromDialog(context, policy);
}

Future<void> _claimFromDialog(BuildContext context, PassPolicyModel policy) async {
  final pass = context.read<PassProvider>();
  final isAd = policy.passType == PassType.ad;

  final confirmed = await showAppConfirmDialog(
    context,
    title: policy.name,
    message: policy.ctaText ??
        (isAd ? '광고를 시청하고 열림패스를 받으시겠습니까?' : '파트너 페이지를 방문하고 열림패스를 받으시겠습니까?'),
    confirmLabel: isAd ? '시청하기' : '방문하기',
  );
  if (!confirmed || !context.mounted) return;

  if (!isAd && policy.linkUrl != null && policy.linkUrl!.isNotEmpty) {
    final uri = Uri.tryParse(policy.linkUrl!);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  if (!context.mounted) return;

  final ok = isAd
      ? await pass.claimAd(policyId: policy.id)
      : await pass.claimPartner(policyId: policy.id);
  if (!context.mounted) return;

  if (ok) {
    await context.read<WalletProvider>().load();
    if (!context.mounted) return;
    AppToast.show(context, '열림패스가 발급되었습니다! (${policy.durationMin}분)');
  } else {
    AppToast.show(context, pass.lastError ?? '열림패스 발급에 실패했습니다.', isError: true);
  }
}

class _PassCtaTile extends StatelessWidget {
  const _PassCtaTile({required this.policy, required this.onTap});

  final PassPolicyModel policy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAd = policy.passType == PassType.ad;
    return PremiumCard(
      padding: const EdgeInsets.all(UnifiedTokens.spaceMd),
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: UnifiedTokens.iconCircleLg,
            height: UnifiedTokens.iconCircleLg,
            decoration: const BoxDecoration(
              color: UnifiedColors.bg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAd ? Icons.smart_display_outlined : Icons.storefront_outlined,
              color: UnifiedColors.textPrimary,
              size: UnifiedTokens.iconMd,
            ),
          ),
          const SizedBox(width: UnifiedTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(policy.name, style: UnifiedText.bodyStrong()),
                Text(
                  '${policy.durationMin}분'
                  '${policy.bonusPoint > 0 ? ' · +${policy.bonusPoint}P' : ''}',
                  style: UnifiedText.caption(),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: UnifiedTokens.iconMd,
            color: UnifiedColors.textCaption,
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCtaTile extends StatelessWidget {
  const _SubscriptionCtaTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(UnifiedTokens.spaceMd),
      backgroundColor: UnifiedColors.black,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: UnifiedTokens.iconCircleLg,
            height: UnifiedTokens.iconCircleLg,
            decoration: BoxDecoration(
              color: UnifiedColors.neon,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.workspace_premium_outlined,
              color: UnifiedColors.black,
              size: UnifiedTokens.iconMd,
            ),
          ),
          const SizedBox(width: UnifiedTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '구독으로 열림패스 자동 지급',
                  style: UnifiedText.bodyStrong(color: Colors.white),
                ),
                Text(
                  '행복머니 정기 보너스까지 함께 받아보세요',
                  style: UnifiedText.caption(color: const Color(0xFFB8B8B8)),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: UnifiedTokens.iconMd,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}
