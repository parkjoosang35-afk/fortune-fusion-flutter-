import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/luck_pouch_toast.dart';
import '../../../wallet/application/wallet_provider.dart';
import '../../application/wish_castle_config_provider.dart';
import '../../application/wish_post_provider.dart';
import 'wish_growth_dialog.dart';

/// [소원성(Wish Castle) 확장] "복주머니 보내기" 공용 바텀시트.
///
/// [재화 구조 정리 - 재연결] 선택한 개수(amount)만큼 실제 지갑(Wallet)에서
/// 차감된다(서버 `/wishes/[id]/bokju`가 원자적으로 처리). 보내기 전 현재 보유
/// 개수를 확인해 부족하면 차단하고, 성공 시 지갑을 새로고침한 뒤 공용
/// 차감 토스트([LuckPouchToastController])를 띄운다.
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
  final wallet = context.read<WalletProvider>();

  final amount = await showAppBottomSheet<int>(
    context,
    title: '복주머니 보내기',
    child: _SendBokjuForm(presets: presets, balance: wallet.balance),
  );
  if (amount == null || !context.mounted) return false;

  // [재화 구조 정리] 선택 이후 최종 잔액을 한 번 더 확인(다른 화면에서 소비했을 수 있음).
  if (wallet.balance < amount) {
    AppToast.show(
      context,
      '복주머니가 부족해요. (보유 ${wallet.balance}개)',
      isError: true,
    );
    return false;
  }

  final provider = context.read<WishPostProvider>();
  final result = await provider.sendBokju(wishId, amount);
  if (!context.mounted) return false;

  if (result == null) {
    AppToast.show(
      context,
      provider.lastBokjuError ?? '복주머니 보내기에 실패했습니다.',
      isError: true,
    );
    return false;
  }

  // [재화 구조 정리] 서버에서 실제 차감이 일어났으므로 지갑 잔액을 동기화하고
  // 공용 차감 토스트로 통일된 피드백을 준다.
  await wallet.load();
  if (!context.mounted) return true;
  LuckPouchToastController.instance.showSpend(amount, '소원 응원');

  if (!config.animationEnabled) {
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
  final int balance;
  const _SendBokjuForm({required this.presets, required this.balance});

  @override
  State<_SendBokjuForm> createState() => _SendBokjuFormState();
}

class _SendBokjuFormState extends State<_SendBokjuForm> {
  int? _selected;

  @override
  void initState() {
    super.initState();
    // [재화 구조 정리] 보유 개수 안에서 고를 수 있는 첫 프리셋을 기본 선택.
    final affordable = widget.presets.where((p) => p <= widget.balance);
    _selected = affordable.isNotEmpty
        ? affordable.first
        : (widget.presets.isNotEmpty ? widget.presets.first : null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          // [재화 구조 정리] 선택한 개수만큼 실제 복주머니가 차감됩니다(상징적 응원 아님).
          '이 소원에 복주머니를 보내 촛불을 밝혀주세요.\n선택한 개수만큼 복주머니가 차감돼요. (보유 ${widget.balance}개)',
          style: UnifiedText.body(color: UnifiedColors.textSecondary),
        ),
        const SizedBox(height: UnifiedTokens.spaceXl),
        Wrap(
          spacing: UnifiedTokens.spaceSm,
          runSpacing: UnifiedTokens.spaceSm,
          children: widget.presets.map((preset) {
            final selected = _selected == preset;
            final affordable = preset <= widget.balance;
            return ChoiceChip(
              label: Text('🧧 $preset', style: UnifiedText.chipLabel()),
              selected: selected,
              onSelected: affordable
                  ? (_) => setState(() => _selected = preset)
                  : null,
              backgroundColor: UnifiedColors.chipInactiveBg,
              selectedColor: UnifiedColors.cardAllMenu,
              side: BorderSide.none,
              // [재화 구조 정리] 보유 개수를 초과하는 프리셋은 선택 불가로 흐리게 표시.
              disabledColor: UnifiedColors.chipInactiveBg.withValues(
                alpha: 0.4,
              ),
              labelStyle: affordable
                  ? null
                  : UnifiedText.chipLabel().copyWith(
                      color: UnifiedColors.textSecondary.withValues(alpha: 0.5),
                    ),
            );
          }).toList(),
        ),
        const SizedBox(height: UnifiedTokens.spaceXl),
        AppButton(
          label: _selected == null ? '개수를 선택해 주세요' : '복주머니 $_selected개 보내기',
          onPressed: (_selected == null || _selected! > widget.balance)
              ? null
              : () => Navigator.of(context).pop(_selected),
        ),
      ],
    );
  }
}
