import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
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
      appBar: AppBar(title: const Text('AI 타로')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '무엇이 궁금하신가요?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _questionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '궁금한 질문을 자유롭게 적어보세요',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _presetQuestions
                    .map(
                      (q) => ActionChip(
                        label: Text(q, style: const TextStyle(fontSize: 12)),
                        onPressed: () =>
                            setState(() => _questionController.text = q),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('스프레드 선택', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
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
                  const SizedBox(width: AppSpacing.md),
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
              const SizedBox(height: AppSpacing.xxl),
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
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: AppSpacing.sm),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            Text(desc, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
