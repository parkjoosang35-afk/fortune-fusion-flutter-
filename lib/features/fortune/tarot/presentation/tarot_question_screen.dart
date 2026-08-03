import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../application/tarot_provider.dart';

/// 03단계 §3.3 / 07단계 - TarotQuestionScreen (입력형 패턴)
/// 질문 입력 + 스프레드 선택(1카드/3카드)
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

  /// [운세 카테고리 확장] 감정/관계운(연애 등) 토픽. 기본값 'general'을
  /// 유지하면 기존 동작(종합 타로)과 완전히 동일하며, 사용자가 '연애'
  /// 토픽을 선택했을 때만 서버가 tarot_love 도메인으로 라우팅한다.
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
    // [운세 카테고리 확장] 딥링크로 전달된 초기값이 유효한 옵션일 때만
    // 반영하고, 그 외에는 기존 기본값으로 폴백한다.
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
    context.read<TarotProvider>().draw(
      question: question,
      spreadType: _spreadType,
      topic: _spreadType == 'yes_no' ? 'general' : _topic,
    );
    Navigator.of(context).pushNamed('/ai-fortune/tarot/loading');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('AI 타로', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(UnifiedTokens.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('무엇이 궁금하신가요?', style: UnifiedText.title()),
              SizedBox(height: UnifiedTokens.spaceSm),
              TextField(
                controller: _questionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '궁금한 질문을 자유롭게 적어보세요',
                ),
              ),
              SizedBox(height: UnifiedTokens.spaceMd),
              Wrap(
                spacing: UnifiedTokens.spaceSm,
                runSpacing: UnifiedTokens.spaceSm,
                children: _presetQuestions
                    .map(
                      (q) => ActionChip(
                        label: Text(q, style: UnifiedText.chipLabel()),
                        backgroundColor: UnifiedColors.chipInactiveBg,
                        side: BorderSide.none,
                        onPressed: () =>
                            setState(() => _questionController.text = q),
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: UnifiedTokens.spaceXl),
              Text('스프레드 선택', style: UnifiedText.title()),
              SizedBox(height: UnifiedTokens.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: _SpreadOption(
                      icon: Icons.filter_1_rounded,
                      label: '1카드',
                      desc: '빠른 답변',
                      selected: _spreadType == 'one_card',
                      onTap: () => setState(() => _spreadType = 'one_card'),
                    ),
                  ),
                  SizedBox(width: UnifiedTokens.spaceMd),
                  Expanded(
                    child: _SpreadOption(
                      icon: Icons.filter_3_rounded,
                      label: '3카드',
                      desc: '과거·현재·미래',
                      selected: _spreadType == 'three_card',
                      onTap: () => setState(() => _spreadType = 'three_card'),
                    ),
                  ),
                  SizedBox(width: UnifiedTokens.spaceMd),
                  // [운세 카테고리 확장] 타로 YES/NO 스프레드(1장 뽑아 방향으로 답변).
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
                SizedBox(height: UnifiedTokens.spaceXl),
                Text('어떤 주제로 볼까요?', style: UnifiedText.title()),
                SizedBox(height: UnifiedTokens.spaceSm),
                Wrap(
                  spacing: UnifiedTokens.spaceSm,
                  runSpacing: UnifiedTokens.spaceSm,
                  children: _topicOptions
                      .map(
                        (t) => ChoiceChip(
                          label: Text(t.$2, style: UnifiedText.chipLabel()),
                          selected: _topic == t.$1,
                          onSelected: (_) => setState(() => _topic = t.$1),
                        ),
                      )
                      .toList(),
                ),
              ],
              SizedBox(height: UnifiedTokens.spaceXxl),
              ElevatedButton(onPressed: _submit, child: const Text('카드 뽑기')),
            ],
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
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(UnifiedTokens.spaceXl),
        decoration: BoxDecoration(
          color: selected ? UnifiedColors.cardAllMenu : UnifiedColors.bg,
          border: Border.all(
            color: selected ? UnifiedColors.black : UnifiedColors.border,
          ),
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
        ),
        child: Column(
          children: [
            Icon(icon, color: UnifiedColors.textPrimary, size: 28),
            SizedBox(height: UnifiedTokens.spaceSm),
            Text(label, style: UnifiedText.bodyStrong()),
            Text(
              desc,
              style: UnifiedText.bodySmall(color: UnifiedColors.textCaption),
            ),
          ],
        ),
      ),
    );
  }
}
