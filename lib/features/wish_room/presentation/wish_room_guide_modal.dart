import 'package:flutter/material.dart';

import '../theme/wish_room_colors.dart';
import '../theme/wish_room_text_styles.dart';
import '../widgets/wish_room_sigils.dart';
import '../widgets/wish_room_pouch_widgets.dart';

/// 신통방통 소원방 · 사용 설명 팝업(4페이지 스와이프)
/// 출처: `handoff/GuideModal.jsx`
///
/// [showWishRoomGuideModal]로 바텀시트 형태로 띈다.
class WishRoomGuideModal extends StatefulWidget {
  const WishRoomGuideModal({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<WishRoomGuideModal> createState() => _WishRoomGuideModalState();
}

class _GuidePage {
  const _GuidePage({
    required this.label,
    required this.icon,
    required this.title,
    required this.body,
    required this.highlight,
  });

  final String label;
  final String icon; // pouch | candle | shard | ad
  final String title;
  final String body;
  final String highlight;
}

const _guidePages = [
  _GuidePage(
    label: 'GUIDE · 01 / 04',
    icon: 'pouch',
    title: '이곳은 모두 무료입니다',
    body: '결제는 없어요. 오직 정성의 흔적,\n달빛 조각(月光片)만 오갑니다.',
    highlight: '無料 · NO PAYMENT',
  ),
  _GuidePage(
    label: 'GUIDE · 02 / 04',
    icon: 'candle',
    title: '소원을 담고, 매일 밝힙니다',
    body: '두루마리에 소원을 적고 인장으로 봉인해요.\n촛불은 이루어질 때까지 함께 켜져있어요.',
    highlight: '願 · 봉인 · 밝히기',
  ),
  _GuidePage(
    label: 'GUIDE · 03 / 04',
    icon: 'shard',
    title: '조각은 활동으로 모여요',
    body: '오늘도 촛불 켜기, 함께 빌기, 소원 봉인 —\n작은 정성마다 조각이 쌓입니다.',
    highlight: '+1 · +2 · +5 · +50',
  ),
  _GuidePage(
    label: 'GUIDE · 04 / 04',
    icon: 'ad',
    title: '광고를 보면 조각을 더 얻어요',
    body: '하루 몇 번, 짧은 영상을 조용히 보면\n복주머니에 조각이 담깁니다. 그게 전부예요.',
    highlight: '☾ 광고 시청 · +3 ~ +10',
  ),
];

class _WishRoomGuideModalState extends State<WishRoomGuideModal> {
  int _page = 0;

  bool get _isLast => _page == _guidePages.length - 1;

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    final cur = _guidePages[_page];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [WishRoomColors.sheetGradientTop, WishRoomColors.sheetGradientBottom],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: WishRoomColors.sheetBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: WishRoomColors.sheetBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(cur.label, style: WishRoomText.monoSm(palette.muted)),
                WishRoomPouchIconButton(
                  icon: Icons.close,
                  palette: palette,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              child: Column(
                key: ValueKey(cur.title),
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GuideIcon(type: cur.icon, palette: palette),
                  const SizedBox(height: 20),
                  Text(
                    cur.title,
                    textAlign: TextAlign.center,
                    style: WishRoomText.h1(palette.fg).copyWith(
                      shadows: [Shadow(color: palette.glowShadow, blurRadius: 20)],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    cur.body,
                    textAlign: TextAlign.center,
                    style: WishRoomText.body(palette.muted).copyWith(height: 1.75),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: palette.glow.withValues(alpha: 0.10),
                      border: Border.all(color: palette.glow.withValues(alpha: 0.35)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(cur.highlight, style: WishRoomText.mono(palette.glow)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_guidePages.length, (i) {
                final on = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: on ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: on ? palette.glow : palette.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_page > 0)
                  Expanded(
                    child: WishRoomPouchButton(
                      label: '이전',
                      primary: false,
                      palette: palette,
                      expand: true,
                      onPressed: () => setState(() => _page -= 1),
                    ),
                  ),
                if (_page > 0) const SizedBox(width: 8),
                Expanded(
                  flex: _page > 0 ? 2 : 1,
                  child: WishRoomPouchButton(
                    label: _isLast ? '소원방 시작하기' : '다음',
                    primary: true,
                    palette: palette,
                    expand: true,
                    onPressed: () {
                      if (_isLast) {
                        widget.onFinished?.call();
                        Navigator.of(context).maybePop();
                      } else {
                        setState(() => _page += 1);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideIcon extends StatelessWidget {
  const _GuideIcon({required this.type, required this.palette});

  final String type;
  final WishRoomPaletteTokens palette;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case 'pouch':
        return SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _halo(palette),
              const WishRoomPouch(size: 100),
              Positioned(
                top: 10,
                right: 6,
                child: Transform.rotate(
                  angle: -10 * 3.14159 / 180,
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.glow,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: palette.glowShadow, blurRadius: 12)],
                    ),
                    child: Text(
                      '無',
                      style: TextStyle(
                        fontFamily: WishRoomText.fontDisplay,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: WishRoomColors.onGlowText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case 'candle':
        return SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              _halo(palette),
              const Positioned(bottom: 10, child: WishRoomCandle(size: 46)),
            ],
          ),
        );
      case 'shard':
        return SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _halo(palette),
              const Positioned(bottom: 6, left: 14, child: WishRoomShard(size: 22)),
              const Positioned(bottom: 8, right: 14, child: WishRoomShard(size: 18)),
              const WishRoomShard(size: 80),
            ],
          ),
        );
      case 'ad':
        return SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _halo(palette),
              WishRoomSigil(size: 110, color: palette.glow, opacity: 0.55),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: palette.glow,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: palette.glowShadow, blurRadius: 20)],
                ),
                child: Icon(Icons.play_arrow, color: WishRoomColors.onGlowText, size: 26),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: palette.glow.withValues(alpha: 0.15),
                    border: Border.all(color: palette.glow),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('+3', style: WishRoomText.mono(palette.glow)),
                      const SizedBox(width: 3),
                      const WishRoomShard(size: 9),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox(width: 120, height: 120);
    }
  }

  Widget _halo(WishRoomPaletteTokens palette) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [palette.glowShadow, palette.glowShadow.withValues(alpha: 0)],
          ),
        ),
      );
}

/// 바텀시트로 GuideModal을 띄운다.
Future<void> showWishRoomGuideModal(BuildContext context, {VoidCallback? onFinished}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: WishRoomColors.backdropColor,
    builder: (ctx) => WishRoomGuideModal(onFinished: onFinished),
  );
}
