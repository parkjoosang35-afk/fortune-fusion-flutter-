import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart' show AppRouter;
import '../application/tarot_audio_controller.dart';
import '../application/tarot_session_controller.dart';
import '../domain/tarot_category_model.dart';
import 'theme/tarot_colors.dart';
import 'theme/tarot_perf_config.dart';
import 'theme/tarot_text_styles.dart';
import 'theme/tarot_theme_scope.dart';
import 'theme/tarot_tokens.dart';
import 'widgets/tarot_category_card.dart';
import 'widgets/tarot_mystic_background.dart';

/// [타로 섹션 전면 개편 §2 정보구조 ①] 타로 메인 홈.
///
/// "단순 운세 메뉴"가 아니라 "타로 세계의 정문"으로 기능하는 화면. 상단
/// 히어로(오늘의 타로 원카드 바로가기) → 인기 카테고리 가로 스크롤 →
/// 신규 카테고리 가로 스크롤 → 6개 그룹 진입 그리드(②서브카테고리허브로 이동)
/// 순서로 구성한다. 기존 `/ai-fortune/tarot/question`(질문화면)과
/// `/ai-fortune/tarot/history`(히스토리)는 그대로 재사용하며 이 화면이
/// 새로운 진입점 역할을 한다.
class TarotHomeScreen extends StatelessWidget {
  const TarotHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TarotThemeScope(
      child: Scaffold(
        backgroundColor: TarotColors.bgVoid,
        body: Stack(
          children: [
            TarotMysticBackground(
              intensity: TarotPerfConfig.backgroundIntensity(0.85),
            ),
            SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _AppBarRow()),
                  SliverToBoxAdapter(child: _HeroBanner()),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: TarotTokens.spaceXl),
                  ),
                  SliverToBoxAdapter(
                    child: _HorizontalSection(
                      title: '지금 가장 많이 보는 카테고리',
                      categories: TarotCategoryData.popular(take: 8),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: TarotTokens.spaceXl),
                  ),
                  SliverToBoxAdapter(
                    child: _HorizontalSection(
                      title: '새로 생긴 카테고리',
                      categories: TarotCategoryData.newest(take: 8),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: TarotTokens.spaceXl),
                  ),
                  SliverToBoxAdapter(child: _GroupGrid()),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: TarotTokens.spaceXxl),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBarRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final audio = context.watch<TarotAudioController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TarotTokens.spaceLg,
        TarotTokens.spaceMd,
        TarotTokens.spaceLg,
        0,
      ),
      child: Row(
        children: [
          Text('타로', style: TarotTextStyles.heroTitle),
          const Spacer(),
          // [§11 P5] 사운드 음소거 토글 - 타로 섹션 전용 SFX만 제어한다.
          IconButton(
            icon: Icon(
              audio.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: TarotColors.textPrimary,
            ),
            tooltip: audio.muted ? '타로 소리 켜기' : '타로 소리 끄기',
            onPressed: () => audio.toggleMute(),
          ),
          IconButton(
            icon: const Icon(
              Icons.history_rounded,
              color: TarotColors.textPrimary,
            ),
            // [접근성] 아이콘 전용 버튼에는 tooltip을 달아 스크린리더가
            // 읽을 시맨틱 라벨을 제공한다(IconButton은 tooltip을 자동으로
            // Semantics label로도 사용한다).
            tooltip: '타로 히스토리 보기',
            onPressed: () {
              audio.playUiTap();
              Navigator.of(context).pushNamed('/ai-fortune/tarot/history');
            },
          ),
        ],
      ),
    );
  }
}

/// 히어로 배너 - "오늘의 타로"(가장 인기 있는 원카드) 바로가기 CTA.
class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final daily = TarotCategoryData.byId('daily_today_tarot');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TarotTokens.spaceLg,
        TarotTokens.spaceLg,
        TarotTokens.spaceLg,
        0,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(TarotTokens.radiusXl),
        onTap: daily == null ? null : () => enterTarotCategory(context, daily),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(TarotTokens.spaceXl),
          decoration: BoxDecoration(
            gradient: TarotColors.nightGradient,
            borderRadius: BorderRadius.circular(TarotTokens.radiusXl),
            border: Border.all(color: TarotColors.borderGlow),
            boxShadow: [
              BoxShadow(
                color: TarotColors.pinkGlow.withValues(alpha: 0.22),
                blurRadius: 28,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('공들여 만든 하나의 타로 세계', style: TarotTextStyles.moodCopy),
                    const SizedBox(height: 6),
                    Text('오늘, 카드가 건네는 한마디', style: TarotTextStyles.screenTitle),
                    const SizedBox(height: TarotTokens.spaceMd),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TarotTokens.spaceLg,
                        vertical: TarotTokens.spaceSm,
                      ),
                      decoration: BoxDecoration(
                        gradient: TarotColors.pinkGlowGradient,
                        borderRadius: BorderRadius.circular(
                          TarotTokens.radiusPill,
                        ),
                      ),
                      child: Text(
                        '오늘의 타로 뽑기',
                        style: TarotTextStyles.ctaLabel.copyWith(
                          color: TarotColors.bgVoid,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TarotTokens.spaceMd),
              const Text('🔮', style: TextStyle(fontSize: 44)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HorizontalSection extends StatelessWidget {
  final String title;
  final List<TarotCategoryMeta> categories;
  const _HorizontalSection({required this.title, required this.categories});

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TarotTokens.spaceLg),
          child: Text(title, style: TarotTextStyles.sectionHeader),
        ),
        const SizedBox(height: TarotTokens.spaceMd),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: TarotTokens.spaceLg,
            ),
            itemCount: categories.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: TarotTokens.spaceMd),
            itemBuilder: (context, i) {
              final c = categories[i];
              return TarotCategoryCard(
                category: c,
                compact: true,
                onTap: () => enterTarotCategory(context, c),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 6개 그룹 진입 그리드 - 탭하면 서브 카테고리 허브(②)로 이동.
class _GroupGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TarotTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('테마별로 둘러보기', style: TarotTextStyles.sectionHeader),
          const SizedBox(height: TarotTokens.spaceMd),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: TarotTokens.spaceMd,
            crossAxisSpacing: TarotTokens.spaceMd,
            childAspectRatio: 2.4,
            children: TarotCategoryGroup.values.map((group) {
              return _GroupTile(group: group);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final TarotCategoryGroup group;
  const _GroupTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final count = TarotCategoryData.byGroup(group).length;
    return InkWell(
      borderRadius: BorderRadius.circular(TarotTokens.radiusLg),
      onTap: () => Navigator.of(
        context,
      ).pushNamed(AppRouter.tarotHubRoute, arguments: group),
      child: Container(
        padding: const EdgeInsets.all(TarotTokens.spaceLg),
        decoration: BoxDecoration(
          color: TarotColors.surfaceCard,
          borderRadius: BorderRadius.circular(TarotTokens.radiusLg),
          border: Border.all(color: group.accentColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              group.label,
              style: TarotTextStyles.bodyStrong,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              '$count개 카테고리',
              style: TarotTextStyles.caption.copyWith(color: group.accentColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// [공용] 카테고리 카드를 탭했을 때의 공통 진입 로직.
///
/// 65개 카테고리 어디서든(홈/허브) 동일하게 사용한다. 카테고리 상세
/// 진입 화면(③)으로 이동하며, [TarotSessionController.selectCategory]를
/// 먼저 호출해 세션 상태머신에 선택된 카테고리를 기록한다.
void enterTarotCategory(BuildContext context, TarotCategoryMeta category) {
  context.read<TarotSessionController>().selectCategory(category);
  Navigator.of(
    context,
  ).pushNamed(AppRouter.tarotCategoryDetailRoute, arguments: category.id);
}
