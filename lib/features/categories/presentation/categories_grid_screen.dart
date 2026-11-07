import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_graphics.dart';
import '../../home/application/fortune_category_provider.dart';
import '../../home/domain/fortune_matrix.dart';
import '../../pass/application/pass_provider.dart';

// 2026-08-13 -- 톤 일관화 토큰. 신 클래스/신 색상 정의 0.
class _Tone {
  _Tone._();
  // spacing grid
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  // shape
  static const double radius = 16;
  static const double elevation = 2;
  // icon
  static const double iconSm = 20;
  static const double iconMd = 28;
  // type scale (Theme 의 textTheme 그대로 사용 -- 신규 정의 0)
  // colors: 0 정의. 항상 Theme.of(context).colorScheme 참조.
}

/// [신규 화면 - 80종 정통사주 전체 보기] `AllCategoriesScreen`의 "37가지 운세
/// 한눈에 보기"(FortuneMatrixSection, 칩 나열형) 요약 진입점과 별개로, 같은
/// 데이터 소스([FortuneMatrix.all])를 2열 카드 그리드로 크게 펼쳐 보여주는
/// 전용 화면이다.
///
/// [원칙] 이 화면은 신규 Repository/Provider/API를 추가하지 않는다:
/// - 데이터: [FortuneMatrix.all](정적 카탈로그, 38개) + [FortuneCategoryProvider]
///   (관리자 연동 로딩만 트리거 — 실제 그리드 소스는 FortuneMatrix.all 그대로).
/// - 진입/이동: [AllCategoriesScreen._openMatrixEntry]와 동일하게, 프리패스
///   게이트 없이 즉시 기존 라우트 또는 공용 결과 화면으로 이동한다(자유
///   이용 원칙 - 2026-11 어뷰징 제한 삭제).
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

  /// [자유 이용 원칙 - 프리패스 어뷰징 제한 삭제, 2026-11] 과거에는 카드
  /// 탭 시 [CategoryGate.decide]/[PassProvider.consume]으로 게이트를
  /// 거쳤으나, 콘텐츠 탐색은 항상 자유롭게 허용하는 정책으로 바뀌면서 이
  /// 게이트가 더 이상 필요 없어졌다. 즉시 기존 라우트 또는 공용 결과
  /// 화면으로 이동한다(결제 판정은 각 결과 화면 내부 ResultAccessService가
  /// 전담).
  Future<void> _openEntry(FortuneCategoryEntry entry) async {
    final route = entry.existingRoute;
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

  // [UI 노출 정책 - 미동작 섹션 숨김] AllCategoriesScreen의
  // FortuneMatrixSection과 동일하게 "오늘 운세"(T)/"이름 운세"(N) 섹션을
  // 이 화면에서도 숨긴다. 데이터(FortuneMatrix)는 삭제하지 않는다.
  static const Set<FortuneGroupCode> _hiddenGroups = {
    FortuneGroupCode.t,
    FortuneGroupCode.n,
  };

  @override
  Widget build(BuildContext context) {
    final visibleGroups = FortuneMatrix.groups
        .where((g) => !_hiddenGroups.contains(g.code))
        .toList();
    final allEntries = visibleGroups.expand((g) => g.items).toList();

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
                for (final group in visibleGroups)
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
                        onTapItem: _openEntry,
                      ),
                    ),
                  ),
              ],
            ),
            if (_checking)
              Container(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.05),
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
              Text('$totalCount종 정통사주 전체 보기', style: UnifiedText.titleLarge()),
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
    required this.onTapItem,
  });

  final IconData icon;
  final String title;
  final String desc;
  final List<FortuneCategoryEntry> items;
  final void Function(FortuneCategoryEntry entry) onTapItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: UnifiedTokens.iconMd,
              color: UnifiedColors.textPrimary,
            ),
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
            return _CategoryCard(entry: entry, onTap: () => onTapItem(entry));
          },
        ),
      ],
    );
  }
}

/// 카드 1개 — 아이콘 + 제목 + 짧은 설명.
/// [자유 이용 원칙 - 프리패스 어뷰징 제한 삭제, 2026-11] 과거에는 여기서
/// [entry.gate]([GateResult])를 읽어 "프리패스"/"1회무료" 등 배지와 우상단
/// 🔒 잠금 오버레이를 그렸으나, 실제 진입 제한이 사라진 뒤에는 이 배지가
/// "눌러도 안 열리는 것처럼" 사용자를 오도할 수 있어 제거했다. 결제
/// 판정은 각 결과 화면의 [결과보기] 버튼에서 ResultAccessService가
/// 전담하므로, 이 그리드 단계에서는 더 이상 잠금 상태를 표시하지 않는다.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.entry, required this.onTap});

  final FortuneCategoryEntry entry;
  final VoidCallback onTap;

  // [2026-08-13 톤 일관화] 로열골드 포인트 색 리터럴을 제거하고
  // Theme.of(context).colorScheme.primary(골드 계열 seed)로 대체한다.
  // 배경/텍스트/카드 색은 전부 기존 UnifiedColors를 그대로 사용한다.

  @override
  Widget build(BuildContext context) {
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
                  color: UnifiedColors.textPrimary,
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

    return card;
  }
}

Widget _toneWrap({
  required Widget child,
  required VoidCallback onTap,
  EdgeInsets padding = const EdgeInsets.all(16),
}) {
  return Card(
    elevation: _Tone.elevation,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_Tone.radius),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(_Tone.radius),
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}
