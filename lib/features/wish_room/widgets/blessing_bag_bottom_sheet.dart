import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/blessing_bag_policy_adapter.dart';
import '../application/gratitude_provider.dart';
import '../application/wish_wall_provider.dart';
import '../domain/gratitude_models.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_wall_theme.dart';

/// 복주머니 허브 팝업 — "보내기" / "받기" 탭.
///
/// [소원방 리스킨 — 팝업 확장] 기존에는 "보내기" 단일 기능만 있는 작은
/// 바텀시트였다. 사용자 지시("적립 및 사용하는거 할때 파업창을 좀 크게 열어서
/// 보내고 받고 하고")에 따라:
/// 1) `DraggableScrollableSheet`로 팝업을 화면 대부분(초기 82%, 최대 94%)을
///    덮도록 크게 열고,
/// 2) 상단에 "보내기"/"받기" 2개 탭을 두어 하나의 팝업에서 복주머니를
///    "보내고 받고" 할 수 있게 했다.
///
/// [재화 정책 — 절대 원칙] 이 파일은 여전히 새 화폐를 만들지 않는다. 모든
/// 잔액 조회/적립/차감은 [WishWallProvider.policy]([BlessingBagPolicyAdapter])
/// → [LuckPouchProvider] → [WalletProvider] 경로로만 처리된다.
enum BlessingBagSheetTab { send, receive }

/// 반환값: 실제로 전송(보내기)에 성공하면 `true`, 그 외(받기만 하고 닫힘/
/// 취소)에는 `false`/`null`.
///
/// [wish]는 "보내기" 탭의 대상 소원(선택적). 소원방 홈(제단)처럼 특정 소원을
/// 지정하지 않고 팝업을 열 때(예: 상단 잔액칩 탭)는 null로 전달하면 "보내기"
/// 탭에서 "먼저 소원을 골라주세요" 안내만 표시하고 "받기" 탭은 그대로
/// 사용할 수 있다.
Future<bool?> showBlessingBagBottomSheet(
  BuildContext context, {
  WishPost? wish,
  BlessingBagSheetTab initialTab = BlessingBagSheetTab.send,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BlessingBagHubSheet(wish: wish, initialTab: initialTab),
  );
}

class _BlessingBagHubSheet extends StatefulWidget {
  const _BlessingBagHubSheet({required this.wish, required this.initialTab});
  final WishPost? wish;
  final BlessingBagSheetTab initialTab;

  @override
  State<_BlessingBagHubSheet> createState() => _BlessingBagHubSheetState();
}

class _BlessingBagHubSheetState extends State<_BlessingBagHubSheet> {
  late BlessingBagSheetTab _tab = widget.initialTab;
  bool _sentSuccess = false;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: WishWallColors.bg2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: WishWallColors.line2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
                child: Row(
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '복주머니',
                        style: WishWallText.title2().copyWith(fontSize: 18),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.of(context).pop(_sentSuccess),
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: WishWallColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                child: _HubTabBar(
                  tab: _tab,
                  onChanged: (t) => setState(() => _tab = t),
                ),
              ),
              const Divider(height: 1, color: WishWallColors.line),
              Expanded(
                child: _tab == BlessingBagSheetTab.send
                    ? _SendPanel(
                        wish: widget.wish,
                        scrollController: scrollController,
                        onSent: () => setState(() => _sentSuccess = true),
                      )
                    : _ReceivePanel(scrollController: scrollController),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HubTabBar extends StatelessWidget {
  const _HubTabBar({required this.tab, required this.onChanged});
  final BlessingBagSheetTab tab;
  final ValueChanged<BlessingBagSheetTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: WishWallColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WishWallColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: _HubTabButton(
              label: '보내기',
              icon: Icons.send_rounded,
              active: tab == BlessingBagSheetTab.send,
              onTap: () => onChanged(BlessingBagSheetTab.send),
            ),
          ),
          Expanded(
            child: _HubTabButton(
              label: '받기',
              icon: Icons.card_giftcard_rounded,
              active: tab == BlessingBagSheetTab.receive,
              onTap: () => onChanged(BlessingBagSheetTab.receive),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubTabButton extends StatelessWidget {
  const _HubTabButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? WishWallColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? WishWallColors.bg : WishWallColors.dim,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: WishWallText.family,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: active ? WishWallColors.bg : WishWallColors.dim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 보내기 탭
// ============================================================

enum _SendState { idle, sending, success }

class _SendPanel extends StatefulWidget {
  const _SendPanel({
    required this.wish,
    required this.scrollController,
    required this.onSent,
  });
  final WishPost? wish;
  final ScrollController scrollController;
  final VoidCallback onSent;

  @override
  State<_SendPanel> createState() => _SendPanelState();
}

class _SendPanelState extends State<_SendPanel> {
  int _amount = 1;
  _SendState _state = _SendState.idle;
  String? _errorReason;
  bool _giftSealToo = false;

  static const int _perSendMax = 5;

  int get _balance => context.read<WishWallProvider>().policy.balance;

  void _setAmount(int v) {
    setState(() {
      _amount = v.clamp(1, _perSendMax);
      _errorReason = null;
    });
  }

  Future<void> _send() async {
    final wish = widget.wish;
    if (wish == null) return;
    final policy = context.read<WishWallProvider>().policy;
    final v = policy.validateSend(_amount);
    if (!v.ok) {
      setState(() => _errorReason = v.reasonCode);
      return;
    }
    setState(() => _state = _SendState.sending);
    final ok = await context.read<WishWallProvider>().sendPouch(
      wish.id,
      _amount,
    );
    if (!mounted) return;
    if (ok) {
      // [소원방 리스킨 — 새 사용 채널] 보내기와 함께 "감사 도장"도 같이
      // 보내기로 선택한 경우, 별도의 소액 지출 채널(giftSeal)을 추가로
      // 요청한다. 실패해도(예: 잔액 소진) 이미 성공한 복주머니 전송은
      // 그대로 유효하게 유지한다(실패는 조용히 무시).
      if (_giftSealToo) {
        await policy.giftSeal();
      }
      widget.onSent();
      setState(() => _state = _SendState.success);
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _state = _SendState.idle;
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
    final wish = widget.wish;
    final balance = _balance;
    final canSend = wish != null &&
        _amount <= balance &&
        _amount <= _perSendMax &&
        _amount > 0;
    final errorLabel = _errorLabel(_errorReason);

    if (_state == _SendState.success) {
      return _SendSuccessView(amount: _amount, giftedSeal: _giftSealToo);
    }

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (wish == null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: WishWallColors.bg2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: WishWallColors.dim,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '소원 게시물을 먼저 열어서 복주머니를 보내보세요',
                    style: WishWallText.caption(),
                  ),
                ),
              ],
            ),
          )
        else
          _TargetWishPreview(wish: wish),
        const SizedBox(height: 16),
        Text(
          wish == null ? '보낼 수량' : '이 소원병에 복주머니를 매달아 응원을 전해요',
          style: WishWallText.caption(),
        ),
        const SizedBox(height: 12),
        // 잔액 카드
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              onTap: _amount < _perSendMax ? () => _setAmount(_amount + 1) : null,
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
                      color: active ? WishWallColors.ink : WishWallColors.bg2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? WishWallColors.ink : WishWallColors.line,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$v개',
                      style: TextStyle(
                        fontFamily: WishWallText.family,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: active ? WishWallColors.bg : WishWallColors.ink2,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // [소원방 리스킨 — 새 사용 채널] 감사 도장(giftSeal) 함께 보내기 옵션.
        InkWell(
          onTap: () => setState(() => _giftSealToo = !_giftSealToo),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _giftSealToo ? WishWallColors.accentSoft : WishWallColors.bg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _giftSealToo ? WishWallColors.accent : WishWallColors.line,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _giftSealToo
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 20,
                  color: _giftSealToo
                      ? WishWallColors.accent
                      : WishWallColors.dim,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '감사 도장(願) 함께 보내기',
                        style: WishWallText.body().copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text('복주머니 1개 추가 소비', style: WishWallText.caption()),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
              Icon(Icons.info_outline, size: 15, color: WishWallColors.dim),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  errorLabel ?? '한 번에 최대 $_perSendMax개까지 보낼 수 있어요',
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
            onPressed: (canSend && _state == _SendState.idle) ? _send : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: WishWallColors.accent,
              disabledBackgroundColor: WishWallColors.line2,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _state == _SendState.sending
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
                    style: WishWallText.label(color: Colors.white).copyWith(
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _TargetWishPreview extends StatelessWidget {
  const _TargetWishPreview({required this.wish});
  final WishPost wish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WishWallColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WishWallColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: wish.categoryId.glassColor,
              border: Border.all(color: wish.categoryId.corkColor),
            ),
            alignment: Alignment.center,
            child: Text(
              wish.isAnonymous ? '?' : wish.authorAvatarEmoji,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              wish.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: WishWallText.caption(),
            ),
          ),
        ],
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

class _SendSuccessView extends StatefulWidget {
  const _SendSuccessView({required this.amount, required this.giftedSeal});
  final int amount;
  final bool giftedSeal;

  @override
  State<_SendSuccessView> createState() => _SendSuccessViewState();
}

class _SendSuccessViewState extends State<_SendSuccessView>
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: CurvedAnimation(
                parent: _controller,
                curve: Curves.elasticOut,
              ),
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: WishWallColors.accentSoft,
                ),
                alignment: Alignment.center,
                child: const Text('✨', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '복주머니 ${widget.amount}개를 보냈어요',
              style: WishWallText.title2().copyWith(fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              widget.giftedSeal
                  ? '감사 도장과 함께 따뜻한 마음이 잘 전해졌어요'
                  : '따뜻한 마음이 잘 전해졌어요',
              style: WishWallText.caption(),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 받기 탭
// ============================================================

class _ReceivePanel extends StatefulWidget {
  const _ReceivePanel({required this.scrollController});
  final ScrollController scrollController;

  @override
  State<_ReceivePanel> createState() => _ReceivePanelState();
}

class _ReceivePanelState extends State<_ReceivePanel> {
  final Set<BlessingBagEarnReason> _claiming = {};
  final Map<BlessingBagEarnReason, int> _claimed = {};

  @override
  void initState() {
    super.initState();
    // [복주머니 확장 Phase02 항목3] 답례 도장(GratitudeSeal) 후보 목록을
    // "받기" 탭 진입 시 로드한다. 로그인/데이터 없음은 Provider 내부에서
    // 조용히 빈 목록으로 처리되므로 별도 에러 UI가 필요 없다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GratitudeProvider>().loadAll();
    });
  }

  Future<void> _claim(BlessingBagEarnReason reason) async {
    if (_claiming.contains(reason) || _claimed.containsKey(reason)) return;
    setState(() => _claiming.add(reason));
    final policy = context.read<WishWallProvider>().policy;
    int granted;
    switch (reason) {
      case BlessingBagEarnReason.altarVisit:
        granted = await policy.earnAltarVisitBonus();
        break;
      case BlessingBagEarnReason.weeklyBoxOpening:
        granted = await policy.earnWeeklyBoxOpeningBonus();
        break;
      case BlessingBagEarnReason.dailyPrayer:
        granted = await policy.earnDailyPrayerBonus();
        break;
      case BlessingBagEarnReason.wishCreatedBonus:
        granted = await policy.earnWishCreatedBonus();
        break;
      case BlessingBagEarnReason.wishFulfilled:
        granted = await policy.earnWishFulfilledBonus();
        break;
      case BlessingBagEarnReason.dailyCandle:
        granted = await policy.earnDailyCandleBonus();
        break;
      default:
        granted = 0;
    }
    if (!mounted) return;
    setState(() {
      _claiming.remove(reason);
      _claimed[reason] = granted;
    });
    if (granted <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('오늘은 이미 받았어요. 내일 다시 시도해주세요'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = context.watch<WishWallProvider>().policy.balance;

    // [소원방 리스킨 — "받기" 확장 채널] 4개 적립 채널을 카드형 리스트로
    // 노출한다. altarVisit는 이 화면 진입 시 자동으로 이미 시도되었을 수
    // 있으므로(WishRoomHomeScreen.initState), 여기서도 다시 누르면 서버가
    // 중복 지급을 막고 0을 반환한다(안전).
    const reasons = [
      BlessingBagEarnReason.altarVisit,
      BlessingBagEarnReason.dailyCandle,
      BlessingBagEarnReason.dailyPrayer,
      BlessingBagEarnReason.weeklyBoxOpening,
      BlessingBagEarnReason.wishFulfilled,
    ];

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        const SizedBox(height: 18),
        Text('오늘 받을 수 있어요', style: WishWallText.caption()),
        const SizedBox(height: 10),
        ...reasons.map((r) => _EarnChannelCard(
              reason: r,
              claiming: _claiming.contains(r),
              claimedAmount: _claimed[r],
              onTap: () => _claim(r),
            )),
        // [복주머니 확장 Phase02 항목3] 답례 도장(GratitudeSeal) 섹션.
        // 기존 giftSeal("감사 도장 보내기")과 혼동을 피하기 위해 "답례 도장"
        // 문구를 사용한다. 내 소원에 복주머니를 보내준 사람에게 24시간 이내
        // 답례하면 나(+2)/상대(+5) 모두 복주머니를 받는다.
        const _GratitudeSealSection(),
      ],
    );
  }
}

// ============================================================
// 답례 도장(GratitudeSeal) 섹션 — [복주머니 확장 Phase02 항목3]
// ============================================================

class _GratitudeSealSection extends StatelessWidget {
  const _GratitudeSealSection();

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GratitudeProvider>();
    if (gp.isLoading && gp.sealable.isEmpty) {
      return const SizedBox.shrink();
    }
    if (gp.sealable.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('답례 도장을 찍어보세요', style: WishWallText.caption()),
          const SizedBox(height: 4),
          Text(
            '내 소원에 복주머니를 보내준 분에게 24시간 안에 답례하면 서로 복주머니를 받아요',
            style: WishWallText.caption(color: WishWallColors.dim),
          ),
          const SizedBox(height: 10),
          ...gp.sealable.map(
            (c) => _GratitudeSealCard(candidate: c, provider: gp),
          ),
        ],
      ),
    );
  }
}

class _GratitudeSealCard extends StatelessWidget {
  const _GratitudeSealCard({required this.candidate, required this.provider});
  final GratitudeSealableCandidate candidate;
  final GratitudeProvider provider;

  String _remainingLabel() {
    final r = candidate.remaining;
    if (r.isNegative) return '만료됨';
    if (r.inHours >= 1) return '${r.inHours}시간 남음';
    final minutes = r.inMinutes;
    return minutes > 0 ? '$minutes분 남음' : '곧 만료';
  }

  @override
  Widget build(BuildContext context) {
    final sealing = provider.isSealing(candidate.sourcePouchId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: WishWallColors.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WishWallColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WishWallColors.accentSoft,
              ),
              alignment: Alignment.center,
              child: const Text('🙏', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '복주머니 ${candidate.amount}개를 받았어요',
                    style: WishWallText.body().copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(_remainingLabel(), style: WishWallText.caption()),
                ],
              ),
            ),
            const SizedBox(width: 8),
            sealing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: WishWallColors.accent,
                    ),
                  )
                : InkWell(
                    onTap: () async {
                      final ok = await provider.seal(candidate.sourcePouchId);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text(
                              provider.lastSealError ?? '답례 도장 찍기에 실패했어요',
                            ),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: WishWallColors.ink,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '답례 도장',
                        style: WishWallText.label(
                          color: WishWallColors.bg,
                        ).copyWith(fontSize: 12),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _EarnChannelCard extends StatelessWidget {
  const _EarnChannelCard({
    required this.reason,
    required this.claiming,
    required this.claimedAmount,
    required this.onTap,
  });

  final BlessingBagEarnReason reason;
  final bool claiming;
  final int? claimedAmount;
  final VoidCallback onTap;

  IconData get _icon {
    switch (reason) {
      case BlessingBagEarnReason.altarVisit:
        return Icons.local_fire_department_rounded;
      case BlessingBagEarnReason.dailyPrayer:
        return Icons.auto_awesome_rounded;
      case BlessingBagEarnReason.weeklyBoxOpening:
        return Icons.inventory_2_rounded;
      case BlessingBagEarnReason.wishFulfilled:
        return Icons.celebration_rounded;
      case BlessingBagEarnReason.dailyCandle:
        return Icons.local_fire_department_outlined;
      default:
        return Icons.card_giftcard_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = claimedAmount != null;
    final gotSomething = done && claimedAmount! > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: done ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: WishWallColors.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: WishWallColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: WishWallColors.accentSoft,
                ),
                alignment: Alignment.center,
                child: Icon(_icon, size: 20, color: WishWallColors.accent2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reason.label,
                      style: WishWallText.body().copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(reason.description, style: WishWallText.caption()),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _EarnChannelTrailing(
                claiming: claiming,
                done: done,
                gotSomething: gotSomething,
                amount: reason.defaultAmount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EarnChannelTrailing extends StatelessWidget {
  const _EarnChannelTrailing({
    required this.claiming,
    required this.done,
    required this.gotSomething,
    required this.amount,
  });
  final bool claiming;
  final bool done;
  final bool gotSomething;
  final int amount;

  @override
  Widget build(BuildContext context) {
    if (claiming) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: WishWallColors.accent,
        ),
      );
    }
    if (done) {
      return Text(
        gotSomething ? '+$amount 받음' : '오늘 완료',
        style: WishWallText.caption(
          color: gotSomething ? WishWallColors.green : WishWallColors.dim,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: WishWallColors.ink,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '+$amount 받기',
        style: WishWallText.label(color: WishWallColors.bg).copyWith(fontSize: 12),
      ),
    );
  }
}
