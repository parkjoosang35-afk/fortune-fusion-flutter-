import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../theme/lucky_box_tokens.dart';
import '../application/pouch_box_provider.dart';
import '../../wallet/application/wallet_provider.dart';
import 'widgets/pouch_grid_view.dart';
import 'widgets/pouch_ad_overlay.dart';
import 'widgets/pouch_opening_view.dart';
import 'widgets/pouch_burst_view.dart';
import 'widgets/pouch_result_view.dart';

/// [행운상자 - 복주머니 탭 신규 기능] dev-spec.md §1 상태 머신을 그대로
/// 구현한 하단바 "복주머니" 탭 메인 화면(PouchTabScreen 매핑).
///
/// ```
/// grid → (tap CTA)      → ad
/// ad   → (5s complete)  → opening
/// opening → (1.1s)      → burst
/// burst → (2.0s complete) → result
/// result → (tap CTA)    → grid    (dailyLeft > 0)
/// result → (tap CTA)    → close   (dailyLeft == 0)
/// ```
///
/// [뒤로가기 없음] 이 화면은 하단 탭 자체이므로 뒤로가기 화살표를 두지
/// 않는다(§1 라우트 원칙). `PopScope`로 시스템 뒤로가기도 흡수해 그리드로만
/// 복귀시킨다(앱 종료/탭 전환 방지 목적이 아니라, ad/opening/burst 진행 중
/// 실수로 화면이 튕겨나가는 것을 막기 위함).
enum _Phase { grid, ad, opening, burst, result }

class PouchBoxTabScreen extends StatefulWidget {
  const PouchBoxTabScreen({super.key});

  @override
  State<PouchBoxTabScreen> createState() => _PouchBoxTabScreenState();
}

class _PouchBoxTabScreenState extends State<PouchBoxTabScreen> {
  _Phase _phase = _Phase.grid;
  bool _starting = false;
  String? _sessionId;
  int _rewardAmount = 0;
  String? _rewardTier;
  int? _balanceAfter;
  int _dailyLeftAfter = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PouchBoxProvider>().loadState();
      context.read<WalletProvider>().load();
    });
  }

  Future<void> _onTapOpenCta() async {
    if (_starting) return;
    setState(() => _starting = true);
    final result = await context.read<PouchBoxProvider>().startWatch();
    if (!mounted) return;
    setState(() => _starting = false);
    if (!result.success) {
      _showSnack(result.errorMessage ?? '지금은 열 수 없어요.');
      // 자격이 바뀐 경우를 대비해 최신 현황을 다시 불러온다.
      context.read<PouchBoxProvider>().loadState();
      return;
    }
    _sessionId = result.data!.sessionId;
    setState(() => _phase = _Phase.ad);
  }

  void _onAdCompleted(int watchSeconds) {
    if (!mounted) return;
    setState(() => _phase = _Phase.opening);
    unawaited(_completeOnServer(watchSeconds));
  }

  Future<void>? _pendingComplete;

  Future<void> _completeOnServer(int watchSeconds) async {
    if (_sessionId == null) return;
    final future = context.read<PouchBoxProvider>().completeWatch(
      sessionId: _sessionId!,
      watchSeconds: watchSeconds,
    );
    _pendingComplete = future.then((result) {
      if (!mounted) return;
      if (!result.success) {
        _rewardAmount = 0;
        _rewardTier = null;
        _balanceAfter = null;
        _dailyLeftAfter = context.read<PouchBoxProvider>().dailyLeft;
        _showSnack(result.errorMessage ?? '보상 지급에 실패했어요.');
        setState(() => _phase = _Phase.grid);
        return;
      }
      final reward = result.data!;
      _rewardAmount = reward.rewardAmount;
      _rewardTier = reward.rewardTier;
      _balanceAfter = reward.balance;
      _dailyLeftAfter = reward.dailyLeft;
      // 실제 지갑 잔액(WalletProvider) 원장도 최신으로 재조회한다
      // (서버가 luck-pouch-engine.ts 경로로 이미 지급 완료했으므로,
      // 여기서는 클라이언트가 다시 적립을 요청하지 않고 조회만 한다).
      unawaited(context.read<WalletProvider>().load());
    });
  }

  void _onAdCancelled() {
    if (!mounted) return;
    setState(() => _phase = _Phase.grid);
  }

  void _onAdFailed() {
    if (!mounted) return;
    _showSnack('광고를 불러오지 못했어요. 잠시 후 다시 시도해주세요.');
    setState(() => _phase = _Phase.grid);
  }

  Future<void> _onOpeningSettle() async {
    // opening(1.1s) shake가 끝나는 시점에는 서버 /complete 응답이 아직 안
    // 왔을 수도 있으므로(광고 시청 중 병렬로 요청했지만 네트워크 지연 가능),
    // burst로 넘어가기 전에 결과를 기다린다. burst 자체도 2.0초라 사용자는
    // 자연스러운 로딩으로 느낀다.
    if (_pendingComplete != null) {
      await _pendingComplete;
    }
    if (!mounted) return;
    if (_phase != _Phase.opening) return; // 이미 grid로 되돌아간 경우(실패)
    // dev-spec.md §8 Haptic — 상자가 실제로 "열리는"(burst 진입) 순간에 진동.
    // 잭팟이면 더 강한 heavyImpact로 특별한 손맛을 준다.
    if (_rewardTier == 'jackpot') {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    setState(() => _phase = _Phase.burst);
  }

  void _onBurstSettle() {
    if (!mounted) return;
    setState(() => _phase = _Phase.result);
  }

  void _onResultDone() {
    if (!mounted) return;
    setState(() => _phase = _Phase.grid);
    context.read<PouchBoxProvider>().loadState();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// dev-spec.md §3-3 "50~300개 복주머니 파티클 방사형 방출" — 보상 등급이
  /// 높을수록 더 많은 파티클을 터뜨려 보상감을 강화한다(잭팟은 항상 최대치).
  int _particleCountFor(int rewardAmount) {
    if (_rewardTier == 'jackpot') return RewardConfig.particlesMax;
    const minR = 50, maxR = 300;
    final ratio = ((rewardAmount - minR) / (maxR - minR)).clamp(0.0, 1.0);
    final count =
        RewardConfig.particlesMin +
        (ratio * (RewardConfig.particlesMax - RewardConfig.particlesMin));
    return count.round();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase == _Phase.grid,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _phase = _Phase.grid);
        }
      },
      child: Scaffold(
        backgroundColor: LuckyBoxTokens.bgSoft,
        body: Stack(
          children: [
            PouchGridView(starting: _starting, onTapCta: _onTapOpenCta),
            if (_phase == _Phase.ad)
              PouchAdOverlay(
                onCompleted: _onAdCompleted,
                onCancelled: _onAdCancelled,
                onFailed: _onAdFailed,
              ),
            if (_phase == _Phase.opening)
              ColoredBox(
                color: LuckyBoxTokens.bgSoft,
                child: PouchOpeningView(onSettle: _onOpeningSettle),
              ),
            if (_phase == _Phase.burst)
              ColoredBox(
                color: LuckyBoxTokens.bgSoft,
                child: PouchBurstView(
                  particleCount: _particleCountFor(_rewardAmount),
                  isJackpot: _rewardTier == 'jackpot',
                  onSettle: _onBurstSettle,
                ),
              ),
            if (_phase == _Phase.result)
              ColoredBox(
                color: LuckyBoxTokens.bgBase,
                child: PouchResultView(
                  balance:
                      _balanceAfter ?? context.watch<WalletProvider>().balance,
                  rewardAmount: _rewardAmount,
                  isJackpot: _rewardTier == 'jackpot',
                  dailyLeft: _dailyLeftAfter,
                  onDone: _onResultDone,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
