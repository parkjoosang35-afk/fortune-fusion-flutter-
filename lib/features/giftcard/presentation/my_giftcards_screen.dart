import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/giftcard_provider.dart';
import '../domain/giftcard_model.dart';

/// 03단계 §9.2 "내 보관함" 계열(MyAmuletsScreen과 동일 재사용패턴) - MyGiftcardsScreen
/// 06§4.10 `GET /v1/giftcards/orders/my` + `POST /:id/use` 대응 화면.
/// J-3(giftcard_usages) 사용처리: 발급된(issued) 상품권만 "사용 처리" 가능.
class MyGiftcardsScreen extends StatefulWidget {
  const MyGiftcardsScreen({super.key});

  @override
  State<MyGiftcardsScreen> createState() => _MyGiftcardsScreenState();
}

class _MyGiftcardsScreenState extends State<MyGiftcardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GiftcardProvider>().loadMyOrders();
    });
  }

  Future<void> _showCode(GiftcardIssueModel issue) async {
    await showAppInfoDialog(
      context,
      title: issue.product.name,
      message:
          '발급 코드\n${issue.issuedCode ?? '-'}\n\n${issue.isUsed ? "이미 사용된 상품권입니다." : "매장에서 코드를 제시하여 사용하세요."}',
    );
  }

  Future<void> _use(GiftcardIssueModel issue) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '상품권 사용 처리',
      message:
          '${issue.product.name}을(를) 사용 완료로 처리하시겠습니까?\n(실제 매장 사용 후에만 처리하세요)',
      confirmLabel: '사용 완료',
    );
    if (!confirmed || !mounted) return;

    final ok = await context.read<GiftcardProvider>().useIssue(issue.id);
    if (!mounted) return;
    if (ok) {
      AppToast.show(context, '사용 처리가 완료되었습니다.');
    } else {
      final error = context.read<GiftcardProvider>().actionError;
      AppToast.show(context, error ?? '사용 처리에 실패했습니다.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final giftcard = context.watch<GiftcardProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('내 상품권함')),
      body: SafeArea(
        child: giftcard.isMyOrdersLoading && giftcard.myOrders.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : giftcard.myOrders.isEmpty
            ? const AppEmptyState(
                icon: Icons.card_giftcard_outlined,
                title: '보유 중인 상품권이 없어요',
                description: '상점에서 포인트로 상품권을 교환해보세요',
              )
            : RefreshIndicator(
                onRefresh: () => giftcard.loadMyOrders(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: giftcard.myOrders.length,
                  itemBuilder: (context, index) {
                    final issue = giftcard.myOrders[index];
                    return _IssueTile(
                      issue: issue,
                      onTapCode: () => _showCode(issue),
                      onUse: () => _use(issue),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _IssueTile extends StatelessWidget {
  final GiftcardIssueModel issue;
  final VoidCallback onTapCode;
  final VoidCallback onUse;

  const _IssueTile({
    required this.issue,
    required this.onTapCode,
    required this.onUse,
  });

  Color get _statusColor {
    switch (issue.status) {
      case GiftcardIssueStatus.issued:
        return issue.isUsed ? AppColors.textHint : AppColors.success;
      case GiftcardIssueStatus.requested:
        return AppColors.warning;
      case GiftcardIssueStatus.failed:
      case GiftcardIssueStatus.cancelled:
      case GiftcardIssueStatus.expired:
        return AppColors.textHint;
    }
  }

  String get _statusLabel {
    if (issue.status == GiftcardIssueStatus.issued && issue.isUsed) {
      return '사용 완료';
    }
    return issue.status.label;
  }

  bool get _canUse =>
      issue.status == GiftcardIssueStatus.issued && !issue.isUsed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTapCode,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.cardSmall),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    issue.product.imageEmoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issue.product.brand,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                        Text(
                          issue.product.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (_canUse) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: AppButton.secondary(
                    label: '사용 완료 처리',
                    onPressed: onUse,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
