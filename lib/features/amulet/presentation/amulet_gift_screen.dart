import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/amulet_provider.dart';
import '../domain/user_amulet_model.dart';

/// 03단계 §3.3 리워드 탭 - AmuletGiftScreen(부적 선물하기)
/// 06§4.8 `POST /v1/amulets/gift` 대응 화면.
/// 03§10.3(감정적 마이크로카피): "부적 선물" - 보유한 디지털 부적을 커뮤니티
/// 상대에게 선물하는 흐름. §10.2 "부적 획득" 애니메이션은 받는 쪽 화면에
/// 동일 적용되나(선물 받는 순간의 감정적 임팩트), Mock 단계에서는 보내는 쪽
/// 화면에서 전송 완료 결과만 확인한다(받는 쪽 알림/애니메이션은 Phase16
/// 커뮤니티 연동 시 확장 예정).
class AmuletGiftScreen extends StatefulWidget {
  const AmuletGiftScreen({super.key});

  @override
  State<AmuletGiftScreen> createState() => _AmuletGiftScreenState();
}

class _AmuletGiftScreenState extends State<AmuletGiftScreen> {
  final _nicknameController = TextEditingController();
  final _messageController = TextEditingController();
  UserAmuletModel? _selected;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AmuletProvider>().loadMyAmulets();
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amulet = _selected;
    if (amulet == null) return;
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      AppToast.show(context, '받는 사람 닉네임을 입력해주세요.', isError: true);
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context,
      title: '부적 선물하기',
      message:
          '"${amulet.item.name}"을 $nickname 님에게 선물하시겠습니까?\n선물한 부적은 되돌릴 수 없습니다.',
      confirmLabel: '선물하기',
    );
    if (!confirmed || !mounted) return;

    setState(() => _sending = true);
    final provider = context.read<AmuletProvider>();
    final message = _messageController.text.trim();
    final ok = await provider.gift(
      amulet.id,
      nickname,
      message.isEmpty ? null : message,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (ok) {
      await showAppInfoDialog(
        context,
        title: '선물을 보냈어요 🎁',
        message: '$nickname 님에게 "${amulet.item.name}"을 선물했습니다.',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } else {
      AppToast.show(
        context,
        provider.actionError ?? '선물 전송에 실패했습니다.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AmuletProvider>();
    final giftable = provider.myAmulets
        .where((a) => a.status == UserAmuletStatus.held)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('부적 선물하기')),
      body: SafeArea(
        child: provider.isMyAmuletsLoading && provider.myAmulets.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : giftable.isEmpty
            ? const AppEmptyState(
                icon: Icons.card_giftcard_outlined,
                title: '선물할 수 있는 부적이 없어요',
                description: '보유 중인 부적이 있어야 선물할 수 있어요',
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '선물할 부적 선택',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...giftable.map(
                      (a) => _GiftSelectTile(
                        amulet: a,
                        selected: _selected?.id == a.id,
                        onTap: () => setState(() => _selected = a),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppTextField(
                      label: '받는 사람 닉네임',
                      controller: _nicknameController,
                      hintText: '닉네임을 입력해주세요',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: '전하는 메시지 (선택)',
                      controller: _messageController,
                      hintText: '따뜻한 메시지를 남겨보세요',
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    AppButton(
                      label: '선물 보내기',
                      isLoading: _sending,
                      onPressed: _selected == null ? null : _submit,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _GiftSelectTile extends StatelessWidget {
  final UserAmuletModel amulet;
  final bool selected;
  final VoidCallback onTap;

  const _GiftSelectTile({
    required this.amulet,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryContainer : Colors.white,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            children: [
              Text(amulet.item.iconEmoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      amulet.item.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      amulet.item.grade.name,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
