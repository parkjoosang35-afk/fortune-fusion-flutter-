import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shop/domain/shop_item_visuals.dart';
import '../application/wish_wall_provider.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_bg_atmosphere.dart';
import '../widgets/wish_room_buttons.dart';
import '../widgets/wish_room_candle.dart';
import '../widgets/wish_room_seal.dart';
import '../widgets/wish_room_seal_mapping.dart';
import 'wish_room_celebration_screen.dart';

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
/// - "✿ 이뤄졌어요" → [Phase02-A 클라이언트 연동] 서버에 실제 wishState/
///   fulfilledAt 필드가 생겼으므로, 로컬 확인 다이얼로그 →
///   [WishWallProvider.markWishFulfilled](서버 `PATCH /wishes/:id/fulfilled`,
///   지급+상태갱신을 하나의 트랜잭션으로 처리) → 08
///   [WishRoomCelebrationScreen]으로 push한다. 서버가 실제 지급한
///   grantedAmount를 반환하므로 더 이상 클라이언트가
///   [BlessingBagPolicyAdapter.earnWishFulfilledBonus]를 직접 호출하지
///   않는다(중복 지급 방지 — 서버 트랜잭션 안에서 이미 checkPolicyEligibility
///   로 건당 1회를 판정·지급함). 하드코딩됐던 `daysToFulfill=89`는 제거하고
///   [WishPost.createdAt] 기준 실제 경과일([_daysSince])을 그대로 넘겨준다.
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오늘은 이미 이 소원에 정성을 더했어요')));
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
    try {
      final result = await context.read<WishWallProvider>().markWishFulfilled(
        wish.id,
      );
      if (!mounted) return;
      setState(() => _wish = result.wish);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('성취 처리에 실패했습니다. 다시 시도해주세요.')),
      );
      return;
    }
    if (!mounted) return;
    // [Phase 01 · 2단계 · orphan 화면 연결] 지급된 복주머니 개수는
    // 08 Celebration 화면이 아니라 이 push 이전에 별도로 안내하지 않는다
    // — Celebration 화면 자체가 "성취"라는 큰 순간을 축하하는 전체화면
    // 연출이므로, 적립 안내를 위한 별도 스낵바를 겹쳐 띄우지 않는다
    // (기존 [_ReceivePanel._claim] 등 팝업형 흐름과 달리 이 흐름은 이미
    // 확인 다이얼로그를 거쳤으므로 추가 확인 UI가 필요 없다).
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WishRoomCelebrationScreen(
          wishText: wish.text,
          daysToFulfill: _daysSince,
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

    // [복주머니 확장 Phase03 — 인장/촛불 "실사용" 연결] 작성 시 선택한
    // sealItemCode/candleItemCode가 있으면 상점 카탈로그의 실제 글리프/색을
    // 사용하고, 없으면(미선택) 기존 카테고리 기반 기본값을 그대로 쓴다.
    final sealCode = wish.sealItemCode;
    final candleCode = wish.candleItemCode;
    final sealGlyph = sealCode != null
        ? sealVisualFor(sealCode).glyph
        : seal.glyph;
    final candleColor = candleCode != null
        ? candleColorFor(candleCode)
        : WishRoomColors.glow;

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
                      WishRoomIconButton(icon: '⋯', onPressed: _showMoreSheet),
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
                                WishRoomCandle(size: 90, color: candleColor),
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
                                    WishRoomPill(
                                      label: sealCode != null
                                          ? '$sealGlyph 인장'
                                          : seal.label,
                                    ),
                                    WishRoomPill(label: wish.categoryId.label),
                                    WishRoomPill(label: '$_daysSince일째'),
                                    // [복주머니 확장 Phase03 — 지킴 부적 보호
                                    // 배지, DECISION-004 합리적 판단] 자동
                                    // 지급 로직 없이 "적용 중" 표시로만
                                    // 실사용 의미를 부여한다.
                                    if (wish.talismanItemCode ==
                                        'talisman_guardian')
                                      const WishRoomPill(label: '🛡️ 지킴 보호 중'),
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
