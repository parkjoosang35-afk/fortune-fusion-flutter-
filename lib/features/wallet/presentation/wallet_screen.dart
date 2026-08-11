import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../application/wallet_provider.dart';
import '../domain/point_history_model.dart';
import '../../fortune_ad/application/fortune_ad_provider.dart';
import '../../fortune_ad/domain/fortune_ad_model.dart';
import '../../fortune_ad/presentation/fortune_ad_watch_dialog.dart';

/// 03단계 §3.3 리워드 탭 - WalletScreen(복주머니 잔액/적립·차감 내역)
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().load();
      // [신통방통 복주머니 광고 적립 시스템] 지갑 화면 진입 시 노출 가능한
      // 광고 목록을 함께 로드한다(관리자 OFF/기간종료 시 목록이 비어와
      // 카드 자체가 자동으로 숨겨진다 — 재배포 없이 즉시 반영).
      context.read<FortuneAdProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(title: const Text('복주머니 지갑')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<WalletProvider>().load(),
          child: ListView(
            padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
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
                    Text('보유 복주머니', style: UnifiedText.caption()),
                    const SizedBox(height: UnifiedTokens.spaceSm),
                    wallet.isLoading
                        ? const SizedBox(
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            '${_comma(wallet.balance)}개',
                            style: UnifiedText.titleLarge(),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: UnifiedTokens.spaceXl),
              const _FortuneAdEarnCard(),
              const SizedBox(height: UnifiedTokens.spaceXxl),
              Text('적립/사용 내역', style: UnifiedText.title()),
              const SizedBox(height: UnifiedTokens.spaceMd),
              if (wallet.history.isEmpty)
                const AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: '아직 복주머니 내역이 없어요',
                )
              else
                ...wallet.history.map((e) => _HistoryTile(item: e)),
            ],
          ),
        ),
      ),
    );
  }

  String _comma(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

class _HistoryTile extends StatelessWidget {
  final PointHistoryModel item;
  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isEarn = item.type == PointHistoryType.earn;
    return Padding(
      padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceMd),
      child: Container(
        padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
        decoration: BoxDecoration(
          color: UnifiedColors.cardSection,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(UnifiedTokens.spaceSm),
              decoration: const BoxDecoration(
                color: UnifiedColors.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEarn ? Icons.add_rounded : Icons.remove_rounded,
                size: UnifiedTokens.iconMd,
                color: UnifiedColors.textSecondary,
              ),
            ),
            const SizedBox(width: UnifiedTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.reason, style: UnifiedText.bodyStrong()),
                  Text(
                    '${item.createdAt.month}.${item.createdAt.day} ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                    style: UnifiedText.bodySmall(),
                  ),
                ],
              ),
            ),
            Text(
              '${isEarn ? '+' : '-'}${item.amount}개',
              style: UnifiedText.bodyStrong(),
            ),
          ],
        ),
      ),
    );
  }
}

/// [신통방통 복주머니 광고 적립 시스템] "🧧 복주머니 무료 충전" 카드.
/// 관리자가 노출 중인 광고가 하나도 없으면(OFF/기간종료/미등록) 자동으로
/// 숨겨진다(재배포 없이 관리자 설정이 즉시 반영되는 구조 — FortuneAdProvider가
/// 빈 목록을 그대로 노출하지 않는 것과 동일한 원리로 위젯 자체를 렌더링하지 않음).
class _FortuneAdEarnCard extends StatelessWidget {
  const _FortuneAdEarnCard();

  @override
  Widget build(BuildContext context) {
    final adProvider = context.watch<FortuneAdProvider>();
    final ad = adProvider.primaryAd;

    if (adProvider.isLoading && ad == null) {
      return const SizedBox.shrink();
    }
    if (ad == null) {
      // 노출 가능한 광고가 없음(관리자 OFF/기간종료/미등록) — 카드 자체를 숨긴다.
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      decoration: BoxDecoration(
        color: UnifiedColors.cardBanner,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: UnifiedColors.bg,
              shape: BoxShape.circle,
            ),
            child: const Text('🧧', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: UnifiedTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('복주머니 무료 충전', style: UnifiedText.bodyStrong()),
                const SizedBox(height: 2),
                Text(
                  '오늘 ${ad.todayWatchedCount}/${ad.perUserDailyLimit}회',
                  style: UnifiedText.caption(),
                ),
              ],
            ),
          ),
          const SizedBox(width: UnifiedTokens.spaceMd),
          ElevatedButton(
            onPressed: ad.watchable
                ? () => _watchAd(context, ad)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: ad.watchable
                  ? UnifiedColors.black
                  : UnifiedColors.chipInactiveBg,
              foregroundColor: ad.watchable
                  ? Colors.white
                  : UnifiedColors.textCaption,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              elevation: 0,
            ),
            child: Text(
              ad.watchable ? '광고 보고 +${ad.rewardAmount}개' : '오늘 완료',
              style: UnifiedText.chipLabel(
                color: ad.watchable ? Colors.white : UnifiedColors.textCaption,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _watchAd(BuildContext context, FortuneAdModel ad) async {
    final result = await FortuneAdWatchDialog.show(context, ad: ad);
    if (!context.mounted) return;

    switch (result.outcome) {
      case FortuneAdWatchOutcome.granted:
        // 서버가 확정한 최신 잔액을 반영(luckybag 애니메이션과 동일한 패턴 —
        // 클라이언트는 wallet.earn()을 직접 호출하지 않고 서버 결과만 재조회한다).
        await context.read<WalletProvider>().load();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('복주머니가 열렸습니다! +${result.grantedAmount}개')),
          );
        }
        break;
      case FortuneAdWatchOutcome.cancelled:
        // 중간 종료 — 보상 없음, 별도 안내 없이 조용히 닫는다.
        break;
      case FortuneAdWatchOutcome.failed:
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.errorMessage ?? '보상 지급에 실패했습니다.')),
          );
        }
        break;
    }
  }
}
