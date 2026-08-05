import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/tarot_session_controller.dart';
import '../domain/tarot_category_model.dart';
import 'theme/tarot_colors.dart';
import 'theme/tarot_perf_config.dart';
import 'theme/tarot_text_styles.dart';
import 'theme/tarot_theme_scope.dart';
import 'theme/tarot_tokens.dart';
import 'widgets/tarot_mystic_background.dart';
import 'widgets/tarot_particle_burst.dart';

/// [타로 섹션 전면 개편 §2 정보구조 ③] 카테고리 상세 진입 화면.
///
/// 카테고리를 탭한 순간 "이 카테고리만의 진입 리추얼"을 보여준 뒤, 질문
/// 확정 CTA를 노출한다. 실제 카드 선택/셔플(⑤)은 아직 P2 단계에서
/// 재구성될 예정이므로, 이 화면은 기존에 검증된 질문 화면
/// (`/ai-fortune/tarot/question`)으로 카테고리의 [topicKey]를 미리 채워
/// 넘겨주는 방식으로 기존 플로우와 연결한다(회귀 없이 신규 화면만 추가).
///
/// [categoryId]는 nullable로 두어, 잘못된 딥링크로 진입해도(예: 오래된
/// 캐시된 링크) 크래시 없이 안내 문구를 보여준다.
class TarotCategoryDetailScreen extends StatefulWidget {
  final String? categoryId;
  const TarotCategoryDetailScreen({super.key, this.categoryId});

  @override
  State<TarotCategoryDetailScreen> createState() =>
      _TarotCategoryDetailScreenState();
}

class _TarotCategoryDetailScreenState extends State<TarotCategoryDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  String _spreadType = 'one_card';

  static const _spreadOptions = [
    ('one_card', '1카드', '빠른 답변'),
    ('three_card', '3카드', '과거·현재·미래'),
  ];

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.categoryId == null
        ? null
        : TarotCategoryData.byId(widget.categoryId!);

    return TarotThemeScope(
      child: Scaffold(
        backgroundColor: TarotColors.bgVoid,
        appBar: AppBar(title: Text(category?.label ?? '타로')),
        body: category == null
            ? const _CategoryNotFound()
            : Stack(
                children: [
                  TarotMysticBackground(
                    intensity: TarotPerfConfig.backgroundIntensity(0.75),
                  ),
                  SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        TarotTokens.spaceLg,
                        TarotTokens.spaceMd,
                        TarotTokens.spaceLg,
                        TarotTokens.spaceXxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _EntryRitual(
                            category: category,
                            controller: _entryController,
                          ),
                          const SizedBox(height: TarotTokens.spaceXl),
                          Text(
                            category.label,
                            style: TarotTextStyles.heroTitle,
                          ),
                          const SizedBox(height: 6),
                          Text(category.moodCopy, style: TarotTextStyles.body),
                          const SizedBox(height: TarotTokens.spaceXxl),
                          Text(
                            '몇 장으로 볼까요?',
                            style: TarotTextStyles.sectionHeader,
                          ),
                          const SizedBox(height: TarotTokens.spaceMd),
                          Row(
                            children: _spreadOptions.map((opt) {
                              final selected = _spreadType == opt.$1;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    right: TarotTokens.spaceMd,
                                  ),
                                  child: _SpreadChoice(
                                    label: opt.$2,
                                    desc: opt.$3,
                                    selected: selected,
                                    accent: category.accentColor,
                                    onTap: () =>
                                        setState(() => _spreadType = opt.$1),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: TarotTokens.spaceXxl),
                          _StartButton(
                            category: category,
                            spreadType: _spreadType,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CategoryNotFound extends StatelessWidget {
  const _CategoryNotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '이 카테고리를 찾을 수 없어요.\n타로 홈으로 돌아가 다시 시도해 주세요.',
        textAlign: TextAlign.center,
        style: TarotTextStyles.body,
      ),
    );
  }
}

/// 카테고리별 [TarotEntryMotion]을 단순화해 표현하는 진입 리추얼.
///
/// 65개 모션 각각을 전부 다른 렌더링으로 구현하지 않고(과설계 방지),
/// 모션 종류를 3가지 시각 패턴(확산/수렴/회전)으로 그룹핑해 재사용하며
/// 색상만 카테고리별 [accentColor]로 차별화한다. 세부 모션 이름은 향후
/// 애니메이션 세분화 로드맵(§11 P6)에서 CustomPainter 단위로 확장 가능.
class _EntryRitual extends StatelessWidget {
  final TarotCategoryMeta category;
  final AnimationController controller;
  const _EntryRitual({required this.category, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = controller.value;
          final scale = Curves.easeOutBack.transform(t);
          final burst = Curves.easeOut.transform(t);
          return Stack(
            alignment: Alignment.center,
            children: [
              if (TarotPerfConfig.showSymbolLayer)
                TarotParticleBurst(
                  progress: burst,
                  count: TarotPerfConfig.particleCount(24),
                  maxDistance: 90,
                ),
              Transform.scale(
                scale: 0.6 + scale * 0.4,
                child: Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        category.accentColor.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: category.accentColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    category.emoji,
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SpreadChoice extends StatelessWidget {
  final String label;
  final String desc;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  const _SpreadChoice({
    required this.label,
    required this.desc,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: TarotTokens.spaceLg),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.18)
              : TarotColors.surfaceCard,
          borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
          border: Border.all(color: selected ? accent : TarotColors.borderSoft),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TarotTextStyles.bodyStrong.copyWith(
                color: selected ? accent : TarotColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(desc, style: TarotTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final TarotCategoryMeta category;
  final String spreadType;
  const _StartButton({required this.category, required this.spreadType});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: category.accentColor,
          foregroundColor: TarotColors.bgVoid,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TarotTokens.radiusPill),
          ),
        ),
        onPressed: () {
          // [타로 리뉴얼] 세션 상태머신에 카테고리를 재확인해 기록한다
          // (타로 홈에서 이미 selectCategory가 호출됐어도, 직접 딥링크로
          // 진입했을 경우를 대비해 이 화면에서도 한 번 더 보장한다).
          context.read<TarotSessionController>().selectCategory(category);
          Navigator.of(context).pushNamed(
            '/ai-fortune/tarot/question',
            arguments: {
              'initialSpreadType': spreadType,
              'initialTopic': category.topicKey,
            },
          );
        },
        child: Text(
          '${category.label} 시작하기',
          style: TarotTextStyles.ctaLabel.copyWith(color: TarotColors.bgVoid),
        ),
      ),
    );
  }
}
