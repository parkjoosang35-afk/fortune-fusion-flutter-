import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_wall_provider.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_bg_atmosphere.dart';
import '../widgets/wish_room_buttons.dart';
import '../widgets/wish_room_candle.dart';
import '../widgets/wish_room_seal.dart';
import '../widgets/wish_room_seal_mapping.dart';

/// 소원방(Wish Room) — 05. 소원 상세(Detail) 화면.
///
/// [디자인 핸드오프 — pixel-perfect 재현] `wish-screens.jsx`의
/// `ScreenDetail` 컴포넌트를 그대로 재구현한다: 상단 nav(←/`WISH · N°NN`/⋯)
/// → 히어로 캔들(90px+radial glow) → 소원카드(날짜eyebrow+본문+3 pill) →
/// 간절함 게이지(★★★★☆+progress bar) → 2개 액션(🔥 소원 더하기/✿ 이뤄졌어요)
/// → quote footer(dashed border).
///
/// [절충 결정 — 소셜기능 매핑]
/// - "🔥 소원 더하기" → 기존 무료 응원([WishWallProvider.support])에 매핑한다.
///   V2 원본에는 응원/기도/복주머니 3버튼이 없고 이 2버튼뿐이므로, 가장
///   유사한 무료 액션(응원=소원의 정성을 더함)에 대응시켰다(발명 최소화).
/// - "✿ 이뤄졌어요" → [WishPost]/[WishWallRepository] 모두 실제 "성취"
///   상태 필드가 없음(`updateWishStatus`는 no-op 스텁, 문서 §데이터 갭 참고).
///   따라서 이 화면은 로컬 확인 다이얼로그 → [BlessingBagPolicyAdapter
///   .earnWishFulfilledBonus] 적립 → 완료 스낵바로 자기완결적으로 처리한다
///   (03 Compose가 존재하지 않는 파일을 import해 컴파일 오류를 냈던 것과
///   동일한 실수를 피하기 위해, 아직 만들어지지 않은 08 Celebration 화면을
///   여기서 import/참조하지 않는다). 08 Celebration이 완성되면 라우팅
///   정리 단계(#10)에서 이 확인 다이얼로그의 "네, 이루었어요" 분기를
///   Celebration 화면으로 push하도록 교체할 수 있다.
/// - 간절함의 크기(★/progress) → [WishPost.glow](0.0~1.0, supportCount 기반
///   기존 계산식)를 그대로 재사용해 5단계 별점/게이지로 환산한다(새 필드
///   추가 없이 기존 데이터로 표현).
class WishRoomDetailScreen extends StatefulWidget {
  const WishRoomDetailScreen({super.key, required this.wishId, this.index = 1});

  final String wishId;

  /// 상단 "WISH · N°NN" 표시용 순번(1부터). 목록에서 넘어올 때 위치를
  /// 넘겨주면 표시되고, 없으면 기본값 1을 사용한다.
  final int index;

  @override
  State<WishRoomDetailScreen> createState() => _WishRoomDetailScreenState();
}

class _WishRoomDetailScreenState extends State<WishRoomDetailScreen> {
  WishPost? _wish;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wish = await context.read<WishWallProvider>().fetchDetail(
      widget.wishId,
    );
    if (!mounted) return;
    setState(() {
      _wish = wish;
      _loading = false;
    });
  }

  String get _dateLabel {
    final wish = _wish;
    if (wish == null) return '';
    final d = wish.createdAt;
    return '${d.year} · ${d.month.toString().padLeft(2, '0')} · '
        '${d.day.toString().padLeft(2, '0')} 봉인';
  }

  int get _daysSince {
    final wish = _wish;
    if (wish == null) return 0;
    return DateTime.now().difference(wish.createdAt).inDays + 1;
  }

  Future<void> _addWish() async {
    final wish = _wish;
    if (wish == null || _busy) return;
    if (wish.hasSupportedByMe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오늘은 이미 이 소원에 정성을 더했어요')),
      );
      return;
    }
    setState(() => _busy = true);
    final updated = await context.read<WishWallProvider>().support(wish.id);
    if (!mounted) return;
    setState(() {
      _wish = updated;
      _busy = false;
    });
  }

  Future<void> _markFulfilled() async {
    final wish = _wish;
    if (wish == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WishRoomColors.backgroundMid,
        title: const Text(
          '소원이 이루어졌나요?',
          style: TextStyle(
            fontFamily: 'NotoSerifKRWish',
            color: WishRoomColors.textPrimary,
          ),
        ),
        content: const Text(
          '"이뤄졌어요"를 누르면 이 소원을 성취로 기록하고\n감사 복주머니를 받아요.',
          style: TextStyle(color: WishRoomColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              '아직이에요',
              style: TextStyle(color: WishRoomColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '네, 이루었어요',
              style: TextStyle(color: WishRoomColors.glow),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final granted = await context
        .read<WishWallProvider>()
        .policy
        .earnWishFulfilledBonus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: WishRoomColors.backgroundMid,
        content: Text(
          granted > 0
              ? '✿ 소원이 이루어졌어요 · 복주머니 +$granted개'
              : '✿ 소원이 이루어졌어요',
          style: const TextStyle(
            fontSize: 13,
            color: WishRoomColors.textPrimary,
          ),
        ),
      ),
    );
  }

  void _showMoreSheet() {
    final wish = _wish;
    if (wish == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: WishRoomColors.backgroundMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: WishRoomColors.textPrimary,
                ),
                title: const Text(
                  '신고하기',
                  style: TextStyle(color: WishRoomColors.textPrimary),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await context.read<WishWallProvider>().reportWish(
                    wish.id,
                    wishReportReasons.first,
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.visibility_off_outlined,
                  color: WishRoomColors.textPrimary,
                ),
                title: const Text(
                  '이 소원 숨기기',
                  style: TextStyle(color: WishRoomColors.textPrimary),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await context.read<WishWallProvider>().hideWish(wish.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: WishRoomColors.backgroundDeep,
        body: Center(
          child: CircularProgressIndicator(color: WishRoomColors.glow),
        ),
      );
    }
    final wish = _wish;
    if (wish == null) {
      return Scaffold(
        backgroundColor: WishRoomColors.backgroundDeep,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    WishRoomIconButton(
                      icon: '←',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    '소원을 찾을 수 없어요',
                    style: TextStyle(color: WishRoomColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final seal = sealForCategory(wish.categoryId);
    final glow = wish.glow;
    final stars = (glow * 5).round().clamp(0, 5);

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: WishRoomBgAtmosphere(sigilSize: 420, sigilOpacity: 0.28),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      WishRoomIconButton(
                        icon: '←',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        'WISH · N°${widget.index.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontFamily: 'IBMPlexMonoWish',
                          fontSize: 10,
                          letterSpacing: 3.0,
                          color: WishRoomColors.textSecondary,
                        ),
                      ),
                      WishRoomIconButton(
                        icon: '⋯',
                        onPressed: _showMoreSheet,
                      ),
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Hero candle
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
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          WishRoomColors.glowShadow,
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const WishRoomCandle(size: 90),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Wish card
                          Container(
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
                                  _dateLabel,
                                  style: const TextStyle(
                                    fontFamily: 'IBMPlexMonoWish',
                                    fontSize: 10,
                                    letterSpacing: 3.0,
                                    color: WishRoomColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  wish.text,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'NotoSerifKRWish',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                    height: 1.5,
                                    color: WishRoomColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    WishRoomPill(label: seal.label),
                                    WishRoomPill(
                                      label: wish.categoryId.label,
                                    ),
                                    WishRoomPill(label: '$_daysSince일째'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Intention gauge
                          Container(
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      '간절함의 크기',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: WishRoomColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      List.generate(
                                        5,
                                        (i) => i < stars ? '★' : '☆',
                                      ).join(),
                                      style: const TextStyle(
                                        fontFamily: 'IBMPlexMonoWish',
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
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: glow.clamp(0.05, 1.0),
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
                                              color:
                                                  WishRoomColors.glowShadow,
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
                          const SizedBox(height: 14),
                          // Actions
                          Row(
                            children: [
                              Expanded(
                                child: WishRoomSecondaryButton(
                                  label: '🔥 소원 더하기',
                                  onPressed: _busy ? null : _addWish,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: WishRoomSecondaryButton(
                                  label: '✿ 이뤄졌어요',
                                  onPressed: _markFulfilled,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Quote footer (dashed border)
                          CustomPaint(
                            painter: _DashedRectPainter(
                              color: WishRoomColors.surfaceCardBorder,
                              radius: 12,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: WishRoomColors.surfaceCard,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
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
                        ],
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

/// 점선(dashed) 라운드 사각 테두리 — Flutter 기본 [Border]는 점선을
/// 지원하지 않아 `v2-shell.css`의 `border: 1px dashed var(--line)` 표현을
/// 위해 최소한의 커스텀 페인터를 둔다(이 화면에서만 사용, 재사용 필요 시
/// 향후 공용 위젯으로 승격 가능).
class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedRectPainter({required this.color, this.radius = 12});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashPath = Path();
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        dashPath.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + dashSpace;
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
