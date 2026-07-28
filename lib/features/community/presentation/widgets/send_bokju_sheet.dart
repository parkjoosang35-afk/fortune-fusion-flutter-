import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/wish_castle_config_provider.dart';
import '../../application/wish_post_provider.dart';
import 'wish_growth_dialog.dart';

/// [소원성(Wish Castle) 확장] "복주머니 보내기" 공용 바텀시트.
///
/// `send_bok_sheet.dart`의 "show*Sheet() + StatefulWidget 폼 + ChoiceChip 선택 단위"
/// 패턴을 그대로 재사용하되, 실제 지갑조회(lookup) 단계는 없다(복주머니는 포인트
/// 이동이 없는 상징적 응원 단위라 수신자 지갑을 조회할 필요가 없음 - 03§9.2).
///
/// 성공 시 바텀시트가 닫힌 뒤 [WishGrowthDialog] 또는 [WishLevelUpDialog]를
/// 이어서 재생한다(레벨업 여부로 분기). CMS `animation_enabled`가 false면
/// 연출을 건너뛰고 즉시 토스트만 노출한다(관리자 CMS 설정 즉시반영 원칙).
Future<bool> showSendBokjuSheet(
  BuildContext context, {
  required String wishId,
}) async {
  final config = context.read<WishCastleConfigProvider>();
  final presets = config.bokjuPresetAmounts;

  final amount = await showAppBottomSheet<int>(
    context,
    title: '복주머니 보내기',
    child: _SendBokjuForm(presets: presets),
  );
  if (amount == null || !context.mounted) return false;

  final provider = context.read<WishPostProvider>();
  final result = await provider.sendBokju(wishId, amount);
  if (!context.mounted) return false;

  if (result == null) {
    AppToast.show(context, '복주머니 보내기에 실패했습니다.', isError: true);
    return false;
  }

  if (!config.animationEnabled) {
    AppToast.show(context, '🧧 복주머니 $amount개를 보냈어요');
    return true;
  }

  if (result.leveledUp) {
    await WishLevelUpDialog.show(
      context,
      previousLevel: result.previousLevel,
      newLevel: result.candleLevel,
      bokjuCount: result.bokjuCount,
    );
  } else if (context.mounted) {
    await WishGrowthDialog.show(
      context,
      bokjuAmount: amount,
      candleLevel: result.candleLevel,
      bokjuCount: result.bokjuCount,
    );
  }

  // [소원성(Wish Castle) 확장] AI 응원 메시지 - 연출(다이얼로그)이 끝난 뒤 짧은
  // 응원 문구를 Toast로 이어서 노출한다. "이루어진다"는 확정적 표현은 wish_config
  // ai_cheer_messages 문구 자체에서 이미 배제되어 있다(admin_web에서 관리).
  if (context.mounted) {
    AppToast.show(context, '💬 ${config.randomCheerMessage()}');
  }
  return true;
}

class _SendBokjuForm extends StatefulWidget {
  final List<int> presets;
  const _SendBokjuForm({required this.presets});

  @override
  State<_SendBokjuForm> createState() => _SendBokjuFormState();
}

class _SendBokjuFormState extends State<_SendBokjuForm> {
  int? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.presets.isNotEmpty) _selected = widget.presets.first;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '이 소원에 복주머니를 보내 촛불을 밝혀주세요.\n실제 포인트가 차감되지 않는 상징적인 응원이에요.',
          style: TextStyle(
            color: AppColors.textSecondaryOf(context),
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: widget.presets.map((preset) {
            final selected = _selected == preset;
            return ChoiceChip(
              label: Text('🧧 $preset'),
              selected: selected,
              onSelected: (_) => setState(() => _selected = preset),
              selectedColor: AppColors.secondary.withValues(alpha: 0.22),
              labelStyle: TextStyle(
                color: selected
                    ? AppColors.secondaryDark
                    : AppColors.textSecondaryOf(context),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: _selected == null ? '개수를 선택해 주세요' : '복주머니 $_selected개 보내기',
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
        ),
      ],
    );
  }
}
