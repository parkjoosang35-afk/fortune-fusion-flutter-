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

  static const _validSpreadTypes = {'one_card', 'three_card', 'yes_no'};

  static const _presetQuestions = [
    '오늘 하루는 어떨까요?',
    '지금 이 고민, 어떻게 풀어가야 할까요?',
    '연애운이 궁금해요',
    '이 선택이 맞을까요?',
  ];

  static const _topicOptions = [('general', '종합'), ('love', '감정/연애')];

  @override
  void initState() {
    super.initState();
    _spreadType = _validSpreadTypes.contains(widget.initialSpreadType)
        ? widget.initialSpreadType!
        : 'one_card';
    final validTopic = _topicOptions.any((t) => t.$1 == widget.initialTopic);
    _topic = validTopic ? widget.initialTopic! : 'general';
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
                            borderRadius: BorderRadius.circular(OzTokens.radiusMd),
                            border: Border.all(color: OzColors.borderSoft),
                          ),
                          child: TextField(
                            controller: _questionController,
                            maxLines: 3,
                            style: OzTypography.body(fontSize: 14, color: OzColors.fg),
                            cursorColor: OzColors.gold,
                            decoration: InputDecoration(
                              hintText: '궁금한 질문을 자유롭게 적어보세요',
                              hintStyle: OzTypography.body(fontSize: 13, color: OzColors.faint),
                              border: InputBorder.none,
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(OzTokens.radiusMd),
                                borderSide: BorderSide(color: OzColors.gold.withValues(alpha: 0.5)),
                              ),
                              contentPadding: const EdgeInsets.all(OzTokens.spaceLg),
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
                                  onTap: () =>
                                      setState(() => _questionController.text = q),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: OzTokens.spaceXxl),
                        Text('스프레드 선택', style: OzTypography.sectionTitle(fontSize: 17)),
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
                            Expanded(
                              child: OzSpreadOption(
                                label: 'YES·NO',
                                desc: '즉답형',
                                ynLabel: 'Y/N',
                                active: _spreadType == 'yes_no',
                                onTap: () => setState(() => _spreadType = 'yes_no'),
                              ),
                            ),
                          ],
                        ),
                        if (_spreadType != 'yes_no') ...[
                          const SizedBox(height: OzTokens.spaceXxl),
                          Text('어떤 주제로 볼까요?', style: OzTypography.sectionTitle(fontSize: 17)),
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
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: OzColors.card,
          borderRadius: BorderRadius.circular(OzTokens.radiusPill),
          border: Border.all(color: OzColors.borderSoft),
        ),
        child: Text(
          label,
          style: OzTypography.body(fontSize: 12, color: OzColors.fg.withValues(alpha: 0.85)),
        ),
      ),
    );
  }
}
