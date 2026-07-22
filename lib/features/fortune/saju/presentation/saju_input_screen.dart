import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/application/auth_provider.dart';
import '../application/saju_provider.dart';

/// 03단계 §3.3 / 07단계 - SajuInputScreen (입력형 패턴)
/// 생년월일시 확인/수정, 주제 선택(재물/애정/직업/건강 멀티선택)
class SajuInputScreen extends StatefulWidget {
  const SajuInputScreen({super.key});

  @override
  State<SajuInputScreen> createState() => _SajuInputScreenState();
}

class _SajuInputScreenState extends State<SajuInputScreen> {
  DateTime? _birthDate;
  TimeOfDay? _birthTime;
  bool _isLunar = false;
  final Set<String> _topics = {'종합'};

  static const _allTopics = ['종합', '재물', '애정', '직업', '건강'];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user?.birthDate != null) {
      final parts = user!.birthDate!.split('-');
      _birthDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      _isLunar = user.isLunar;
      if (user.birthTime != null) {
        final t = user.birthTime!.split(':');
        _birthTime = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1930, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _birthTime ?? const TimeOfDay(hour: 12, minute: 0));
    if (picked != null) setState(() => _birthTime = picked);
  }

  void _submit() {
    if (_birthDate == null) return;
    final birthDateStr =
        '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}';
    final birthTimeStr = _birthTime != null
        ? '${_birthTime!.hour.toString().padLeft(2, '0')}:${_birthTime!.minute.toString().padLeft(2, '0')}'
        : null;

    context.read<SajuProvider>().requestSaju(
          birthDate: birthDateStr,
          birthTime: birthTimeStr,
          isLunar: _isLunar,
          topics: _topics.toList(),
        );
    Navigator.of(context).pushNamed('/ai-fortune/saju/loading');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 사주')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('생년월일시', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              _FieldTile(
                icon: Icons.cake_outlined,
                label: _birthDate == null
                    ? '생년월일 선택'
                    : '${_birthDate!.year}년 ${_birthDate!.month}월 ${_birthDate!.day}일',
                onTap: _pickDate,
              ),
              const SizedBox(height: AppSpacing.sm),
              _FieldTile(
                icon: Icons.access_time_rounded,
                label: _birthTime == null ? '태어난 시간(선택)' : _birthTime!.format(context),
                onTap: _pickTime,
              ),
              Row(
                children: [
                  const Text('음력'),
                  Switch(value: _isLunar, onChanged: (v) => setState(() => _isLunar = v), activeThumbColor: AppColors.primary),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('관심 주제 (다중 선택 가능)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _allTopics.map((t) {
                  final selected = _topics.contains(t);
                  return FilterChip(
                    label: Text(t),
                    selected: selected,
                    selectedColor: AppColors.primaryContainer,
                    checkmarkColor: AppColors.primary,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _topics.add(t);
                      } else if (_topics.length > 1) {
                        _topics.remove(t);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton(
                onPressed: _birthDate == null ? null : _submit,
                child: const Text('분석하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FieldTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
