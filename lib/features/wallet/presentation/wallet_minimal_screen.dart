import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../mypage/presentation/theme/mypage_minimal_theme.dart';
import '../../fortune_ad/application/fortune_ad_provider.dart';
import '../../fortune_ad/domain/fortune_ad_model.dart';
import '../../fortune_ad/presentation/fortune_ad_watch_dialog.dart';
import '../application/wallet_provider.dart';
import '../domain/point_history_model.dart';

/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S03] 신규 "복주머니 지갑" 화면.
///
/// design_handoff_mypage_minimal.zip README §4 "S03 복주머니 지갑 ★강조
/// 화면" 스펙에 따른 전면 신규 화면이다. 기존 `WalletContent`/
/// `WalletScreen`(다크 `UnifiedColors` 톤)은 README §3-2 매핑표에 따라
/// 레이아웃이 크게 달라져(히어로 76px 잔액+회전 링, 네오브루털 쿠폰 카드,
/// 칩 필터 원장 등) 같은 파일을 리스킨하는 대신 새 파일로 작성했다 —
/// 기존 파일은 프로젝트 관례(다른 화면에서 재사용 가능하도록 보존)에 따라
/// 삭제하지 않는다. 대신 `/reward/wallet` 라우트(지갑 진입점, S01 지갑
/// 카드 포함 3곳에서 참조)가 이 화면을 가리키도록 app_router.dart만
/// 교체한다 — "복주머니" 하단탭(PouchBoxTabScreen)은 완전히 별개 기능이라
/// 이번 변경의 대상이 아니다.
///
/// 데이터 소스(변경 없음, 기존 Provider 재사용):
/// - [WalletProvider]: 잔액(balance), 내역(history)
/// - [FortuneAdProvider]: "광고 보고 복주머니 받기" 카드의 정책/오늘 시청
///   횟수. 지급 로직은 기존 [FortuneAdWatchDialog]를 그대로 호출한다(S04는
///   AdMob SDK 전체화면 광고와 결합된 별도 Dialog 상태머신이라 이번 S03
///   리뉴얼에서 내부 로직을 바꾸지 않는다 — §S02/S03 작업과 동일한
///   "로직은 그대로, 스킨만 교체/신규배치" 원칙).
class WalletMinimalScreen extends StatefulWidget {
  const WalletMinimalScreen({super.key});

  @override
  State<WalletMinimalScreen> createState() => _WalletMinimalScreenState();
}

enum _LedgerFilter { all, earn, spend }

class _WalletMinimalScreenState extends State<WalletMinimalScreen>
    with SingleTickerProviderStateMixin {
  _LedgerFilter _filter = _LedgerFilter.all;
  late final AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    // README §S03 히어로 배경: 250px 원형 링이 140초에 한 바퀴 회전.
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 140),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().load();
      context.read<FortuneAdProvider>().load();
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  Future<void> _refresh() => context.read<WalletProvider>().load();

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final adProvider = context.watch<FortuneAdProvider>();

    final filtered = _filterHistory(wallet.history, _filter);
    final grouped = _groupByDate(filtered);

    return Scaffold(
      backgroundColor: MyPageColors.paper,
      body: SafeArea(
        child: RefreshIndicator(
          color: MyPageColors.red,
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              // README "서브화면 공통 셸" 상단바: padding 52 12 10,
              // grid 44 1fr 44, 가운데 타이틀 17px/800.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 52, 12, 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 40,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: MyPageColors.ink,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          '복주머니 지갑',
                          textAlign: TextAlign.center,
                          style: MyPageTextStyles.header,
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  MyPageSpacing.subX,
                  6,
                  MyPageSpacing.subX,
                  120,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _Hero(
                      balance: wallet.balance,
                      isLoading: wallet.isLoading,
                      ringController: _ringController,
                    ),
                    const SizedBox(height: 28),
                    const Text('복주머니 더 받기', style: MyPageTextStyles.cardTitle),
                    const SizedBox(height: 10),
                    _EarnAdCard(ads: adProvider.ads),
                    const SizedBox(height: 14),
                    const _EarnCouponCard(),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pushNamed('/shrine'),
                        child: const Text(
                          '복주머니 사용하러 가기 ›',
                          style: TextStyle(
                            fontFamily: MyPageFonts.ui,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: MyPageColors.ink2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _LedgerFilterChips(
                      value: _filter,
                      onChanged: (f) => setState(() => _filter = f),
                    ),
                    const SizedBox(height: 14),
                    if (filtered.isEmpty)
                      const _LedgerEmptyState()
                    else
                      for (final group in grouped) ...[
                        _DateGroupLabel(label: group.label),
                        const SizedBox(height: 8),
                        for (final item in group.items) _LedgerTile(item: item),
                        const SizedBox(height: 6),
                      ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PointHistoryModel> _filterHistory(
    List<PointHistoryModel> source,
    _LedgerFilter filter,
  ) {
    switch (filter) {
      case _LedgerFilter.all:
        return source;
      case _LedgerFilter.earn:
        return source.where((e) => e.type == PointHistoryType.earn).toList();
      case _LedgerFilter.spend:
        return source.where((e) => e.type == PointHistoryType.spend).toList();
    }
  }

  List<_DateGroup> _groupByDate(List<PointHistoryModel> items) {
    final Map<String, List<PointHistoryModel>> map = {};
    final List<String> order = [];
    for (final item in items) {
      final key =
          '${item.createdAt.year}.${item.createdAt.month.toString().padLeft(2, '0')}.${item.createdAt.day.toString().padLeft(2, '0')}';
      if (!map.containsKey(key)) {
        map[key] = [];
        order.add(key);
      }
      map[key]!.add(item);
    }
    return order.map((key) {
      final d = map[key]!.first.createdAt;
      // README §S03 원장: "IBM Plex Mono 10px, letter-spacing .25em, 예
      // '2026 · 11 · 05'".
      final label =
          '${d.year} · ${d.month.toString().padLeft(2, '0')} · ${d.day.toString().padLeft(2, '0')}';
      return _DateGroup(label: label, items: map[key]!);
    }).toList();
  }
}

class _DateGroup {
  const _DateGroup({required this.label, required this.items});
  final String label;
  final List<PointHistoryModel> items;
}

/// README §S03 히어로: 福 도장(46×46, rotate -7°) + 76px/900 잔액 + "개" +
/// 라벨 + 배경 250px 회전 원형 링(福 祿 壽 喜).
class _Hero extends StatelessWidget {
  const _Hero({
    required this.balance,
    required this.isLoading,
    required this.ringController,
  });

  final int balance;
  final bool isLoading;
  final AnimationController ringController;

  String _comma(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 26),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 배경 회전 링(福 祿 壽 喜) — 140초 1회전.
            AnimatedBuilder(
              animation: ringController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: ringController.value * 2 * math.pi,
                  child: child,
                );
              },
              child: const SizedBox(
                width: 250,
                height: 250,
                child: _FuRingBackground(),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: -7 * math.pi / 180,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: MyPageColors.red,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x478B2C1F),
                          offset: Offset(0, 6),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '福',
                      style: TextStyle(
                        fontFamily: MyPageFonts.hanja,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: Color(0xFFFBF1DE),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: MyPageColors.red,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(_comma(balance), style: MyPageTextStyles.numXl),
                          const SizedBox(width: 4),
                          const Text(
                            '개',
                            style: TextStyle(
                              fontFamily: MyPageFonts.ui,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: MyPageColors.red,
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 4),
                const Text('보유 중인 복주머니', style: MyPageTextStyles.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 福 祿 壽 喜 4글자를 250px 원 둘레에 배치한 배경 링.
class _FuRingBackground extends StatelessWidget {
  const _FuRingBackground();

  static const _glyphs = ['福', '祿', '壽', '喜'];

  @override
  Widget build(BuildContext context) {
    const radius = 108.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        for (int i = 0; i < _glyphs.length; i++)
          Builder(
            builder: (context) {
              final angle = (i / _glyphs.length) * 2 * math.pi - math.pi / 2;
              final dx = radius * math.cos(angle);
              final dy = radius * math.sin(angle);
              return Transform.translate(
                offset: Offset(dx, dy),
                child: Text(
                  _glyphs[i],
                  style: const TextStyle(
                    fontFamily: MyPageFonts.hanja,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    color: Color(0x1F8B2C1F),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// README §S03 ① 광고 카드 `EarnAdCard` — 화면에서 가장 강한 요소.
/// 그라데이션 bg + shine 애니메이션 + "+3" 금색 강조 + "무료" 배지 +
/// 우하단 워터마크 "福". 관리자가 등록한 광고(복수 가능)를 순회해
/// 카드를 반복 렌더링한다(기존 `_FortuneAdCard` 다중화 로직과 동일).
class _EarnAdCard extends StatefulWidget {
  const _EarnAdCard({required this.ads});
  final List<FortuneAdModel> ads;

  @override
  State<_EarnAdCard> createState() => _EarnAdCardState();
}

class _EarnAdCardState extends State<_EarnAdCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    // README: "빛이 스치는 shine 애니메이션: 3.6초 반복"
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ads.isEmpty) {
      // 관리자가 광고를 하나도 등록/노출하지 않았다면 카드 자체를 숨긴다
      // (기존 `WalletContent`와 동일한 원칙).
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        for (int i = 0; i < widget.ads.length; i++) ...[
          _buildCard(context, widget.ads[i]),
          if (i != widget.ads.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildCard(BuildContext context, FortuneAdModel ad) {
    final reachedLimit = !ad.watchable && ad.todayRemainingCount <= 0;

    return GestureDetector(
      onTap: ad.watchable ? () => _watchAd(context, ad) : null,
      child: Opacity(
        opacity: reachedLimit ? 0.5 : 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.8, -1),
                end: Alignment(0.8, 1),
                colors: [
                  Color(0xFFB4372A),
                  Color(0xFF8B2C1F),
                  Color(0xFF6A1D14),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
              boxShadow: MyPageShadows.earn,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 우하단 워터마크 "福" 110px opacity .13.
                Positioned(
                  right: -16,
                  bottom: -28,
                  child: Text(
                    '福',
                    style: TextStyle(
                      fontFamily: MyPageFonts.hanja,
                      fontWeight: FontWeight.w900,
                      fontSize: 110,
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                  ),
                ),
                // shine 대각선 하이라이트 애니메이션(40~80% 구간 동안 지나감).
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _shineController,
                    builder: (context, child) {
                      final t = _shineController.value;
                      // 0.0~0.4: 보이지 않음, 0.4~0.8: 좌→우로 이동, 0.8~1.0: 보이지 않음.
                      double shineX;
                      if (t < 0.4 || t > 0.8) {
                        shineX = -2.0;
                      } else {
                        shineX = ((t - 0.4) / 0.4) * 3.0 - 1.5;
                      }
                      return ClipRect(
                        child: Align(
                          alignment: Alignment(shineX, 0),
                          widthFactor: 0.35,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.16),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Color(0xFFFFF7E8),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '광고 보고 복주머니 받기',
                            style: TextStyle(
                              fontFamily: MyPageFonts.ui,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: Color(0xFFFFF7E8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reachedLimit
                                ? '오늘은 모두 받았어요 · 내일 다시 만나요'
                                // README: "횟수·시간은 실제 정책 값으로
                                // 바꿔 주세요" — ad.watchSeconds/
                                // perUserDailyLimit 실제 값을 사용한다.
                                : '${ad.watchSeconds}초 광고 시청 · 하루 ${ad.perUserDailyLimit}번까지',
                            style: TextStyle(
                              fontFamily: MyPageFonts.ui,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: const Color(
                                0xFFFFF7E8,
                              ).withValues(alpha: 0.82),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    reachedLimit
                        ? const Icon(
                            Icons.check_rounded,
                            color: MyPageColors.gold2,
                            size: 28,
                          )
                        : Text(
                            '+${ad.rewardAmount}',
                            style: const TextStyle(
                              fontFamily: MyPageFonts.ui,
                              fontWeight: FontWeight.w900,
                              fontSize: 30,
                              color: MyPageColors.gold2,
                              shadows: [
                                Shadow(
                                  color: Color(0x75F6D77C),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
                // 우상단 "무료" 배지.
                if (!reachedLimit)
                  Positioned(
                    top: -6,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MyPageColors.gold2,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '무료',
                        style: TextStyle(
                          fontFamily: MyPageFonts.ui,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: Color(0xFF5E1A12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // S04(복주머니 광고, +3개)는 AdMob SDK 전체화면 광고와 결합된 별도
  // Dialog 상태머신(`FortuneAdWatchDialog` — starting/watching/verifying/
  // granted/error)이라, 이번 S03 리뉴얼에서는 기존 호출부를 그대로
  // 재사용한다(§S02와 동일한 "로직은 그대로" 원칙). S04 바텀시트 자체의
  // 시각 리스킨은 별도 작업으로 분리한다.
  Future<void> _watchAd(BuildContext context, FortuneAdModel ad) async {
    final walletProvider = context.read<WalletProvider>();
    final adProvider = context.read<FortuneAdProvider>();
    final result = await FortuneAdWatchDialog.show(context, ad: ad);
    if (!context.mounted) return;

    switch (result.outcome) {
      case FortuneAdWatchOutcome.granted:
        await walletProvider.load();
        await adProvider.refreshStatus(ad);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('복주머니가 열렸습니다! +${result.grantedAmount}개')),
          );
        }
        break;
      case FortuneAdWatchOutcome.cancelled:
        break;
      case FortuneAdWatchOutcome.failed:
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.errorMessage ?? '보상 지급에 실패했습니다.')),
          );
        }
        break;
    }
  }
}

/// README §S03 ② 쿠폰 카드 `EarnCouponCard` — 네오브루털 스타일
/// (2px solid ink 테두리 + 4px 4px 0 하드 섀도우), 누르면 섀도우가
/// 1px 1px 0 + translate(3,3)로 눌리는 애니메이션.
class _EarnCouponCard extends StatefulWidget {
  const _EarnCouponCard();

  @override
  State<_EarnCouponCard> createState() => _EarnCouponCardState();
}

class _EarnCouponCardState extends State<_EarnCouponCard> {
  bool _pressed = false;

  void _navigate(BuildContext context) {
    // README §4-S05: "직접 입력을 기본으로, QR은 보조 버튼" — 기존
    // `BokjuCouponScanScreen`이 카메라 실패 시 코드 직접입력으로 자동
    // 폴백하는 로직을 이미 갖고 있으므로(§3-2 매핑표 비고) 그대로 재사용한다.
    Navigator.of(context).pushNamed('/reward/coupon/scan');
  }

  @override
  Widget build(BuildContext context) {
    final offset = _pressed ? const Offset(3, 3) : Offset.zero;
    final shadow = _pressed
        ? MyPageShadows.couponPressed
        : MyPageShadows.coupon;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () => _navigate(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(offset.dx, offset.dy, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: MyPageColors.surface,
          border: Border.all(color: MyPageColors.ink, width: 2),
          borderRadius: BorderRadius.circular(22),
          boxShadow: shadow,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF3D27A),
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: Alignment.center,
              child: const Text(
                '券',
                style: TextStyle(
                  fontFamily: MyPageFonts.hanja,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: MyPageColors.red,
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('쿠폰 등록하기', style: MyPageTextStyles.cardTitle),
                  SizedBox(height: 4),
                  Text(
                    '받은 쿠폰 코드 입력 · QR 스캔',
                    style: TextStyle(
                      fontFamily: MyPageFonts.ui,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: MyPageColors.ink3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: MyPageColors.ink,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '등록 ›',
                style: TextStyle(
                  fontFamily: MyPageFonts.ui,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFFFFFAF0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// README §S03 원장: 칩 [전체][적립][사용], padding 8×14, pill, 13px/700.
/// 선택된 칩은 bg --mp-ink / fg paper.
class _LedgerFilterChips extends StatelessWidget {
  const _LedgerFilterChips({required this.value, required this.onChanged});

  final _LedgerFilter value;
  final ValueChanged<_LedgerFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip('전체', _LedgerFilter.all),
        const SizedBox(width: 8),
        _chip('적립', _LedgerFilter.earn),
        const SizedBox(width: 8),
        _chip('사용', _LedgerFilter.spend),
      ],
    );
  }

  Widget _chip(String label, _LedgerFilter filter) {
    final selected = value == filter;
    return GestureDetector(
      onTap: () => onChanged(filter),
      child: AnimatedContainer(
        duration: MyPageMotion.fade,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? MyPageColors.ink : MyPageColors.paper2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: MyPageFonts.ui,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? MyPageColors.paper : MyPageColors.ink2,
          ),
        ),
      ),
    );
  }
}

class _DateGroupLabel extends StatelessWidget {
  const _DateGroupLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: MyPageFonts.mono,
          fontWeight: FontWeight.w500,
          fontSize: 10,
          letterSpacing: 2.5,
          color: MyPageColors.ink3,
        ),
      ),
    );
  }
}

/// README §S03 원장 행: 34px 원형 글리프 + 제목 15px/800 + 출처 12px/600 +
/// 우측 금액(적립=빨강 "+10", 사용=ink2 "-5", 아이콘 bg 회색).
class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.item});
  final PointHistoryModel item;

  @override
  Widget build(BuildContext context) {
    final isEarn = item.type == PointHistoryType.earn;
    final timeLabel =
        '${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isEarn ? MyPageColors.redSoft : MyPageColors.paper2,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              isEarn ? Icons.add_rounded : Icons.remove_rounded,
              size: 18,
              color: isEarn ? MyPageColors.red : MyPageColors.ink3,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.reason,
                  style: MyPageTextStyles.row.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  timeLabel,
                  style: const TextStyle(
                    fontFamily: MyPageFonts.ui,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: MyPageColors.ink3,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isEarn ? '+' : '-'}${item.amount}',
            style: TextStyle(
              fontFamily: MyPageFonts.ui,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: isEarn ? MyPageColors.red : MyPageColors.ink2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerEmptyState extends StatelessWidget {
  const _LedgerEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 36,
            color: MyPageColors.ink3,
          ),
          const SizedBox(height: 10),
          const Text('아직 복주머니 내역이 없어요', style: MyPageTextStyles.caption),
        ],
      ),
    );
  }
}
