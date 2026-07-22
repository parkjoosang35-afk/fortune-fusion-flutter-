import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_provider.dart';

/// 03단계 §3.3 SignupProfileStepScreen(단계형) 간소화 버전
/// 로그인 직후 사주/운세 계산에 필요한 생년월일시를 미보유 시 1회 입력받는다(02번 §3-② 흐름 반영)
class ProfileCheckScreen extends StatefulWidget {
  const ProfileCheckScreen({super.key});

  @override
  State<ProfileCheckScreen> createState() => _ProfileCheckScreenState();
}

class _ProfileCheckScreenState extends State<ProfileCheckScreen> {
  DateTime? _birthDate;
  TimeOfDay? _birthTime;
  bool _isLunar = false;
  String _gender = 'F';
  bool _skipTime = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user?.birthDate != null) {
      // 이미 프로필이 있으면 곧바로 홈으로
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1930, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) setState(() => _birthTime = picked);
  }

  Future<void> _submit() async {
    if (_birthDate == null) return;
    final birthDateStr =
        '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}';
    final birthTimeStr = (!_skipTime && _birthTime != null)
        ? '${_birthTime!.hour.toString().padLeft(2, '0')}:${_birthTime!.minute.toString().padLeft(2, '0')}'
        : null;

    await context.read<AuthProvider>().updateProfile(
      birthDate: birthDateStr,
      birthTime: birthTimeStr,
      isLunar: _isLunar,
      gender: _gender,
    );
    if (mounted)
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('프로필 설정')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '정확한 사주/운세 분석을 위해\n생년월일시를 입력해 주세요',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xl),
              _FieldTile(
                icon: Icons.cake_outlined,
                label: _birthDate == null
                    ? '생년월일 선택'
                    : '${_birthDate!.year}년 ${_birthDate!.month}월 ${_birthDate!.day}일',
                onTap: _pickDate,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Text('음력'),
                  Switch(
                    value: _isLunar,
                    onChanged: (v) => setState(() => _isLunar = v),
                    activeThumbColor: AppColors.primary,
                  ),
                  const Spacer(),
                  const Text('시간 모름'),
                  Switch(
                    value: _skipTime,
                    onChanged: (v) => setState(() => _skipTime = v),
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
              if (!_skipTime) ...[
                const SizedBox(height: AppSpacing.md),
                _FieldTile(
                  icon: Icons.access_time_rounded,
                  label: _birthTime == null
                      ? '태어난 시간 선택'
                      : _birthTime!.format(context),
                  onTap: _pickTime,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'F', label: Text('여성')),
                  ButtonSegment(value: 'M', label: Text('남성')),
                ],
                selected: {_gender},
                onSelectionChanged: (v) => setState(() => _gender = v.first),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton(
                onPressed: _birthDate == null ? null : _submit,
                child: const Text('완료'),
              ),
              TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/home', (route) => false),
                child: const Text('나중에 하기'),
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

  const _FieldTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
    );
  }
}
