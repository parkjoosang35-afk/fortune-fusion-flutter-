import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/web_ads/web_ad_config.dart';
import '../../../core/web_ads/widgets/web_ad_vignette.dart';
import '../navigation/saju_dimension_transition.dart';
import '../state/saju_renewal_provider.dart';
import '../theme/saju_dark_tokens.dart';
import '../widgets/saju_base_widgets.dart';
import '../widgets/saju_story_widgets.dart';
import '../widgets/saju_visual_widgets.dart';
import 'birth_input_screen.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 디자인 핸드오프] 화면① 메인(진입).
/// `design_handoff_jeongtong_saju_v3/design_files/saju/screens-a.jsx`의
/// `ScreenMain`을 1:1로 재현한다 — 잉크 다크 배경, 팔괘 심볼, "정통사주"
/// 세리프 히어로 타이틀, 안내자 말풍선(4.2초 후 자동 사라짐), 금빛 CTA.
///
/// [절대 금지] 기존 69종 그리드(JeontongEightyScreen)와 동일한 UI/UX를
/// 만들지 않는다 — 사용자는 "내 사주를 계산했더니 이런 이야기가
/// 발견됐다"는 경험을 해야 한다(지시서 §최종 사용자 흐름).
///
/// [디자인 핸드오프 대비 축소 사항] JSX `ScreenMain`의 `t.revisit`(최근
/// 본 이야기 다시보기 카드)과 `t.profileComplete`(입력 스킵 분기)는
/// mock 토글용 prop이며, 현재 `SajuRenewalProvider`에는 대응하는 실제
/// 상태가 없다(서버가 "마지막으로 본 토픽"을 따로 캐싱해 내려주지
/// 않음) — 따라서 이번 재구축에서는 "내 사주 분석하기" 단일 진입점만
/// 구현한다(가짜 더미 카드를 보여주지 않는다는 원칙과도 일치).
class SajuRenewalHomeScreen extends StatefulWidget {
  const SajuRenewalHomeScreen({super.key});

  @override
  State<SajuRenewalHomeScreen> createState() => _SajuRenewalHomeScreenState();
}

class _SajuRenewalHomeScreenState extends State<SajuRenewalHomeScreen> {
  bool _showGuide = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 4200), () {
      if (mounted) setState(() => _showGuide = false);
    });
  }

  void _start(BuildContext context) {
    context.read<SajuRenewalProvider>().startNewAnalysis();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BirthInputScreen()));
  }

  /// docs/03 §00 "복귀 전환(300ms)" — 01 → 00(앱 셸)로 돌아갈 때,
  /// 즉시 pop하는 대신 다크 오버레이 페이드아웃(M-02)을 먼저 재생한다.
  /// 뒤로가기 버튼(←)과 시스템 백(아래 [PopScope]) 양쪽 모두 이 경로를
  /// 거치도록 통일한다.
  Future<void> _exitWithReturnTransition(BuildContext context) async {
    if (!Navigator.of(context).canPop()) return;
    await playSajuReturnOverlayThenPop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _exitWithReturnTransition(context);
        }
      },
      child: Scaffold(
        body: SajuDarkBase(
          child: SafeArea(
            child: Column(
              children: [
                // [웹 AdSense — STEP E] 정통사주 플로우 진입점에서 1회만
                // Vignette(전면 전환) 페이지 레벨 광고를 트리거한다. 레이아웃
                // 공간을 차지하지 않는 순수 트리거이므로 어디에 둬도 무해하다.
                const WebAdVignette(surface: WebAdSurface.sajuRenewal),
                SajuTopBar(
                  left: SajuIconButton(
                    icon: '←',
                    onTap: () => _exitWithReturnTransition(context),
                  ),
                  title: 'SINTONG · 正統四柱',
                ),
                const SizedBox(height: 34),
                Column(
                  children: [
                    Text('정통사주', style: SajuType.hero),
                    const SizedBox(height: 16),
                    Text(
                      '당신의 사주에는,\n어떤 이야기가 숨어 있을까요?',
                      textAlign: TextAlign.center,
                      style: SajuType.body16,
                    ),
                  ],
                ),
                const Expanded(
                  child: Center(child: SajuBagua(size: 290, speedSeconds: 120)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 46),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SajuButton(
                        label: '내 사주 분석하기',
                        onTap: () => _start(context),
                      ),
                      Positioned(
                        right: -4,
                        bottom: 118,
                        child: AnimatedOpacity(
                          opacity: _showGuide ? 1 : 0,
                          duration: SajuMotion.card,
                          child: AnimatedSlide(
                            offset: _showGuide
                                ? Offset.zero
                                : const Offset(0, 0.08),
                            duration: SajuMotion.card,
                            child: IgnorePointer(
                              child: SajuGuidePlaceholder(
                                text: '어서 오세요. 여기부터는 당신의 여덟 글자가\n이야기를 들려줄 거예요.',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
