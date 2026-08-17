import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/domain/access/access_checker.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_badge.dart';
import '../../../core/widgets/premium_graphics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../home/domain/jeontong_eighty_matrix.dart';
import '../../pass/presentation/pass_gate_helper.dart';
import '../../pass/presentation/pass_time_format.dart';

/// [3단계 2차 실제 구조 정리 - 작업1] 운세탭(FortuneHubScreen) 4분류 개편.
///
/// 기존(v2)에는 필터칩(전체/무료/사주/타로/손금) + 평면 카테고리 리스트
/// 구조였고, "사주" 항목이 AI사주 라우트(`/ai-fortune/saju/input`)에만
/// 연결되어 있어 정통사주(PHASE1~4, 69종) 진입점이 이 화면에 전혀 없었다.
///
/// 이번 개편은 사용자가 확정한 4영역 구조를 그대로 반영한다.
///   ① 정통운세 - 정통사주 69종
///   ② 이미지운세 - 관상 / 손금
///   ③ 카드운세 - 타로
///   ④ AI운세 - AI 사주 / AI 이름운세 / AI 궁합 / AI 운세해석
///
/// [절대 원칙 준수]
/// - PHASE1~4 계산엔진/SajuProfile/NarrativeGenerator는 전혀 건드리지
///   않는다. 이 화면은 오직 기존 라우트로의 "진입 배선"만 다룬다.
/// - 정통사주 69종 카테고리 자체(A~H, JeontongEightyMatrix)는 무수정.
/// - 각 항목은 전부 기존에 이미 존재하는 라우트만 재사용한다(신규 화면
///   생성 없음). 아직 실제 화면이 없는 "AI 운세해석"만 기존 앱 전반에서
///   이미 쓰이는 "준비중 안내 토스트" 패턴을 그대로 재사용한다(신규 UX
///   패턴 추가 아님).
/// - "AI 상담"(AI사주상담/AI타로상담/AI고민상담 3종, `/ai-fortune/
///   consultation/type`)은 지시 10번(신규 UI 비노출)에 따라 이 화면에서
///   의도적으로 제외한다 — 코드/라우트는 삭제하지 않고 그대로 둔다.
/// - "오늘의 운세"는 2026-08-13 결정으로 이미 정통사주 69종에 통합되어
///   `RemovedDailyFortuneStub`로 dead-letter 처리되어 있으므로, 이 화면의
///   4영역 구조에도 별도 항목으로 다시 넣지 않는다(중복 노출 방지).
///
/// [주의] 진입 게이트체크 로직(navigateWithPassGate)과 PassProvider/
/// AccessChecker는 기존 그대로 재사용한다 — 기능은 무변경, 배선/레이아웃만 정리.
class FortuneHubScreen extends StatefulWidget {
  const FortuneHubScreen({super.key});

  @override
  State<FortuneHubScreen> createState() => _FortuneHubScreenState();
}

/// 운세 카테고리 1개 항목의 표시/이동 정보.
/// [route]가 null이면 아직 실제 화면이 없는 항목 → 탭 시 "준비중" 안내만
/// 표시한다(AllCategoriesScreen._open, home_screen._FortuneCategoryChips와
/// 동일한 기존 패턴 재사용).
class _FortuneItem {
  const _FortuneItem({
    required this.title,
    required this.desc,
    required this.icon,
    required this.route,
    required this.requiresPass,
  });

  final String title;
  final String desc;
  final IconData icon;
  final String? route;
  final bool requiresPass;
}

/// 4개 영역(정통운세/이미지운세/카드운세/AI운세) 중 1개 영역의 데이터.
class _FortuneSection {
  const _FortuneSection({
    required this.title,
    required this.subtitle,
    required this.headerIcon,
    required this.items,
  });

  final String title;
  final String subtitle;
  final IconData headerIcon;
  final List<_FortuneItem> items;
}

class _FortuneHubScreenState extends State<FortuneHubScreen> {
  bool _checking = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // [프리패스 테스트 인프라] §7/§13 — AccessChecker.openPassState가 expiresAt
    // 기준으로 실시간 재계산하므로, 1초마다 rebuild만 트리거하면 만료 순간
    // 자동으로 배지/히어로 카드가 잠금 상태로 전환된다(자동 재잠금).
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// ① 정통운세 - 정통사주 69종. PHASE1~4 계산엔진으로 이어지는 진입점은
  /// 기존에 홈 화면 "운세" 카드가 이미 쓰고 있는 [JeontongEightyMatrix.
  /// browseRoute](`/jeontong/eighty`, JeontongEightyScreen)를 그대로
  /// 재사용한다. `JeontongEightyGridScreen`과의 최종 통합 여부는 작업4에서
  /// 별도로 검토하며, 이번 작업에서는 화면을 새로 만들거나 교체하지 않는다.
  static const _traditionalSection = _FortuneSection(
    title: '정통운세',
    subtitle: 'PHASE1~4 정통사주 69종 · 태어난 시간으로 보는 정통 명리',
    headerIcon: Icons.auto_stories_rounded,
    items: [
      _FortuneItem(
        title: '정통사주 69종',
        desc: '연월일시 명식으로 정통 이론에 따라 풀이하는 69가지 운세',
        icon: Icons.auto_stories_outlined,
        route: JeontongEightyMatrix.browseRoute,
        requiresPass: true,
      ),
    ],
  );

  /// ② 이미지운세 - 관상 / 손금(둘 다 사진 촬영 기반 기존 화면 재사용).
  static const _imageSection = _FortuneSection(
    title: '이미지운세',
    subtitle: '사진 한 장으로 보는 얼굴과 손의 이야기',
    headerIcon: Icons.face_retouching_natural_rounded,
    items: [
      _FortuneItem(
        title: '관상',
        desc: '사진으로 보는 AI 관상 분석',
        icon: Icons.face_outlined,
        route: '/ai-fortune/face/capture',
        requiresPass: true,
      ),
      _FortuneItem(
        title: '손금',
        desc: '손바닥 속에 숨겨진 나의 운명',
        icon: Icons.back_hand_outlined,
        route: '/ai-fortune/palm/capture',
        requiresPass: true,
      ),
    ],
  );

  /// ③ 카드운세 - 타로. [타로 섹션 전면 개편] 신규 "정문"(TarotHomeScreen,
  /// `/tarot/home`)이 기존 질문/결과/히스토리 화면을 내부적으로 재사용하도록
  /// 이미 설계되어 있으므로, 사용자에게 노출되는 진입점은 이 하나로 통일한다
  /// (기존에도 이 화면은 이미 `/tarot/home`을 쓰고 있었음 — 변경 없음).
  static const _tarotSection = _FortuneSection(
    title: '카드운세',
    subtitle: '78장의 카드가 전하는 지금 이 순간의 메시지',
    headerIcon: Icons.style_rounded,
    items: [
      _FortuneItem(
        title: '타로',
        desc: '연애·재물·선택 등 원하는 주제로 카드를 뽑아보세요',
        icon: Icons.style_outlined,
        route: '/tarot/home',
        requiresPass: true,
      ),
    ],
  );

  /// ④ AI운세 - AI 사주 / AI 이름운세 / AI 궁합 / AI 운세해석.
  /// [명칭 분리 원칙] 여기 "AI 사주"는 PHASE1~4 정통사주와 완전히 별개인
  /// AI(LLM) 해석 화면(`/ai-fortune/saju/input`)이며, 절대 "정통사주"라는
  /// 이름을 쓰지 않는다.
  /// "AI 궁합"은 기존에 이미 라우팅되어 있는 `/compatibility/input`을 그대로
  /// 재사용한다(신규 개발 없음). "AI 운세해석"은 현재 전용 화면이 없어 기존
  /// 앱 전반에서 쓰이는 "준비중" 안내 패턴을 그대로 적용한다(route: null).
  static const _aiSection = _FortuneSection(
    title: 'AI운세',
    subtitle: 'AI가 분석하는 사주·이름·궁합·종합 해석',
    headerIcon: Icons.auto_awesome_rounded,
    items: [
      _FortuneItem(
        title: 'AI 사주',
        desc: 'AI가 분석하는 나의 사주 명식',
        icon: Icons.psychology_outlined,
        route: '/ai-fortune/saju/input',
        requiresPass: true,
      ),
      _FortuneItem(
        title: 'AI 이름운세',
        desc: '이름에 담긴 기운을 성명학으로 해석해요',
        icon: Icons.badge_outlined,
        route: '/ai-fortune/name/input',
        requiresPass: true,
      ),
      _FortuneItem(
        title: 'AI 궁합',
        desc: '나와 상대방의 인연을 유형별로 풀이해보세요',
        icon: Icons.favorite_outline_rounded,
        route: '/compatibility/input',
        requiresPass: true,
      ),
      _FortuneItem(
        title: 'AI 운세해석',
        desc: '여러 운세 결과를 종합해 AI가 풀어드려요',
        icon: Icons.insights_outlined,
        route: null,
        requiresPass: true,
      ),
    ],
  );

  static const _sections = [
    _traditionalSection,
    _imageSection,
    _tarotSection,
    _aiSection,
  ];

  Future<void> _handleTap(_FortuneItem item) async {
    if (item.route == null) {
      AppToast.show(context, '${item.title} · 준비 중이에요! 곧 만나볼 수 있어요 🙏');
      return;
    }
    if (item.requiresPass) setState(() => _checking = true);
    await navigateWithPassGate(
      context,
      title: item.title,
      route: item.route!,
      requiresPass: item.requiresPass,
    );
    if (mounted && item.requiresPass) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessChecker>();
    final passState = access.openPassState;
    final isPassActive = passState.isActive;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            UnifiedTokens.screenPadding,
            UnifiedTokens.spaceMd,
            UnifiedTokens.screenPadding,
            UnifiedTokens.spaceXxl,
          ),
          children: [
            Text('운세', style: UnifiedText.titleLarge()),
            const SizedBox(height: 4),
            Text('오늘 당신의 운명은 어떤 이야기를 담고 있을까요?', style: UnifiedText.body()),
            const SizedBox(height: UnifiedTokens.spaceXl),

            // 열림패스 상태 히어로 카드 - 기준 시안의 "오늘의 운세 이야기" 카드 톤 재사용.
            FadeSlideIn(
              child: _PassHeroCard(
                isActive: isPassActive,
                remainingSec: passState.remaining.inSeconds,
                isBusy: _checking,
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            // [4분류 구조] 정통운세 / 이미지운세 / 카드운세 / AI운세를 순서대로
            // 섹션 헤더 + 카드 리스트로 렌더링한다. 처음 보는 사용자도 "이 앱의
            // 운세 기능이 4가지로 나뉘어 있다"는 것을 한눈에 파악할 수 있도록,
            // 필터칩 대신 항상 4개 섹션을 전부 펼쳐서 보여준다.
            ...List.generate(_sections.length, (sectionIndex) {
              final section = _sections[sectionIndex];
              return Padding(
                padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceXxl),
                child: FadeSlideIn(
                  delay: Duration(milliseconds: 60 * sectionIndex),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        index: sectionIndex + 1,
                        icon: section.headerIcon,
                        title: section.title,
                        subtitle: section.subtitle,
                      ),
                      const SizedBox(height: UnifiedTokens.spaceMd),
                      ...List.generate(section.items.length, (itemIndex) {
                        final item = section.items[itemIndex];
                        final isReady = item.route != null;
                        final badgeLabel = !isReady
                            ? '준비중'
                            : (isPassActive ? '이용가능' : '프리패스');
                        final badgeType = !isReady
                            ? PremiumBadgeType.pass
                            : (isPassActive
                                  ? PremiumBadgeType.done
                                  : PremiumBadgeType.pass);
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: itemIndex == section.items.length - 1
                                ? 0
                                : UnifiedTokens.spaceMd,
                          ),
                          child: _FortuneCategoryCard(
                            title: item.title,
                            desc: item.desc,
                            icon: item.icon,
                            badgeLabel: badgeLabel,
                            badgeType: badgeType,
                            onTap: _checking ? null : () => _handleTap(item),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// 4영역 각각의 섹션 헤더 - "①/②/③/④" 순번 배지 + 아이콘 + 제목/부제.
/// 처음 보는 사용자가 "운세 메뉴가 4가지 영역으로 나뉜다"는 것을 스크롤만
/// 해도 즉시 파악할 수 있도록 순번을 명시적으로 표시한다.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final int index;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: UnifiedTokens.iconCircleLg,
          height: UnifiedTokens.iconCircleLg,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: UnifiedColors.cardAllMenu,
            borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
          ),
          child: Icon(
            icon,
            size: UnifiedTokens.iconLg,
            color: UnifiedColors.textPrimary,
          ),
        ),
        const SizedBox(width: UnifiedTokens.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$index. $title', style: UnifiedText.title()),
              const SizedBox(height: 2),
              Text(subtitle, style: UnifiedText.caption()),
            ],
          ),
        ),
      ],
    );
  }
}

/// 열림패스 상태를 알리는 히어로 카드 - 연라벤더 그라디언트 + 은은한 그래픽.
class _PassHeroCard extends StatelessWidget {
  const _PassHeroCard({
    required this.isActive,
    required this.remainingSec,
    required this.isBusy,
  });

  final bool isActive;
  final int remainingSec;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    // [프리패스 단순화 - 쿠팡파트너스 전용] §6 — HH:MM:SS 형식으로 통일.
    final timeLabel = '${formatPassHms(Duration(seconds: remainingSec))} 남음';

    return PremiumCard(
      backgroundColor: UnifiedColors.cardMain,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isActive ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                size: UnifiedTokens.iconMd,
                color: UnifiedColors.textPrimary,
              ),
              const SizedBox(width: UnifiedTokens.spaceSm),
              Text(
                isBusy
                    ? '프리패스 확인 중...'
                    : isActive
                    ? '프리패스 활성중 · $timeLabel'
                    : '프리패스가 없어요',
                style: UnifiedText.title(),
              ),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceXs),
          Text(
            isActive
                ? '지금 모든 운세 카테고리를 자유롭게 열람할 수 있어요'
                : '카테고리 진입 시 발급 방법을 안내해드려요',
            style: UnifiedText.caption(),
          ),
        ],
      ),
    );
  }
}

/// 운세 카테고리 카드 - 큰 라운드 카드 + 좌측 정렬 텍스트 + 우측 배지.
class _FortuneCategoryCard extends StatelessWidget {
  const _FortuneCategoryCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.badgeLabel,
    required this.badgeType,
    required this.onTap,
  });

  final String title;
  final String desc;
  final IconData icon;
  final String badgeLabel;
  final PremiumBadgeType badgeType;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Row(
        children: [
          Container(
            width: UnifiedTokens.iconCircleLg,
            height: UnifiedTokens.iconCircleLg,
            decoration: BoxDecoration(
              color: UnifiedColors.bg,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
            ),
            child: Icon(
              icon,
              size: UnifiedTokens.iconLg,
              color: UnifiedColors.textPrimary,
            ),
          ),
          const SizedBox(width: UnifiedTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: UnifiedText.bodyStrong()),
                const SizedBox(height: 2),
                Text(
                  desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UnifiedText.caption(),
                ),
              ],
            ),
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          PremiumBadge(label: badgeLabel, type: badgeType),
        ],
      ),
    );
  }
}
