import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/wallet_provider.dart';

/// [Phase22-3 - 커뮤니티 화면 황금률 출구버튼] "복 나누기" 공용 바텀시트.
///
/// 03단계 §9.1 공통 BottomSheet 헬퍼(`app_bottom_sheet.dart`)를 재사용하고,
/// `wish_report_sheet.dart`의 "show*Sheet() + StatefulWidget 폼" 패턴을 그대로
/// 따른다. 소원게시판/부적/궁합 등 여러 화면에서 작성자 닉네임(문자열)만 알고 있는
/// 상태로 호출되므로, 내부에서 [WalletRepository.lookupUserByNickname]으로 먼저
/// 실제 userId를 확인한 뒤에만 [WalletProvider.sendBok]을 호출한다.
///
/// 반환값: 실제로 복 나누기가 성공했으면 true, 취소/실패로 닫혔으면 false.
Future<bool> showSendBokSheet(
  BuildContext context, {
  required String recipientNickname,
}) async {
  final result = await showAppBottomSheet<bool>(
    context,
    title: '복 나누기',
    child: _SendBokForm(recipientNickname: recipientNickname),
  );
  return result ?? false;
}

enum _SendBokStep { lookingUp, ready, lookupFailed }

class _SendBokForm extends StatefulWidget {
  final String recipientNickname;
  const _SendBokForm({required this.recipientNickname});

  @override
  State<_SendBokForm> createState() => _SendBokFormState();
}

class _SendBokFormState extends State<_SendBokForm> {
  final _amountController = TextEditingController();
  _SendBokStep _step = _SendBokStep.lookingUp;
  int? _resolvedUserId;
  String? _lookupError;
  bool _isSubmitting = false;

  static const List<int> _presetAmounts = [10, 30, 50, 100];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _lookup());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    setState(() => _step = _SendBokStep.lookingUp);
    final wallet = context.read<WalletProvider>();
    final resolved = await wallet.lookupUserByNickname(
      widget.recipientNickname,
    );
    if (!mounted) return;
    if (resolved == null) {
      setState(() {
        _step = _SendBokStep.lookupFailed;
        _lookupError = wallet.lastSendError ?? '유저를 찾을 수 없습니다.';
      });
      return;
    }
    setState(() {
      _step = _SendBokStep.ready;
      _resolvedUserId = resolved.userId;
    });
  }

  Future<void> _submit() async {
    final userId = _resolvedUserId;
    if (userId == null) return;
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      AppToast.show(context, '보낼 복 액수를 입력해 주세요.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    final wallet = context.read<WalletProvider>();
    final sent = await wallet.sendBok(
      toUserId: userId,
      amount: amount,
      memo: '복 나누기',
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (sent != null) {
      Navigator.of(context).pop(true);
      AppToast.show(
        context,
        '$amount복을 나눴어요! ${sent.refundAmount}복을 환급받았어요 🍀',
      );
    } else {
      AppToast.show(
        context,
        wallet.lastSendError ?? '복 나누기에 실패했습니다.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _SendBokStep.lookingUp:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        );
      case _SendBokStep.lookupFailed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _lookupError ?? '유저를 찾을 수 없습니다.',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.ghost(
              label: '닫기',
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        );
      case _SendBokStep.ready:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.recipientNickname} 님에게 복을 나눠보세요.\n보내면 일부를 즉시 환급받아요.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: '보낼 복(BOK)',
              controller: _amountController,
              hintText: '숫자만 입력해 주세요',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: _presetAmounts.map((preset) {
                return ChoiceChip(
                  label: Text('$preset복'),
                  selected: _amountController.text.trim() == '$preset',
                  onSelected: (_) =>
                      setState(() => _amountController.text = '$preset'),
                  selectedColor: AppColors.primaryContainer,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: '복 나누기',
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
            ),
          ],
        );
    }
  }
}
