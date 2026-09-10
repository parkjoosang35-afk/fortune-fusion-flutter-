import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../application/tarot_session_controller.dart';
import 'oz/oz_theme.dart';
import 'oz/widgets/oz_background.dart';
import 'oz/widgets/oz_chip.dart';
import 'oz/widgets/oz_primary_button.dart';
import 'oz/widgets/oz_spread_option.dart';
import 'oz/widgets/oz_topbar.dart';

/// [타로 오즈 리스킨 · 화면04 ASK] 질문 입력 화면.
///
/// 순수 리스킨: 필드/로직(질문 입력·스프레드·주제 선택, [_submit] 전체
/// 로직, `_validSpreadTypes`/`_topicOptions`/`_presetQuestions` 데이터,
/// initState의 fallback 로직)은 그대로 유지하고 위젯 트리만 오즈 스타일로
/// 교체한다.
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
  static const _validSpreadTypes = {
    'one_card',
    'three_card',
    'five_card',
    'yes_no',
  };

  static const _presetQuestions = [
    '오늘 하루는 어떨까요?',
    '지금 이 고민, 어떻게 풀어가야 할까요?',
    '연애운이 궁금해요',
    '이 선택이 맞을까요?',
  ];

  static const _topicOptions = [('general', '종합'), ('love', '감정/연애')];

  // [65종 타로 리딩엔진 §계획3] 5개 파일럿 카테고리는 `category.id`가 topic
  // 으로 전달된다(예: 'love_reunion_chance'). 이 값들은 `_topicOptions`
  // (기존 레거시 2개 칩)에는 없지만 유효한 신규 topic이므로, 카테고리
  // 상세화면을 거쳐 들어온 경우엔 그대로 통과시켜야 한다. 현재 5개
  // 파일럿 중 YES/NO를 지원하는 topic만 별도로 표시해 YES/NO 옵션 노출
  // 여부를 결정한다(서버 tarot_topics.yes_no_enabled와 동기화된 값).
  static const _pilotTopicIds = {
    'love_flow_of_crush',
    'love_inner_truth',
    'love_reunion_chance',
    'career_job_change',
    'wealth_fortune',
  };
  static const _yesNoEnabledTopicIds = {'love_reunion_chance'};

  bool get _yesNoAvailable =>
      !_pilotTopicIds.contains(_topic) || _yesNoEnabledTopicIds.contains(_topic);

  @override
  void initState() {
    super.initState();
    _spreadType = _validSpreadTypes.contains(widget.initialSpreadType)
        ? widget.initialSpreadType!
        : 'one_card';
    final validLegacyTopic = _topicOptions.any(
      (t) => t.$1 == widget.initialTopic,
    );
    final validPilotTopic = _pilotTopicIds.contains(widget.initialTopic);
    _topic = (validLegacyTopic || validPilotTopic)
        ? widget.initialTopic!
        : 'general';
    // 딥링크로 들어온 topic이 YES/NO 미지원 파일럿 주제인데 spreadType이
    // yes_no였다면(정상적으로는 발생하지 않지만 방어적으로) one_card로
    // 되돌려 서버 측 차단 에러를 사전에 방지한다.
    if (_spreadType == 'yes_no' && !_yesNoAvailable) {
      _spreadType = 'one_card';
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _submit() {
    final question = _questionController.text.trim().isEmpty
        ? '오늘의 전반적인 운세'
        : _questionController.text.trim();
    context.read<TarotSessionController>().confirmQuestion(
      spreadType: _spreadType,
      question: question,
      topic: _spreadType == 'yes_no' ? 'general' : _topic,
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
                          children: _presetQuestions
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
                                onTap: () =>
                                    setState(() => _spreadType = 'three_card'),
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
                                onTap: () =>
                                    setState(() => _spreadType = 'five_card'),
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
                        if (_spreadType != 'yes_no') ...[
                          const SizedBox(height: OzTokens.spaceXxl),
                          Text(
                            '어떤 주제로 볼까요?',
                            style: OzTypography.sectionTitle(fontSize: 17),
                          ),
                          const SizedBox(height: OzTokens.spaceMd),
                          Wrap(
                            spacing: OzTokens.spaceSm,
                            runSpacing: OzTokens.spaceSm,
                            children: _topicOptions
                                .map(
                                  (t) => OzChip(
                                    label: t.$2,
                                    selected: _topic == t.$1,
                                    onTap: () => setState(() => _topic = t.$1),
                                  ),
                                )
                                .toList(),
                          ),
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
