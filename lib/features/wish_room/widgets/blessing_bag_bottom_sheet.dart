import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/blessing_bag_policy_adapter.dart';
import '../application/gratitude_provider.dart';
import '../application/wish_wall_provider.dart';
import '../domain/gratitude_models.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_wall_theme.dart';
import 'wish_room_gift_burst_overlay.dart';
import 'wish_room_meditation_dialog.dart';

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
                      onPressed: () => Navigator.of(context).pop(_sentSuccess),
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
    final result = await context.read<WishWallProvider>().sendPouch(
      wish.id,
      _amount,
    );
    if (!mounted) return;
    if (result.ok) {
      // [소원방 리스킨 — 새 사용 채널] 보내기와 함께 "감사 도장"도 같이
      // 보내기로 선택한 경우, 별도의 소액 지출 채널(giftSeal)을 추가로
      // 요청한다. 실패해도(예: 잔액 소진) 이미 성공한 복주머니 전송은
      // 그대로 유효하게 유지한다(실패는 조용히 무시).
      if (_giftSealToo) {
        await policy.giftSeal();
      }
      widget.onSent();
      setState(() => _state = _SendState.success);
      // [소원방 개편 · 7c — 애니메이션 강화] 바텀시트 내부 카드 연출만으로는
      // 부족하다는 사용자 지시("애니메이션 효괴 확실하게")에 따라, 화면
      // 전체를 덮는 골든 플래시 + 이모지 폭죽 연출을 함께 재생한다. 이
      // 연출은 표시 전용이며 서버 호출(sendPouch)이 이미 성공한 뒤에만
      // 실행되므로 재화 로직에는 전혀 영향을 주지 않는다.
      unawaited(playWishRoomGiftBurst(context, centerEmoji: '🧧'));
      // [STEP04 PART2 마무리 §1] _SendSuccessView 연출이 끝까지 재생되도록
      // 대기 후 닫는다(전체화면 연출과 맞춰 대기 시간을 늘렸다).
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted) Navigator.of(context).pop(true);
    } else {
      // [SECTION10 발견 UX 버그 수정 — 최소 침습] 서버가 구분해 내려준
      // 실패 사유(reasonCode)를 그대로 사용한다. 과거에는 항상
      // 'insufficientBalance'로 하드코딩되어, amount 화이트리스트
      // ([1,5,10,50,100]) 위반 시에도 "복주머니가 부족해요"라고 잘못
      // 표시했다. 서버/DB 정책은 변경하지 않고 표시 문구 분기만 고친다.
      setState(() {
        _state = _SendState.idle;
        _errorReason = result.reasonCode ?? 'insufficientBalance';
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
        // [SECTION10 발견 UX 버그 수정] 서버 amount 화이트리스트
        // ([1,5,10,50,100]) 위반 사유. 잔액 부족과 다른 원인임을 명확히
        // 구분해 안내한다(서버 정책 자체는 변경하지 않음).
        return '올바른 복주머니 수량을 선택해주세요';
      case 'unknown':
        return '전송에 실패했어요. 다시 시도해주세요';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wish = widget.wish;
    final balance = _balance;
    final canSend =
        wish != null &&
        _amount <= balance &&
        _amount <= _perSendMax &&
        _amount > 0;
    final errorLabel = _errorLabel(_errorReason);

    if (_state == _SendState.success) {
      return _SendSuccessView(
        amount: _amount,
        giftedSeal: _giftSealToo,
        recipientName: wish?.displayName ?? '익명',
      );
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
                      color: active ? WishWallColors.ink : WishWallColors.bg2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active
                            ? WishWallColors.ink
                            : WishWallColors.line,
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
              color: _giftSealToo
                  ? WishWallColors.accentSoft
                  : WishWallColors.bg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _giftSealToo
                    ? WishWallColors.accent
                    : WishWallColors.line,
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
                    style: WishWallText.label(
                      color: Colors.white,
                    ).copyWith(fontSize: 15),
                  ),
          ),
        ),
      ],
    );
  }
}

/// [소원방 개편 · 7c] "보내기" 대상 미리보기 — 기존에는 작은 아바타 이모지와
/// 소원 본문만 보여줘서 "누구에게 보내는지" 전혀 식별할 수 없었다. 사용자
/// 승인("니가 쓴 기획대로 다바꿔")에 따라 수신자 이름(또는 익명 표시)을
/// 카드 상단에 명확한 문구로 노출한다. [WishPost.displayName]이 이미
/// `isAnonymous`를 반영해 '익명'/실제 닉네임을 반환하므로 그대로 사용한다.
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${wish.displayName}님에게 보내요',
                      style: WishWallText.body().copyWith(
                        fontWeight: FontWeight.w700,
                        color: WishWallColors.accent2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      wish.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: WishWallText.caption(),
                    ),
                  ],
                ),
              ),
            ],
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

/// [소원방 개편 · 7c — 애니메이션 대폭 강화] 복주머니 전송 성공 연출.
///
/// 서버 [WishWallProvider.sendPouch]가 실제로 성공(`ok == true`)한 뒤에만
/// [_SendPanel]이 이 위젯을 표시한다 — 즉 여기서 그려지는 개수/애니메이션은
/// 전부 "이미 서버가 확정한 결과"에 대한 표현일 뿐, 서버 호출 이전에
/// 미리 낙관적으로 보여주지 않는다(Wallet/PointHistory/WishBokju 로직은
/// 이 파일에서 건드리지 않음 — 표시 전용).
///
/// [강화 배경] 사용자가 "애니메이션 효괴 확실하게"라고 명시적으로(두 차례)
/// 요구했다. 기존 1400ms 단일 페이드 연출은 임팩트가 부족하다는 지적에
/// 따라: 1) 회전하는 다중 링 확산, 2) 탄성(elastic) 바운스로 등장하는
/// 복주머니, 3) 개별 지연을 가진 반짝임(sparkle) 파티클들, 4) 수신자
/// 이름을 포함한 더 명확한 문구, 5) 전체 재생시간을 1800ms로 늘려 임팩트를
/// 강화했다. 동시에 [_SendPanel._send]에서 [playWishRoomGiftBurst] 전체화면
/// 오버레이도 함께 재생되어 이중으로 화려한 연출을 만든다.
class _SendSuccessView extends StatefulWidget {
  const _SendSuccessView({
    required this.amount,
    required this.giftedSeal,
    required this.recipientName,
  });
  final int amount;
  final bool giftedSeal;
  final String recipientName;

  @override
  State<_SendSuccessView> createState() => _SendSuccessViewState();
}

class _SendSuccessViewState extends State<_SendSuccessView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pouchScale;
  late final Animation<double> _pouchOpacity;
  late final Animation<double> _pouchRotation;
  late final Animation<double> _ring1Progress;
  late final Animation<double> _ring2Progress;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _line1Opacity;
  late final Animation<double> _line2Opacity;
  late final Animation<double> _line3Opacity;
  late final List<_SparklePoint> _sparkles;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _sparkles = List.generate(10, (i) {
      final angle = (i / 10) * 2 * pi + rand.nextDouble() * 0.4;
      return _SparklePoint(
        angle: angle,
        distance: 46 + rand.nextDouble() * 30,
        delay: 0.15 + rand.nextDouble() * 0.35,
        size: 8 + rand.nextDouble() * 6,
      );
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pouchScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.2, end: 1.25), weight: 35),
          TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.92), weight: 15),
          TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.06), weight: 15),
          TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 35),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.55, curve: Curves.linear),
          ),
        );
    _pouchOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
    );
    _pouchRotation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: -0.35, end: 0.12), weight: 60),
          TweenSequenceItem(tween: Tween(begin: 0.12, end: 0.0), weight: 40),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
          ),
        );
    _ring1Progress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.6, curve: Curves.easeOutCubic),
    );
    _ring2Progress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.18, 0.75, curve: Curves.easeOutCubic),
    );
    _glowOpacity =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 45),
          TweenSequenceItem(tween: ConstantTween(0.0), weight: 30),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.1, 0.65, curve: Curves.easeInOut),
          ),
        );
    _line1Opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 0.72, curve: Curves.easeOut),
    );
    _line2Opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.65, 0.87, curve: Curves.easeOut),
    );
    _line3Opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildRing(double progress, double maxScale, Color color) {
    final scale = 0.3 + Curves.easeOut.transform(progress) * maxScale;
    final opacity = (1 - progress).clamp(0.0, 1.0) * 0.7;
    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.2),
          ),
        ),
      ),
    );
  }

  Widget _buildSparkle(_SparklePoint s, double t) {
    final localT = ((t - s.delay) / (0.95 - s.delay)).clamp(0.0, 1.0);
    if (localT <= 0 || localT >= 1) return const SizedBox.shrink();
    final eased = Curves.easeOutCubic.transform(localT);
    final dx = cos(s.angle) * s.distance * eased;
    final dy = sin(s.angle) * s.distance * eased;
    final fadeOut = localT > 0.6 ? (1 - (localT - 0.6) / 0.4) : 1.0;
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: fadeOut.clamp(0.0, 1.0),
        child: Text('✨', style: TextStyle(fontSize: s.size)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 빛 효과(glow burst)
                      Opacity(
                        opacity: _glowOpacity.value,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                WishWallColors.accent,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 확산 링 2겹
                      _buildRing(
                        _ring1Progress.value,
                        1.35,
                        WishWallColors.accent,
                      ),
                      _buildRing(
                        _ring2Progress.value,
                        1.0,
                        WishWallColors.accent2,
                      ),
                      // 반짝임 파티클
                      ..._sparkles.map((s) => _buildSparkle(s, t)),
                      // 등장하는 복주머니(탄성 바운스 + 살짝 회전)
                      Opacity(
                        opacity: _pouchOpacity.value.clamp(0.0, 1.0),
                        child: Transform.rotate(
                          angle: _pouchRotation.value,
                          child: Transform.scale(
                            scale: _pouchScale.value.clamp(0.0, 1.4),
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: WishWallColors.accentSoft,
                                boxShadow: [
                                  BoxShadow(
                                    color: WishWallColors.accent.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '🧧',
                                style: TextStyle(fontSize: 34),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Opacity(
                  opacity: _line1Opacity.value,
                  child: Text(
                    '${widget.recipientName}님에게',
                    style: WishWallText.caption(
                      color: WishWallColors.accent2,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 4),
                Opacity(
                  opacity: _line2Opacity.value,
                  child: Text(
                    '복주머니 ${widget.amount}개를 보냈어요',
                    style: WishWallText.title2().copyWith(fontSize: 19),
                  ),
                ),
                const SizedBox(height: 6),
                Opacity(
                  opacity: _line3Opacity.value,
                  child: Text(
                    '당신의 소원이 이루어지길 함께 빌게요 ✨',
                    style: WishWallText.caption(),
                  ),
                ),
                if (widget.giftedSeal) ...[
                  const SizedBox(height: 4),
                  Opacity(
                    opacity: _line3Opacity.value,
                    child: Text(
                      '감사 도장(願)도 함께 전해졌어요',
                      style: WishWallText.caption(color: WishWallColors.dim),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SparklePoint {
  const _SparklePoint({
    required this.angle,
    required this.distance,
    required this.delay,
    required this.size,
  });

  final double angle;
  final double distance;
  final double delay;
  final double size;
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

    // [복주머니 확장 Phase02 항목4 — 2/3] daily_meditation은 다른 채널과
    // 달리 즉시 지급을 요청하지 않는다. 60초 명상 다이얼로그를 먼저 열고,
    // 그 안에서 타이머가 실제로 완료된 시점에만 지급을 요청한다(다이얼로그
    // 내부에서 이미 서버 호출까지 마치고 지급된 금액을 반환).
    if (reason == BlessingBagEarnReason.dailyMeditation) {
      final granted = await showMeditationDialog(context);
      if (!mounted || granted == null) return; // 도중 취소 - 아무것도 안 함
      setState(() => _claimed[reason] = granted);
      return;
    }

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
      BlessingBagEarnReason.dailyMeditation,
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
        ...reasons.map(
          (r) => _EarnChannelCard(
            reason: r,
            claiming: _claiming.contains(r),
            claimedAmount: _claimed[r],
            onTap: () => _claim(r),
          ),
        ),
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
          Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text(
                '받은 선물함',
                style: WishWallText.body().copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: WishWallColors.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${gp.sealable.length}',
                  style: WishWallText.caption(color: WishWallColors.accent2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '누가 내 소원에 복주머니를 보냈는지 확인하고, 24시간 안에 답례 도장을 찍으면 서로 복주머니를 받아요',
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

/// [소원방 개편 · 7d] "답례 도장" 카드 — 기존에는 발신자를 전혀 알 수 없는
/// "복주머니 N개를 받았어요"만 표시했다. 사용자 승인에 따라 이제
/// [candidate.senderNickname]을 카드 상단에 굵게 표시해 "누가" 보냈는지
/// 바로 알 수 있게 하고, 답례 도장을 찍는 순간 [playWishRoomGiftBurst]
/// 전체화면 연출(inbound=true, "받는" 방향)을 재생해 수령 액션을 명확하고
/// 화려하게 체감할 수 있게 했다.
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
          border: Border.all(
            color: WishWallColors.accent.withValues(alpha: 0.35),
          ),
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
              child: const Text('🧧', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${candidate.senderNickname}님이 보냈어요',
                    style: WishWallText.caption(
                      color: WishWallColors.accent2,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '복주머니 ${candidate.amount}개',
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
                      if (!context.mounted) return;
                      if (ok) {
                        // [소원방 개편 · 7d] 답례 성공 — 화면 전체를 덮는
                        // "받는" 방향(inbound) 연출을 재생해 확실한 수령
                        // 체감을 준다.
                        unawaited(
                          playWishRoomGiftBurst(
                            context,
                            centerEmoji: '🙏',
                            inbound: true,
                          ),
                        );
                        final granted = provider.lastSealedResult?.amount;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text(
                              granted != null && granted > 0
                                  ? '답례 도장을 찍었어요! 복주머니 $granted개를 받았어요 🎉'
                                  : '답례 도장을 찍었어요 🎉',
                            ),
                          ),
                        );
                      } else {
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
      case BlessingBagEarnReason.dailyMeditation:
        return Icons.self_improvement_rounded;
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
        style: WishWallText.label(
          color: WishWallColors.bg,
        ).copyWith(fontSize: 12),
      ),
    );
  }
}
