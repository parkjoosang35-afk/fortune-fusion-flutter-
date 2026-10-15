import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/theme/dark_page_theme.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/router/app_navigator_key.dart';
import '../application/bokju_coupon_provider.dart';
import '../domain/pending_bokju_coupon.dart';
import 'bokju_coupon_success_screen.dart';

/// [비로그인 진입 복귀] 로그인/회원가입 완료 직후 호출한다(귀인지도
/// `replayPendingGuinjiJoin()`과 동일한 타이밍 전략 — `login_screen.dart`/
/// `signup_screen.dart`의 성공 분기에서 호출). 저장된 토큰이 없으면 아무
/// 동작도 하지 않는다.
void replayPendingBokjuCoupon() {
  final token = PendingBokjuCouponStore.consume();
  if (token == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final navState = appNavigatorKey.currentState;
    if (navState == null) return;
    navState.push(
      MaterialPageRoute(
        builder: (_) => BokjuCouponResolveScreen(token: token),
      ),
    );
  });
}

/// [복주머니 마케팅 쿠폰] QR 스캔/딥링크로 받은 `token`을 미리보기(resolve)
/// 조회하고, "등록하기" 버튼으로 실제 적립(redeem)까지 진행하는 단일 화면.
///
/// [진입 경로] 3가지 모두 이 화면으로 귀결된다:
///   1) 딥링크(`fortunefusion://coupon/{token}` / `https://sintong.kr/coupon/{token}`)
///      — [GuinjiDeepLinkHandler]가 수신해 이 화면으로 push.
///   2) named route `/coupon/{token}` — 웹 URL로 직접 진입(App Router
///      '/g/', '/r/', '/w/'와 동일한 와일드카드 선매칭 패턴).
///   3) 카메라 QR 스캔([BokjuCouponScanScreen]) 또는 수동 코드 입력
///      ([BokjuCouponEntryScreen]) — 모두 token을 얻은 �이 이 화면을 push.
///
/// [비로그인 처리] 서버 `resolve`/`redeem` 모두 로그인을 강제한다. 토큰을
/// 들고 왔지만 비로그인 상태면 [PendingBokjuCouponStore]에 토큰을 저장해두고
/// 로그인 화면으로 보낸 뒤, 로그인 완료 후 [replayPendingBokjuCoupon]이 이
/// 화면으로 자동 복귀시킨다(귀인지도 `PendingGuinjiJoinStore`와 동일한
/// 패턴).
class BokjuCouponResolveScreen extends StatefulWidget {
  const BokjuCouponResolveScreen({super.key, required this.token});

  final String token;

  @override
  State<BokjuCouponResolveScreen> createState() =>
      _BokjuCouponResolveScreenState();
}

class _BokjuCouponResolveScreenState extends State<BokjuCouponResolveScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!await AuthTokenStore.isLoggedIn()) {
        if (!mounted) return;
        PendingBokjuCouponStore.save(widget.token);
        Navigator.of(context).pushNamed('/login');
        return;
      }
      if (!mounted) return;
      context.read<BokjuCouponProvider>().loadPreview(widget.token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BokjuCouponProvider>();

    return DarkPage(
      child: Scaffold(
        backgroundColor: UnifiedColors.bg,
        appBar: AppBar(title: const Text('복주머니 쿠폰')),
        body: SafeArea(child: _buildBody(context, provider)),
      ),
    );
  }

  Widget _buildBody(BuildContext context, BokjuCouponProvider provider) {
    switch (provider.status) {
      case BokjuCouponFlowStatus.idle:
      case BokjuCouponFlowStatus.resolving:
        return const Center(child: CircularProgressIndicator());

      case BokjuCouponFlowStatus.error:
        return _ErrorView(
          message: provider.errorMessage ?? '쿠폰을 조회하지 못했습니다.',
          onRetry: () =>
              context.read<BokjuCouponProvider>().loadPreview(widget.token),
        );

      case BokjuCouponFlowStatus.previewReady:
      case BokjuCouponFlowStatus.redeeming:
        final preview = provider.preview;
        if (preview == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Padding(
          padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
                decoration: BoxDecoration(
                  color: UnifiedColors.cardMain,
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preview.campaignTitle, style: UnifiedText.titleLarge()),
                    const SizedBox(height: UnifiedTokens.spaceSm),
                    Text(
                      '복주머니 ${preview.grantAmount}개 지급',
                      style: UnifiedText.bodyStrong(color: UnifiedColors.black),
                    ),
                    if (preview.guideText != null &&
                        preview.guideText!.isNotEmpty) ...[
                      const SizedBox(height: UnifiedTokens.spaceMd),
                      Text(preview.guideText!, style: UnifiedText.body()),
                    ],
                    const SizedBox(height: UnifiedTokens.spaceMd),
                    Text(
                      '사용 기한: ${_formatDate(preview.validTo)}까지',
                      style: UnifiedText.caption(),
                    ),
                  ],
                ),
              ),
              if (!preview.redeemable) ...[
                const SizedBox(height: UnifiedTokens.spaceLg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(UnifiedTokens.spaceMd),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(UnifiedTokens.radiusMd),
                  ),
                  child: Text(
                    preview.reasonIfNot ?? '지금은 등록할 수 없는 쿠폰입니다.',
                    style: UnifiedText.body(color: Colors.redAccent),
                  ),
                ),
              ],
              const Spacer(),
              if (provider.status == BokjuCouponFlowStatus.redeeming) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: UnifiedTokens.spaceLg),
              ],
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: preview.redeemable
                        ? UnifiedColors.black
                        : UnifiedColors.chipInactiveBg,
                    foregroundColor: preview.redeemable
                        ? Colors.black
                        : UnifiedColors.textCaption,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(UnifiedTokens.radiusPill),
                    ),
                  ),
                  onPressed: preview.redeemable &&
                          provider.status != BokjuCouponFlowStatus.redeeming
                      ? () => _handleRedeem(context)
                      : null,
                  child: const Text(
                    '등록하기',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );

      case BokjuCouponFlowStatus.success:
        final result = provider.result;
        if (result == null) {
          return const Center(child: CircularProgressIndicator());
        }
        // success 상태 진입 즉시 성공 화면으로 교체(이 화면을 스택에서 제거).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => BokjuCouponSuccessScreen(result: result),
            ),
          );
        });
        return const Center(child: CircularProgressIndicator());
    }
  }

  Future<void> _handleRedeem(BuildContext context) async {
    final provider = context.read<BokjuCouponProvider>();
    final ok = await provider.redeem();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? '쿠폰 등록에 실패했습니다.')),
      );
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: UnifiedTokens.spaceLg),
            Text(message, style: UnifiedText.body(), textAlign: TextAlign.center),
            const SizedBox(height: UnifiedTokens.spaceLg),
            ElevatedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
