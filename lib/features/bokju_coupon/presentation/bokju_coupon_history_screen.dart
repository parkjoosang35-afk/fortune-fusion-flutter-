import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/theme/dark_page_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../application/bokju_coupon_provider.dart';
import '../domain/bokju_coupon_model.dart';

/// [복주머니 마케팅 쿠폰] "내 쿠폰함" — 지금까지 등록(redeem) 성공한 쿠폰
/// 이력을 보여주는 화면. 지갑 화면의 적립/사용 내역과는 별개로, 쿠폰
/// 출처(캠페인명)까지 함께 보여주는 전용 목록이다.
class BokjuCouponHistoryScreen extends StatefulWidget {
  const BokjuCouponHistoryScreen({super.key});

  @override
  State<BokjuCouponHistoryScreen> createState() =>
      _BokjuCouponHistoryScreenState();
}

class _BokjuCouponHistoryScreenState extends State<BokjuCouponHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BokjuCouponProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BokjuCouponProvider>();

    return DarkPage(
      child: Scaffold(
        backgroundColor: UnifiedColors.bg,
        appBar: AppBar(title: const Text('내 쿠폰함')),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => context.read<BokjuCouponProvider>().loadHistory(),
            child: provider.historyLoading && provider.history.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.history.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          AppEmptyState(
                            icon: Icons.confirmation_number_outlined,
                            title: '등록한 쿠폰이 없어요',
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets.all(UnifiedTokens.spaceXl),
                        itemCount: provider.history.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: UnifiedTokens.spaceMd),
                        itemBuilder: (context, index) =>
                            _HistoryTile(item: provider.history[index]),
                      ),
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});
  final BokjuCouponHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      decoration: BoxDecoration(
        color: UnifiedColors.cardMain,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.campaignTitle ?? '복주머니 쿠폰',
                  style: UnifiedText.bodyStrong(),
                ),
                const SizedBox(height: UnifiedTokens.spaceXs),
                Text(_formatDate(item.redeemedAt), style: UnifiedText.caption()),
              ],
            ),
          ),
          Text(
            '+${item.grantedAmount}개',
            style: UnifiedText.bodyStrong(color: UnifiedColors.black),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
