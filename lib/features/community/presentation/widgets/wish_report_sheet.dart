import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/wish_post_provider.dart';
import '../../domain/wish_post_model.dart';

const _reportReasons = ['스팸/광고', '욕설/비방', '음란물', '거짓정보', '기타'];

/// 06§4.12 `POST /{targetType}/:id/report` 공용 신고 - 04A reports(L-6) 대응
/// (03§9.1 공통 BottomSheet 헬퍼 재사용, 신규 원자단위 추가 없이 Chip+TextField 조합)
Future<void> showWishReportSheet(
  BuildContext context, {
  required ReportTargetType targetType,
  required String targetId,
}) {
  return showAppBottomSheet(
    context,
    title: '신고하기',
    child: _WishReportForm(targetType: targetType, targetId: targetId),
  );
}

class _WishReportForm extends StatefulWidget {
  final ReportTargetType targetType;
  final String targetId;
  const _WishReportForm({required this.targetType, required this.targetId});

  @override
  State<_WishReportForm> createState() => _WishReportFormState();
}

class _WishReportFormState extends State<_WishReportForm> {
  String? _selectedReason;
  final _detailController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) {
      AppToast.show(context, '신고 사유를 선택해 주세요.', isError: true);
      return;
    }
    setState(() => _isSubmitting = true);
    final reason = _detailController.text.trim().isEmpty
        ? _selectedReason!
        : '$_selectedReason: ${_detailController.text.trim()}';
    final ok = await context.read<WishPostProvider>().report(
      widget.targetType,
      widget.targetId,
      reason,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).pop();
    AppToast.show(
      context,
      ok ? '신고가 접수되었습니다.' : '신고 접수에 실패했습니다.',
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: UnifiedTokens.spaceSm,
          runSpacing: UnifiedTokens.spaceSm,
          children: _reportReasons.map((reason) {
            final selected = _selectedReason == reason;
            return ChoiceChip(
              label: Text(reason, style: UnifiedText.chipLabel()),
              selected: selected,
              onSelected: (_) => setState(() => _selectedReason = reason),
              backgroundColor: UnifiedColors.chipInactiveBg,
              selectedColor: UnifiedColors.cardAllMenu,
              side: BorderSide.none,
            );
          }).toList(),
        ),
        const SizedBox(height: UnifiedTokens.spaceMd),
        TextField(
          controller: _detailController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '상세 사유(선택)를 입력해 주세요'),
        ),
        const SizedBox(height: UnifiedTokens.spaceXl),
        AppButton(
          label: '신고 제출',
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }
}
