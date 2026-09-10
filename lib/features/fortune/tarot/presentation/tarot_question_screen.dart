import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../application/tarot_session_controller.dart';
import '../domain/tarot_category_model.dart';
import '../domain/tarot_suggested_questions.dart';
import 'oz/oz_theme.dart';
import 'oz/widgets/oz_background.dart';
import 'oz/widgets/oz_chip.dart';
import 'oz/widgets/oz_primary_button.dart';
import 'oz/widgets/oz_spread_option.dart';
import 'oz/widgets/oz_topbar.dart';

/// [타로 오즈 리스킨 · 화면04 ASK] 질문 입력 화면.
///
/// 순수 리스킨: 필드/로직(질문 입력·스프레드·주제 선택, [_submit] 전체
/// 로직, `_validSpreadTypes`/`_topicOptions` 데이터, initState의 fallback
/// 로직)은 그대로 유지하고 위젯 트리만 오즈 스타일로 교체한다.
///
/// [65종 타로 리딩엔진 §질문칩 주제별 차별화 - 버그 수정] 기존
/// `_presetQuestions`(고정 4문구)는 선택된 65개 주제와 무관하게 항상
/// 동일했다("65개 타로 = 65개 독립 리딩" 원칙 위배). [_suggestedQuestions]
/// getter로 대체해 `TarotSuggestedQuestions.forTopic(_topic)`을 통해
/// 주제별로 다른 추천 질문이 노출되도록 수정.
class TarotQuestionScreen extends StatefulWidget {
  const TarotQuestionScreen({
    super.key,
    this.initialSpreadType,
    this.initialTopic,
  });

  final String? initialSpreadType;
  final String? initialTopic;

  @override
  State<TarotQuestionScreen> createState() => _TarotQuestionScreenState();
}

class _TarotQuestionScreenState extends State<TarotQuestionScreen> {
  final _questionController = TextEditingController();
  late String _spreadType;
  late String _topic;

  // [65종 타로 리딩엔진 §계획3] 5카드 추가.
  // [65종 타로 리딩엔진 §계획1 - choice_ab] A/B 양자택일 추가.
  static const _validSpreadTypes = {
    'one_card',
    'three_card',
    'five_card',
    'yes_no',
    'choice_ab',
  };

  final _optionAController = TextEditingController();
  final _optionBController = TextEditingController();

  /// [65종 타로 리딩엔진 §계획1 - choice_ab] daily_direction_of_choice
  /// 주제(A/B 양자택일 전용)로 진입했는지 여부.
  bool get _isChoiceAbTopic => _topic == 'daily_direction_of_choice';

  static const _topicOptions = [('general', '종합'), ('love', '감정/연애')];

  // [65종 타로 리딩엔진 §질문칩 주제별 차별화] 선택된 `_topic`에 맞는
  // 추천 질문 3개(또는 매핑 없을 시 레거시 4개 범용 문구)를 반환한다.
  // 주제를 바꿔 선택할 때마다 이 값도 함께 바뀌어야 하므로 build()에서
  // 매번 새로 조회하는 getter로 둔다.
  List<String> get _suggestedQuestions =>
      TarotSuggestedQuestions.forTopic(_topic);

  // [65종 타로 리딩엔진 §계획3→§51/§61 감사 후 확장] 65개 카테고리 중
  // daily_direction_of_choice(A/B 양자택일, 별도 개발 대상)를 제외한 64개는
  // `category.id`가 곧 서버 `tarot_topics.topic_key`로 시딩되어 있다
  // (docs/tarot_65_topics_design_table.md 확정본 반영,
  // admin_web/prisma/seed_tarot_pilot_topics.ts +
  // seed_tarot_remaining_60_topics.ts 시딩 완료). 이 값들은 `_topicOptions`
  // (기존 레거시 2개 칩)에는 없지만 유효한 신규 topic이므로, 카테고리
  // 상세화면을 거쳐 들어온 경우엔 그대로 통과시켜야 한다.
  static const _seededTopicIds = {
    // 연애·관계 14개
    'love_flow_of_crush', 'love_inner_truth', 'love_reunion_chance',
    'love_will_they_contact', 'love_confession_timing', 'love_fortune',
    'love_marriage_chance', 'love_relationship_future',
    'love_secret_relationship', 'love_long_distance',
    'love_lingering_after_breakup', 'love_destined_connection',
    'love_next_chapter_of_crush', 'love_timing_of_fate',
    // 일·커리어 12개
    'career_job_change', 'career_interview_result',
    'career_boss_relationship', 'career_coworker_flow',
    'career_project_result', 'career_promotion_chance',
    'career_startup_fortune', 'career_freelance_fortune',
    'career_current_job_future', 'career_yearly_flow',
    'career_aptitude_direction', 'career_new_sprout',
    // 금전·현실 9개
    'wealth_fortune', 'wealth_spending_flow', 'wealth_investment_flow',
    'wealth_contract_success', 'wealth_incoming_timing',
    'wealth_spending_warning', 'wealth_solution_hint',
    'wealth_asset_direction', 'wealth_harvest_timing',
    // 일상·운세 9개 (daily_direction_of_choice는 A/B 별도개발이라 제외)
    'daily_today_tarot', 'daily_this_week', 'daily_this_month',
    'daily_this_year', 'daily_message_needed_now', 'daily_things_to_watch',
    'daily_luck_point', 'daily_tomorrow_feeling', 'daily_quarterly_flow',
    // 감정·내면 10개
    'emotion_current_heart', 'emotion_anxiety_root', 'emotion_need_comfort',
    'emotion_to_let_go', 'emotion_can_i_restart', 'emotion_advice_for_myself',
    'emotion_hidden_talent', 'emotion_inner_growth', 'emotion_wave',
    'emotion_time_lag',
    // 특별테마 10개
    'special_soul_card', 'special_destiny_card', 'special_dawn_tarot',
    'special_full_moon_tarot', 'special_wish_tarot',
    'special_lucky_door_tarot', 'special_maze_of_fate_tarot',
    'special_secret_garden_tarot', 'special_guardian_star_tarot',
    'special_midnight_vow_tarot',
  };

  // [§51/§61 감사 - YES/NO 12개 확정] 대표님 마스터 프롬프트 §17 및
  // docs/tarot_65_topics_design_table.md 검증표와 정확히 일치하는 12개
  // (서버 tarot_topics.yes_no_enabled=1과 동기화된 값).
  static const _yesNoEnabledTopicIds = {
    'love_reunion_chance',
    'love_will_they_contact',
    'love_confession_timing',
    'love_marriage_chance',
    'career_job_change',
    'career_interview_result',
    'career_project_result',
    'career_promotion_chance',
    'wealth_investment_flow',
    'wealth_contract_success',
    'emotion_can_i_restart',
    'special_wish_tarot',
  };

  bool get _isSeededTopic => _seededTopicIds.contains(_topic);

  bool get _yesNoAvailable =>
      !_isSeededTopic || _yesNoEnabledTopicIds.contains(_topic);

  /// [Bug2 수정] 시딩된 개별 타로 주제(65개 카테고리)로 진입한 경우 그
  /// 표시용 한글 이름을 반환한다. 레거시 2칩 주제('general'/'love')인
  /// 경우는 null을 반환해 기존 칩 UI를 그대로 노출한다.
  String? get _seededTopicLabel {
    if (!_isSeededTopic) return null;
    for (final meta in TarotCategoryData.all) {
      if (meta.id == _topic) return meta.label;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _spreadType = _validSpreadTypes.contains(widget.initialSpreadType)
        ? widget.initialSpreadType!
        : 'one_card';
    final validLegacyTopic = _topicOptions.any(
      (t) => t.$1 == widget.initialTopic,
    );
    final validSeededTopic = _seededTopicIds.contains(widget.initialTopic);
    // [65종 타로 리딩엔진 §계획1 - choice_ab] daily_direction_of_choice는
    // `_seededTopicIds`에서 의도적으로 제외되어 있으므로(A/B 별도 개발
    // 대상이라는 주석) 여기서 별도로 유효 topic으로 인정해줘야 한다.
    // 이 체크가 없으면 카테고리 상세화면을 거쳐 들어와도 'general'로
    // 강제 폴백되어 choice_ab UI가 전혀 노출되지 않는 버그가 생긴다.
    final validChoiceAbTopic =
        widget.initialTopic == 'daily_direction_of_choice';
    _topic = (validLegacyTopic || validSeededTopic || validChoiceAbTopic)
        ? widget.initialTopic!
        : 'general';
    // 딥링크로 들어온 topic이 YES/NO 미지원 파일럿 주제인데 spreadType이
    // yes_no였다면(정상적으로는 발생하지 않지만 방어적으로) one_card로
    // 되돌려 서버 측 차단 에러를 사전에 방지한다.
    if (_spreadType == 'yes_no' && !_yesNoAvailable) {
      _spreadType = 'one_card';
    }
    // [65종 타로 리딩엔진 §계획1 - choice_ab] daily_direction_of_choice
    // 주제는 서버 tarot_topics.allowed_spreads = ["choice_ab"]만 허용한다
    // (§43 확정본). 이 주제로 들어오면 다른 스프레드 UI를 아예 노출하지
    // 않고 항상 choice_ab로 강제 고정한다.
    if (_isChoiceAbTopic) {
      _spreadType = 'choice_ab';
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _optionAController.dispose();
    _optionBController.dispose();
    super.dispose();
  }

  void _submit() {
    final question = _questionController.text.trim().isEmpty
        ? '오늘의 전반적인 운세'
        : _questionController.text.trim();

    // [65종 타로 리딩엔진 §계획1 - choice_ab] A/B 두 선택지는 필수 입력.
    // 비어있으면 제출을 막고 안내만 표시한다(서버도 동일하게 차단하지만
    // 화면에서 먼저 막아 불필요한 API 실패를 방지).
    String? optionA;
    String? optionB;
    if (_isChoiceAbTopic) {
      optionA = _optionAController.text.trim();
      optionB = _optionBController.text.trim();
      if (optionA.isEmpty || optionB.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비교할 두 선택지를 모두 입력해주세요.')),
        );
        return;
      }
    }

    // [§51/§61 감사 - Bug1 수정] 기존에는 spreadType이 'yes_no'이면 topic을
    // 무조건 'general'로 강제 변경해, 재회 가능성/이직운 등 개별 타로
    // 주제로 YES/NO를 선택해도 서버에 'general'이 전달되어 신규 엔진
    // 경로(78장 풀덱 + 해당 주제 포지션)가 아닌 레거시 경로로 빠지는
    // 버그가 있었다. topic은 항상 실제 선택된 주제(_topic)를 그대로
    // 전달해야 한다.
    context.read<TarotSessionController>().confirmQuestion(
      spreadType: _spreadType,
      question: question,
      topic: _topic,
      optionA: optionA,
      optionB: optionB,
    );
    Navigator.of(context).pushNamed('/tarot/card-select');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OzColors.bgDeep,
      body: Stack(
        children: [
          const OzBackground(),
          SafeArea(
            child: Column(
              children: [
                OzTopbar(
                  title: '무엇이 궁금하신가요',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      OzTokens.spaceLg,
                      OzTokens.spaceSm,
                      OzTokens.spaceLg,
                      OzTokens.spaceXxl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '마음속 질문을\n들려주세요',
                          style: OzTypography.hero(fontSize: 24),
                        ),
                        const SizedBox(height: OzTokens.spaceLg),
                        Container(
                          decoration: BoxDecoration(
                            color: OzColors.cardSoft,
                            borderRadius: BorderRadius.circular(
                              OzTokens.radiusMd,
                            ),
                            border: Border.all(color: OzColors.borderSoft),
                          ),
                          child: TextField(
                            controller: _questionController,
                            maxLines: 3,
                            style: OzTypography.body(
                              fontSize: 14,
                              color: OzColors.fg,
                            ),
                            cursorColor: OzColors.gold,
                            decoration: InputDecoration(
                              hintText: '궁금한 질문을 자유롭게 적어보세요',
                              hintStyle: OzTypography.body(
                                fontSize: 13,
                                color: OzColors.faint,
                              ),
                              border: InputBorder.none,
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  OzTokens.radiusMd,
                                ),
                                borderSide: BorderSide(
                                  color: OzColors.gold.withValues(alpha: 0.5),
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(
                                OzTokens.spaceLg,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: OzTokens.spaceMd),
                        Wrap(
                          spacing: OzTokens.spaceSm,
                          runSpacing: OzTokens.spaceSm,
                          children: _suggestedQuestions
                              .map(
                                (q) => _PresetChip(
                                  label: q,
                                  onTap: () => setState(
                                    () => _questionController.text = q,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        // [65종 타로 리딩엔진 §계획1 - choice_ab] 이 주제는
                        // allowed_spreads가 choice_ab 하나뿐이므로 스프레드
                        // 선택 UI 자체를 노출하지 않고, 대신 비교할 두
                        // 선택지를 입력받는 전용 UI로 대체한다.
                        if (_isChoiceAbTopic) ...[
                          const SizedBox(height: OzTokens.spaceXxl),
                          Text(
                            'A/B 두 선택지를 알려주세요',
                            style: OzTypography.sectionTitle(fontSize: 17),
                          ),
                          const SizedBox(height: OzTokens.spaceMd),
                          _OptionInputField(
                            label: '선택 A',
                            controller: _optionAController,
                            hintText: '예: 이 회사에 남는다',
                            accent: OzColors.teal,
                          ),
                          const SizedBox(height: OzTokens.spaceMd),
                          _OptionInputField(
                            label: '선택 B',
                            controller: _optionBController,
                            hintText: '예: 이직을 한다',
                            accent: OzColors.rose,
                          ),
                        ] else ...[
                          const SizedBox(height: OzTokens.spaceXxl),
                          Text(
                            '스프레드 선택',
                            style: OzTypography.sectionTitle(fontSize: 17),
                          ),
                          const SizedBox(height: OzTokens.spaceMd),
                          Row(
                            children: [
                              Expanded(
                                child: OzSpreadOption(
                                  label: '1카드',
                                  desc: '빠른 답변',
                                  cardCount: 1,
                                  active: _spreadType == 'one_card',
                                  onTap: () =>
                                      setState(() => _spreadType = 'one_card'),
                                ),
                              ),
                              const SizedBox(width: OzTokens.spaceSm),
                              Expanded(
                                child: OzSpreadOption(
                                  label: '3카드',
                                  desc: '과거·현재·미래',
                                  cardCount: 3,
                                  active: _spreadType == 'three_card',
                                  onTap: () => setState(
                                    () => _spreadType = 'three_card',
                                  ),
                                ),
                              ),
                              const SizedBox(width: OzTokens.spaceSm),
                              // [65종 타로 리딩엔진 §계획3] 5카드 옵션 추가.
                              Expanded(
                                child: OzSpreadOption(
                                  label: '5카드',
                                  desc: '심화 리딩',
                                  cardCount: 5,
                                  active: _spreadType == 'five_card',
                                  onTap: () => setState(
                                    () => _spreadType = 'five_card',
                                  ),
                                ),
                              ),
                              // [65종 타로 리딩엔진 §계획3] YES/NO는
                              // `yes_no_enabled` 주제(현재는 재회 가능성만)에서만
                              // 노출한다. 레거시 20개 topic(비파일럿)은 계속
                              // 노출(기존 동작 그대로 유지).
                              if (_yesNoAvailable) ...[
                                const SizedBox(width: OzTokens.spaceSm),
                                Expanded(
                                  child: OzSpreadOption(
                                    label: 'YES·NO',
                                    desc: '즉답형',
                                    ynLabel: 'Y/N',
                                    active: _spreadType == 'yes_no',
                                    onTap: () =>
                                        setState(() => _spreadType = 'yes_no'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // [§51/§61 감사 - Bug2 수정] 65개 카테고리 상세화면을
                          // 거쳐 개별 타로 주제(예: '재회 가능성')로 진입한
                          // 경우, 어떤 주제인지 전혀 표시되지 않고 무관한
                          // 레거시 2칩('종합'/'감정·연애')만 노출되던 버그를
                          // 고쳐, 선택된 개별 타로명을 명확히 보여주는 배지로
                          // 교체한다. 레거시 진입(개별 카테고리를 거치지 않은
                          // 경우)에는 기존 2칩 UI를 그대로 유지한다.
                          if (_spreadType != 'yes_no') ...[
                            const SizedBox(height: OzTokens.spaceXxl),
                            Text(
                              '어떤 주제로 볼까요?',
                              style: OzTypography.sectionTitle(fontSize: 17),
                            ),
                            const SizedBox(height: OzTokens.spaceMd),
                            if (_seededTopicLabel != null)
                              _SeededTopicBadge(label: _seededTopicLabel!)
                            else
                              Wrap(
                                spacing: OzTokens.spaceSm,
                                runSpacing: OzTokens.spaceSm,
                                children: _topicOptions
                                    .map(
                                      (t) => OzChip(
                                        label: t.$2,
                                        selected: _topic == t.$1,
                                        onTap: () =>
                                            setState(() => _topic = t.$1),
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],
                        ],
                        const SizedBox(height: OzTokens.spaceXxl),
                        OzPrimaryButton(
                          label: '카드 뽑으러 가기',
                          onPressed: _submit,
                          trailingIcon: Icons.arrow_forward_rounded,
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

/// [Bug2 수정] 65개 개별 타로 카테고리로 진입했을 때, 레거시 2칩 대신
/// 선택된 개별 타로명을 명확히 보여주는 배지.
class _SeededTopicBadge extends StatelessWidget {
  final String label;
  const _SeededTopicBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: OzColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(OzTokens.radiusPill),
        border: Border.all(color: OzColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 16, color: OzColors.gold),
          const SizedBox(width: 6),
          Text(
            label,
            style: OzTypography.body(fontSize: 13, color: OzColors.fg)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// [65종 타로 리딩엔진 §계획1 - choice_ab] A/B 선택지 입력 필드.
/// 질문 입력창과 동일한 톤(카드형 배경 + 골드 포커스 보더)을 유지하되,
/// 좌측에 'A'/'B' 라벨 배지를 두어 두 입력을 시각적으로 구분한다.
class _OptionInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final Color accent;
  const _OptionInputField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OzColors.cardSoft,
        borderRadius: BorderRadius.circular(OzTokens.radiusMd),
        border: Border.all(color: OzColors.borderSoft),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: OzTokens.spaceMd,
        vertical: 4,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.5)),
            ),
            child: Text(
              label.substring(label.length - 1),
              style: OzTypography.monoLabel(fontSize: 13, color: accent),
            ),
          ),
          const SizedBox(width: OzTokens.spaceSm),
          Expanded(
            child: TextField(
              controller: controller,
              style: OzTypography.body(fontSize: 14, color: OzColors.fg),
              cursorColor: OzColors.gold,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: OzTypography.body(
                  fontSize: 13,
                  color: OzColors.faint,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OzTokens.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: OzColors.card,
          borderRadius: BorderRadius.circular(OzTokens.radiusPill),
          border: Border.all(color: OzColors.borderSoft),
        ),
        child: Text(
          label,
          style: OzTypography.body(
            fontSize: 12,
            color: OzColors.fg.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
