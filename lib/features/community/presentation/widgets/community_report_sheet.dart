import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/community_post_provider.dart';
import '../../domain/community_post_model.dart' show ReportTargetType;

const _reportReasons = ['스팸/광고', '욕설/비방', '음란물', '거짓정보', '기타'];

/// 06§4.12 `POST /{targetType}/:id/report` 공용 신고 - 04A reports(L-6) 대응
/// wish_report_sheet.dart와 동일한 UI패턴이나 CommunityPostProvider를 사용하도록
/// 분리(Provider 간 결합 방지 - 03§9.2 원칙)
Future<void> showCommunityReportSheet(
  BuildContext context, {
  required ReportTargetType targetType,
  required String targetId,
}) {
  return showAppBottomSheet(
    context,
    title: '신고하기',
    child: _CommunityReportForm(targetType: targetType, targetId: targetId),
  );
}

class _CommunityReportForm extends StatefulWidget {
  final ReportTargetType targetType;
  final String targetId;
  const _CommunityReportForm({
    required this.targetType,
    required this.targetId,
  });

  @override
  State<_CommunityReportForm> createState() => _CommunityReportFormState();
}

class _CommunityReportFormState extends State<_CommunityReportForm> {
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
    final ok = await context.read<CommunityPostProvider>().report(
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
