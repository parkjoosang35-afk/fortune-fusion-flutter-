import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/web_ads/web_ad_config.dart';
import '../../../core/web_ads/widgets/web_ad_vignette.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/user_model.dart';
import '../data/models/topic_card.dart';
import '../data/saju_recent_story_store.dart';
import '../navigation/saju_dimension_transition.dart';
import '../state/saju_renewal_provider.dart';
import '../theme/saju_dark_tokens.dart';
import '../widgets/saju_base_widgets.dart';
import '../widgets/saju_story_widgets.dart';
import '../widgets/saju_visual_widgets.dart';
import 'birth_input_screen.dart';
import 'calculating_screen.dart';
import 'story_preview_screen.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 디자인 핸드오프] 화면① 메인(진입).
/// `design_handoff_jeongtong_saju_v3/design_files/saju/screens-a.jsx`의
/// `ScreenMain`을 1:1로 재현한다 — 잉크 다크 배경, 팔괘 심볼, "정통사주"
/// 세리프 히어로 타이틀, 안내자 말풍선(평생 1회만), 재방문 시 "최근 본
/// 이야기" 카드, 금빛 CTA(프로필 완전 여부에 따라 02/03 분기).
///
/// [절대 금지] 기존 69종 그리드(JeontongEightyScreen)와 동일한 UI/UX를
/// 만들지 않는다 — 사용자는 "내 사주를 계산했더니 이런 이야기가
/// 발견됐다"는 경험을 해야 한다(지시서 §최종 사용자 흐름).
class SajuRenewalHomeScreen extends StatefulWidget {
  const SajuRenewalHomeScreen({super.key});

  @override
  State<SajuRenewalHomeScreen> createState() => _SajuRenewalHomeScreenState();
}

/// docs/03 §01 "안내자(민세레나)" — 사용자 단위 영구 플래그. 한 번
/// `saju_guide_seen=true`가 기록되면 이 기기에서는 다시 노출하지 않는다.
const String _kGuideSeenKey = 'saju_guide_seen';

class _SajuRenewalHomeScreenState extends State<SajuRenewalHomeScreen> {
  bool _showGuide = false;
  SajuRecentStory? _recentStory;
  bool _recentStoryLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadGuideFlag();
    _loadRecentStory();
  }

  /// docs/03 §01: "정통사주 섹션 첫 진입 시 1회만(사용자 단위 영구 플래그
  /// saju_guide_seen). 진입 직후 표시 → 4.2s 후 opacity 0 + translateY 8,
  /// 600ms 페이드아웃. 이후 재진입 시 미노출."
  Future<void> _loadGuideFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_kGuideSeenKey) ?? false;
    if (!mounted) return;
    if (seen) {
      // 이미 본 적 있으면 아예 노출하지 않는다.
      return;
    }
    setState(() => _showGuide = true);
    Future.delayed(const Duration(milliseconds: 4200), () async {
      if (!mounted) return;
      setState(() => _showGuide = false);
      await prefs.setBool(_kGuideSeenKey, true);
    });
  }

  /// docs/03 §01 "최근 본 이야기 카드" — 노출 조건: 마지막으로 본 이야기
  /// (05 이상 도달, 이 구현에서는 07 상세까지 완료)가 존재. 최근 1개만.
  Future<void> _loadRecentStory() async {
    final story = await SajuRecentStoryStore.load();
    if (!mounted) return;
    setState(() {
      _recentStory = story;
      _recentStoryLoaded = true;
    });
  }

  /// docs/03 §01 인터랙션: "CTA 탭: 프로필 완전(생년월일·양음력·성별·
  /// 출생지 + 시간 또는 "모름" 명시) → 03 직행, 아니면 → 02."
  /// 02 화면(birth_input_screen)이 생년월일/양음력/시간(또는 모름)/
  /// 성별/태어난 곳(기본값 "서울")을 모두 저장하므로, 한 번이라도 02를
  /// 완료한 사용자는 이 기준을 모두 만족한다.
  bool _isProfileComplete(UserModel? user) {
    if (user == null) return false;
    if (user.birthDate == null || user.birthDate!.isEmpty) return false;
    if (user.gender != 'male' && user.gender != 'female') return false;
    if (user.birthPlace == null || user.birthPlace!.isEmpty) return false;
    // 시간은 "입력되어 있거나" 또는 "모름으로 명시"되어 있으면 완전.
    final timeExplicit =
        user.birthTimeUnknown ||
        (user.birthTime != null && user.birthTime!.isNotEmpty);
    return timeExplicit;
  }

  /// [버그 수정 — "출생정보 저장안됨" 근본 원인] 기존에는 로그인 여부를
  /// 전혀 확인하지 않고 게스트도 곧장 02(BirthInputScreen)로 보냈다.
  /// 02 화면에서 "사주 분석 시작하기"를 눌러 저장을 시도하면
  /// AuthProvider.updateProfile()이 `currentUser == null`이라 항상 실패하고,
  /// 사용자는 원인을 알 수 없는 폴백 에러만 보게 됐다. 02 화면 진입 전에
  /// 로그인 여부를 먼저 확인해, 비로그인 사용자는 로그인/회원가입으로
  /// 먼저 유도한다(로그인 완료 후 이 버튼을 다시 누르면 정상 진행).
  Future<bool> _ensureLoggedIn(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) return true;
    final goLogin = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: SajuInk.i900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: SajuText.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text('🔮', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 12),
                const Text(
                  '사주 분석을 시작하려면\n로그인이 필요합니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: SajuType.serif,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    height: 1.4,
                    color: SajuGold.g100,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '출생정보를 안전하게 저장하려면\n로그인 후 이용해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: SajuType.ui,
                    fontSize: 13,
                    height: 1.5,
                    color: SajuText.muted,
                  ),
                ),
                const SizedBox(height: 22),
                SajuButton(
                  label: '로그인 / 회원가입',
                  onTap: () => Navigator.of(sheetContext).pop(true),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: const Text(
                    '나중에 할게요',
                    style: TextStyle(
                      fontFamily: SajuType.ui,
                      fontSize: 13,
                      color: SajuText.faint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (goLogin != true) return false;
    if (!context.mounted) return false;
    await Navigator.of(context).pushNamed('/login');
    if (!context.mounted) return false;
    // 로그인 화면은 성공 시 '/home'으로 스택을 교체하므로, 이 화면은 이미
    // pop되어 있을 수 있다 — 그 경우 더 이상 진행할 필요가 없다.
    return context.read<AuthProvider>().isLoggedIn;
  }

  Future<void> _start(BuildContext context) async {
    final loggedIn = await _ensureLoggedIn(context);
    if (!loggedIn || !context.mounted) return;
    final auth = context.read<AuthProvider>();
    final renewal = context.read<SajuRenewalProvider>();
    if (_isProfileComplete(auth.currentUser)) {
      // 프로필이 이미 완전하면 02(출생정보 입력)를 건너뛰고 03(분석중)으로
      // 직행한다(docs/03 §01 인터랙션 규칙).
      renewal.startCalculating();
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CalculatingScreen()));
      return;
    }
    renewal.startNewAnalysis();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BirthInputScreen()));
  }

  /// 재방문 카드 탭 — "그 이야기의 05(해제 여부 유지)"로 이동한다. 이미
  /// 해제된 주제인지 여부는 서버가 interpret 호출 시 재판단하므로,
  /// 여기서는 summary(미리보기) 재조회만 수행하고 05 화면으로 보낸다.
  void _openRecentStory(BuildContext context) {
    final story = _recentStory;
    if (story == null) return;
    final renewal = context.read<SajuRenewalProvider>();
    renewal.loadPreview(story.toTopicCard());
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const StoryPreviewScreen()));
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
    final showRecentCard = _recentStoryLoaded && _recentStory != null;
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
                // E-30(docs/07) — 작은 화면(높이 < 700): "01: Bagua를
                // 남은 높이에 맞춰 축소(최소 200)". Expanded가 준 실제
                // 가용 높이를 측정해 290(기본)과 200(최소) 사이로 줄인다.
                // 화면이 충분히 크면(가용 높이 ≥ 290) 기존과 동일하게
                // 290 그대로 유지되어 일반 기기에는 아무 영향이 없다.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final baguaSize = constraints.hasBoundedHeight
                          ? constraints.maxHeight.clamp(200.0, 290.0)
                          : 290.0;
                      return Center(
                        child: SajuBagua(size: baguaSize, speedSeconds: 120),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 46),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showRecentCard) ...[
                            _RecentStoryCard(
                              story: _recentStory!,
                              onTap: () => _openRecentStory(context),
                            ),
                            const SizedBox(height: 12),
                          ],
                          SajuButton(
                            label: '내 사주 분석하기',
                            onTap: () => _start(context),
                          ),
                        ],
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

/// docs/03 §01 "최근 본 이야기 카드" (01-C).
class _RecentStoryCard extends StatelessWidget {
  const _RecentStoryCard({required this.story, required this.onTap});

  final SajuRecentStory story;
  final VoidCallback onTap;

  SajuScene get _token {
    switch (story.scene) {
      case SajuRenewalScene.money:
        return SajuScene.money;
      case SajuRenewalScene.talent:
        return SajuScene.talent;
      case SajuRenewalScene.love:
        return SajuScene.love;
      case SajuRenewalScene.life:
        return SajuScene.life;
      case SajuRenewalScene.guin:
        return SajuScene.guin;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _token;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SajuText.line),
          color: const Color.fromRGBO(250, 243, 224, 0.04),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: SajuText.lineGold),
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  colors: [t.tint.withValues(alpha: 0.35), SajuInk.i850],
                ),
              ),
              child: Text(
                t.glyph,
                style: TextStyle(color: SajuGold.g300, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '최근 본 이야기',
                    style: TextStyle(
                      fontFamily: SajuType.ui,
                      fontSize: 10.5,
                      color: SajuText.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    story.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: SajuType.serif,
                      fontSize: 14,
                      color: SajuGold.g100,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '이어서 보기 →',
              style: TextStyle(
                fontFamily: SajuType.ui,
                fontSize: 12,
                color: SajuGold.g300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
