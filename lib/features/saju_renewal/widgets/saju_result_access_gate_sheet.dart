import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_toast.dart';
import '../../ads_test/domain/admob_ad_ids.dart';
import '../../pass/presentation/coupang_pass_sheet.dart';
import '../../pouch_box/presentation/widgets/mini_pouch_icon.dart';
import '../../result_access/application/result_access_provider.dart';
import '../../result_access/data/result_access_repository.dart';
import '../../result_access/domain/pending_result_access_return.dart';
import '../../result_access/domain/result_access_model.dart';
import '../theme/saju_dark_tokens.dart';
import 'saju_base_widgets.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 디자인 핸드오프] 화면06 결과보기 게이트.
/// `docs/02_컴포넌트.md` C-12 · `docs/03_화면명세.md` §06 사양을 그대로
/// 재현한다.
///
/// [로직 재사용 원칙 — docs/10 §2 "로직은 재사용, 외형은 C-12로 교체
/// 필수. 기존 시트 외형 그대로면 검수 반려"] 이 위젯은 기존
/// [ResultAccessGateSheet]가 쓰던 [ResultAccessProvider](quote 조회 ·
/// begin 호출 · AdMob RewardedAd 로드/표시 · 서버 재검증)와
/// [showCoupangPassSheet]/[PendingResultAccessReturnStore]를 **그대로**
/// 호출한다 — 판정·차감·광고 로직을 다시 구현하지 않는다. 바뀌는 것은
/// 오직 비주얼(다크 바텀시트, 인용 마스킹 카드, GateOption 3행, 금빛
/// 프리패스 인장)뿐이다.
class SajuResultAccessGateSheet extends StatefulWidget {
  const SajuResultAccessGateSheet({
    super.key,
    required this.contentId,
    required this.contentTitle,
    required this.quoteText,
    this.returnRoute = '/saju-renewal',
  });

  final String? contentId;
  final String contentTitle;

  /// 인용 카드에 쓸 문장(summary의 마지막 문장, C-06-8). null/빈 문자열이면
  /// 인용 카드 자체를 생략한다.
  final String? quoteText;
  final String returnRoute;

  @override
  State<SajuResultAccessGateSheet> createState() =>
      _SajuResultAccessGateSheetState();
}

/// 06-D/06-E "수단 사용 중" 오버레이 연출 종류.
enum _UsingOverlay { none, pass, pouch }

class _SajuResultAccessGateSheetState
    extends State<SajuResultAccessGateSheet> {
  ResultAccessPaymentMethod? _processingMethod;
  bool _launchingCoupang = false;
  _UsingOverlay _overlay = _UsingOverlay.none;

  bool get _busy =>
      _processingMethod != null ||
      _launchingCoupang ||
      _overlay != _UsingOverlay.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuote());
  }

  Future<void> _loadQuote() async {
    await context.read<ResultAccessProvider>().loadQuote(
      contentType: 'saju_renewal',
      categoryKey: 'saju_renewal',
    );
  }

  Future<void> _beginAndClose(
    ResultAccessPaymentMethod method, {
    String? adSessionId,
  }) async {
    final provider = context.read<ResultAccessProvider>();
    final transactionId = generateResultAccessTransactionId();
    final result = await provider.begin(
      transactionId: transactionId,
      contentType: 'saju_renewal',
      contentId: widget.contentId,
      categoryKey: 'saju_renewal',
      paymentMethod: method,
      adSessionId: adSessionId,
    );
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _processingMethod = null;
        _overlay = _UsingOverlay.none;
      });
      AppToast.show(context, provider.lastError ?? '결과보기에 실패했습니다.', isError: true);
      return;
    }
    Navigator.of(context).pop(result);
  }

  /// 06-D 프리패스 사용 연출 — "通" 인장 1.2s 후 07로(=시트 close).
  Future<void> _handleFreePass() async {
    if (_busy) return;
    setState(() {
      _processingMethod = ResultAccessPaymentMethod.freepass;
      _overlay = _UsingOverlay.pass;
    });
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    await _beginAndClose(ResultAccessPaymentMethod.freepass);
  }

  /// 06-E 복주머니 사용 연출 — 개봉 1.4s 후 07로.
  Future<void> _handlePouch() async {
    if (_busy) return;
    setState(() {
      _processingMethod = ResultAccessPaymentMethod.pouch;
      _overlay = _UsingOverlay.pouch;
    });
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    await _beginAndClose(ResultAccessPaymentMethod.pouch);
  }

  Future<void> _handleAd() async {
    if (_busy) return;
    if (!AdmobAdIds.isSupportedPlatform) {
      AppToast.show(context, '이 플랫폼(Web 등)에서는 광고를 지원하지 않아요.', isError: true);
      return;
    }
    setState(() => _processingMethod = ResultAccessPaymentMethod.ad);

    final provider = context.read<ResultAccessProvider>();
    final sessionId = await provider.startAdSession();
    if (!mounted) return;
    if (sessionId == null) {
      setState(() => _processingMethod = null);
      AppToast.show(context, provider.lastError ?? '광고를 시작할 수 없어요.', isError: true);
      return;
    }

    var earned = false;
    RewardedAd.load(
      adUnitId: AdmobAdIds.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) async {
              ad.dispose();
              if (!mounted) return;
              if (!earned) {
                setState(() => _processingMethod = null);
                AppToast.show(context, '광고를 끝까지 시청해야 무료로 볼 수 있어요.', isError: true);
                return;
              }
              final completed = await provider.completeAdSession(sessionId);
              if (!mounted) return;
              if (!completed) {
                setState(() => _processingMethod = null);
                AppToast.show(
                  context,
                  provider.lastError ?? '광고 시청 완료 처리에 실패했습니다.',
                  isError: true,
                );
                return;
              }
              await _beginAndClose(
                ResultAccessPaymentMethod.ad,
                adSessionId: sessionId,
              );
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (!mounted) return;
              setState(() => _processingMethod = null);
              AppToast.show(context, '광고 표시에 실패했어요. 잠시 후 다시 시도해주세요.', isError: true);
            },
          );
          ad.show(
            onUserEarnedReward: (ad, reward) {
              earned = true;
            },
          );
        },
        onAdFailedToLoad: (error) {
          if (!mounted) return;
          setState(() => _processingMethod = null);
          AppToast.show(context, '지금은 광고를 불러올 수 없어요. 잠시 후 다시 시도해주세요.', isError: true);
        },
      ),
    );
  }

  Future<void> _handleCoupangClaim() async {
    if (_busy) return;
    setState(() => _launchingCoupang = true);

    await PendingResultAccessReturnStore.save(
      PendingResultAccessReturn(
        contentType: 'saju_renewal',
        contentId: widget.contentId,
        selectedCategory: null,
        question: null,
        userInput: const {},
        resultRequestId: null,
        returnRoute: widget.returnRoute,
        savedAt: DateTime.now(),
        contentTitle: widget.contentTitle,
        categoryKey: 'saju_renewal',
      ),
    );
    if (!mounted) return;

    await showCoupangPassSheet(context, categoryTitle: widget.contentTitle);

    await PendingResultAccessReturnStore.clear();
    if (!mounted) return;
    setState(() => _launchingCoupang = false);
    await _loadQuote();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResultAccessProvider>();
    return Stack(
      children: [
        SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [SajuViolet.v800, SajuInk.i900],
                stops: [0.0, 0.7],
              ),
              border: const Border(
                top: BorderSide(color: SajuText.lineGold),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 40,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. 그랩바.
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: SajuText.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 2. 인용 카드(C-06-8) — 마지막 문장 마스킹.
                if (widget.quoteText != null && widget.quoteText!.isNotEmpty)
                  _QuoteCard(text: widget.quoteText!),
                if (widget.quoteText != null && widget.quoteText!.isNotEmpty)
                  const SizedBox(height: 18),
                // 3. 타이틀(C-06-1).
                const Text(
                  '이 사주 이야기를\n더 깊이 알아볼까요?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: SajuType.serif,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    height: 1.45,
                    color: SajuGold.g100,
                  ),
                ),
                const SizedBox(height: 16),
                // 4. 부제(C-06-2).
                const Text(
                  '아래 3가지 중 하나로 열 수 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: SajuType.ui,
                    fontSize: 12.5,
                    color: SajuText.muted,
                  ),
                ),
                const SizedBox(height: 20),
                if (provider.isLoadingQuote)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: CircularProgressIndicator(color: SajuGold.g300),
                    ),
                  )
                else if (provider.quote == null)
                  _buildLoadError(provider)
                else
                  _buildOptions(provider.quote!),
              ],
            ),
          ),
        ),
        // 06-D/06-E "수단 사용 중" 전체 오버레이.
        if (_overlay != _UsingOverlay.none)
          Positioned.fill(
            child: _UsingOverlayView(kind: _overlay),
          ),
      ],
    );
  }

  Widget _buildLoadError(ResultAccessProvider provider) {
    final needsLogin = provider.lastErrorReason == 'UNAUTHORIZED';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              if (needsLogin) ...[
                const Text('🔒', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 10),
              ],
              Text(
                needsLogin
                    ? '로그인 후 결과보기를 이용할 수 있어요.'
                    : (provider.lastError ?? '결과보기 권한 정보를 불러오지 못했습니다.'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: SajuType.ui,
                  fontSize: 14,
                  color: SajuText.fg2,
                ),
              ),
            ],
          ),
        ),
        SajuButton(
          label: needsLogin ? '로그인하고 결과보기' : '다시 시도',
          height: 48,
          onTap: needsLogin ? _handleLoginRequired : _loadQuote,
        ),
      ],
    );
  }

  Future<void> _handleLoginRequired() async {
    await PendingResultAccessReturnStore.save(
      PendingResultAccessReturn(
        contentType: 'saju_renewal',
        contentId: widget.contentId,
        selectedCategory: null,
        question: null,
        userInput: const {},
        resultRequestId: null,
        returnRoute: widget.returnRoute,
        savedAt: DateTime.now(),
        contentTitle: widget.contentTitle,
        categoryKey: 'saju_renewal',
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed('/login');
  }

  Widget _buildOptions(ResultAccessQuote quote) {
    final showCoupangClaim = !quote.freePassAvailable && !quote.todayClaimed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GateOption(
          leading: _PassMarkIcon(dim: !quote.freePassAvailable),
          title: quote.freePassAvailable ? '프리패스로 보기' : '프리패스로 보기',
          subtitle: quote.freePassAvailable
              ? null
              : '보유한 프리패스가 없어요',
          trailing: quote.freePassHasLegacyUnlimited &&
                  quote.freePassRemaining <= 0
              ? null
              : '보유 ${quote.freePassRemaining}회',
          enabled: quote.freePassAvailable && !_busy,
          loading: _processingMethod == ResultAccessPaymentMethod.freepass,
          onTap: _handleFreePass,
        ),
        const SizedBox(height: 8),
        _GateOption(
          leading: const MiniPouchIcon(size: 30),
          title: '복주머니로 보기',
          subtitle: quote.pouchAvailable && quote.pouchSufficient
              ? null
              : '${quote.pouchPrice}개가 필요해요',
          trailing: '보유 ${quote.pouchBalance}개',
          enabled: quote.pouchAvailable && quote.pouchSufficient && !_busy,
          loading: _processingMethod == ResultAccessPaymentMethod.pouch,
          onTap: _handlePouch,
        ),
        const SizedBox(height: 8),
        _GateOption(
          leading: const _AdIcon(),
          title: '광고 보고 무료로 보기',
          subtitle: '짧은 광고 한 편이면 열려요',
          trailing: '무료',
          enabled: quote.adAvailable && AdmobAdIds.isSupportedPlatform && !_busy,
          loading: _processingMethod == ResultAccessPaymentMethod.ad,
          onTap: _handleAd,
        ),
        if (showCoupangClaim) ...[
          const SizedBox(height: 16),
          Container(height: 1, color: SajuText.line),
          const SizedBox(height: 14),
          SajuButton(
            label: '오늘의 프리패스 2회 받기',
            loading: _launchingCoupang,
            leading: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF3A2A12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '通',
                style: TextStyle(
                  fontFamily: SajuType.serif,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: SajuGold.g300,
                ),
              ),
            ),
            onTap: _busy ? null : _handleCoupangClaim,
          ),
          const SizedBox(height: 8),
          const Text(
            '쿠팡 방문 시 하루 한 번 받을 수 있어요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: SajuType.ui,
              fontSize: 11.5,
              color: SajuText.faint,
            ),
          ),
        ] else if (!quote.freePassAvailable && quote.todayClaimed)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              '오늘의 프리패스를 받았어요 · 내일 다시 받을 수 있어요',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: SajuType.ui,
                fontSize: 12,
                color: SajuText.faint,
              ),
            ),
          ),
      ],
    );
  }
}

/// 인용 카드 — 미리보기 마지막 문장 + 오른쪽 마스크(텍스트가 가려지는 연출).
class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SajuText.line),
        color: SajuText.fg.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.black, Colors.black, Colors.transparent],
              stops: [0.0, 0.45, 0.92],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: Text(
              '"$text"',
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: const TextStyle(
                fontFamily: SajuType.body,
                fontSize: 14,
                height: 1.65,
                color: SajuText.fg2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('◆', style: TextStyle(color: SajuGold.g500, fontSize: 8)),
              const SizedBox(width: 6),
              const Text(
                '정통사주 분석',
                style: TextStyle(
                  fontFamily: SajuType.ui,
                  fontSize: 11,
                  color: SajuGold.g500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 프리패스 아이콘 — 36×36 r9, radial 금빛 그라데이션, "通" 각인, −6° 회전.
class _PassMarkIcon extends StatelessWidget {
  const _PassMarkIcon({this.dim = false});
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -6 * 3.14159265 / 180,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: dim
                ? [SajuGold.g500.withValues(alpha: 0.35), SajuInk.i800]
                : const [SajuGold.g100, SajuGold.g300, SajuGold.g500],
            stops: dim ? const [0.0, 1.0] : const [0.0, 0.45, 1.0],
          ),
        ),
        child: Text(
          '通',
          style: TextStyle(
            fontFamily: SajuType.serif,
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: dim ? SajuText.faint : const Color(0xFF3A2A12),
          ),
        ),
      ),
    );
  }
}

class _AdIcon extends StatelessWidget {
  const _AdIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: SajuText.lineGold),
      ),
      child: const Text('☾', style: TextStyle(color: SajuGold.g300, fontSize: 16)),
    );
  }
}

/// GateOption — 최소 높이 64 · r14 · 배경 5%(비활성 2%) · 보더 line.gold.
class _GateOption extends StatefulWidget {
  const _GateOption({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final String? trailing;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  State<_GateOption> createState() => _GateOptionState();
}

class _GateOptionState extends State<_GateOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: disabled ? null : widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: disabled
                  ? SajuText.fg.withValues(alpha: 0.02)
                  : SajuText.fg.withValues(alpha: 0.05),
              border: Border.all(color: SajuText.lineGold),
            ),
            child: Row(
              children: [
                widget.leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontFamily: SajuType.body,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: SajuGold.g100,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle!,
                          style: const TextStyle(
                            fontFamily: SajuType.ui,
                            fontSize: 12,
                            color: SajuText.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SajuGold.g300,
                    ),
                  )
                else if (widget.trailing != null)
                  Text(
                    widget.trailing!,
                    style: TextStyle(
                      fontFamily: SajuType.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: disabled ? SajuText.faint : SajuGold.g300,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 06-D/06-E 수단 사용 중 전체화면 오버레이 — 프리패스 "通" 인장 모션 /
/// 복주머니 개봉 모션.
class _UsingOverlayView extends StatefulWidget {
  const _UsingOverlayView({required this.kind});
  final _UsingOverlay kind;

  @override
  State<_UsingOverlayView> createState() => _UsingOverlayViewState();
}

class _UsingOverlayViewState extends State<_UsingOverlayView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPass = widget.kind == _UsingOverlay.pass;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 0.9,
          colors: [
            SajuViolet.v800.withValues(alpha: 0.96),
            SajuInk.i900.withValues(alpha: 0.98),
          ],
          stops: const [0.0, 0.7],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                final scale = isPass
                    ? (1.8 - 0.8 * Curves.easeOutBack.transform(t.clamp(0, 1)))
                    : (0.6 + 0.4 * Curves.elasticOut.transform(t.clamp(0, 1)));
                return Transform.scale(
                  scale: scale.clamp(0.4, 2.0),
                  child: isPass
                      ? Container(
                          width: 96,
                          height: 96,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                SajuGold.g100,
                                SajuGold.g300,
                                SajuGold.g500,
                              ],
                              stops: [0.0, 0.45, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: SajuGold.g300.withValues(alpha: 0.7),
                                blurRadius: 36,
                              ),
                            ],
                          ),
                          child: const Text(
                            '通',
                            style: TextStyle(
                              fontFamily: SajuType.serif,
                              fontWeight: FontWeight.w900,
                              fontSize: 42,
                              color: Color(0xFF3A2A12),
                            ),
                          ),
                        )
                      : const MiniPouchIcon(size: 130),
                );
              },
            ),
            const SizedBox(height: 28),
            Text(
              isPass ? '프리패스로 이야기를 열고 있어요' : '복주머니를 열고 있어요',
              style: const TextStyle(
                fontFamily: SajuType.body,
                fontSize: 16,
                color: SajuGold.g100,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPass ? '프리패스 1회를 사용해요' : '복주머니 100개를 사용해요',
              style: const TextStyle(
                fontFamily: SajuType.ui,
                fontSize: 12,
                color: SajuText.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [호출 헬퍼] 정통사주 다크 게이트 바텀시트를 띄운다. 성공 시
/// [ResultAccessBeginResult]를 반환, 취소/닫힘이면 null.
Future<ResultAccessBeginResult?> showSajuResultAccessGateSheet(
  BuildContext context, {
  String? contentId,
  required String contentTitle,
  String? quoteText,
  String returnRoute = '/saju-renewal',
}) {
  return showModalBottomSheet<ResultAccessBeginResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => SajuResultAccessGateSheet(
      contentId: contentId,
      contentTitle: contentTitle,
      quoteText: quoteText,
      returnRoute: returnRoute,
    ),
  );
}
