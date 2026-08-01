import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../application/tarot_provider.dart';

/// 03단계 §3.3 / 07단계 - TarotQuestionScreen (입력형 패턴)
/// 질문 입력 + 스프레드 선택(1카드/3카드)
class TarotQuestionScreen extends StatefulWidget {
  const TarotQuestionScreen({super.key});

  @override
  State<TarotQuestionScreen> createState() => _TarotQuestionScreenState();
}

class _TarotQuestionScreenState extends State<TarotQuestionScreen> {
  final _questionController = TextEditingController();
  String _spreadType = 'one_card';

  static const _presetQuestions = [
    '오늘 하루는 어떨까요?',
    '지금 이 고민, 어떻게 풀어가야 할까요?',
    '연애운이 궁금해요',
    '이 선택이 맞을까요?',
  ];

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
                ],
              ),
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
