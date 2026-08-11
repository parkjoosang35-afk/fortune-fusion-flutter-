import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/wish_item_model.dart';
import '../../domain/enums/prayer_type.dart';
import '../providers/wish_room_providers.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_animations.dart';
import '../widgets/wish_room_background.dart';
import '../widgets/wish_room_candle.dart';
import '../widgets/wish_room_common_buttons.dart';
import 'wish_celebration_screen.dart';
import 'wish_room_prayer_flow.dart';

/// [디자인 핸드오프 8개 화면 재구현] 소원 상세 화면 — `ScreenDetail` 스펙.
///
/// `wish-screens.jsx`(311-410줄) / README `5. Wish Detail` 정확한 값을
/// 그대로 재구현: BgAtmosphere(420, 0.28) → Nav row(←/eyebrow "WISH ·
/// N°0X"/⋯) → Hero candle(90px + 200x200 radial glow) → 소원 카드(날짜
/// eyebrow + 타이틀 + pill 행) → Intention gauge 카드(★ 별점 + progress
/// bar) → Actions row(btnSecondary 2개: 🔥 소원 더하기 / ✿ 이뤄졌어요) →
/// 점선 인용구 박스.
///
/// [데이터 모델 절충] JSX 데모는 pill 3개("합격"/"공부"/"34일째")를
/// 보여주지만 [WishItem]에는 임의 태그 필드가 없다. 실제 데이터로 의미가
/// 통하는 2개만 사용한다: 카테고리 라벨(이모지+텍스트)과 "N일째"
/// (등록일 기준 경과일). 도장(Seal)과 마찬가지로 순수 표시용 파생값이며
/// 저장 데이터는 건드리지 않는다.
///
/// [Action 연결] "🔥 소원 더하기"는 기존에 테스트로 검증된
/// [WishRoomPrayerFlow.startPrayerFlow](치성 종류 선택 바텀시트 →
/// prayForWish)를 그대로 재사용한다(§ "기존 구현 삭제/재작성 금지").
/// "✿ 이뤄졌어요"는 [PrayerType.gratitude]로 감사 치성을 실행해 완료
/// 처리한다(정책표: 복주머니 소비 없이 완료 처리). 성공 시 README
/// Navigation 스펙("Detail '✿ 이뤄졌어요' → Celebration")대로
/// [WishCelebrationScreen]으로 이동한다.
class WishDetailScreen extends ConsumerStatefulWidget {
  final WishItem wish;

  /// 소원 목록 내 위치(0-base) — eyebrow "WISH · N°0X" 표기에 사용.
  final int index;

  const WishDetailScreen({super.key, required this.wish, required this.index});

  @override
  ConsumerState<WishDetailScreen> createState() => _WishDetailScreenState();
}

class _WishDetailScreenState extends ConsumerState<WishDetailScreen> {
  bool _isCompleting = false;

  /// growthStage(5단계) → 별점(1~5)으로 그대로 매핑.
  int get _starCount =>
      WishGrowthStage.values.indexOf(widget.wish.growthStage) + 1;

  Future<void> _handleAddIntention() async {
    final controller = ref.read(wishRoomControllerProvider.notifier);
    await WishRoomPrayerFlow.startPrayerFlow(
      context,
      ref,
      controller,
      forWish: widget.wish,
    );
  }

  Future<void> _handleFulfilled() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    final controller = ref.read(wishRoomControllerProvider.notifier);
    final success = await controller.prayForWish(
      wishId: widget.wish.id,
      type: PrayerType.gratitude,
    );
    if (!mounted) return;
    setState(() => _isCompleting = false);
    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WishCelebrationScreen(wish: widget.wish),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('처리 중 문제가 생겼어요. 잠시 후 다시 시도해주세요.')),
      );
    }
  }

  String _sealedDateLabel(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year} · $month · $day 봉인';
  }

  @override
  Widget build(BuildContext context) {
    final wish = widget.wish;
    final days = DateTime.now().difference(wish.createdAt).inDays;
    final eyebrowIndex = (widget.index + 1).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: WishRoomBackground(
              mainSigilSize: 420,
              mainSigilOpacity: 0.28,
            ),
          ),
          SafeArea(
            child: DramaticEntrance(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  WishRoomSpacing.md,
                  WishRoomSpacing.sm,
                  WishRoomSpacing.md,
                  WishRoomSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Nav row ──
                    Row(
                      children: [
                        WishRoomIconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            size: 18,
                            color: WishRoomColors.textSecondary,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        Text(
                          'WISH · N°$eyebrowIndex',
                          style: WishRoomTextStyles.eyebrow,
                        ),
                        const Spacer(),
                        WishRoomIconButton(
                          icon: const Icon(
                            Icons.more_horiz,
                            size: 18,
                            color: WishRoomColors.textSecondary,
                          ),
                          onPressed: () => _showMoreMenu(context),
                        ),
                      ],
                    ),
                    // ── Hero candle ──
                    SizedBox(
                      height: 180,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Positioned(
                            top: 0,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    WishRoomColors.glowShadow.withValues(
                                      alpha: 0.7,
                                    ),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.7],
                                ),
                              ),
                            ),
                          ),
                          const WishRoomCandle(size: 90),
                        ],
                      ),
                    ),
                    const SizedBox(height: WishRoomSpacing.md),
                    // ── Wish card ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: WishRoomColors.surfaceCard,
                        border: Border.all(
                          color: WishRoomColors.surfaceCardBorder,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _sealedDateLabel(wish.createdAt),
                            style: WishRoomTextStyles.eyebrow,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            wish.title,
                            textAlign: TextAlign.center,
                            style: WishRoomTextStyles.wishBodyDetail,
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              WishRoomPill(
                                label:
                                    '${wish.category.emoji} ${wish.category.label}',
                              ),
                              WishRoomPill(label: '$days일째'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: WishRoomSpacing.md),
                    // ── Intention gauge ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: WishRoomColors.surfaceCard,
                        border: Border.all(
                          color: WishRoomColors.surfaceCardBorder,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '간절함의 크기',
                                style: WishRoomTextStyles.bodySm.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '★' * _starCount + '☆' * (5 - _starCount),
                                style: const TextStyle(
                                  fontFamily: 'IBMPlexMonoWish',
                                  fontSize: 13,
                                  color: WishRoomColors.glow,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Container(
                              height: 6,
                              color: WishRoomColors.surfaceCardBorder,
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: wish.growthProgress.clamp(
                                  0.02,
                                  1.0,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        WishRoomColors.accent,
                                        WishRoomColors.glow,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: WishRoomColors.glowShadow,
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: WishRoomSpacing.md),
                    // ── Actions ──
                    Row(
                      children: [
                        Expanded(
                          child: WishRoomSecondaryButton(
                            label: '🔥 소원 더하기',
                            onPressed: _handleAddIntention,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: WishRoomSecondaryButton(
                            label: _isCompleting ? '처리 중...' : '✿ 이뤄졌어요',
                            onPressed: _isCompleting ? null : _handleFulfilled,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: WishRoomSpacing.xl),
                    // ── Quote footer ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: WishRoomColors.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CustomPaint(
                        painter: _DashedBorderPainter(
                          color: WishRoomColors.surfaceCardBorder,
                          radius: 12,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '"간절히 원하면, 온 우주가 도와준다"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'GowunBatangWish',
                              fontSize: 12,
                              height: 1.6,
                              color: WishRoomColors.textSecondary,
                            ),
                          ),
                        ),
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

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: WishRoomColors.backgroundMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WishRoomRadius.lg),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WishRoomSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                enabled: !widget.wish.isRepresentative,
                leading: const Icon(
                  Icons.star_outline,
                  color: WishRoomColors.textPrimary,
                ),
                title: Text(
                  widget.wish.isRepresentative ? '이미 대표 소원이에요' : '대표 소원으로 설정',
                  style: WishRoomTextStyles.bodyMd.copyWith(
                    color: WishRoomColors.textPrimary,
                  ),
                ),
                onTap: widget.wish.isRepresentative
                    ? null
                    : () async {
                        Navigator.of(sheetContext).pop();
                        final controller = ref.read(
                          wishRoomControllerProvider.notifier,
                        );
                        final success = await controller.setRepresentative(
                          widget.wish.id,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success ? '대표 소원으로 설정했어요' : '설정에 실패했어요',
                            ),
                          ),
                        );
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// css `border: 1px dashed var(--line)`를 재현하는 대시 테두리 페인터.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const dashWidth = 4.0;
    const dashGap = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
