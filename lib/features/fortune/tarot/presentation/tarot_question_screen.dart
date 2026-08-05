import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../application/tarot_session_controller.dart';
import 'theme/tarot_colors.dart';
import 'theme/tarot_perf_config.dart';
import 'theme/tarot_text_styles.dart';
import 'theme/tarot_theme_scope.dart';
import 'theme/tarot_tokens.dart';
import 'widgets/tarot_mystic_background.dart';

/// [타로 섹션 전면 개편 §2 정보구조 ④ / §7 P2] TarotQuestionScreen 다크테마 전환.
///
/// 기존(화이트 `UnifiedColors` 입력형 패턴)을 타로 전용 다크 미스틱 톤
/// ([TarotColors]/[TarotThemeScope])으로 전면 재도장한다. 필드/로직(질문
/// 입력·스프레드·주제 선택)은 그대로 유지해 회귀를 만들지 않고, 제출
/// 시점의 목적지만 바꾼다: 기존에는 [TarotProvider.draw]를 직접 호출해
/// 곧장 로딩 화면으로 넘어갔지만, 이제는 [TarotSessionController
/// .confirmQuestion]으로 세션 상태를 확정하고 카드 선택 화면(⑤,
/// `/tarot/card-select`)으로 이동한다 - "질문 → 카드 셀렉션"이라는
/// 타로 특유의 리추얼 단계를 모든 진입 경로(카테고리 경유든 레거시
/// 딥링크든)에 공통으로 적용한다.
class TarotQuestionScreen extends StatefulWidget {
  // [운세 카테고리 확장] 전체보기에서 관리자 카테고리(타로 YES/NO, 감정관계운
  // 등)를 탭했을 때, 이 공용 질문 화면의 스프레드/토픽을 미리 선택해두기
  // 위한 선택적 인자. null(기존 모든 진입 경로)이면 기존 기본값
  // (one_card / general)과 완전히 동일하다(회귀 없음).
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
    return TarotThemeScope(
      child: Scaffold(
        backgroundColor: TarotColors.bgVoid,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('무엇이 궁금하신가요', style: TarotTextStyles.screenTitle),
        ),
        body: Stack(
          children: [
            TarotMysticBackground(
              intensity: TarotPerfConfig.backgroundIntensity(0.6),
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
                    Text('마음속 질문을 들려주세요', style: TarotTextStyles.sectionHeader),
                    const SizedBox(height: TarotTokens.spaceSm),
                    Container(
                      decoration: BoxDecoration(
                        color: TarotColors.surfaceCard,
                        borderRadius: BorderRadius.circular(
                          TarotTokens.radiusMd,
                        ),
                        border: Border.all(color: TarotColors.borderSoft),
                      ),
                      child: TextField(
                        controller: _questionController,
                        maxLines: 3,
                        style: TarotTextStyles.bodyStrong,
                        cursorColor: TarotColors.pinkGlow,
                        decoration: InputDecoration(
                          hintText: '궁금한 질문을 자유롭게 적어보세요',
                          hintStyle: TarotTextStyles.body.copyWith(
                            color: TarotColors.textFaint,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(
                            TarotTokens.spaceLg,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: TarotTokens.spaceMd),
                    Wrap(
                      spacing: TarotTokens.spaceSm,
                      runSpacing: TarotTokens.spaceSm,
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
                    const SizedBox(height: TarotTokens.spaceXxl),
                    Text('스프레드 선택', style: TarotTextStyles.sectionHeader),
                    const SizedBox(height: TarotTokens.spaceMd),
                    Row(
                      children: [
                        Expanded(
                          child: _SpreadOption(
                            icon: Icons.filter_1_rounded,
                            label: '1카드',
                            desc: '빠른 답변',
                            selected: _spreadType == 'one_card',
                            onTap: () =>
                                setState(() => _spreadType = 'one_card'),
                          ),
                        ),
                        const SizedBox(width: TarotTokens.spaceMd),
                        Expanded(
                          child: _SpreadOption(
                            icon: Icons.filter_3_rounded,
                            label: '3카드',
                            desc: '과거·현재·미래',
                            selected: _spreadType == 'three_card',
                            onTap: () =>
                                setState(() => _spreadType = 'three_card'),
                          ),
                        ),
                        const SizedBox(width: TarotTokens.spaceMd),
                        Expanded(
                          child: _SpreadOption(
                            icon: Icons.rule_rounded,
                            label: 'YES·NO',
                            desc: '즉답형',
                            selected: _spreadType == 'yes_no',
                            onTap: () => setState(() => _spreadType = 'yes_no'),
                          ),
                        ),
                      ],
                    ),
                    if (_spreadType != 'yes_no') ...[
                      const SizedBox(height: TarotTokens.spaceXxl),
                      Text('어떤 주제로 볼까요?', style: TarotTextStyles.sectionHeader),
                      const SizedBox(height: TarotTokens.spaceMd),
                      Wrap(
                        spacing: TarotTokens.spaceSm,
                        runSpacing: TarotTokens.spaceSm,
                        children: _topicOptions
                            .map(
                              (t) => _TopicChip(
                                label: t.$2,
                                selected: _topic == t.$1,
                                onTap: () => setState(() => _topic = t.$1),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: TarotTokens.spaceXxl),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TarotColors.pinkGlow,
                          foregroundColor: TarotColors.bgVoid,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              TarotTokens.radiusPill,
                            ),
                          ),
                        ),
                        onPressed: _submit,
                        child: Text(
                          '카드 뽑으러 가기',
                          style: TarotTextStyles.ctaLabel.copyWith(
                            color: TarotColors.bgVoid,
                          ),
                        ),
                      ),
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

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TarotTokens.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TarotTokens.spaceLg,
          vertical: TarotTokens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: TarotColors.surfaceCard,
          borderRadius: BorderRadius.circular(TarotTokens.radiusPill),
          border: Border.all(color: TarotColors.borderSoft),
        ),
        child: Text(label, style: TarotTextStyles.chipLabel),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TopicChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TarotTokens.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TarotTokens.spaceLg,
          vertical: TarotTokens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? TarotColors.pinkGlow.withValues(alpha: 0.22)
              : TarotColors.surfaceCard,
          borderRadius: BorderRadius.circular(TarotTokens.radiusPill),
          border: Border.all(
            color: selected ? TarotColors.pinkGlow : TarotColors.borderSoft,
          ),
        ),
        child: Text(
          label,
          style: TarotTextStyles.chipLabel.copyWith(
            color: selected ? TarotColors.pinkGlow : TarotColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _SpreadOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final bool selected;
  final VoidCallback onTap;

  const _SpreadOption({
    required this.icon,
    required this.label,
    required this.desc,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(TarotTokens.spaceLg),
        decoration: BoxDecoration(
          color: selected
              ? TarotColors.pinkGlow.withValues(alpha: 0.16)
              : TarotColors.surfaceCard,
          border: Border.all(
            color: selected ? TarotColors.pinkGlow : TarotColors.borderSoft,
          ),
          borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? TarotColors.pinkGlow : TarotColors.textPrimary,
              size: 26,
            ),
            const SizedBox(height: TarotTokens.spaceSm),
            Text(
              label,
              style: TarotTextStyles.bodyStrong.copyWith(
                color: selected
                    ? TarotColors.pinkGlow
                    : TarotColors.textPrimary,
              ),
            ),
            Text(desc, style: TarotTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
