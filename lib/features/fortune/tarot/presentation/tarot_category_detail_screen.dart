import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../pass/presentation/pass_gate_helper.dart';
import '../application/tarot_session_controller.dart';
import '../domain/tarot_category_model.dart';
import 'oz/oz_theme.dart';
import 'oz/widgets/oz_background.dart';
import 'oz/widgets/oz_category_detail_hero.dart';
import 'oz/widgets/oz_primary_button.dart';
import 'oz/widgets/oz_spread_option.dart';
import 'oz/widgets/oz_topbar.dart';

/// [타로 오즈 리스킨 · 화면03 CATEGORY DETAIL] 카테고리 상세 진입 화면.
///
/// 순수 리스킨: 위젯 트리만 "오즈의 타로" 감성으로 교체하고, 기존 로직
/// (카테고리 조회, `_spreadOptions` 데이터, 진입 애니메이션 타이밍,
/// [_StartButton]의 selectCategory+pushNamed 로직)은 100% 그대로 유지한다.
///
/// [둘러보기 우선 원칙 - 타로 프리패스 타이밍 수정] 다른 기능(정통사주 등)과
/// 동일하게 "메인 진입 → 게이트 없이 둘러보기 → 다음 액션에서 프리패스"
/// 흐름을 맞추기 위해, 이 화면(카테고리+스프레드 선택)까지는 게이트 없이
/// 자유롭게 둘러볼 수 있게 하고, [_StartButton]("시작하기" = 다음 액션)을
/// 누르는 순간에만 [navigateWithPassGate]로 프리패스 게이트를 수행한다.
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

  // [65종 타로 리딩엔진 §계획3] 5카드 옵션 추가. 신규 파일럿 주제가 아닌
  // 카테고리(레거시 20개 topicKey)에서는 서버가 5카드를 지원하지 않지만,
  // 그 경우에도 UI는 그대로 노출하고 서버가 "지원하지 않는 스프레드"로
  // 안전하게 차단하는 구조이므로 화면 단에서 별도 분기를 두지 않는다.
  static const _spreadOptions = [
    ('one_card', '1카드', '빠른 답변'),
    ('three_card', '3카드', '과거·현재·미래'),
    ('five_card', '5카드', '심화 리딩'),
  ];

  /// [65종 타로 리딩엔진 §계획1 - choice_ab] daily_direction_of_choice
  /// 카테고리는 서버가 choice_ab 스프레드만 지원하므로, 몇 장으로 볼지
  /// 고르는 UI 자체를 건너뛰고 곧바로 choice_ab로 진입한다.
  bool get _isChoiceAbCategory =>
      widget.categoryId == 'daily_direction_of_choice';

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    if (_isChoiceAbCategory) {
      _spreadType = 'choice_ab';
    }
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

    return Scaffold(
      backgroundColor: OzColors.bgDeep,
      body: Stack(
        children: [
          const OzBackground(),
          SafeArea(
            child: Column(
              children: [
                OzTopbar(
                  title: category?.label ?? '타로',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: category == null
                      ? const _CategoryNotFound()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                            OzTokens.spaceLg,
                            0,
                            OzTokens.spaceLg,
                            OzTokens.spaceXxl,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OzCategoryDetailHero(category: category),
                              const SizedBox(height: OzTokens.spaceXl),
                              _EntryRitual(
                                category: category,
                                controller: _entryController,
                              ),
                              const SizedBox(height: OzTokens.spaceLg),
                              // [65종 타로 리딩엔진 §계획1 - choice_ab]
                              // daily_direction_of_choice는 choice_ab
                              // 스프레드 1개만 지원하므로 "몇 장으로
                              // 볼까요?" 선택 UI를 노출하지 않는다. 대신
                              // 다음 화면(질문화면)에서 A/B 선택지를
                              // 입력받게 됨을 미리 안내한다.
                              if (_isChoiceAbCategory)
                                _ChoiceAbNotice(category: category)
                              else ...[
                                Text(
                                  '몇 장으로 볼까요?',
                                  style: OzTypography.sectionTitle(
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: OzTokens.spaceMd),
                                Row(
                                  children: _spreadOptions.map((opt) {
                                    final selected = _spreadType == opt.$1;
                                    return Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: OzTokens.spaceMd,
                                        ),
                                        child: OzSpreadOption(
                                          label: opt.$2,
                                          desc: opt.$3,
                                          cardCount: opt.$1 == 'five_card'
                                              ? 5
                                              : opt.$1 == 'three_card'
                                              ? 3
                                              : 1,
                                          active: selected,
                                          onTap: () => setState(
                                            () => _spreadType = opt.$1,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                              const SizedBox(height: OzTokens.spaceXxl),
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
        ],
      ),
    );
  }
}

class _CategoryNotFound extends StatelessWidget {
  const _CategoryNotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(OzTokens.spaceXl),
        child: Text(
          '이 카테고리를 찾을 수 없어요.\n타로 홈으로 돌아가 다시 시도해 주세요.',
          textAlign: TextAlign.center,
          style: OzTypography.body(),
        ),
      ),
    );
  }
}

/// 카테고리별 진입 리추얼 - 오즈 톤(골드 링 + 원형 글로우 + 카테고리 이모지).
class _EntryRitual extends StatelessWidget {
  final TarotCategoryMeta category;
  final AnimationController controller;
  const _EntryRitual({required this.category, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = controller.value;
          final scale = Curves.easeOutBack.transform(t);
          final fade = Curves.easeOut.transform(t);
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.6 + scale * 0.4,
              child: Center(
                child: Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        OzColors.gold.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: OzColors.gold.withValues(alpha: 0.55),
                    ),
                    boxShadow: OzColors.goldGlow(alpha: 0.2, blur: 20),
                  ),
                  child: Text(
                    category.emoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// [65종 타로 리딩엔진 §계획1 - choice_ab] daily_direction_of_choice
/// 카테고리 상세화면에서 "몇 장으로 볼까요?" UI 대신 노출되는 안내 배너.
class _ChoiceAbNotice extends StatelessWidget {
  final TarotCategoryMeta category;
  const _ChoiceAbNotice({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(OzTokens.spaceLg),
      decoration: BoxDecoration(
        color: OzColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(OzTokens.radiusMd),
        border: Border.all(color: OzColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, size: 18, color: OzColors.gold),
          const SizedBox(width: OzTokens.spaceSm),
          Expanded(
            child: Text(
              '이 리딩은 5장의 카드로 두 선택지를 비교해요.\n다음 화면에서 비교할 두 선택지를 알려주세요.',
              style: OzTypography.body(fontSize: 13, color: OzColors.fg),
            ),
          ),
        ],
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
    return OzPrimaryButton(
      label: '${category.label} 시작하기',
      onPressed: () async {
        // [타로 리뉴얼] 세션 상태머신에 카테고리를 재확인해 기록한다
        // (타로 홈에서 이미 selectCategory가 호출됐어도, 직접 딥링크로
        // 진입했을 경우를 대비해 이 화면에서도 한 번 더 보장한다).
        context.read<TarotSessionController>().selectCategory(category);
        // [둘러보기 우선 원칙 - 타로 프리패스 타이밍 수정] 카테고리+스프레드
        // 선택까지는 게이트 없이 자유롭게 둘러볼 수 있게 하고, 실제로 질문
        // 입력(다음 액션)으로 넘어가는 이 "시작하기" 시점에만 프리패스
        // 게이트를 수행한다(정통사주의 "소카테고리 탭" 시점과 동일한 위치).
        await navigateWithPassGate(
          context,
          title: '${category.label} 타로',
          route: '/ai-fortune/tarot/question',
          requiresPass: true,
          arguments: {
            'initialSpreadType': spreadType,
            // [65종 타로 리딩엔진 §핵심 버그 수정] 신규 서버 tarot_topics.
            // topic_key는 65개 카테고리의 고유 `id`값으로 시딩되어 있다
            // (예: 'love_reunion_chance'). 기존에는 20개로 수렴하는
            // `category.topicKey`(예: 'reunion')를 그대로 넘겨 신규 엔진
            // 경로가 전혀 트리거되지 않았다. `category.id`로 넘기면:
            // - 5개 파일럿 카테고리 → 서버가 신규 topic으로 인식(78장 풀덱
            //   + DB 포지션 기반 신규 엔진 경로)
            // - 나머지 60개 카테고리 → 서버가 topic_key 미매칭으로 판단해
            //   기존 레거시 경로(15장 DECK, topic 파라미터는 무시되고
            //   질문화면에서 다시 topic 선택)로 자동 폴백 → 하위 호환 유지.
            'initialTopic': category.id,
          },
        );
      },
      trailingIcon: Icons.arrow_forward_rounded,
    );
  }
}
