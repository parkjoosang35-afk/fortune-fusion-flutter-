import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/domain/access/access_checker.dart';
import '../../../core/domain/gate/category_gate.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_button.dart';
import '../../../core/widgets/premium_chip.dart';
import '../../../core/widgets/premium_badge.dart';
import '../../../core/widgets/premium_graphics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../auth/application/auth_provider.dart';
import '../../pass/application/pass_provider.dart';
import '../../pass/domain/pending_pass_request.dart';
import '../../pass/presentation/pass_gate_helper.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../community/presentation/community_hub_screen.dart';
import '../application/fortune_category_provider.dart';
import '../domain/fortune_category_model.dart';
import '../domain/fortune_matrix.dart';
import 'widgets/fortune_matrix_section.dart';

/// [전체보기 카테고리 허브] Fortune Fusion(신통방통) 앱 전체 카테고리를 한 화면에서
/// 파악·탐색할 수 있게 만드는 허브 페이지.
///
/// 점신류 앱의 "카테고리 풍부함"을 벤치마킹하되 그대로 베끼지 않고, 우리 서비스
/// 구조(열림패스/복주머니/부적/소원게시판·소원방/AI상담/커뮤니티)에 맞춰 재구성한다.
/// 화면 순서: ①헤더 ②오늘 추천 ③대표카테고리4개 ④전체 그룹(연동콘텐츠만) ⑤빠른진입
/// ⑥열림패스 상태 ⑦하단 연결 CTA.
///
/// [주의] 이 페이지는 Presentation 레이어 신규 화면이며, 기존 Provider(Pass/Wallet)
/// 와 공용 위젯(PremiumCard/PremiumButton/PremiumChip 등), 공용 헬퍼
/// (navigateWithPassGate/showPassRequiredSheet/showWishHallOfFameSheet)를 그대로
/// 재사용한다. 상세 결과 화면/커뮤니티 상세 화면은 이번 작업 범위에서 손대지 않는다.
class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PassProvider>().load();
      context.read<WalletProvider>().load();
      // [운세 카테고리 확장] 관리자(FortuneCategory/FortuneCategoryGroup)가
      // 설정한 그룹/정렬/노출 데이터를 로드한다. 실패하거나 아직 로딩 중이면
      // 기존 정적 _categoryGroups로 그대로 폴백되어(_resolveCategoryGroups)
      // 화면 동작에는 영향이 없다.
      context.read<FortuneCategoryProvider>().load();
    });
  }

  /// 카테고리(대표4개/그룹칩/빠른진입) 공통 진입 핸들러.
  /// - route가 null이면 아직 상세 화면이 없는 카테고리 → "준비중" 안내만 표시.
  /// - route가 있으면 기존 [navigateWithPassGate]로 열림패스 게이트체크 후 이동.
  Future<void> _open(
    BuildContext context, {
    required String label,
    String? route,
    bool requiresPass = false,
  }) async {
    if (route == null) {
      AppToast.show(context, '$label · 준비 중이에요! 곧 만나볼 수 있어요 🙏');
      return;
    }
    if (requiresPass) setState(() => _checking = true);
    // [운세 카테고리 확장 - 딥링크] 관리자 카테고리(오행 재물운/타로 YES·NO
    // 등)를 탭한 경우, saju/tarot 공용 입력화면에 미리 선택된 토픽/스프레드를
    // 넘겨준다. 매칭되는 관리자 카테고리가 없으면(기존 정적 항목) null이라
    // 기존 동작과 완전히 동일하다.
    final arguments = _resolveDeepLinkArguments(
      context,
      label: label,
      route: route,
    );
    await navigateWithPassGate(
      context,
      title: label,
      route: route,
      requiresPass: requiresPass,
      arguments: arguments,
    );
    if (mounted && requiresPass) setState(() => _checking = false);
  }

  /// [운섹션 87 카테고리 통합] [FortuneMatrix] 항목 진입 핸들러.
  ///
  /// 기존 [_open]은 requiresPass(bool) 하나로만 판단해 서버 소진형
  /// [PassProvider.consume]을 호출하지만, 87개 카테고리는 그보다 세분화된
  /// 정책(하루1회/최초1회/항상프리패스)을 가지므로 [CategoryGate.decide]로
  /// 먼저 판정한다. 통과하면 이미 화면이 있는 카테고리는 그 라우트로,
  /// 아직 없는 카테고리는 공용 결과 화면(`/fortune/category`)으로 보낸다.
  ///
  /// [STEP8 - _openMatrixEntry 서버 검증 우회 문제 해결] [CategoryGate.decide]는
  /// "열림패스가 활성 상태면 정책과 무관하게 항상 허용"이라는 순수 로컬 판정만
  /// 한다(서버 호출 없음). 그래서 saju/name/face/palm/compatibility처럼 서버가
  /// "이 패스로 이 카테고리를 이미 2회 이용했는지"를 검증하는 카테고리라도, 이
  /// 매트릭스 경로(37개 카테고리)로 들어오면 그 검증이 전혀 걸리지 않는 구조적
  /// 갭이 있었다. 이제 로컬 판정이 통과했고(=열림패스 활성) 진입 라우트가
  /// [categoryKeyForRoute]에 매핑된 카테고리라면, [navigateWithPassGate]와 동일한
  /// 방식으로 서버 게이트체크(checkOnly)를 한 번 더 거친다. 매핑되지 않은 라우트
  /// (타로/오늘의 운세 등, 무료이거나 각 API 자신이 최종 검증)는 기존 동작 그대로
  /// 유지한다(회귀 없음).
  Future<void> _openMatrixEntry(FortuneCategoryEntry entry) async {
    // [STEP8-2 로그인 필수 UI] 무료 카테고리(openFree/freeOncePerDay 등)는
    // 로그인 없이도 그대로 열람 가능해야 하므로, CategoryGate.decide로 먼저
    // 로컬 정책을 판정한 "이후"에도 여전히 프리패스가 필요한 경우
    // (=paidOnlyPassGate이거나 무료 소진으로 차단된 경우)에만 로그인을
    // 강제한다. 즉 "프리패스 클릭시 로그인 필수" 원칙을 이 매트릭스 경로에도
    // 동일하게 적용하되, 완전 무료 콘텐츠까지 로그인 장벽을 세우지 않는다.
    setState(() => _checking = true);
    final access = context.read<AccessChecker>();
    final decision = await CategoryGate.decide(entry, access);
    if (!mounted) return;

    if (!decision.allowed) {
      setState(() => _checking = false);
      if (!context.read<AuthProvider>().isLoggedIn) {
        PendingPassRequestStore.save(
          PendingPassRequest(
            title: entry.title,
            route: entry.existingRoute ?? FortuneMatrix.genericCategoryRoute,
            arguments: entry.existingRoute != null
                ? entry.routeArguments
                : entry.id,
            categoryKey: entry.existingRoute != null
                ? categoryKeyForRoute(entry.existingRoute!)
                : null,
          ),
        );
        await showLoginRequiredSheet(context, categoryTitle: entry.title);
        return;
      }
      await showPassRequiredSheet(context, categoryTitle: entry.title);
      return;
    }

    final route = entry.existingRoute;
    final categoryKey = route != null ? categoryKeyForRoute(route) : null;

    if (categoryKey != null && access.isOpenPassActive()) {
      final pass = context.read<PassProvider>();
      final ok = await pass.consume(
        contentType: 'fortune_category',
        contentId: entry.title,
        categoryKey: categoryKey,
      );
      if (!mounted) return;
      setState(() => _checking = false);
      if (!ok) {
        if (pass.lastErrorReason == 'CATEGORY_LIMIT_REACHED') {
          await showCategoryLimitReachedSheet(
            context,
            categoryTitle: entry.title,
            message: pass.lastError,
          );
        } else {
          await showPassRequiredSheet(context, categoryTitle: entry.title);
        }
        return;
      }
    } else {
      setState(() => _checking = false);
    }

    if (route != null) {
      Navigator.of(context).pushNamed(route, arguments: entry.routeArguments);
      return;
    }
    Navigator.of(
      context,
    ).pushNamed(FortuneMatrix.genericCategoryRoute, arguments: entry.id);
  }

  /// [운세 카테고리 확장 - 딥링크] categoryKey → saju 초기 토픽 매핑.
  /// 매핑되지 않은 categoryKey(예: 종합 'saju')는 null을 반환해 기존
  /// 기본 동작('종합' 선택)을 그대로 유지한다.
  static const Map<String, String> _sajuTopicByCategoryKey = {
    'saju_wealth': '재물',
    'saju_career': '직업',
    'saju_love': '애정',
    'saju_health': '건강',
    'saju_monthly': '월별',
  };

  /// [운세 카테고리 확장 - 딥링크] categoryKey → tarot 초기 스프레드/토픽 매핑.
  static const Map<String, ({String? spreadType, String? topic})>
  _tarotDeepLinkByCategoryKey = {
    'tarot_yesno': (spreadType: 'yes_no', topic: null),
    'tarot_love': (spreadType: null, topic: 'love'),
  };

  /// 탭한 항목의 [label]을 관리자(FortuneCategoryProvider) 카테고리 목록에서
  /// 역매칭해 categoryKey를 찾고, saju/tarot 입력화면에 전달할 초기값 Map을
  /// 만든다. 정적 placeholder 항목(관리자 데이터에 없는 label)이거나 대상
  /// 라우트가 아니면 null → 기존 화면 기본 동작 그대로.
  Object? _resolveDeepLinkArguments(
    BuildContext context, {
    required String label,
    required String route,
  }) {
    if (route != '/ai-fortune/saju/input' &&
        route != '/ai-fortune/tarot/question') {
      return null;
    }
    final groups = context.read<FortuneCategoryProvider>().groups;
    String? categoryKey;
    for (final g in groups) {
      for (final c in g.categories) {
        if (c.title == label) {
          categoryKey = c.categoryKey;
          break;
        }
      }
      if (categoryKey != null) break;
    }
    if (categoryKey == null) return null;

    if (route == '/ai-fortune/saju/input') {
      final topic = _sajuTopicByCategoryKey[categoryKey];
      if (topic == null) return null;
      return {
        'initialTopics': [topic],
      };
    }

    final cfg = _tarotDeepLinkByCategoryKey[categoryKey];
    if (cfg == null) return null;
    return {
      if (cfg.spreadType != null) 'initialSpreadType': cfg.spreadType,
      if (cfg.topic != null) 'initialTopic': cfg.topic,
    };
  }

  /// [운세 카테고리 확장] 정적 그룹(_categoryGroups)의 [title] ↔ 관리자
  /// FortuneCategoryGroup.code 매핑.
  /// [미연동 콘텐츠 삭제] "테마 운세"(별자리/혈액형/꿈해몽 등 전부
  /// 미연동)와 "행운/정화"(행운의번호/살풀이 전부 미연동) 그룹은
  /// _categoryGroups에서 통째로 삭제했으므로 매핑도 함께 제거한다.
  static const Map<String, String> _groupCodeByTitle = {
    '오늘/기간 운세': 'today',
    '사주': 'saju',
    '타로': 'tarot',
    '얼굴/손금': 'face_palm',
    '상담/해석': 'consultation_ext',
  };

  /// 관리자 데이터를 기존 정적 그룹 구조([_categoryGroups]와 동일한 레코드
  /// 타입)로 병합한다.
  /// - 매핑되는 그룹: 관리자 카테고리(활성+노출, displayOrder 정렬)를 앞에
  ///   배치하고, 아직 상세 화면이 없는 기존 정적 placeholder 항목(예:
  ///   "만세력", "대운/세운")은 라벨이 중복되지 않는 한 뒤에 그대로 유지한다.
  /// - 매핑되지 않는 그룹은 정적 데이터를 그대로 둔다.
  /// - 관리자 데이터 로딩 실패/로딩 중/데이터 없음이면 전체를 기존 정적
  ///   [_categoryGroups]로 폴백한다(레이아웃/문구 100% 기존 유지).
  List<
    ({
      IconData icon,
      String title,
      String desc,
      List<({String label, String? route, bool pass})> items,
    })
  >
  _resolveCategoryGroups(FortuneCategoryProvider provider) {
    if (!provider.state.isSuccess || provider.groups.isEmpty) {
      return _categoryGroups;
    }
    final byCode = <String, FortuneCategoryGroupData>{
      for (final g in provider.groups) g.code: g,
    };

    return _categoryGroups.map((staticGroup) {
      final code = _groupCodeByTitle[staticGroup.title];
      final adminGroup = code == null ? null : byCode[code];
      if (adminGroup == null || adminGroup.categories.isEmpty) {
        return staticGroup;
      }

      final adminItems = adminGroup.categories
          .map((c) => (label: c.title, route: c.route, pass: c.requiresPass))
          .toList();
      final adminLabels = adminItems.map((e) => e.label).toSet();
      final remainingStaticItems = staticGroup.items
          .where((e) => !adminLabels.contains(e.label))
          .toList();

      return (
        icon: staticGroup.icon,
        title: adminGroup.label,
        desc: adminGroup.description?.isNotEmpty == true
            ? adminGroup.description!
            : staticGroup.desc,
        items: [...adminItems, ...remainingStaticItems],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pass = context.watch<PassProvider>();
    final wallet = context.watch<WalletProvider>();
    final categoryGroups = _resolveCategoryGroups(
      context.watch<FortuneCategoryProvider>(),
    );

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            UnifiedTokens.spaceXl,
            UnifiedTokens.spaceMd,
            UnifiedTokens.spaceXl,
            UnifiedTokens.spaceXxl,
          ),
          children: [
            _Header(balance: wallet.balance),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            FadeSlideIn(
              child: _TrendingRow(
                onTap: (label, route, pass) => _open(
                  context,
                  label: label,
                  route: route,
                  requiresPass: pass,
                ),
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            FadeSlideIn(
              delay: const Duration(milliseconds: 40),
              child: const PremiumSectionTitleLite(
                title: '대표 카테고리',
                subtitle: '오늘 가장 먼저 확인해볼 4가지',
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: _FeaturedGrid(
                pass: pass,
                busy: _checking,
                onTap: (label, route, requiresPass) => _open(
                  context,
                  label: label,
                  route: route,
                  requiresPass: requiresPass,
                ),
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: const PremiumSectionTitleLite(
                title: '전체 카테고리',
                subtitle: '당신에게 맞는 해석을 골라보세요',
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            ...List.generate(categoryGroups.length, (index) {
              final group = categoryGroups[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceMd),
                child: FadeSlideIn(
                  delay: Duration(milliseconds: 40 * index),
                  child: _CategoryGroupCard(
                    group: group,
                    onTapItem: (label, route, requiresPass) => _open(
                      context,
                      label: label,
                      route: route,
                      requiresPass: requiresPass,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: UnifiedTokens.spaceSm),

            // [운섹션 87 카테고리 통합 - 궁합 신규 구현 완료] 위 "전체
            // 카테고리"(관리자 8그룹)와는 별개로, 실제 구현된 87개 카테고리
            // (T/S/N/C/K/V/O/F/X/G/B/D/R)를 한 화면에서 그룹별로 훑어볼 수
            // 있게 노출한다. 각 항목을 탭하면 [_openMatrixEntry]가
            // [CategoryGate]로 판정 후 이동한다.
            FadeSlideIn(
              child: const PremiumSectionTitleLite(
                title: '37가지 운세 한눈에 보기',
                subtitle: '오늘·사주·이름·궁합·관상손금 등 전체',
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            FadeSlideIn(
              delay: const Duration(milliseconds: 40),
              child: FortuneMatrixSection(onTapEntry: _openMatrixEntry),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            FadeSlideIn(
              child: const PremiumSectionTitleLite(
                title: '지금 많이 찾는 기능',
                subtitle: '운세 그 이상, 마음을 나누는 순간들',
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            FadeSlideIn(
              delay: const Duration(milliseconds: 40),
              child: const _QuickEntryRow(),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            FadeSlideIn(child: _PassStatusStrip(pass: pass)),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            FadeSlideIn(
              delay: const Duration(milliseconds: 40),
              child: const _BottomConnectRow(),
            ),
          ],
        ),
      ),
    );
  }
}

/// ① 상단 헤더 - 뒤로가기 + 타이틀/보조카피 + 복주머니 소형 상태 표시.
///
/// [복주머니 노출 정책] 이 페이지의 주인공은 운세 카테고리 탐색이므로, 복주머니는
/// 숫자를 크게 강조하지 않고 상단의 아주 작은 보조 pill로만 노출한다(탭하면
/// 지갑 화면으로 연결). 적립/구매 구조는 지갑 화면에서 다룬다.
class _Header extends StatelessWidget {
  const _Header({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: UnifiedColors.cardAllMenu,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: UnifiedTokens.iconMd,
              color: UnifiedColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: UnifiedTokens.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('전체보기', style: UnifiedText.titleLarge()),
              const SizedBox(height: 4),
              Text('오늘 필요한 운세와 해석을 한 번에 만나보세요', style: UnifiedText.body()),
            ],
          ),
        ),
        const SizedBox(width: UnifiedTokens.spaceSm),
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: UnifiedColors.cardAllMenu,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.savings_outlined,
                  size: UnifiedTokens.iconSm,
                  color: UnifiedColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text('$balance', style: UnifiedText.chipLabel()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 섹션 타이틀 + 보조 카피 1줄(감성 톤 유지) - 이 화면 전용 라이트 버전.
/// 기존 [PremiumSectionTitle]은 "제목+우측 액션"용이라, 이 화면처럼 제목 아래
/// 감성 서브카피가 필요한 곳엔 별도의 얇은 위젯으로 통일해 재사용한다.
class PremiumSectionTitleLite extends StatelessWidget {
  const PremiumSectionTitleLite({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: UnifiedText.title()),
        const SizedBox(height: 3),
        Text(subtitle, style: UnifiedText.caption()),
      ],
    );
  }
}

/// ② 오늘 추천 / 인기 카테고리 - 가로 스크롤 미니 칩. 대표카테고리(큰 카드)보다
/// 가볍게, "지금 많이 보는" 느낌만 전달하는 보조 진입 스트립.
class _TrendingRow extends StatelessWidget {
  const _TrendingRow({required this.onTap});

  final void Function(String label, String? route, bool requiresPass) onTap;

  static const _items = [
    // [프리패스 전체잠금 통일] 오늘의 운세 전체잠금(과거 무료 노출).
    (Icons.wb_sunny_outlined, '오늘의 운세', '/home/daily-fortune-detail', true),
    (Icons.style_outlined, '타로', '/ai-fortune/tarot/question', true),
    (
      Icons.chat_bubble_outline_rounded,
      'AI 상담',
      '/ai-fortune/consultation/type',
      true,
    ),
    (Icons.badge_outlined, '이름 운세', '/ai-fortune/name/input', true),
    (Icons.back_hand_outlined, '손금', '/ai-fortune/palm/capture', true),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: UnifiedTokens.spaceSm),
        itemBuilder: (context, i) {
          final (icon, label, route, requiresPass) = _items[i];
          return PremiumChip(
            label: label,
            icon: icon,
            selected: false,
            onTap: () => onTap(label, route, requiresPass),
            inactiveBg: UnifiedColors.chipInactiveBg,
            inactiveFg: UnifiedColors.textSecondary,
            labelStyle: UnifiedText.chipLabel(),
          );
        },
      ),
    );
  }
}

/// ③ 대표 카테고리 4개(오늘의 운세/정통사주/궁합/타로) - 2x2 큰 카드 그리드.
/// 그룹 칩보다 훨씬 크게 보여, "가장 먼저 눌러볼 카테고리"임을 시각적으로 강조한다.
class _FeaturedGrid extends StatelessWidget {
  const _FeaturedGrid({
    required this.pass,
    required this.busy,
    required this.onTap,
  });

  final PassProvider pass;
  final bool busy;
  final void Function(String label, String route, bool requiresPass) onTap;

  static const _items = [
    (
      '오늘의 운세',
      '오늘 하루의 흐름과 행운 포인트',
      Icons.wb_sunny_outlined,
      '/home/daily-fortune-detail',
      // [프리패스 전체잠금 통일] 오늘의 운세 전체잠금(과거 무료 노출).
      true,
    ),
    (
      '정통사주',
      '타고난 기운과 인생의 방향',
      Icons.auto_stories_outlined,
      '/ai-fortune/saju/input',
      true,
    ),
    (
      '이름 운세',
      '이름에 담긴 기운과 어울림',
      Icons.badge_outlined,
      '/ai-fortune/name/input',
      true,
    ),
    (
      '타로',
      '지금 마음과 선택의 해석',
      Icons.style_outlined,
      '/ai-fortune/tarot/question',
      true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // [버그 수정] 이 Column은 ListView(높이 unbounded) 안에 있으므로,
    // 내부 Row에 crossAxisAlignment.stretch를 쓰면 Row가 "부모 높이에 맞춰
    // 자식을 늘리라"는 tight 무한 높이 제약을 자식(_FeaturedCard)에 그대로
    // 전달해 "BoxConstraints forces an infinite height" 레이아웃 예외가
    // 발생한다. release 모드에서는 이 예외가 콘솔에 노출되지 않고 해당
    // 서브트리만 조용히 비어 보이는 형태로 나타난다("대표 카테고리" 아래
    // 카드 4개가 통째로 사라지는 버그의 정확한 원인).
    // _FeaturedCard는 이미 SizedBox(height: 138)로 고정 높이를 갖고 있어
    // stretch가 애초에 불필요했으므로 제거한다.
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: UnifiedTokens.spaceSm),
          Row(
            children: [
              for (var col = 0; col < 2; col++) ...[
                if (col > 0) const SizedBox(width: UnifiedTokens.spaceSm),
                Expanded(
                  child: _FeaturedCard(
                    item: _items[row * 2 + col],
                    pass: pass,
                    busy: busy,
                    onTap: onTap,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.item,
    required this.pass,
    required this.busy,
    required this.onTap,
  });

  final (String, String, IconData, String, bool) item;
  final PassProvider pass;
  final bool busy;
  final void Function(String label, String route, bool requiresPass) onTap;

  @override
  Widget build(BuildContext context) {
    final (title, desc, icon, route, requiresPass) = item;
    final isFree = !requiresPass;
    // [재잠금 정확도] pass.isActive(서버 스냅샷) 대신 AccessChecker의 실시간
    // 계산값을 사용해 만료 시점 이후 즉시 배지가 잠금 상태로 반영되게 한다.
    final isPassActive = context.watch<AccessChecker>().openPassState.isActive;
    final badgeLabel = isFree ? '무료' : (isPassActive ? '이용가능' : '프리패스');
    final badgeType = isFree || isPassActive
        ? PremiumBadgeType.done
        : PremiumBadgeType.pass;

    return SizedBox(
      height: 138,
      child: PremiumCard(
        backgroundColor: UnifiedColors.cardAllMenu,
        borderColor: Colors.transparent,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
        showShadow: false,
        padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
        onTap: busy ? null : () => onTap(title, route, requiresPass),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: UnifiedTokens.iconCircleLg,
                  height: UnifiedTokens.iconCircleLg,
                  alignment: Alignment.center,
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
                const Spacer(),
                PremiumBadge(label: badgeLabel, type: badgeType),
              ],
            ),
            const Spacer(),
            Text(title, style: UnifiedText.title()),
            const SizedBox(height: 3),
            Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: UnifiedText.caption(),
            ),
          ],
        ),
      ),
    );
  }
}

/// ④ 전체 카테고리 그룹의 데이터 정의.
/// [미연동 콘텐츠 삭제] 상세 화면이 없던(route: null) 하위 항목을 모두
/// 삭제했다. 그 결과 모든 항목이 미연동이었던 "테마 운세"(별자리/혈액형/
/// 꿈해몽/포춘쿠키/능력평가)와 "행운/정화"(행운의번호/살풀이) 2개 그룹은
/// 통째로 삭제했다(기존 8개 → 5개 그룹). 남은 그룹의 항목은 전부 실제
/// 화면으로 연동되어 있으므로 "준비중" 안내 분기는 더 이상 발생하지 않는다.
/// requiresPass가 true인 항목은 [navigateWithPassGate]로 열림패스 게이트를 거친다.
const List<
  ({
    IconData icon,
    String title,
    String desc,
    List<({String label, String? route, bool pass})> items,
  })
>
_categoryGroups = [
  (
    icon: Icons.wb_sunny_outlined,
    title: '오늘/기간 운세',
    desc: '오늘 하루의 흐름을 확인해보세요',
    items: [
      // [프리패스 전체잠금 통일] 오늘의 운세 전체잠금(과거 무료 노출).
      (label: '오늘의 운세', route: '/home/daily-fortune-detail', pass: true),
    ],
  ),
  (
    icon: Icons.auto_stories_outlined,
    title: '사주',
    desc: '타고난 기운과 흐름을 깊게 해석해보세요',
    items: [
      (label: '정통사주', route: '/ai-fortune/saju/input', pass: true),
      (label: '오늘의 사주', route: '/ai-fortune/saju/input', pass: true),
    ],
  ),
  (
    icon: Icons.style_outlined,
    title: '타로',
    desc: '지금 마음이 궁금할 때, 카드에게 물어보세요',
    items: [
      (label: '오늘의 타로', route: '/ai-fortune/tarot/question', pass: true),
      (label: '연애타로', route: '/ai-fortune/tarot/question', pass: true),
      (label: '재물타로', route: '/ai-fortune/tarot/question', pass: true),
      (label: '선택타로', route: '/ai-fortune/tarot/question', pass: true),
      (label: '속마음 타로', route: '/ai-fortune/tarot/question', pass: true),
    ],
  ),
  (
    icon: Icons.face_outlined,
    title: '얼굴/손금',
    desc: '얼굴과 손에 담긴 이야기를 읽어보세요',
    items: [
      (label: '오늘의 관상', route: '/ai-fortune/face/capture', pass: true),
      (label: '손금', route: '/ai-fortune/palm/capture', pass: true),
    ],
  ),
  (
    icon: Icons.chat_bubble_outline_rounded,
    title: '상담/해석',
    desc: '혼자 고민하지 말고 함께 이야기해요',
    items: [
      (label: 'AI 상담', route: '/ai-fortune/consultation/type', pass: true),
      (label: '고민상담', route: '/ai-fortune/consultation/type', pass: true),
    ],
  ),
];

/// 그룹 1개를 카드로 렌더링 - 제목/설명 + 하위 카테고리 미니 칩(Wrap).
class _CategoryGroupCard extends StatelessWidget {
  const _CategoryGroupCard({required this.group, required this.onTapItem});

  final ({
    IconData icon,
    String title,
    String desc,
    List<({String label, String? route, bool pass})> items,
  })
  group;
  final void Function(String label, String? route, bool requiresPass) onTapItem;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                group.icon,
                size: UnifiedTokens.iconMd,
                color: UnifiedColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(group.title, style: UnifiedText.title()),
            ],
          ),
          const SizedBox(height: 3),
          Text(group.desc, style: UnifiedText.caption()),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.items
                .map(
                  (item) => _SubCategoryChip(
                    label: item.label,
                    isReady: item.route != null,
                    onTap: () => onTapItem(item.label, item.route, item.pass),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// 그룹 내부 하위 카테고리 미니 칩 - 상세 화면이 없는 항목은 살짝 옅게 표시해
/// "곧 만나볼 카테고리"임을 은은하게 구분한다(그래도 탭은 가능 - 준비중 안내).
class _SubCategoryChip extends StatelessWidget {
  const _SubCategoryChip({
    required this.label,
    required this.isReady,
    required this.onTap,
  });

  final String label;
  final bool isReady;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isReady ? UnifiedColors.bg : UnifiedColors.chipInactiveBg,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
          border: Border.all(color: Colors.transparent),
        ),
        child: Text(
          label,
          style: UnifiedText.chipLabel(
            color: isReady
                ? UnifiedColors.textPrimary
                : UnifiedColors.textCaption,
          ),
        ),
      ),
    );
  }
}

/// ⑤ 빠른 진입 기능 섹션 - AI상담/이름운세/행운의번호/소원게시판/소원방.
/// 우리 서비스 고유 감성 기능·커뮤니티로 이어주는 짧은 CTA 카드 5개.
class _QuickEntryRow extends StatelessWidget {
  const _QuickEntryRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, __) =>
            const SizedBox(width: UnifiedTokens.spaceSm),
        itemBuilder: (context, i) {
          switch (i) {
            case 0:
              return _QuickEntryCard(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'AI 상담',
                onTap: () async {
                  final isPassActive = context
                      .read<AccessChecker>()
                      .canAccessFortuneScope();
                  if (isPassActive) {
                    Navigator.of(
                      context,
                    ).pushNamed('/ai-fortune/consultation/type');
                  } else {
                    await navigateWithPassGate(
                      context,
                      title: 'AI 상담',
                      route: '/ai-fortune/consultation/type',
                      requiresPass: true,
                    );
                  }
                },
              );
            case 1:
              return _QuickEntryCard(
                icon: Icons.badge_outlined,
                label: '이름 운세',
                onTap: () =>
                    Navigator.of(context).pushNamed('/ai-fortune/name/input'),
              );
            case 2:
              return _QuickEntryCard(
                icon: Icons.auto_awesome_outlined,
                label: '행운의 번호',
                onTap: () =>
                    AppToast.show(context, '오늘의 행운숫자는 홈 화면에서 곧 만나볼 수 있어요 ✨'),
              );
            default:
              return _QuickEntryCard(
                icon: Icons.star_border_rounded,
                label: '신통방통 소원방',
                onTap: () => Navigator.of(context).pushNamed('/wish-room'),
              );
          }
        },
      ),
    );
  }
}

class _QuickEntryCard extends StatelessWidget {
  const _QuickEntryCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      child: PremiumCard(
        backgroundColor: UnifiedColors.cardAllMenu,
        borderColor: Colors.transparent,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
        showShadow: false,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: UnifiedTokens.iconLg,
              color: UnifiedColors.textPrimary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: UnifiedText.chipLabel(),
            ),
          ],
        ),
      ),
    );
  }
}

/// ⑥ 열림패스 상태 영역 - 이 페이지의 주인공이 아닌 "카테고리 탐색을 돕는 보조
/// 구조"로만 취급한다.
/// - 비활성: 옅은 안내 배너 + "광고 보고 열기" 버튼(기존 [showPassRequiredSheet] 재사용)
/// - 활성: 홍보 문구를 완전히 숨기고 "남은 시간"만 깔끔하게 표시
class _PassStatusStrip extends StatefulWidget {
  const _PassStatusStrip({required this.pass});

  final PassProvider pass;

  @override
  State<_PassStatusStrip> createState() => _PassStatusStripState();
}

class _PassStatusStripState extends State<_PassStatusStrip> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // [재잠금 정확도] 만료 시점이 지나면 사용자가 아무 조작을 하지 않아도
    // 이 스트립이 자동으로 다시 나타나도록 1초 간격으로 리빌드한다.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessChecker>();
    final passState = access.openPassState;
    if (passState.isActive) {
      final sec = passState.remaining.inSeconds;
      final h = sec ~/ 3600;
      final m = (sec % 3600) ~/ 60;
      final timeLabel = h > 0 ? '$h시간 $m분 남음' : '$m분 남음';

      return PremiumCard(
        backgroundColor: UnifiedColors.passBar,
        borderColor: Colors.transparent,
        showShadow: false,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(
              Icons.lock_open_rounded,
              size: UnifiedTokens.iconMd,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '프리패스 이용 중',
                style: UnifiedText.bodyStrong(color: Colors.white),
              ),
            ),
            Text(
              timeLabel,
              style: UnifiedText.chipLabel(color: UnifiedColors.neon),
            ),
          ],
        ),
      );
    }

    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('프리패스로 더 많은 운세 보기', style: UnifiedText.bodyStrong()),
                const SizedBox(height: 3),
                Text('광고 보고 전체 운세 열기', style: UnifiedText.caption()),
              ],
            ),
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          SizedBox(
            width: 96,
            child: PremiumButton.secondary(
              label: '열어보기',
              height: 36,
              onPressed: () =>
                  showPassRequiredSheet(context, categoryTitle: '전체 운세'),
            ),
          ),
        ],
      ),
    );
  }
}

/// ⑦ 하단 연결 CTA - 커뮤니티 가기 / 후기 보기 / 고민상담 보기.
/// 전체보기가 "운세 메뉴판"에서 끝나지 않고 커뮤니티·감성 기능까지 이어지도록
/// 마지막에 가볍게 3개의 연결 지점을 배치한다.
class _BottomConnectRow extends StatelessWidget {
  const _BottomConnectRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ConnectTile(
            icon: Icons.forum_rounded,
            label: '커뮤니티 가기',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CommunityHubScreen()),
            ),
          ),
        ),
        const SizedBox(width: UnifiedTokens.spaceSm),
        Expanded(
          child: _ConnectTile(
            icon: Icons.chat_bubble_rounded,
            label: '고민상담 보기',
            onTap: () => Navigator.of(
              context,
            ).pushNamed('/ai-fortune/consultation/type'),
          ),
        ),
      ],
    );
  }
}

class _ConnectTile extends StatelessWidget {
  const _ConnectTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: UnifiedColors.cardAllMenu,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
          border: Border.all(color: Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: UnifiedTokens.iconMd,
              color: UnifiedColors.textPrimary,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: UnifiedText.chipLabel(),
            ),
          ],
        ),
      ),
    );
  }
}
