import 'package:flutter/material.dart';

import '../../wish_room/theme/wish_room_theme.dart';
import '../../wish_room/widgets/wish_room_dust.dart';

/// [상점 기획 결함 수정 — 구매 체감 애니메이션] 상점에서 아이템을 구매했을 때
/// "좋은 기운이 들어오는" 느낌을 주는 전면 오버레이 효과.
///
/// [배경] 기존에는 구매 성공 시 SnackBar 텍스트 한 줄이 전부였다(플랫한 시스템
/// 알림처럼 보여 "돈만 쓰고 아무 느낌도 없다"는 지적을 받음). 이 위젯은
/// [Overlay]에 직접 삽입되어 화면 전체를 은은하게 덮으며, 글로우 버스트 +
/// 아이템 글리프 확대 + 상승 먼지 + 문구를 순서대로 보여준 뒤 자동으로
/// 사라진다(사용자 입력 불필요, 흐름을 막지 않음).
///
/// 사용법: `showShopPurchaseEffect(context, glyph: ..., label: '옥 도장을 얻었어요')`
Future<void> showShopPurchaseEffect(
  BuildContext context, {
  required Widget glyph,
  required String label,
  String? sublabel,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = OverlayEntry(
    builder: (_) => _ShopPurchaseEffectOverlay(
      glyph: glyph,
      label: label,
      sublabel: sublabel,
    ),
  );
  overlay.insert(completer);
  // 전체 시퀀스(글로우 등장 → 유지 → 페이드아웃) 총 길이만큼 대기 후 제거.
  await Future.delayed(const Duration(milliseconds: 2000));
  completer.remove();
}

class _ShopPurchaseEffectOverlay extends StatefulWidget {
  const _ShopPurchaseEffectOverlay({
    required this.glyph,
    required this.label,
    this.sublabel,
  });

  final Widget glyph;
  final String label;
  final String? sublabel;

  @override
  State<_ShopPurchaseEffectOverlay> createState() =>
      _ShopPurchaseEffectOverlayState();
}

class _ShopPurchaseEffectOverlayState extends State<_ShopPurchaseEffectOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // 0.0~0.15: 글로우/글리프 등장(bounce). 0.15~0.75: 유지. 0.75~1.0: 페이드아웃.
          final entrance = Curves.elasticOut.transform(
            (t / 0.22).clamp(0.0, 1.0),
          );
          final scrimOpacity = t < 0.75
              ? (t / 0.15).clamp(0.0, 1.0) * 0.55
              : (0.55 * ((1 - t) / 0.25).clamp(0.0, 1.0));
          final contentOpacity = t < 0.08
              ? (t / 0.08).clamp(0.0, 1.0)
              : t > 0.78
              ? ((1 - t) / 0.22).clamp(0.0, 1.0)
              : 1.0;
          final glowPulse = 0.7 + 0.3 * (0.5 + 0.5 * (t * 6).remainder(1));

          return Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: scrimOpacity),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: contentOpacity.clamp(0.0, 1.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 글로우 버스트
                            Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    WishRoomColors.glow.withValues(
                                      alpha: 0.45 * glowPulse * entrance,
                                    ),
                                    WishRoomColors.glowShadow.withValues(
                                      alpha: 0.3 * entrance,
                                    ),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.4, 0.75],
                                ),
                              ),
                            ),
                            // 상승 먼지(기운이 들어오는 느낌)
                            const Positioned.fill(
                              child: WishRoomDust(
                                count: 14,
                                color: WishRoomColors.glow,
                                duration: Duration(milliseconds: 1600),
                              ),
                            ),
                            // 아이템 글리프(bounce 확대)
                            Transform.scale(
                              scale: 0.4 + 0.6 * entrance,
                              child: widget.glyph,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'GowunBatangWish',
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: WishRoomColors.textPrimary,
                          shadows: [
                            Shadow(color: Color(0xCC000000), blurRadius: 12),
                          ],
                        ),
                      ),
                      if (widget.sublabel != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.sublabel!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: WishRoomColors.glow,
                            shadows: [
                              Shadow(color: Color(0xCC000000), blurRadius: 8),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
