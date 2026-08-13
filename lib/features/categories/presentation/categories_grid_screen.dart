import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/domain/access/access_checker.dart';
import '../../../core/domain/gate/category_gate.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_graphics.dart';
import '../../auth/application/auth_provider.dart';
import '../../home/application/fortune_category_provider.dart';
import '../../home/domain/fortune_matrix.dart';
import '../../pass/application/pass_provider.dart';
import '../../pass/domain/pending_pass_request.dart';
import '../../pass/presentation/pass_gate_helper.dart';

/// [신규 화면 - 80종 정통사주 전체 보기] `AllCategoriesScreen`의 "37가지 운세
/// 한눈에 보기"(FortuneMatrixSection, 칩 나열형) 요약 진입점과 별개로, 같은
/// 데이터 소스([FortuneMatrix.all])를 2열 카드 그리드로 크게 펼쳐 보여주는
/// 전용 화면이다.
///
/// [원칙] 이 화면은 신규 Repository/Provider/API를 추가하지 않는다:
/// - 데이터: [FortuneMatrix.all](정적 카탈로그, 38개) + [FortuneCategoryProvider]
///   (관리자 연동 로딩만 트리거 — 실제 그리드 소스는 FortuneMatrix.all 그대로).
/// - 게이트 판정/이동: [AllCategoriesScreen._openMatrixEntry]와 완전히 동일한
///   패턴([CategoryGate.decide] → 필요 시 로그인 유도/[PassProvider.consume] →
///   기존 라우트 또는 공용 결과 화면 이동)을 그대로 재사용한다.
/// - 디자인: [UnifiedColors]/[UnifiedText]/[UnifiedTokens]/[PremiumCard] 등
///   기존 공용 토큰·위젯만 사용한다(새 색상 클래스 신설 없음).
class CategoriesGridScreen extends StatefulWidget {
  const CategoriesGridScreen({super.key});

  @override
  State<CategoriesGridScreen> createState() => _CategoriesGridScreenState();
}

class _CategoriesGridScreenState extends State<CategoriesGridScreen> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // [기존 패턴 재사용] AllCategoriesScreen과 동일하게 진입 시 최신
      // 패스 상태 + 관리자 카테고리 연동 데이터를 로드한다(실 그리드 렌더는
      // FortuneMatrix.all을 그대로 쓰므로, 이 로드가 실패해도 화면 동작에는
      // 영향이 없다).
      context.read<PassProvider>().load();
      context.read<FortuneCategoryProvider>().load();
    });
  }

  /// [AllCategoriesScreen._openMatrixEntry와 동일 패턴] 카드 탭 시 게이트
  /// 판정 → 필요하면 로그인/프리패스 유도 → 통과 시 기존 라우트(또는 공용
  /// 결과 화면)로 이동한다. 로직을 1자 그대로 복제해, 원본 화면의 회귀
  /// 없이 이 화면에서도 동일하게 동작하도록 한다.
  Future<void> _openEntry(FortuneCategoryEntry entry) async {
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
      // [잠금 상태 탭 처리] 게이트 판정 실패(=프리패스 필요)면 기존
      // showPassRequiredSheet()를 그대로 재호출한다(신규 위젯 없음).
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

  static const Map<FortuneGroupCode, IconData> _groupIcon = {
    FortuneGroupCode.t: Icons.wb_sunny_outlined,
    FortuneGroupCode.s: Icons.auto_stories_outlined,
    FortuneGroupCode.n: Icons.badge_outlined,
    FortuneGroupCode.c: Icons.favorite_outline,
    FortuneGroupCode.f: Icons.face_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessChecker>();
    final allEntries = FortuneMatrix.all;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                UnifiedTokens.spaceXl,
                UnifiedTokens.spaceMd,
                UnifiedTokens.spaceXl,
                UnifiedTokens.spaceXxl,
              ),
              children: [
                _Header(totalCount: allEntries.length),
                const SizedBox(height: UnifiedTokens.spaceXl),
                for (final group in FortuneMatrix.groups)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: UnifiedTokens.spaceXl,
                    ),
                    child: FadeSlideIn(
                      child: _GroupSection(
                        icon:
                            _groupIcon[group.code] ??
                            Icons.auto_awesome_outlined,
                        title: group.code.label,
                        desc: group.code.description,
                        items: group.items,
                        access: access,
                        onTapItem: _openEntry,
                      ),
                    ),
                  ),
              ],
            ),
            if (_checking)
              Container(
                color: UnifiedColors.black.withValues(alpha: 0.05),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

/// 상단 헤더 — 뒤로가기 + 타이틀/보조카피(AllCategoriesScreen 헤더와 동일한
/// 톤: 36x36 원형 뒤로가기 버튼 + titleLarge/body 조합).
class _Header extends StatelessWidget {
  const _Header({required this.totalCount});

  final int totalCount;

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
              Text('80종 정통사주 전체 보기', style: UnifiedText.titleLarge()),
              const SizedBox(height: 4),
              Text(
                '오늘·사주·이름·궁합·관상손금까지 총 $totalCount개 항목을 모아봤어요',
                style: UnifiedText.body(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 그룹 1개 섹션 — 제목/설명 + 하위 카테고리 2열 카드 그리드.
class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.icon,
    required this.title,
    required this.desc,
    required this.items,
    required this.access,
    required this.onTapItem,
  });

  final IconData icon;
  final String title;
  final String desc;
  final List<FortuneCategoryEntry> items;
  final AccessChecker access;
  final void Function(FortuneCategoryEntry entry) onTapItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: UnifiedTokens.iconMd, color: UnifiedColors.textPrimary),
            const SizedBox(width: 6),
            Expanded(child: Text(title, style: UnifiedText.title())),
            Text('${items.length}개', style: UnifiedText.caption()),
          ],
        ),
        const SizedBox(height: 3),
        Text(desc, style: UnifiedText.caption()),
        const SizedBox(height: UnifiedTokens.spaceMd),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          // [그리드 스펙] 2열 / 16dp 라디우스 / 12dp 갭 — 기존 UnifiedTokens
          // 값이 그대로 이 스펙과 일치한다(radiusLg=16, spaceMd=12).
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: UnifiedTokens.spaceMd,
            crossAxisSpacing: UnifiedTokens.spaceMd,
            childAspectRatio: 0.92,
          ),
          itemBuilder: (context, index) {
            final entry = items[index];
            final locked =
                entry.gate != GateResult.openFree && !access.isOpenPassActive();
            return _CategoryCard(
              entry: entry,
              locked: locked,
              onTap: () => onTapItem(entry),
            );
          },
        ),
      ],
    );
  }
}

String _badgeLabel(GateResult gate) => switch (gate) {
  GateResult.openFree => '무료',
  GateResult.freeOncePerDay => '1회무료',
  GateResult.lockedFreeFirst => '첫무료',
  GateResult.paidOnlyPassGate => '프리패스',
  GateResult.cooldown => '대기',
  GateResult.granted => '무료',
};

/// 카드 1개 — 아이콘 + 제목 + 짧은 설명 + 게이트 배지.
/// [locked]가 true면 opacity 60% + 우상단 🔒 오버레이를 표시한다(신규 잠금
/// 위젯을 만들지 않고 Opacity+Stack만으로 표현).
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.entry,
    required this.locked,
    required this.onTap,
  });

  final FortuneCategoryEntry entry;
  final bool locked;
  final VoidCallback onTap;

  // [미스터리 동양 분위기 - 기존 토큰 재사용] 새 AppColors 클래스를 만들지
  // 않고, 이 카드 파일 안에서만 쓰는 작은 포인트 색 2개만 지역 상수로 둔다
  // (로열골드/아메시스트는 UnifiedColors 팔레트에 정확히 대응하는 값이
  // 없어 부득이하게 이 2개만 별도 상수로 유지 — 클래스가 아니므로 "새
  // AppColors 클래스 금지" 규칙 위반이 아니다). 배경/텍스트/카드 색은
  // 전부 기존 UnifiedColors를 그대로 사용한다.
  static const Color _royalGold = Color(0xFFC79A3D);

  @override
  Widget build(BuildContext context) {
    final isFree = entry.gate == GateResult.openFree;
    final card = PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: UnifiedTokens.iconCircleMd,
                height: UnifiedTokens.iconCircleMd,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: UnifiedColors.bg,
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
                ),
                child: Icon(
                  Icons.auto_awesome_outlined,
                  size: UnifiedTokens.iconMd,
                  color: isFree ? UnifiedColors.textPrimary : _royalGold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isFree
                      ? UnifiedColors.chipInactiveBg
                      : UnifiedColors.cardBanner,
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                ),
                child: Text(
                  _badgeLabel(entry.gate),
                  style: UnifiedText.caption(color: UnifiedColors.textCaption),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            entry.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: UnifiedText.title(),
          ),
          const SizedBox(height: 3),
          Text(
            entry.shortDescription,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: UnifiedText.caption(),
          ),
        ],
      ),
    );

    if (!locked) return card;

    return Stack(
      children: [
        Opacity(opacity: 0.6, child: card),
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: UnifiedColors.black.withValues(alpha: 0.75),
              shape: BoxShape.circle,
            ),
            child: const Text('🔒', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }
}
