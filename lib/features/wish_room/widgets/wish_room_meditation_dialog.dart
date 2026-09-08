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
/// [소원방 3대 개선 — "60초 명상" 실제 명상으로 개선] 사용자 불만("영상은
/// 도대체 몰 하라는건지 알수가 없어 그냥 타이머 돌리고있는데 무슨 명상을
/// 해?")에 따라, 단순 숫자 카운트다운을 실제 호흡 가이드로 교체한다.
/// 4초 들이쉬기 → 2초 멈춤 → 4초 내쉬기(1라운드 10초) × 6라운드 = 60초.
/// 각 단계마다 문구와 남은 초를 명확히 보여주고, 원의 크기가 들이쉴 때
/// 커지고 내쉴 때 작아지도록 애니메이션해 실제로 따라 호흡할 수 있게 한다.
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

/// 호흡 3단계 — 들이쉬기(4초) → 멈춤(2초) → 내쉬기(4초).
enum _BreathPhase { inhale, hold, exhale }

class _MeditationDialog extends StatefulWidget {
  const _MeditationDialog();

  @override
  State<_MeditationDialog> createState() => _MeditationDialogState();
}

class _MeditationDialogState extends State<_MeditationDialog> {
  static const int _inhaleSeconds = 4;
  static const int _holdSeconds = 2;
  static const int _exhaleSeconds = 4;
  static const int _roundSeconds =
      _inhaleSeconds + _holdSeconds + _exhaleSeconds; // 10초
  static const int _totalRounds = 6; // 6 x 10초 = 60초
  static const int _totalMs = _roundSeconds * _totalRounds * 1000;
  static const int _tickMs = 100;

  Timer? _ticker;
  int _elapsedMs = 0;
  bool _completed = false;
  bool _claiming = false;
  int? _grantedAmount;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: _tickMs), _onTick);
  }

  void _onTick(Timer timer) {
    if (!mounted) return;
    final next = _elapsedMs + _tickMs;
    setState(() => _elapsedMs = next.clamp(0, _totalMs));
    if (_elapsedMs >= _totalMs) {
      timer.cancel();
      _onMeditationComplete();
    }
  }

  int get _posInRoundMs => _elapsedMs % (_roundSeconds * 1000);

  int get _currentRound =>
      (_elapsedMs ~/ (_roundSeconds * 1000)).clamp(0, _totalRounds - 1) + 1;

  _BreathPhase get _phase {
    final pos = _posInRoundMs;
    if (pos < _inhaleSeconds * 1000) return _BreathPhase.inhale;
    if (pos < (_inhaleSeconds + _holdSeconds) * 1000) return _BreathPhase.hold;
    return _BreathPhase.exhale;
  }

  /// 현재 단계 안에서 남은 초(올림). 예: 들이쉬기 시작 직후 4, 끝날 때 1.
  int get _phaseRemainingSeconds {
    final pos = _posInRoundMs;
    int phaseStartMs;
    int phaseDurationMs;
    switch (_phase) {
      case _BreathPhase.inhale:
        phaseStartMs = 0;
        phaseDurationMs = _inhaleSeconds * 1000;
        break;
      case _BreathPhase.hold:
        phaseStartMs = _inhaleSeconds * 1000;
        phaseDurationMs = _holdSeconds * 1000;
        break;
      case _BreathPhase.exhale:
        phaseStartMs = (_inhaleSeconds + _holdSeconds) * 1000;
        phaseDurationMs = _exhaleSeconds * 1000;
        break;
    }
    final elapsedInPhase = pos - phaseStartMs;
    final remainingMs = phaseDurationMs - elapsedInPhase;
    return (remainingMs / 1000).ceil().clamp(1, phaseDurationMs ~/ 1000);
  }

  double get _phaseProgress {
    final pos = _posInRoundMs;
    switch (_phase) {
      case _BreathPhase.inhale:
        return (pos / (_inhaleSeconds * 1000)).clamp(0.0, 1.0);
      case _BreathPhase.hold:
        return ((pos - _inhaleSeconds * 1000) / (_holdSeconds * 1000)).clamp(
          0.0,
          1.0,
        );
      case _BreathPhase.exhale:
        return ((pos - (_inhaleSeconds + _holdSeconds) * 1000) /
                (_exhaleSeconds * 1000))
            .clamp(0.0, 1.0);
    }
  }

  static const double _minScale = 0.82;
  static const double _maxScale = 1.2;

  double get _breathScale {
    switch (_phase) {
      case _BreathPhase.inhale:
        return _minScale + (_maxScale - _minScale) * _phaseProgress;
      case _BreathPhase.hold:
        return _maxScale;
      case _BreathPhase.exhale:
        return _maxScale - (_maxScale - _minScale) * _phaseProgress;
    }
  }

  String get _phaseLabel {
    switch (_phase) {
      case _BreathPhase.inhale:
        return '천천히 숨을 들이쉬어요';
      case _BreathPhase.hold:
        return '잠시 멈춰요';
      case _BreathPhase.exhale:
        return '천천히 숨을 내쉬어요';
    }
  }

  String get _phaseWord {
    switch (_phase) {
      case _BreathPhase.inhale:
        return '들이쉬기';
      case _BreathPhase.hold:
        return '멈춤';
      case _BreathPhase.exhale:
        return '내쉬기';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overallProgress = _elapsedMs / _totalMs;
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
              _completed ? '명상을 마쳤어요' : '라운드 $_currentRound / $_totalRounds',
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
                  : _phaseLabel,
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
                  // [호흡 가이드] 원이 들이쉴 때 커지고 내쉴 때 작아진다.
                  // 100ms 틱마다 setState로 갱신되는 [_breathScale]을 그대로
                  // 반영해 부드러운 애니메이션 없이도 매끄럽게 보이도록
                  // AnimatedScale의 duration을 tick 간격과 맞춘다.
                  AnimatedScale(
                    scale: _completed ? 1.0 : _breathScale,
                    duration: const Duration(milliseconds: _tickMs),
                    curve: Curves.linear,
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
                  ),
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: CircularProgressIndicator(
                      value: _completed ? 1 : overallProgress,
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
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_phaseRemainingSeconds',
                          style: const TextStyle(
                            fontFamily: 'IBMPlexMonoWish',
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: WishRoomColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _phaseWord,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: WishRoomColors.textSecondary,
                          ),
                        ),
                      ],
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
