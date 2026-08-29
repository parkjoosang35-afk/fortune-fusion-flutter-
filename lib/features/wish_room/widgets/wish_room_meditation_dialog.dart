import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/blessing_bag_policy_adapter.dart';
import '../application/wish_wall_provider.dart';
import '../theme/wish_room_theme.dart';

/// [복주머니 확장 Phase02 항목4 — 일일 적립 이벤트 2/3] 60초 명상 다이얼로그.
///
/// bokjumeoni-plan §02 EARN "매일의 발자국" 4종 중 daily_meditation
/// (+2, 1일 1회)의 실제 트리거 UI. 단순 버튼 한 번으로 지급을 요청하는
/// 다른 채널(altarVisit 등)과 달리, 이 채널은 "60초를 실제로 채워서
/// 기다려야" 지급 요청이 나가도록 만든다(행위 자체가 보상의 조건).
///
/// [서버 최종 판단 원칙] 클라이언트가 60초를 다 채웠다고 판단해도, 실제
/// 지급 여부(오늘 이미 받았는지 등)는 여전히 서버(checkPolicyEligibility)가
/// 최종 결정한다 — 이 다이얼로그는 "언제 요청을 보낼지"만 통제한다.
///
/// 반환값: 다이얼로그가 닫힐 때 실제로 지급된 금액(int). 타이머를 다
/// 채우지 못하고 취소하면 지급 요청 자체가 발생하지 않으며 null을 반환한다.
Future<int?> showMeditationDialog(BuildContext context) {
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (_) => const _MeditationDialog(),
  );
}

class _MeditationDialog extends StatefulWidget {
  const _MeditationDialog();

  @override
  State<_MeditationDialog> createState() => _MeditationDialogState();
}

class _MeditationDialogState extends State<_MeditationDialog>
    with SingleTickerProviderStateMixin {
  static const int _totalSeconds = 60;

  late final AnimationController _breath;
  Timer? _ticker;
  int _remaining = _totalSeconds;
  bool _completed = false;
  bool _claiming = false;
  int? _grantedAmount;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer timer) {
    if (!mounted) return;
    setState(() {
      if (_remaining > 0) {
        _remaining -= 1;
      }
    });
    if (_remaining <= 0) {
      timer.cancel();
      _onMeditationComplete();
    }
  }

  Future<void> _onMeditationComplete() async {
    if (_completed) return;
    setState(() {
      _completed = true;
      _claiming = true;
    });
    // [서버 최종 판단] 60초를 다 채운 시점에만 지급을 "요청"한다. 실제
    // 지급 여부(오늘 이미 받았는지)는 서버가 결정한다.
    final policy = context.read<WishWallProvider>().policy;
    final granted = await _requestBonus(policy);
    if (!mounted) return;
    setState(() {
      _claiming = false;
      _grantedAmount = granted;
    });
  }

  Future<int> _requestBonus(BlessingBagPolicyAdapter policy) {
    return policy.earnDailyMeditationBonus();
  }

  void _cancel() {
    if (_completed) return;
    _ticker?.cancel();
    Navigator.of(context).pop(null);
  }

  void _close() {
    Navigator.of(context).pop(_grantedAmount ?? 0);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = 1 - (_remaining / _totalSeconds);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        decoration: BoxDecoration(
          color: WishRoomColors.backgroundSoft,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: WishRoomColors.surfaceCardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _completed ? '명상을 마쳤어요' : '60초 명상',
              style: const TextStyle(
                fontFamily: 'NotoSerifKRWish',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: WishRoomColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _completed
                  ? (_claiming
                        ? '복주머니를 확인하고 있어요…'
                        : (_grantedAmount != null && _grantedAmount! > 0
                              ? '오늘의 마음을 가라앉혔어요'
                              : '오늘은 이미 받았어요. 내일 다시 해보세요'))
                  : '숨을 천천히 들이쉬고 내쉬며\n잠시 마음을 가라앉혀요',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: WishRoomColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _breath,
                    builder: (context, _) {
                      final scale = _completed
                          ? 1.0
                          : 0.88 + 0.12 * _breath.value;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                WishRoomColors.glow.withValues(
                                  alpha: _completed ? 0.55 : 0.35,
                                ),
                                WishRoomColors.glowShadow,
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.55, 1.0],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: CircularProgressIndicator(
                      value: _completed ? 1 : progress,
                      strokeWidth: 4,
                      backgroundColor: WishRoomColors.surfaceCardBorder,
                      valueColor: const AlwaysStoppedAnimation(
                        WishRoomColors.glow,
                      ),
                    ),
                  ),
                  if (_completed && !_claiming)
                    Text(
                      _grantedAmount != null && _grantedAmount! > 0
                          ? '🎁 +${_grantedAmount!}'
                          : '🙏',
                      style: const TextStyle(
                        fontFamily: 'IBMPlexMonoWish',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: WishRoomColors.glow,
                      ),
                    )
                  else if (_completed && _claiming)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: WishRoomColors.glow,
                      ),
                    )
                  else
                    Text(
                      '$_remaining',
                      style: const TextStyle(
                        fontFamily: 'IBMPlexMonoWish',
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: WishRoomColors.textPrimary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: _completed
                  ? OutlinedButton(
                      onPressed: _claiming ? null : _close,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: WishRoomColors.textPrimary,
                        side: const BorderSide(
                          color: WishRoomColors.surfaceCardBorder,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('확인'),
                    )
                  : TextButton(
                      onPressed: _cancel,
                      child: const Text(
                        '그만두기',
                        style: TextStyle(color: WishRoomColors.textTertiary),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
