import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_wall_provider.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_wall_theme.dart';

/// 복주머니 보내기 바텀시트.
///
/// [handoff.zip] 기획안 §4.5 바텀시트 사양(Grip+헤더+잔액카드+스테퍼+
/// 빠른선택1/3/5+정책안내+Send버튼, idle→sending→success 상태흐름)을
/// Flutter로 이식. 실제 잔액/차감은 [WishWallProvider.sendPouch] →
/// [BlessingBagPolicyAdapter] → [LuckPouchProvider]를 그대로 거친다.
///
/// 반환값: 실제로 전송에 성공하면 `true`, 취소/실패 시 `false`/`null`.
Future<bool?> showBlessingBagBottomSheet(
  BuildContext context, {
  required WishPost wish,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BlessingBagSheet(wish: wish),
  );
}

enum _SheetState { idle, sending, success }

class _BlessingBagSheet extends StatefulWidget {
  const _BlessingBagSheet({required this.wish});
  final WishPost wish;

  @override
  State<_BlessingBagSheet> createState() => _BlessingBagSheetState();
}

class _BlessingBagSheetState extends State<_BlessingBagSheet> {
  int _amount = 1;
  _SheetState _state = _SheetState.idle;
  String? _errorReason;

  static const int _perSendMax = 5;

  int get _balance =>
      context.read<WishWallProvider>().policy.balance;

  void _setAmount(int v) {
    setState(() {
      _amount = v.clamp(1, _perSendMax);
      _errorReason = null;
    });
  }

  Future<void> _send() async {
    final policy = context.read<WishWallProvider>().policy;
    final v = policy.validateSend(_amount);
    if (!v.ok) {
      setState(() => _errorReason = v.reasonCode);
      return;
    }
    setState(() => _state = _SheetState.sending);
    final ok = await context
        .read<WishWallProvider>()
        .sendPouch(widget.wish.id, _amount);
    if (!mounted) return;
    if (ok) {
      setState(() => _state = _SheetState.success);
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _state = _SheetState.idle;
        _errorReason = 'insufficientBalance';
      });
    }
  }

  String? _errorLabel(String? code) {
    switch (code) {
      case 'insufficientBalance':
        return '복주머니가 부족해요';
      case 'exceedsPerSendMax':
        return '한 번에 최대 $_perSendMax개까지 보낼 수 있어요';
      case 'invalidAmount':
        return '보낼 수량을 확인해주세요';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = _balance;
    final canSend = _amount <= balance && _amount <= _perSendMax && _amount > 0;
    final errorLabel = _errorLabel(_errorReason);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: _state == _SheetState.success
                ? _SuccessView(amount: _amount)
                : Column(
                    key: const ValueKey('form'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: WishWallColors.line2,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '복주머니 보내기',
                              style: WishWallText.title2().copyWith(fontSize: 18),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            icon: const Icon(Icons.close, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '이 소원병에 복주머니를 매달아 응원을 전해요',
                        style: WishWallText.caption(),
                      ),
                      const SizedBox(height: 16),
                      // 잔액 카드
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: WishWallColors.accentSoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: WishWallColors.accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '내 복주머니',
                              style: WishWallText.body().copyWith(
                                fontWeight: FontWeight.w600,
                                color: WishWallColors.accent2,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$balance개',
                              style: WishWallText.title2().copyWith(
                                fontSize: 20,
                                color: WishWallColors.accent2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 스테퍼
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StepperButton(
                            icon: Icons.remove,
                            onTap: _amount > 1 ? () => _setAmount(_amount - 1) : null,
                          ),
                          Container(
                            width: 72,
                            alignment: Alignment.center,
                            child: Text(
                              '$_amount',
                              style: WishWallText.display().copyWith(fontSize: 32),
                            ),
                          ),
                          _StepperButton(
                            icon: Icons.add,
                            onTap: _amount < _perSendMax
                                ? () => _setAmount(_amount + 1)
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 빠른 선택 1/3/5
                      Row(
                        children: [1, 3, 5].map((v) {
                          final active = _amount == v;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                onTap: () => _setAmount(v),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? WishWallColors.ink
                                        : WishWallColors.bg2,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: active
                                          ? WishWallColors.ink
                                          : WishWallColors.line,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${v}개',
                                    style: TextStyle(
                                      fontFamily: WishWallText.family,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: active ? Colors.white : WishWallColors.ink2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      // 정책 안내
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: WishWallColors.bg2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 15,
                              color: WishWallColors.dim,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                errorLabel ??
                                    '한 번에 최대 $_perSendMax개까지 보낼 수 있어요',
                                style: WishWallText.caption(
                                  color: errorLabel != null
                                      ? WishWallColors.red
                                      : WishWallColors.dim,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (canSend && _state == _SheetState.idle)
                              ? _send
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: WishWallColors.accent,
                            disabledBackgroundColor: WishWallColors.line2,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _state == _SheetState.sending
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : Text(
                                  '$_amount개 보내기',
                                  style: WishWallText.label(color: Colors.white)
                                      .copyWith(fontSize: 15),
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: WishWallColors.bg2,
          border: Border.all(
            color: enabled ? WishWallColors.line2 : WishWallColors.line,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? WishWallColors.ink : WishWallColors.dim,
        ),
      ),
    );
  }
}

class _SuccessView extends StatefulWidget {
  const _SuccessView({required this.amount});
  final int amount;

  @override
  State<_SuccessView> createState() => _SuccessViewState();
}

class _SuccessViewState extends State<_SuccessView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: WishWallColors.accentSoft,
              ),
              alignment: Alignment.center,
              child: const Text('✨', style: TextStyle(fontSize: 30)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '복주머니 ${widget.amount}개를 보냈어요',
            style: WishWallText.title2().copyWith(fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            '따뜻한 마음이 잘 전해졌어요',
            style: WishWallText.caption(),
          ),
        ],
      ),
    );
  }
}
