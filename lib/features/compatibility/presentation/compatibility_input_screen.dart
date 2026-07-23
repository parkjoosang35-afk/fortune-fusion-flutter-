import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/compatibility_provider.dart';
import '../domain/compatibility_model.dart';

/// 03단계 §3.3 / 07단계 - CompatibilityInputScreen (입력형 패턴)
/// 두 사람의 이름/생년월일 입력 → 결과화면에서 로딩 상태 처리
class CompatibilityInputScreen extends StatefulWidget {
  const CompatibilityInputScreen({super.key});

  @override
  State<CompatibilityInputScreen> createState() =>
      _CompatibilityInputScreenState();
}

class _CompatibilityInputScreenState extends State<CompatibilityInputScreen> {
  final _nameAController = TextEditingController(text: '나');
  final _nameBController = TextEditingController();
  DateTime? _birthDateA;
  DateTime? _birthDateB;
  CompatibilityType _type = CompatibilityType.love;

  @override
  void dispose() {
    _nameAController.dispose();
    _nameBController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isA) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1930, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isA) {
          _birthDateA = picked;
        } else {
          _birthDateB = picked;
        }
      });
    }
  }

  void _submit() {
    if (_birthDateA == null || _birthDateB == null) return;
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    context.read<CompatibilityProvider>().request(
      birthDateA: fmt(_birthDateA!),
      birthDateB: fmt(_birthDateB!),
      nameA: _nameAController.text.trim(),
      nameB: _nameBController.text.trim(),
      type: _type,
    );
    Navigator.of(context).pushNamed('/ai-fortune/compatibility/result');
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _birthDateA != null && _birthDateB != null;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 궁합')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('관계유형', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: CompatibilityType.values.map((t) {
                  final selected = _type == t;
                  return ChoiceChip(
                    label: Text(t.label),
                    selected: selected,
                    onSelected: (_) => setState(() => _type = t),
                    selectedColor: AppColors.primaryContainer,
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              _PersonCard(
                title: '나',
                nameController: _nameAController,
                birthDate: _birthDateA,
                onPickDate: () => _pickDate(true),
              ),
              const SizedBox(height: AppSpacing.md),
              const Center(
                child: Icon(
                  Icons.favorite_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _PersonCard(
                title: '상대방',
                nameController: _nameBController,
                birthDate: _birthDateB,
                onPickDate: () => _pickDate(false),
                hint: '상대방 이름(선택)',
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton(
                onPressed: canSubmit ? _submit : null,
                child: const Text('궁합 분석하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final String title;
  final TextEditingController nameController;
  final DateTime? birthDate;
  final VoidCallback onPickDate;
  final String? hint;

  const _PersonCard({
    required this.title,
    required this.nameController,
    required this.birthDate,
    required this.onPickDate,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: nameController,
            decoration: InputDecoration(hintText: hint ?? '이름'),
          ),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(AppRadius.button),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cake_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    birthDate == null
                        ? '생년월일 선택'
                        : '${birthDate!.year}년 ${birthDate!.month}월 ${birthDate!.day}일',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
