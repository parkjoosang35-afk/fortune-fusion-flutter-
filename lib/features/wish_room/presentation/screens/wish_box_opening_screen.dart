import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/models/wish_item_model.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_animations.dart';
import '../widgets/wish_room_background.dart';
import '../widgets/wish_room_common_buttons.dart';
import '../widgets/wish_room_dust.dart';

/// [디자인 핸드오프 8개 화면 재구현] 소원함 개봉 화면 — `ScreenBoxOpening` 스펙.
///
/// `wish-screens.jsx`(516-600줄) / README `7. Wish Box Opening` 정확한
/// 값을 그대로 재구현: BgAtmosphere(620, 0.55) → 상단 eyebrow "소원함이
/// 열립니다" → 260×260 중앙 애니메이션 스택(방사형 광폭발 펄스 + 12개
/// 광선 + 나무 상자(뚜껑/금속 밴드/자물쇠) + 상승 크리스탈 먼지 16개) →
/// 타이틀 "봉인이 풀렸어요" + 서브타이틀 + CTA "확인하러 가기".
///
/// [트리거 조건 — 대형 작업 pending 갭 해소] README "Navigation":
/// "When a wish's box unlock date passes (product decision — e.g., 100
/// days) → intercept next Home entrance with Wish Box Opening ceremony →
/// Detail". [WishItem] 모델에는 `unlockAt`/`status` 필드가 없고(§ "새
/// 재화 추가 금지" 원칙에 따라 새 영속 필드/재화를 추가하지 않는다), 이
/// 화면은 순수 표시용 파생 조건으로만 트리거한다: 소원 등록일
/// (`createdAt`) 기준 [kBoxUnlockDays](README 예시값 100일, 하드코딩된
/// "관리자 설정값"이 아니라 순수 UI 연출 발생 조건 — 복주머니/보상/재화와
/// 무관) 이상 경과하면 다음 Home 진입 시 1회 이 세리머니를 보여주고
/// Detail로 이어준다. 이미 보여준 소원은 앱 세션 동안(재시작 전까지)
/// [WishBoxOpeningTracker]에 기록해 반복 노출을 막는다 — 이 트래커는 순수
/// 클라이언트 세션 메모리이며 저장/재화/보상 판정에 전혀 관여하지 않는다.
const int kBoxUnlockDays = 100;

/// [세션 전용, 비영속] 이번 앱 세션 동안 이미 개봉 세리머니를 보여준
/// 소원 id 집합. 앱을 재시작하면 초기화되며, 저장 데이터(Hive/서버)에는
/// 전혀 쓰이지 않는다 — 순수히 "같은 세션에서 반복 노출하지 않기 위한"
/// UI 편의용 메모리다.
class WishBoxOpeningTracker {
  WishBoxOpeningTracker._();

  static final Set<String> _shownWishIds = <String>{};

  static bool hasShown(String wishId) => _shownWishIds.contains(wishId);

  static void markShown(String wishId) => _shownWishIds.add(wishId);

  @visibleForTesting
  static void resetForTest() => _shownWishIds.clear();
}

class WishBoxOpeningScreen extends StatelessWidget {
  final WishItem wish;
  final VoidCallback onConfirm;

  const WishBoxOpeningScreen({
    super.key,
    required this.wish,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final days = DateTime.now().difference(wish.createdAt).inDays;

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: WishRoomBackground(
              mainSigilSize: 620,
              mainSigilOpacity: 0.55,
            ),
          ),
          SafeArea(
            child: DramaticEntrance(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '소원함이 열립니다',
                      style: WishRoomTextStyles.eyebrowWide,
                    ),
                    const _BoxOpeningAnimationStack(),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '봉인이 풀렸어요',
                          textAlign: TextAlign.center,
                          style: WishRoomTextStyles.screenTitle,
                        ),
                        const SizedBox(height: WishRoomSpacing.sm),
                        Text(
                          '$days일 동안 밝혔던\n당신의 소원이 하늘에 닿았습니다',
                          textAlign: TextAlign.center,
                          style: WishRoomTextStyles.bodySm.copyWith(
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: WishRoomPrimaryButton(
                        label: '확인하러 가기',
                        onPressed: onConfirm,
                      ),
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

/// 260×260 중앙 애니메이션 스택: 광폭발 펄스(2.4s ease-in-out infinite,
/// scale 1→1.08→1) + 12개 광선 + 나무 상자 + 상승 크리스탈 먼지 16개.
class _BoxOpeningAnimationStack extends StatefulWidget {
  const _BoxOpeningAnimationStack();

  @override
  State<_BoxOpeningAnimationStack> createState() =>
      _BoxOpeningAnimationStackState();
}

class _BoxOpeningAnimationStackState extends State<_BoxOpeningAnimationStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── 광폭발 펄스 ──
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final scale = 1.0 + 0.08 * _pulseController.value;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          WishRoomColors.glow.withValues(alpha: 0.9),
                          WishRoomColors.glowShadow,
                          WishRoomColors.glow.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.3, 0.65],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // ── 12개 광선 ──
          const _LightRays(),
          // ── 나무 상자 ──
          const _WoodenBox(),
          // ── 상승 크리스탈 먼지 16개 ──
          const Positioned.fill(
            child: IgnorePointer(
              child: WishRoomDust(count: 16, color: WishRoomColors.glow),
            ),
          ),
        ],
      ),
    );
  }
}

class _LightRays extends StatelessWidget {
  const _LightRays();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: CustomPaint(painter: _RaysPainter()),
    );
  }
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = WishRoomColors.glow.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    for (int i = 0; i < 12; i++) {
      final a = (i / 12) * 2 * pi - pi / 2;
      final start = Offset(center.dx, center.dy);
      final end = Offset(center.dx + cos(a) * 95, center.dy + sin(a) * 95);
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter oldDelegate) => false;
}

/// 나무 상자(150×100): 몸체 그라디언트 + 위로 열린 뚜껑(perspective 근사) +
/// 중앙 금속 밴드 + 금색 자물쇠.
class _WoodenBox extends StatelessWidget {
  const _WoodenBox();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 124,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 뚜껑(열려서 위로 기울어진 패널) — perspective rotateX 근사를
          // Transform으로 표현.
          Positioned(
            top: 0,
            left: -4,
            right: -4,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateX(-1.0),
              child: Container(
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF8B6A4A), Color(0xFF5B3A2B)],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  border: Border.all(color: const Color(0xFF2A1A0A)),
                  boxShadow: [
                    BoxShadow(
                      color: WishRoomColors.glowShadow,
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 상자 몸체
          Positioned(
            top: 24,
            left: 0,
            right: 0,
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
                clipBehavior: Clip.none,
                children: [
                  // 중앙 금속 밴드
                  Positioned(
                    top: 50 - 3,
                    left: -4,
                    right: -4,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [WishRoomColors.accent, Color(0xFF8B3A2B)],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 자물쇠
                  Positioned(
                    top: 30,
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
        ],
      ),
    );
  }
}
