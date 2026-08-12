import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/wish_room_provider.dart';
import '../../theme/wish_room_colors.dart';
import '../../theme/wish_room_text_styles.dart';
import '../../widgets/wish_room_sigils.dart';
import '../../widgets/wish_room_pouch_widgets.dart';
import 'wish_room_earn_moment_screen.dart';

/// 14. 보름달 이벤트(월 1회) — 출처: PouchScreens.jsx `ScreenFullMoon`
///
/// dev-spec §5 EarnEvent "만월×2월1회"에 대응. 하루/월 1회만 노출되는
/// 특수 보너스 화면으로, [WishRoomProvider.earnFullMoonBonus]를 호출해
/// 조각을 담고 [WishRoomEarnMomentScreen]으로 이동한다.
class WishRoomFullMoonScreen extends StatefulWidget {
  const WishRoomFullMoonScreen({super.key});

  @override
  State<WishRoomFullMoonScreen> createState() => _WishRoomFullMoonScreenState();
}

class _WishRoomFullMoonScreenState extends State<WishRoomFullMoonScreen>
    with TickerProviderStateMixin {
  late final AnimationController _orbit1;
  late final AnimationController _orbit2;
  late final AnimationController _orbit3;

  @override
  void initState() {
    super.initState();
    _orbit1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
    _orbit2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat(reverse: true);
    _orbit3 = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbit1.dispose();
    _orbit2.dispose();
    _orbit3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    final provider = context.watch<WishRoomProvider>();
    final claimed = provider.todayLimits.fullMoonClaimed;

    return Scaffold(
      backgroundColor: palette.bg2,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 1.0,
                  colors: [palette.glow.withValues(alpha: 0.5), palette.bg1, palette.bg2],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          Center(child: WishRoomSigil(size: 480, color: palette.glow, opacity: 0.5)),
          Positioned.fill(child: WishRoomDust(count: 18, color: palette.glow)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('FULL MOON · 만월의 밤', style: WishRoomText.monoSm(palette.muted)),
                  _buildMoon(palette),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '오늘 밤은\n보름달입니다',
                        textAlign: TextAlign.center,
                        style: WishRoomText.display1(palette.fg).copyWith(
                          fontSize: 26,
                          shadows: [Shadow(color: palette.glowShadow, blurRadius: 24)],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '자정까지 모든 조각이\n두 배로 담깁니다',
                        textAlign: TextAlign.center,
                        style: WishRoomText.body(palette.muted).copyWith(height: 1.7),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: palette.card,
                          border: Border.all(color: palette.glow),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const WishRoomShard(size: 13),
                            const SizedBox(width: 8),
                            Text(
                              '×2 · 06시간 남음',
                              style: WishRoomText.monoSm(palette.glow),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      WishRoomPouchButton(
                        label: claimed ? '오늘은 이미 담았어요' : '❖ 오늘의 조각 담기',
                        primary: true,
                        palette: palette,
                        expand: true,
                        onPressed: claimed ? null : () => _claim(context, provider),
                      ),
                      const SizedBox(height: 10),
                      WishRoomPouchButton(
                        label: '내일 다시 볼래요',
                        primary: false,
                        palette: palette,
                        expand: true,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoon(WishRoomPaletteTokens palette) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.3),
                colors: [
                  Color(0xFFFFF8ED),
                  Color(0xFFF0EAFF),
                  Color(0xFFD0BCE5),
                  Color(0xFF8B7DB5),
                ],
                stops: [0.0, 0.35, 0.75, 1.0],
              ),
              boxShadow: [
                BoxShadow(color: palette.glowShadow, blurRadius: 60),
                BoxShadow(color: palette.glowShadow.withValues(alpha: 0.5), blurRadius: 120),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 130 * 0.30,
                  left: 130 * 0.25,
                  child: _crater(12),
                ),
                Positioned(
                  top: 130 * 0.55,
                  left: 130 * 0.55,
                  child: _crater(18, h: 14),
                ),
                Positioned(
                  top: 130 * 0.40,
                  left: 130 * 0.65,
                  child: _crater(8),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _orbit1,
            builder: (context, _) => Positioned(
              top: 12,
              right: 20,
              child: Opacity(
                opacity: 0.6 + 0.4 * _orbit1.value,
                child: const WishRoomShard(size: 16),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _orbit2,
            builder: (context, _) => Positioned(
              bottom: 18,
              left: 14,
              child: Opacity(
                opacity: 0.6 + 0.4 * _orbit2.value,
                child: const WishRoomShard(size: 14),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _orbit3,
            builder: (context, _) => Positioned(
              top: 44,
              left: 4,
              child: Opacity(
                opacity: 0.6 + 0.4 * _orbit3.value,
                child: const WishRoomShard(size: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _crater(double w, {double? h}) => Container(
        width: w,
        height: h ?? w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.08),
        ),
      );

  Future<void> _claim(BuildContext context, WishRoomProvider provider) async {
    final result = await provider.earnFullMoonBonus();
    if (result != null && context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => WishRoomEarnMomentScreen(result: result)),
      );
    }
  }
}
