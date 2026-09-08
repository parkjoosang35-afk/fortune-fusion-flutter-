import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../application/wallet_provider.dart';
import '../domain/point_history_model.dart';
import '../../fortune_ad/application/fortune_ad_provider.dart';
import '../../fortune_ad/domain/fortune_ad_model.dart';
import '../../fortune_ad/presentation/fortune_ad_watch_dialog.dart';

/// [복주머니 화면 재구성] `WalletScreen`(/reward/wallet)과 하단바 "복주머니" 탭
/// (`LuckyBagScreen`)이 동일한 콘텐츠(잔액 + 무료 충전 카드들 + 적립/사용 내역)를
/// 공유하도록 분리한 공용 위젯. 두 화면 모두 `WalletProvider`/`FortuneAdProvider`가
/// 이미 로드되어 있다고 가정하고(각 화면 initState에서 `.load()` 호출), 여기서는
/// 순수 렌더링만 담당한다.
///
/// [무료 충전 카드 다중화] 기존에는 `FortuneAdProvider.primaryAd`(첫 번째 광고 1개)만
/// 노출했지만, 관리자가 광고를 여러 개 등록하면 그 수만큼 카드가 계속 늘어나도록
/// `ads`(전체 목록)를 순회해 카드를 렌더링한다.
class WalletContent extends StatelessWidget {
  const WalletContent({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final adProvider = context.watch<FortuneAdProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BalanceCard(balance: wallet.balance, isLoading: wallet.isLoading),
        const SizedBox(height: UnifiedTokens.spaceXl),
        // 관리자가 등록한 광고 수만큼 "복주머니 무료 충전" 카드가 늘어난다.
        for (final ad in adProvider.ads) ...[
          _FortuneAdCard(ad: ad),
          const SizedBox(height: UnifiedTokens.spaceMd),
        ],
        if (adProvider.ads.isNotEmpty)
          const SizedBox(height: UnifiedTokens.spaceSm),
        _CollapsibleHistorySection(history: wallet.history),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.isLoading});
  final int balance;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          isLoading
              ? const SizedBox(
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('${_comma(balance)}개', style: UnifiedText.titleLarge()),
        ],
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

/// "🧧 복주머니 무료 충전" 카드 1개(광고 1건에 대응). 관리자가 광고를 여러 개
/// 등록하면 이 카드가 [WalletContent]에서 그만큼 반복 렌더링된다.
class _FortuneAdCard extends StatelessWidget {
  const _FortuneAdCard({required this.ad});
  final FortuneAdModel ad;

  @override
  Widget build(BuildContext context) {
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
                Text(
                  ad.title.isNotEmpty ? ad.title : '복주머니 무료 충전',
                  style: UnifiedText.bodyStrong(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
            onPressed: ad.watchable ? () => _watchAd(context, ad) : null,
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
        // 서버가 확정한 최신 잔액을 반영(클라이언트는 직접 적립하지 않고
        // 서버 결과만 재조회한다).
        await context.read<WalletProvider>().load();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('복주머니가 열렸습니다! +${result.grantedAmount}개')),
          );
        }
        break;
      case FortuneAdWatchOutcome.cancelled:
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

/// [사용자 요청] "적립/사용 내용은 작은 바 하나 놓고 누르면 펼쳐지게" —
/// 기본은 접힌 작은 바 형태이고, 탭하면 전체 내역이 펼쳐지는 아코디언 섹션.
class _CollapsibleHistorySection extends StatefulWidget {
  const _CollapsibleHistorySection({required this.history});
  final List<PointHistoryModel> history;

  @override
  State<_CollapsibleHistorySection> createState() =>
      _CollapsibleHistorySectionState();
}

class _CollapsibleHistorySectionState
    extends State<_CollapsibleHistorySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: UnifiedTokens.spaceLg,
              vertical: UnifiedTokens.spaceMd,
            ),
            decoration: BoxDecoration(
              color: UnifiedColors.cardSection,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: UnifiedTokens.iconMd,
                  color: UnifiedColors.textSecondary,
                ),
                const SizedBox(width: UnifiedTokens.spaceSm),
                Expanded(
                  child: Text('적립/사용 내역', style: UnifiedText.bodyStrong()),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: UnifiedColors.textCaption,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: !_expanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: UnifiedTokens.spaceMd),
                  child: widget.history.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: '아직 복주머니 내역이 없어요',
                        )
                      : Column(
                          children: widget.history
                              .map((e) => _HistoryTile(item: e))
                              .toList(),
                        ),
                ),
        ),
      ],
    );
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
