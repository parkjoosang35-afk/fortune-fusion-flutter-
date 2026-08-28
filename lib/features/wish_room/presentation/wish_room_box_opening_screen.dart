import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_wall_provider.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_bg_atmosphere.dart';
import '../widgets/wish_room_buttons.dart';
import '../widgets/wish_room_dust.dart';

/// 소원방(Wish Room) — 07. 소원함 개봉(Box Opening) 화면.
///
/// [디자인 핸드오프 — pixel-perfect 재현] `wish-screens.jsx`의
/// `ScreenBoxOpening` 컴포넌트를 그대로 재구현한다: 상단 eyebrow("소원함이
/// 열립니다") → 중앙 오브젝트(pulse 발광 + 12줄 광선 + 나무상자(뚜껑/금속밴드
/// /자물쇠)+상승 먼지 16개) → 타이틀"봉인이 풀렸어요"+서브텍스트 →
/// CTA("확인하러 가기").
///
/// [절충 결정 — 진입 트리거]
/// - 원본 JSX에는 "며칠째 밝혔던 소원"의 일수가 하드코딩(140일)되어 있으나,
///   이 화면은 [wishAgeDays] 파라미터로 실제 값을 주입받아 문구를 채운다
///   (호출부가 실제 최고령 소원의 나이를 계산해 넘겨줄 수 있도록 함수형으로
///   설계 — 발명 없이 실데이터 연동 가능하게 열어둠, 기본값 7일).
/// - [BlessingBagPolicyAdapter.earnWeeklyBoxOpeningBonus] 자동 적립 —
///   04 Home의 `initState`가 `earnAltarVisitBonus()`를 자동 호출하는 것과
///   동일한 패턴을 따른다(주간 1회 제한은 서버가 판정, 이미 지급됐으면
///   grantedAmount=0 반환). 팝업(blessing_bag_bottom_sheet)의 "받기" 탭에도
///   같은 채널이 있으나 이 화면은 "소원함을 실제로 열었다"는 행위 자체가
///   트리거이므로 진입 시 자동 청구가 자연스럽다.
///
/// [Phase02-A 클라이언트 연동] 호출부(wish_room_home_screen)가 이미
/// `WishWallProvider.markBoxOpened(wishId)`를 push 직전에 호출해 서버
/// openedBoxAt을 기록하므로, 이 화면 자체는 별도로 opened API를 다시
/// 호출하지 않는다(idempotent 서버 API라 중복 호출해도 안전은 하지만,
/// "07 화면을 실제로 봤음"을 기록하는 책임은 호출부 1곳에만 두어
/// 책임 소재를 명확히 한다).
class WishRoomBoxOpeningScreen extends StatefulWidget {
  const WishRoomBoxOpeningScreen({
    super.key,
    this.wishAgeDays = 7,
    this.wish100DaysGrantedAmount = 0,
  });

  /// "N일 동안 밝혔던 당신의 소원이 하늘에 닿았습니다" 문구의 N.
  final int wishAgeDays;

  /// [소원방 마무리 - Phase B] 호출부(WishRoomHomeScreen)가
  /// `WishWallProvider.markBoxOpened`를 통해 이미 서버에서 확정 지급받은
  /// wish_100days(+30, 소원당 1회) 금액. 0이면 이 채널의 지급 없음(이미
  /// 지급됨 등)이므로 안내 문구를 표시하지 않는다.
  final int wish100DaysGrantedAmount;

  @override
  State<WishRoomBoxOpeningScreen> createState() =>
      _WishRoomBoxOpeningScreenState();
}

class _WishRoomBoxOpeningScreenState extends State<WishRoomBoxOpeningScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  int? _grantedAmount;

  @override
  void initState() {
    super.initState();
    // [anim-dramatic] pulse 2.4s ease-in-out 무한 반복.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _claimBonus());
  }

  Future<void> _claimBonus() async {
    final granted = await context
        .read<WishWallProvider>()
        .policy
        .earnWeeklyBoxOpeningBonus();
    if (!mounted) return;
    // [Phase B] 두 채널(weekly_box_opening + wish_100days)이 같은 화면
    // 진입에서 동시에 지급될 수 있으므로 합산해서 안내한다.
    setState(
      () => _grantedAmount = granted + widget.wish100DaysGrantedAmount,
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: WishRoomBgAtmosphere(sigilSize: 620, sigilOpacity: 0.55),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                children: [
                  const Text(
                    '소원함이 열립니다',
                    style: TextStyle(
                      fontFamily: 'IBMPlexMonoWish',
                      fontSize: 10,
                      letterSpacing: 4.0,
                      color: WishRoomColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 260,
                        height: 260,
                        child: AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, _) {
                            final t =
                                _pulse.value; // 0~1 (ease via curve below)
                            final glowOpacity = 0.6 + 0.3 * t;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Explosion of light (pulse)
                                Container(
                                  width: 260,
                                  height: 260,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        WishRoomColors.glow.withValues(
                                          alpha: glowOpacity,
                                        ),
                                        WishRoomColors.glowShadow,
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.3, 0.65],
                                    ),
                                  ),
                                ),
                                // Rays
                                CustomPaint(
                                  size: const Size(260, 260),
                                  painter: _RaysPainter(
                                    color: WishRoomColors.glow,
                                  ),
                                ),
                                // Wooden box
                                const _WoodenBox(),
                                // Rising particles
                                const Positioned.fill(
                                  child: WishRoomDust(
                                    count: 16,
                                    color: WishRoomColors.glow,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      const Text(
                        '봉인이 풀렸어요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'NotoSerifKRWish',
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          height: 1.3,
                          color: WishRoomColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${widget.wishAgeDays}일 동안 밝혔던\n당신의 소원이 하늘에 닿았습니다',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: WishRoomColors.textSecondary,
                        ),
                      ),
                      if (_grantedAmount != null && _grantedAmount! > 0) ...[
                        const SizedBox(height: 10),
                        Text(
                          '🎁 복주머니 +${_grantedAmount!}개',
                          style: const TextStyle(
                            fontFamily: 'IBMPlexMonoWish',
                            fontSize: 12,
                            letterSpacing: 1.0,
                            color: WishRoomColors.glow,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  WishRoomPrimaryButton(
                    label: '확인하러 가기',
                    onPressed: () => Navigator.of(context).pop(),
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

/// 12줄 광선 SVG(`<line>` 12개, `rotate({a})`)를 CustomPainter로 재구현.
class _RaysPainter extends CustomPainter {
  final Color color;

  const _RaysPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    for (int i = 0; i < 12; i++) {
      final a = (i / 12) * 2 * pi;
      final p1 = center;
      final p2 = center + Offset(sin(a) * 95, -cos(a) * 95);
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 나무상자(뚜껑/금속밴드/자물쇠) — JSX 인라인 style 레이어를 그대로 재현.
class _WoodenBox extends StatelessWidget {
  const _WoodenBox();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 124, // 뚜껑(24) + 몸통(100)까지 포함한 여유 높이
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 몸통
          Positioned(
            bottom: 0,
            child: Container(
              width: 150,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF6B4A2B), Color(0xFF3A2515)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                border: Border.all(color: const Color(0xFF2A1A0A)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Metal band (세로 50% 위치)
                  Positioned(
                    top: 44,
                    left: -4,
                    right: -4,
                    child: Container(
                      height: 6,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [WishRoomColors.accent, Color(0xFF8B3A2B)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Lock
                  Positioned(
                    top: 24,
                    left: 65,
                    child: Container(
                      width: 20,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFD4AF37), Color(0xFF8B6F1A)],
                        ),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFF2A1A0A)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Lid (뚜껑, perspective rotateX(-60deg) 근사 — 위쪽으로 살짝
          // 기울어진 사다리꼴로 표현).
          Positioned(
            bottom: 100,
            child: ClipPath(
              clipper: _LidClipper(),
              child: Container(
                width: 158,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF8B6A4A), Color(0xFF5B3A2B)],
                  ),
                  border: Border.all(color: const Color(0xFF2A1A0A)),
                  boxShadow: const [
                    BoxShadow(
                      color: WishRoomColors.glowShadow,
                      blurRadius: 12,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 뚜껑의 `perspective(200px) rotateX(-60deg)` 원근 기울임을 사다리꼴
/// 클리핑으로 근사(위쪽이 좁고 아래쪽이 넓은 형태로 "젖혀진" 느낌).
class _LidClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const inset = 14.0;
    return Path()
      ..moveTo(inset, 0)
      ..lineTo(size.width - inset, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
