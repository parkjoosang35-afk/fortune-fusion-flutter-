import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart' show AppRouter;
import '../application/tarot_audio_controller.dart';
import '../application/tarot_session_controller.dart';
import '../domain/tarot_category_model.dart';
import 'oz/oz_theme.dart';
import 'oz/widgets/oz_background.dart';
import 'oz/widgets/oz_category_card.dart';
import 'oz/widgets/oz_hero_carousel.dart';
import 'oz/widgets/oz_theme_card.dart';
import 'oz/widgets/oz_topbar.dart';

/// [타로 섹션 전면 개편 §2 정보구조 ①] 타로 메인 홈 — 오즈의 타로 리스킨.
///
/// "단순 운세 메뉴"가 아니라 "타로 세계의 정문"으로 기능하는 화면. 상단
/// 히어로 캐러셀(5초 자동 스와이프) → 인기 카테고리 그리드 → 신규
/// 카테고리 그리드 → 6개 그룹 진입 그리드(②서브카테고리허브로 이동)
/// 순서로 구성한다.
///
/// ⚠️ 순수 UI 리스킨: 데이터/라우팅/상태관리 로직은 기존과 완전히
/// 동일하다 - 바뀐 것은 오직 위젯 트리(비주얼)뿐이다.
/// - [TarotCategoryData.popular]/[TarotCategoryData.newest]/[byGroup] 그대로 사용
/// - [enterTarotCategory] 공용 함수 시그니처/로직 그대로 유지(맨 아래 정의)
/// - `/ai-fortune/tarot/history`, [AppRouter.tarotHubRoute] 라우팅 그대로 유지
class TarotHomeScreen extends StatelessWidget {
  const TarotHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<TarotAudioController>();
    return Scaffold(
      backgroundColor: OzColors.bgDeep,
      body: Stack(
        children: [
          const OzBackground(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: OzTopbar(
                    title: '타로',
                    actions: [
                      OzTopbarIconButton(
                        icon: audio.muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        tooltip: audio.muted ? '타로 소리 켜기' : '타로 소리 끄기',
                        onTap: () => audio.toggleMute(),
                      ),
                      const SizedBox(width: 4),
                      OzTopbarIconButton(
                        icon: Icons.history_rounded,
                        tooltip: '타로 히스토리 보기',
                        onTap: () {
                          audio.playUiTap();
                          Navigator.of(
                            context,
                          ).pushNamed('/ai-fortune/tarot/history');
                        },
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: OzHeroCarousel(
                    onSlideTap: (categoryId) {
                      final c = TarotCategoryData.byId(categoryId);
                      if (c != null) enterTarotCategory(context, c);
                    },
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: OzTokens.spaceXxl),
                ),
                SliverToBoxAdapter(
                  child: _CategorySection(
                    title: '◆ 지금 가장 많이 보는 카테고리',
                    categories: TarotCategoryData.popular(take: 8),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: OzTokens.spaceXxl),
                ),
                SliverToBoxAdapter(
                  child: _CategorySection(
                    title: '◆ 새로 생긴 카테고리',
                    categories: TarotCategoryData.newest(take: 8),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: OzTokens.spaceXxl),
                ),
                const SliverToBoxAdapter(child: _ThemeGridSection()),
                const SliverToBoxAdapter(
                  child: SizedBox(height: OzTokens.spaceXxl),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 인기/신규 카테고리 4열 그리드 섹션. CSS 대응: .oz-cat-grid.
class _CategorySection extends StatelessWidget {
  final String title;
  final List<TarotCategoryMeta> categories;
  const _CategorySection({required this.title, required this.categories});

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OzTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: OzTypography.sectionTitle(fontSize: 16)),
          const SizedBox(height: OzTokens.spaceMd),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (context, i) {
              final c = categories[i];
              return OzCategoryCard(
                category: c,
                onTap: () => enterTarotCategory(context, c),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 6개 그룹 진입 그리드 - 탭하면 서브 카테고리 허브(②)로 이동.
/// CSS 대응: .oz-theme-grid.
class _ThemeGridSection extends StatelessWidget {
  const _ThemeGridSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OzTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('◆ 테마별로 둘러보기', style: OzTypography.sectionTitle(fontSize: 16)),
          const SizedBox(height: OzTokens.spaceMd),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: TarotCategoryGroup.values.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
            ),
            itemBuilder: (context, i) {
              final group = TarotCategoryGroup.values[i];
              return OzThemeCard(
                group: group,
                count: TarotCategoryData.byGroup(group).length,
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(AppRouter.tarotHubRoute, arguments: group),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// [공용] 카테고리 카드를 탭했을 때의 공통 진입 로직.
///
/// 65개 카테고리 어디서든(홈/허브) 동일하게 사용한다. 카테고리 상세
/// 진입 화면(③)으로 이동하며, [TarotSessionController.selectCategory]를
/// 먼저 호출해 세션 상태머신에 선택된 카테고리를 기록한다.
///
/// ⚠️ 오즈 리스킨 대상 외 로직 - 절대 변경하지 않음.
void enterTarotCategory(BuildContext context, TarotCategoryMeta category) {
  context.read<TarotSessionController>().selectCategory(category);
  Navigator.of(
    context,
  ).pushNamed(AppRouter.tarotCategoryDetailRoute, arguments: category.id);
}
