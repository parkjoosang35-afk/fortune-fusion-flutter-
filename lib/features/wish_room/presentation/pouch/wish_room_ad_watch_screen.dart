import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/wish_room_provider.dart';
import '../../domain/wish_room_models.dart';
import '../../theme/wish_room_colors.dart';
import '../../theme/wish_room_text_styles.dart';
import '../../widgets/wish_room_sigils.dart';
import '../../widgets/wish_room_pouch_widgets.dart';
import 'wish_room_earn_moment_screen.dart';

/// 16. 광고 시청 — 출처: `handoff/dev-spec.md` §7 (미구현 화면 · 스펙 정의됨)
///
/// 절대 원칙 준수:
///  - 결제/충전 버튼 없음 — 오직 "짧은 영상을 조용히 지켜보는" 행위만 존재
///  - 광고 재생 도중 스킵 불가(§7.2 "30초 후에만 스킵 가능"), 완료 시에만 조각 지급
///
/// [주의] 실제 광고 SDK(AdMob 등)는 미결 상태(dev-spec §8-8). 여기서는
/// 소원방 톤을 유지한 시뮬레이션 광고 플레이어를 구현하고, SDK 연동 지점만
/// [_simulatedSeconds]로 명확히 표시해 둔다.
class WishRoomAdWatchScreen extends StatefulWidget {
  const WishRoomAdWatchScreen({super.key});

  @override
  State<WishRoomAdWatchScreen> createState() => _WishRoomAdWatchScreenState();
}

class _WishRoomAdWatchScreenState extends State<WishRoomAdWatchScreen>
    with SingleTickerProviderStateMixin {
  // SDK 연동 지점: 실제 광고 SDK가 붙기 전까지는 이 값으로 시청 시간을
  // 시뮬레이션한다(dev-spec §7.2 카피 상 "30초"이나, 개발/QA 편의를 위해
  // 6초로 단축해 두었다 — SDK 연동 시 실제 광고 길이로 대체될 값).
  static const _simulatedSeconds = 6;

  late final AnimationController _sigilCtrl;
  int _remaining = _simulatedSeconds;
  bool _finished = false;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _sigilCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _tick();
  }

  @override
  void dispose() {
    _sigilCtrl.dispose();
    super.dispose();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _remaining = _remaining > 0 ? _remaining - 1 : 0;
        if (_remaining == 0) _finished = true;
      });
      if (_remaining > 0) _tick();
    });
  }

  Future<void> _handleClaim() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    final provider = context.read<WishRoomProvider>();
    final result = await provider.earnAdWatched();
    if (!mounted) return;
    if (result == null) {
      // 오늘 시청 한도 소진 등 — 결제 유도 없이 조용히 안내만 한다.
      await showDialog<void>(
        context: context,
        barrierColor: WishRoomColors.backdropColor,
        builder: (ctx) => _QuietDialog(
          message: '이번엔 조각이 담기지 않았어요',
          onClose: () => Navigator.of(ctx).pop(),
        ),
      );
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WishRoomEarnMomentScreen(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    final provider = context.watch<WishRoomProvider>();
    final adDone = provider.todayLimits.adCount;
    final adLimit = WishRoomTodayLimits.adDailyLimit;

    return WishRoomPouchBg(
      palette: palette,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    WishRoomPouchIconButton(
                      icon: Icons.close,
                      palette: palette,
                      onPressed: _finished
                          ? () => Navigator.of(context).maybePop()
                          : null,
                    ),
                    WishRoomPouchMonoLabel(
                      text: 'AD · 조용히 보기',
                      palette: palette,
                    ),
                    const SizedBox(width: 34),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              RotationTransition(
                                turns: _sigilCtrl,
                                child: WishRoomSigil(
                                  size: 220,
                                  color: palette.sigil,
                                  opacity: 0.28,
                                ),
                              ),
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: palette.card,
                                  border: Border.all(color: palette.line),
                                  boxShadow: [
                                    BoxShadow(
                                      color: palette.glowShadow,
                                      blurRadius: 24,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _finished
                                      ? Icons.check_rounded
                                      : Icons.play_arrow_rounded,
                                  color: palette.glow,
                                  size: 44,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _finished ? '조용히 다 지켜보셨어요' : '광고를 조용히 지켜보세요',
                          textAlign: TextAlign.center,
                          style: WishRoomText.h2(palette.fg),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _finished
                              ? '아래에서 조각을 담아 가세요'
                              : '$_remaining초 · 오늘 $adDone/$adLimit회',
                          style: WishRoomText.monoSm(palette.muted),
                        ),
                        const SizedBox(height: 20),
                        if (!_finished)
                          SizedBox(
                            width: 220,
                            child: LinearProgressIndicator(
                              value: 1 - (_remaining / _simulatedSeconds),
                              backgroundColor: palette.line,
                              color: palette.glow,
                              minHeight: 4,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                WishRoomPouchButton(
                  label: _finished ? '❖ 조각 담기' : '조용히 지켜보는 중',
                  primary: true,
                  palette: palette,
                  expand: true,
                  onPressed: _finished && !_requesting ? _handleClaim : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuietDialog extends StatelessWidget {
  const _QuietDialog({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    return Dialog(
      backgroundColor: palette.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: WishRoomText.body(palette.fg),
            ),
            const SizedBox(height: 18),
            WishRoomPouchButton(
              label: '알겠어요',
              primary: true,
              palette: palette,
              expand: true,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
