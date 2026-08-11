import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/wish_item_model.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_common_buttons.dart';
import '../widgets/wish_room_sigil.dart';
import 'wish_room_prayer_flow.dart';

/// [디자인 핸드오프 8개 화면 재구현] 소원 성취 화면 — `ScreenCelebration` 스펙.
///
/// `wish-screens.jsx`(601-681줄) / README `8. Celebration` 정확한 값을
/// 그대로 재구현: full-bleed 방사형 배경(`--accent`→`--bg-1`→`--bg-2`) +
/// 겹쳐진 마법진 2개(640px `--glow` 정회전 + 400px `--fg` 역회전) + 14개
/// 떨어지는 꽃잎 → eyebrow "✿ FULFILLED ✿" → 히어로 글리프 "成" → 타이틀
/// "소원이 / 이루어졌어요" → 소원 본문(서브타이틀) → 날짜 pill("🕯 N일
/// 만에 이룬 소원") → CTA 2개(감사의 소원 남기기 / 소원방으로 돌아가기).
///
/// [연결 지점] README "Navigation": `Detail "✿ 이뤄졌어요" → Celebration`.
/// [WishDetailScreen]에서 `PrayerType.gratitude` 완료 처리가 성공하면 이
/// 화면으로 네비게이트한다(§ "기존 구현 삭제/재작성 금지" — 완료 처리
/// 로직 자체는 그대로 재사용, 여기서는 그 결과를 보여주는 화면만 추가).
///
/// [데이터 절충] JSX 데모 서브타이틀("엄마 무릎 수술이...")은 고정 예시
/// 문구다. 실제로는 완료된 소원의 실제 제목(`wish.title`)을 그대로 보여준다
/// — 새 재화/필드를 추가하지 않고 기존 [WishItem] 데이터만으로 완성한다.
/// "N일 만에 이룬 소원"의 N은 `wish.createdAt` 기준 경과일(파생값, 별도
/// 저장하지 않음).
///
/// [CTA 배선] "감사의 소원 남기기"는 이 화면 자체의 `ref`로 기존에 검증된
/// [WishRoomPrayerFlow.openWriteScreen](슬롯 부족 시 확장 안내까지 포함)을
/// 그대로 재사용해 새 소원 작성 화면을 연다(§ "기존 구현 삭제/재작성
/// 금지" — 새 작성 로직을 만들지 않고 이미 있는 흐름을 연결만 한다).
/// [WishDetailScreen]이 이미 pop된 뒤라 그 context/ref를 넘겨받지 않고,
/// [ConsumerWidget]으로 이 화면 자신의 살아있는 ref를 사용한다.
class WishCelebrationScreen extends ConsumerWidget {
  final WishItem wish;

  const WishCelebrationScreen({super.key, required this.wish});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = DateTime.now().difference(wish.createdAt).inDays;

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: Stack(
        children: [
          // ── full-bleed 방사형 배경 ──
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.2),
                  radius: 1.1,
                  colors: [
                    WishRoomColors.accent,
                    WishRoomColors.backgroundSoft,
                    WishRoomColors.backgroundDeep,
                  ],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          // ── 겹쳐진 마법진 2개(정회전 640px + 역회전 400px) ──
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: WishRoomSigilRing(
                  size: 640,
                  color: WishRoomColors.glow,
                  opacity: 0.6,
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: WishRoomSigilRing(
                  size: 400,
                  color: WishRoomColors.textPrimary,
                  opacity: 0.3,
                  reverse: true,
                ),
              ),
            ),
          ),
          // ── 떨어지는 꽃잎 14개 ──
          const Positioned.fill(
            child: IgnorePointer(child: _PetalFall(count: 14)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ── eyebrow ──
                  const Text(
                    '✿ FULFILLED ✿',
                    style: WishRoomTextStyles.eyebrowWide,
                  ),
                  // ── 히어로 글리프 + 타이틀 + 서브타이틀 + 날짜 pill ──
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '成',
                        style: TextStyle(
                          fontFamily: 'NotoSerifKRWish',
                          fontWeight: FontWeight.w900,
                          fontSize: 82,
                          height: 1.0,
                          color: WishRoomColors.glow,
                          shadows: [
                            Shadow(
                              color: WishRoomColors.glow.withValues(alpha: 0.7),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '소원이\n이루어졌어요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'NotoSerifKRWish',
                          fontWeight: FontWeight.w900,
                          fontSize: 30,
                          height: 1.2,
                          color: WishRoomColors.textPrimary,
                          shadows: [
                            Shadow(
                              color: WishRoomColors.glowShadow,
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        wish.title,
                        textAlign: TextAlign.center,
                        style: WishRoomTextStyles.bodySm.copyWith(
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: WishRoomColors.surfaceCard,
                          borderRadius: BorderRadius.circular(
                            WishRoomRadius.pill,
                          ),
                          border: Border.all(color: WishRoomColors.glow),
                        ),
                        child: Text(
                          '🕯 $days일 만에 이룬 소원',
                          style: WishRoomTextStyles.metaMono.copyWith(
                            color: WishRoomColors.glow,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // ── CTA 2개 ──
                  Column(
                    children: [
                      WishRoomPrimaryButton(
                        label: '감사의 소원 남기기',
                        onPressed: () {
                          Navigator.of(context).pop();
                          WishRoomPrayerFlow.openWriteScreen(context, ref);
                        },
                      ),
                      const SizedBox(height: 10),
                      WishRoomGhostButton(
                        label: '소원방으로 돌아가기',
                        onPressed: () => Navigator.of(context).pop(),
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
}

/// README 애니메이션표: `petal-fall 6s linear infinite`
/// (translateY 0→780px, rotate 0→720deg). 14개, 좌우 위치/지연/회전값은
/// JSX 원본과 동일한 결정론적 공식(`(i*11+5)%100`, `(i*0.4)%5`, `i*25`)을
/// 그대로 사용해 시각적으로 대응시킨다.
class _PetalFall extends StatefulWidget {
  final int count;

  const _PetalFall({required this.count});

  @override
  State<_PetalFall> createState() => _PetalFallState();
}

class _PetalFallState extends State<_PetalFall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _PetalPainter(
              count: widget.count,
              progress: _controller.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _PetalPainter extends CustomPainter {
  final int count;
  final double progress; // 0~1, 6초 주기 내 진행도

  _PetalPainter({required this.count, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < count; i++) {
      final leftFraction = (i * 11 + 5) % 100 / 100.0;
      final delayFraction = ((i * 0.4) % 5) / 6.0; // JSX: (i*0.4)%5 초 지연
      final rotStart = (i * 25) * (3.1415926535 / 180.0);

      final localT = ((progress - delayFraction) % 1.0 + 1.0) % 1.0;
      final dy = -20 + localT * (size.height + 40);
      final dx = leftFraction * size.width;
      final angle = rotStart + localT * (720 * 3.1415926535 / 180.0);

      final paint = Paint()
        ..color = (i % 2 == 1 ? WishRoomColors.accent : WishRoomColors.glow)
            .withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(angle);
      final rrect = RRect.fromRectAndCorners(
        const Rect.fromLTWH(-4, -6, 8, 12),
        topLeft: const Radius.elliptical(6.4, 9.6),
        bottomRight: const Radius.elliptical(6.4, 9.6),
        topRight: const Radius.elliptical(1.6, 2.4),
        bottomLeft: const Radius.elliptical(1.6, 2.4),
      );
      canvas.drawRRect(rrect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PetalPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
