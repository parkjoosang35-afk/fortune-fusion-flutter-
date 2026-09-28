import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_toast.dart';
import '../../ads_test/domain/admob_ad_ids.dart';
import '../../pass/presentation/coupang_pass_sheet.dart';
import '../application/result_access_provider.dart';
import '../data/result_access_repository.dart';
import '../domain/pending_result_access_return.dart';
import '../domain/result_access_model.dart';

/// [결과보기 통합 권한 시스템 v1.0, §6] 결과보기 화면 3택 UI — §8 공통
/// ResultAccessService(getQuote/begin/ad-session)만 호출하는 단일 게이트
/// 바텀시트. 정통사주 69종·타로 65종·운세 전체가 이 위젯 하나만 재사용한다
/// (§8.1 공통화 원칙 — 콘텐츠별 전용 게이트 위젯을 새로 만들지 않는다).
///
/// [자유 이용 원칙, P1/P2] 이 시트는 오직 "[결과보기] 버튼을 누른 시점"에만
/// 뜬다 — 입력화면/카테고리 탐색 자체는 프리패스 유무와 무관하게 항상
/// 자유롭게 가능해야 하며, 그 자유 탐색 흐름을 이 파일이 막아서는 안 된다.
///
/// [반환값] 성공(§8.5 결제 확정)하면 [ResultAccessBeginResult]를 그대로
/// 반환한다 — 호출부는 이 결과의 `transactionId`를 콘텐츠 API(saju/tarot/...)
/// 호출에 그대로 실어 보내야 한다. 사용자가 취소했거나 쿠팡 이동으로
/// 이어졌으면 null을 반환한다(쿠팡 이동은 §7에 따라 별도 상태 저장/복원으로
/// 처리되므로, 이 시트가 그 결과까지 기다렸다가 반환할 필요가 없다).
///
/// [비로그인 결과보기 복귀 지시서 R2] 로그인/회원가입 성공 직후 호출되는
/// 공통 진입점. [PendingResultAccessReturnStore]에 저장된 값이 있으면(=이
/// 시트의 "로그인하고 결과보기" CTA를 거쳐 로그인하러 갔던 경우) 그 값을
/// 소비해 **원래 화면으로 `replace` 복귀**한 뒤, 같은 프레임에 이 게이트
/// 시트를 다시 띄운다(사용자가 로그인만 마치면 별도 조작 없이 곧바로 3택
/// 화면을 다시 보게 된다). 저장된 값이 없으면(일반 로그인) 아무 것도 하지
/// 않는다 — 호출부(login_screen.dart/signup_screen.dart)는 이 함수 호출
/// 여부와 무관하게 기존 `/home` 이동 로직을 그대로 유지해야 한다(반환값
/// true면 이 함수가 이미 복귀 라우팅까지 처리했다는 뜻이므로 호출부의
/// `/home` 이동을 건너뛰어야 한다).
Future<bool> restorePendingResultAccessAfterLogin(BuildContext context) async {
  final pending = await PendingResultAccessReturnStore.consume();
  if (pending == null) return false;
  if (!context.mounted) return false;

  // [뒤로가기 시 로그인 화면으로 돌아가지 않도록] replace로 원래 화면에
  // 복귀한다 — 로그인 화면(및 그 이전 결과보기 시트를 띄웠던 화면)은
  // 스택에서 제거된다.
  await Navigator.of(context).pushReplacementNamed(
    pending.returnRoute,
    arguments: pending.userInput.isEmpty
        ? null
        : {'restoredInput': pending.userInput},
  );
  if (!context.mounted) return true;

  // 복귀한 화면 위에 곧바로 결과보기 시트를 다시 띄운다 — 로그인 전에
  // 보고 있던 콘텐츠 컨텍스트 그대로. 이 시점에는 이미 로그인이 완료된
  // 상태이므로 quote 조회가 정상적으로 성공한다.
  await showResultAccessGateSheet(
    context,
    contentType: pending.contentType,
    contentId: pending.contentId,
    categoryKey: pending.categoryKey,
    contentTitle:
        pending.contentTitle ?? pending.selectedCategory ?? pending.contentType,
    returnRoute: pending.returnRoute,
    userInputForRestore: pending.userInput,
    selectedCategory: pending.selectedCategory,
    question: pending.question,
    resultRequestId: pending.resultRequestId,
  );
  return true;
}

Future<ResultAccessBeginResult?> showResultAccessGateSheet(
  BuildContext context, {
  required String contentType,
  String? contentId,
  String? categoryKey,
  required String contentTitle,
  required String returnRoute,
  Map<String, dynamic>? userInputForRestore,
  String? selectedCategory,
  String? question,
  String? resultRequestId,
}) {
  return showModalBottomSheet<ResultAccessBeginResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: UnifiedColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ResultAccessGateSheet(
      contentType: contentType,
      contentId: contentId,
      categoryKey: categoryKey,
      contentTitle: contentTitle,
      returnRoute: returnRoute,
      userInputForRestore: userInputForRestore ?? const {},
      selectedCategory: selectedCategory,
      question: question,
      resultRequestId: resultRequestId,
    ),
  );
}

class ResultAccessGateSheet extends StatefulWidget {
  const ResultAccessGateSheet({
    super.key,
    required this.contentType,
    this.contentId,
    this.categoryKey,
    required this.contentTitle,
    required this.returnRoute,
    required this.userInputForRestore,
    this.selectedCategory,
    this.question,
    this.resultRequestId,
  });

  final String contentType;
  final String? contentId;
  final String? categoryKey;
  final String contentTitle;
  final String returnRoute;
  final Map<String, dynamic> userInputForRestore;
  final String? selectedCategory;
  final String? question;
  final String? resultRequestId;

  @override
  State<ResultAccessGateSheet> createState() => _ResultAccessGateSheetState();
}

class _ResultAccessGateSheetState extends State<ResultAccessGateSheet> {
  /// [§8.4 더블탭 방지] 3개 버튼 중 어느 것이라도 처리 중이면 전체 비활성화.
  /// null이면 대기 상태, 값이 있으면 "그 결제수단으로 처리 중"을 의미한다.
  ResultAccessPaymentMethod? _processingMethod;

  /// 쿠팡 프리패스 발급 흐름(별도 결제수단이 아니라 §7 상태저장+시트 전환)도
  /// 동일하게 다른 버튼들을 잠가야 하므로 별도 플래그로 관리한다.
  bool _launchingCoupang = false;

  bool get _busy => _processingMethod != null || _launchingCoupang;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuote());
  }

  Future<void> _loadQuote() async {
    await context.read<ResultAccessProvider>().loadQuote(
      contentType: widget.contentType,
      categoryKey: widget.categoryKey,
    );
  }

  /// §8.5 "결제 확정" 공통 처리 — FREEPASS/POUCH/AD 3가지 결제수단이 모두
  /// 이 메서드를 거쳐 begin()을 호출하고, 성공하면 시트를 닫으며 결과를
  /// 호출부에 그대로 반환한다.
  Future<void> _beginAndClose(
    ResultAccessPaymentMethod method, {
    String? adSessionId,
  }) async {
    final provider = context.read<ResultAccessProvider>();
    final transactionId = generateResultAccessTransactionId();
    final result = await provider.begin(
      transactionId: transactionId,
      contentType: widget.contentType,
      contentId: widget.contentId,
      categoryKey: widget.categoryKey,
      paymentMethod: method,
      adSessionId: adSessionId,
    );
    if (!mounted) return;
    if (result == null) {
      setState(() => _processingMethod = null);
      AppToast.show(context, provider.lastError ?? '결과보기에 실패했습니다.', isError: true);
      return;
    }
    Navigator.of(context).pop(result);
  }

  void _handleFreePass() {
    if (_busy) return;
    setState(() => _processingMethod = ResultAccessPaymentMethod.freepass);
    _beginAndClose(ResultAccessPaymentMethod.freepass);
  }

  void _handlePouch() {
    if (_busy) return;
    setState(() => _processingMethod = ResultAccessPaymentMethod.pouch);
    _beginAndClose(ResultAccessPaymentMethod.pouch);
  }

  /// [§8.3 광고 서버 재검증] "시트에서 선택 → AdMob 표시 → 서버가 광고 완료
  /// 확인 → begin 승인" 순서를 그대로 지킨다. 클라이언트의 onUserEarnedReward
  /// 콜백만으로는 절대 begin()을 호출하지 않고, completeAdSession()의 서버
  /// 응답이 성공했을 때만 begin()으로 넘어간다.
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
                // [§5 중도 종료 시 권한 승인 안 함] 끝까지 보지 않았으면
                // completeAdSession/begin 둘 다 절대 호출하지 않는다.
                setState(() => _processingMethod = null);
                AppToast.show(
                  context,
                  '광고를 끝까지 시청해야 무료로 볼 수 있어요.',
                  isError: true,
                );
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
              // reward.amount는 사용하지 않는다 — "끝까지 봤다"는 사실만 기록.
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

  /// [§7 쿠팡 이동 후 상태 복원] 쿠팡 방문 직전에 지금 화면 복원에 필요한
  /// 최소 정보를 디스크(SharedPreferences)에 저장한다 — OS가 쿠팡 이동 중
  /// Flutter 프로세스를 kill해도 복원할 수 있도록.
  ///
  /// [설계 - 이 시트를 닫지 않고 그 위에 쿠팡 시트를 띄운다] 프로세스가
  /// 살아남는 일반적인 경우(대부분의 최신 기기)에는 이 게이트 시트를 그대로
  /// 유지한 채 쿠팡 흐름(showCoupangPassSheet)을 그 위에 쌓아 올린다 —
  /// 그러면 쿠팡 지급이 끝나고 돌아왔을 때 "원래 결과보기 화면(게이트
  /// 시트)"이 이미 그 자리에 있으므로 별도 복원 로직 없이도 §7 요구사항이
  /// 자연스럽게 충족된다. 프로세스가 실제로 kill된 경우에만(이 async 함수
  /// 자체가 통째로 중단됨) [PendingResultAccessReturnStore]에 저장된 정보가
  /// 다음 앱 부팅 시(스플래시) 복원 로직에 의해 대신 소비된다.
  Future<void> _handleCoupangClaim() async {
    if (_busy) return;
    setState(() => _launchingCoupang = true);

    await PendingResultAccessReturnStore.save(
      PendingResultAccessReturn(
        contentType: widget.contentType,
        contentId: widget.contentId,
        selectedCategory: widget.selectedCategory,
        question: widget.question,
        userInput: widget.userInputForRestore,
        resultRequestId: widget.resultRequestId,
        returnRoute: widget.returnRoute,
        savedAt: DateTime.now(),
        contentTitle: widget.contentTitle,
        categoryKey: widget.categoryKey,
      ),
    );
    if (!mounted) return;

    // 쿠팡 흐름은 기존에 검증된 showCoupangPassSheet를 그대로 재사용한다
    // (§10 프리패스는 쿠팡 파트너스 전용 원칙 — 신규 쿠팡 흐름을 새로
    // 만들지 않는다). 이 게이트 시트는 닫지 않고 그 위에 쌓는다.
    await showCoupangPassSheet(context, categoryTitle: widget.contentTitle);

    // 이 지점에 도달했다는 것 자체가 "프로세스가 살아서 정상적으로
    // 돌아왔다"는 뜻이므로(§7이 대비하는 kill 시나리오라면 이 줄은 절대
    // 실행되지 않는다) 저장된 복원 상태를 정리하고, 갱신된 프리패스
    // 잔여횟수를 반영하기 위해 견적을 다시 불러온다.
    await PendingResultAccessReturnStore.clear();
    if (!mounted) return;
    setState(() => _launchingCoupang = false);
    await _loadQuote();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResultAccessProvider>();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: UnifiedTokens.spaceXl,
          right: UnifiedTokens.spaceXl,
          top: UnifiedTokens.spaceLg,
          bottom: UnifiedTokens.spaceXl + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHandle(),
            Text(
              '결과보기',
              style: UnifiedText.titleLarge(),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: UnifiedTokens.spaceXs),
            Text(
              '${widget.contentTitle} 결과를 아래 3가지 중 하나로 확인할 수 있어요.',
              style: UnifiedText.caption(color: UnifiedColors.textCaption),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: UnifiedTokens.spaceLg),
            if (provider.isLoadingQuote)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(color: UnifiedColors.neon),
                ),
              )
            else if (provider.quote == null)
              _buildLoadError(provider)
            else
              _buildOptions(provider.quote!),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: UnifiedTokens.spaceLg),
        decoration: BoxDecoration(
          color: UnifiedColors.border,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
        ),
      ),
    );
  }

  /// [비로그인 결과보기 복귀 지시서 R1/R4] 조회 실패 사유가 'UNAUTHORIZED'
  /// (=서버가 401을 반환, 비로그인 상태)이면 "다시 시도"(=동일 요청 재실행,
  /// 로그인 상태가 안 바뀌었으니 똑같이 실패해 사실상 무동작으로 보였다)가
  /// 아니라 "로그인 / 회원가입" CTA를 보여준다. 그 외(네트워크/5xx 등
  /// 진짜 일시적 오류)에는 기존과 동일하게 재시도 버튼을 유지한다 — 재시도는
  /// 순수 네트워크/서버 오류 문맥에서만 의미 있다는 지시서 R1 원칙 그대로.
  Widget _buildLoadError(ResultAccessProvider provider) {
    final needsLogin = provider.lastErrorReason == 'UNAUTHORIZED';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              if (needsLogin) ...[
                const Text('🔒', style: TextStyle(fontSize: 32)),
                SizedBox(height: UnifiedTokens.spaceSm),
              ],
              Text(
                needsLogin
                    ? '로그인 후 결과보기를 이용할 수 있어요.'
                    : (provider.lastError ?? '결과보기 권한 정보를 불러오지 못했습니다.'),
                style: needsLogin
                    ? UnifiedText.bodyStrong()
                    : UnifiedText.body(color: UnifiedColors.textCaption),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: needsLogin ? _handleLoginRequired : _loadQuote,
            style: ElevatedButton.styleFrom(
              backgroundColor: UnifiedColors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
              ),
            ),
            child: Text(needsLogin ? '로그인하고 결과보기' : '다시 시도'),
          ),
        ),
      ],
    );
  }

  /// [비로그인 결과보기 복귀 지시서 R2] 로그인/회원가입으로 보내기 직전에
  /// 지금 보고 있던 콘텐츠 컨텍스트(어떤 화면·어떤 입력값으로 돌아와야
  /// 하는지)를 저장한다. 이미 존재하는 [PendingResultAccessReturnStore]
  /// (§7 "쿠팡 이동 후 복귀"용으로 만들어진 디스크 저장소)를 그대로
  /// 재사용한다 — 로그인 왕복도 쿠팡 왕복과 동일하게 "이 화면을 떠났다가
  /// 돌아와야 한다"는 구조가 같으므로 신규 저장소를 만들지 않는다(§8.1
  /// 공통화 원칙과 동일한 이유). 저장 후 이 시트를 닫고 `/login`으로
  /// 이동한다 — 로그인 성공 시 login_screen.dart가 이 저장값을 소비해
  /// 원래 화면 + 이 시트를 자동으로 복원한다(R2).
  Future<void> _handleLoginRequired() async {
    await PendingResultAccessReturnStore.save(
      PendingResultAccessReturn(
        contentType: widget.contentType,
        contentId: widget.contentId,
        selectedCategory: widget.selectedCategory,
        question: widget.question,
        userInput: widget.userInputForRestore,
        resultRequestId: widget.resultRequestId,
        returnRoute: widget.returnRoute,
        savedAt: DateTime.now(),
        contentTitle: widget.contentTitle,
        categoryKey: widget.categoryKey,
      ),
    );
    if (!mounted) return;
    // 이 시트를 닫고(null 반환 — 호출부는 "사용자가 취소함"과 동일하게
    // 처리하면 되므로 별도 분기 불필요) 로그인 화면으로 이동한다. 뒤로가기
    // 시 이 시트가 다시 뜨지 않도록 pop 후 push(로그인 화면은 스택에
    // 쌓인다 — 로그인 화면 자체의 "뒤로가기" 버튼으로 원래 화면에 돌아올
    // 수 있어야 하므로 replace가 아니라 일반 push를 쓴다).
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed('/login');
  }

  Widget _buildOptions(ResultAccessQuote quote) {
    final showCoupangClaim =
        !quote.freePassAvailable && !quote.todayClaimed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GateOptionButton(
          icon: Icons.confirmation_number_rounded,
          label: _freePassLabel(quote),
          enabled: quote.freePassAvailable && !_busy,
          loading: _processingMethod == ResultAccessPaymentMethod.freepass,
          onTap: _handleFreePass,
        ),
        SizedBox(height: UnifiedTokens.spaceSm),
        _GateOptionButton(
          icon: Icons.savings_rounded,
          label: '복주머니로 보기 (-${quote.pouchPrice}개)'
              '${quote.pouchAvailable ? '' : ' · 이용 불가'}',
          subLabel: '보유 ${quote.pouchBalance}개',
          enabled: quote.pouchAvailable && quote.pouchSufficient && !_busy,
          loading: _processingMethod == ResultAccessPaymentMethod.pouch,
          onTap: _handlePouch,
        ),
        SizedBox(height: UnifiedTokens.spaceSm),
        _GateOptionButton(
          icon: Icons.smart_display_rounded,
          label: '광고 보고 무료로 보기',
          enabled: quote.adAvailable && AdmobAdIds.isSupportedPlatform && !_busy,
          loading: _processingMethod == ResultAccessPaymentMethod.ad,
          onTap: _handleAd,
        ),
        if (showCoupangClaim) ...[
          SizedBox(height: UnifiedTokens.spaceLg),
          Container(height: 1, color: UnifiedColors.border),
          SizedBox(height: UnifiedTokens.spaceLg),
          _GateOptionButton(
            icon: Icons.card_giftcard_rounded,
            label: '오늘의 프리패스 2회 받기 (쿠팡 방문)',
            highlighted: true,
            enabled: !_busy,
            loading: _launchingCoupang,
            onTap: _handleCoupangClaim,
          ),
        ] else if (!quote.freePassAvailable && quote.todayClaimed)
          Padding(
            padding: const EdgeInsets.only(top: UnifiedTokens.spaceMd),
            child: Text(
              '오늘의 프리패스는 이미 받았어요. 내일 다시 받을 수 있어요.',
              style: UnifiedText.caption(color: UnifiedColors.textCaption),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  /// §6.1/6.2/6.3 프리패스 보유 상태별 라벨.
  String _freePassLabel(ResultAccessQuote quote) {
    if (quote.freePassHasLegacyUnlimited && quote.freePassRemaining <= 0) {
      return '프리패스로 보기 (무제한 이용중)';
    }
    if (quote.freePassRemaining <= 0) {
      return '프리패스로 보기 (보유 0회)';
    }
    if (quote.freePassRemaining == 1) {
      return '프리패스로 보기 (마지막 1회)';
    }
    return '프리패스로 보기 (${quote.freePassRemaining}회 남음)';
  }
}

class _GateOptionButton extends StatelessWidget {
  const _GateOptionButton({
    required this.icon,
    required this.label,
    this.subLabel,
    required this.enabled,
    required this.loading,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final String? subLabel;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final bg = highlighted
        ? UnifiedColors.neon
        : (enabled ? UnifiedColors.black : UnifiedColors.chipInactiveBg);
    final fg = highlighted
        ? UnifiedColors.black
        : (enabled ? Colors.white : UnifiedColors.textCaption);

    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: UnifiedColors.chipInactiveBg,
          disabledForegroundColor: UnifiedColors.textCaption,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  SizedBox(width: UnifiedTokens.spaceSm),
                  Flexible(
                    child: Text(
                      label,
                      style: UnifiedText.bodyStrong(color: fg),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (subLabel != null) ...[
                    SizedBox(width: UnifiedTokens.spaceXs),
                    Text(
                      '($subLabel)',
                      style: UnifiedText.caption(color: fg),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
