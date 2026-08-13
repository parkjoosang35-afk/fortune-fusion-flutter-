import 'package:flutter/material.dart';
import '../../../config/feature_flags.dart';
import '../../../core/telemetry/ai_call_counter.dart';
import '../../../core/telemetry/feature_flag_counter.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_button.dart';
import '../../../core/widgets/premium_card.dart';

/// [AI 사주 호출 점진 전환 - 운영 디버그 메뉴] 현재 feature flag 값과
/// 카운터(누적/오늘)를 확인하고, 필요 시 카운터를 초기화하는 전용 화면.
///
/// [노출 원칙] 이 화면은 일반 사용자에게 절대 노출되지 않아야 한다:
/// - 라우팅: 앱 내부 어디에서도 이 화면으로 가는 버튼/메뉴를 추가하지
///   않는다. 오직 딥링크(`/dev-tools`, 이번 작업 범위 아님 — 라우터에는
///   등록하지 않았다) 또는 어드민 role 진입으로만 접근한다.
/// - 빌드: `--dart-define=ENABLE_DEBUG_MENU=true`가 아닌 한 release 빌드
///   에서 이 화면 자체는 존재해도 되지만(코드 삭제 없음), 실제 노출 여부는
///   [kEnableDebugMenu]로 판단한다.
///
/// [결제/구독/광고 무관] 이 화면은 [PassProvider]/[SubscriptionProvider]/
/// [WalletProvider] 등 결제 관련 어떤 것도 참조하지 않는다. 오직
/// [FeatureFlags]/[FeatureFlagCounter]/[AiCallCounter]만 읽고 초기화한다.
class FeatureFlagDebugScreen extends StatefulWidget {
  const FeatureFlagDebugScreen({super.key});

  /// release 빌드에서 이 화면을 완전히 숨기고 싶을 때 참고할 수 있는
  /// 빌드타임 스위치. `--dart-define=ENABLE_DEBUG_MENU=true`로 실행해야만
  /// true가 된다(기본값 false).
  static const bool kEnableDebugMenu = bool.fromEnvironment(
    'ENABLE_DEBUG_MENU',
    defaultValue: false,
  );

  @override
  State<FeatureFlagDebugScreen> createState() =>
      _FeatureFlagDebugScreenState();
}

class _FeatureFlagDebugScreenState extends State<FeatureFlagDebugScreen> {
  int _totalCalled = 0;
  int _todayCalled = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final total = await AiCallCounter.readTotalCalled();
    final today = await AiCallCounter.readTodayCalled();
    if (!mounted) return;
    setState(() {
      _totalCalled = total;
      _todayCalled = today;
      _loading = false;
    });
  }

  Future<void> _reset() async {
    await FeatureFlagCounter.resetFlag(AiCallCounter.flagKey);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlagDebugScreen.kEnableDebugMenu) {
      // [노출 절대 금지] 빌드 스위치가 꺼져 있으면 일반 안내만 보여주고
      // 어떤 flag/카운터 값도 노출하지 않는다.
      return Scaffold(
        backgroundColor: UnifiedColors.bg,
        body: SafeArea(
          child: Center(
            child: Text('디버그 메뉴가 비활성화되어 있어요.', style: UnifiedText.body()),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: UnifiedColors.cardAllMenu,
                      borderRadius: BorderRadius.circular(
                        UnifiedTokens.radiusMd,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: UnifiedTokens.iconMd,
                      color: UnifiedColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: UnifiedTokens.spaceMd),
                Text('Feature Flag 디버그', style: UnifiedText.titleLarge()),
              ],
            ),
            const SizedBox(height: UnifiedTokens.spaceXl),
            PremiumCard(
              backgroundColor: UnifiedColors.cardAllMenu,
              borderColor: Colors.transparent,
              showShadow: false,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
              padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('현재 Flag 값', style: UnifiedText.title()),
                  const SizedBox(height: UnifiedTokens.spaceSm),
                  _flagRow(
                    'kUseLegacyAiSajuMain',
                    FeatureFlags.kUseLegacyAiSajuMain,
                  ),
                  _flagRow(
                    'kUseLegacyAiSajuHistory',
                    FeatureFlags.kUseLegacyAiSajuHistory,
                  ),
                  _flagRow(
                    'kUseLegacyAiSajuBookmark',
                    FeatureFlags.kUseLegacyAiSajuBookmark,
                  ),
                  _flagRow(
                    'kUseLegacyAiSajuProfile',
                    FeatureFlags.kUseLegacyAiSajuProfile,
                  ),
                ],
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXl),
            PremiumCard(
              backgroundColor: UnifiedColors.cardAllMenu,
              borderColor: Colors.transparent,
              showShadow: false,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
              padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '메인 AI 사주 호출 카운터 (${AiCallCounter.flagKey})',
                    style: UnifiedText.title(),
                  ),
                  const SizedBox(height: UnifiedTokens.spaceSm),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(),
                    )
                  else ...[
                    Text('오늘 호출: $_todayCalled회', style: UnifiedText.body()),
                    const SizedBox(height: 4),
                    Text('누적 호출: $_totalCalled회', style: UnifiedText.body()),
                  ],
                ],
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXl),
            PremiumButton.secondary(label: '새로고침', onPressed: _load),
            const SizedBox(height: UnifiedTokens.spaceSm),
            PremiumButton(label: '카운터 초기화', onPressed: _reset),
          ],
        ),
      ),
    );
  }

  Widget _flagRow(String key, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(key, style: UnifiedText.body())),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: value ? UnifiedColors.chipInactiveBg : UnifiedColors.cardBanner,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
            ),
            child: Text(
              value ? 'true' : 'false',
              style: UnifiedText.chipLabel(color: UnifiedColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
