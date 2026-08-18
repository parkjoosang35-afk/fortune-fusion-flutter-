import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../pass/presentation/pass_gate_helper.dart';
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
  // [신통방통 2단계] 윤달 여부 — 음력(_isLunar=true)일 때만 UI에 노출되고
  // 값이 의미를 가진다. 양력에서는 항상 false로 서버 전송한다.
  bool _isLeapMonth = false;
  String _gender = 'F';
  bool _skipTime = false;
  final TextEditingController _birthPlaceController = TextEditingController();

  @override
  void dispose() {
    _birthPlaceController.dispose();
    super.dispose();
  }

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
        // [STEP8-2 로그인 필수 UI] 프리패스 게이트 때문에 로그인 화면으로
        // 왔던 경우, 홈 이동 완료 후 원래 가려던 화면으로 자동 이어간다.
        replayPendingPassRequest();
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
      // 음력 선택 시에만 윤달 값을 의미 있게 전달(양력이면 항상 false).
      isLeapMonth: _isLunar ? _isLeapMonth : false,
      // 계산엔진에는 기존과 동일하게 관례값(12:00)이 전달되지만, 사용자가
      // "시간 모름"을 선택했다는 상태 자체는 서버에도 별도로 보존한다.
      birthTimeUnknown: _skipTime,
      birthPlace: _birthPlaceController.text.trim().isEmpty
          ? null
          : _birthPlaceController.text.trim(),
      gender: _gender,
    );
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      replayPendingPassRequest();
    }
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
                    onChanged: (v) => setState(() {
                      _isLunar = v;
                      // 양력으로 되돌아가면 윤달 값은 의미가 없으므로 초기화.
                      if (!v) _isLeapMonth = false;
                    }),
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
              // [신통방통 2단계] 윤달 여부 — 음력 선택 시에만 노출(양력에서는
              // 사용하지 않음). 계산엔진의 BirthInfo.isLeapMonth와 그대로 연결된다.
              if (_isLunar) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Text('윤달(음력)'),
                    Switch(
                      value: _isLeapMonth,
                      onChanged: (v) => setState(() => _isLeapMonth = v),
                      activeThumbColor: AppColors.primary,
                    ),
                  ],
                ),
              ],
              if (_skipTime) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '출생시간을 모르면 정오(12:00) 기준으로 계산되며,\n결과 화면에서 정확도가 낮을 수 있다는 안내가 함께 표시됩니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
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
              TextField(
                controller: _birthPlaceController,
                decoration: const InputDecoration(
                  labelText: '출생지역 (선택)',
                  hintText: '예: 서울특별시',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
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
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/home', (route) => false);
                  // [6-5-A 발견사항 수정] 정상 제출(_submit)과 동일하게, 스킵을
                  // 선택한 경우에도 프리패스 게이트로 인해 대기 중이던 원래
                  // 요청을 재실행한다(로그인 흐름 정합성 - 편향 없이 두 경로 모두 처리).
                  replayPendingPassRequest();
                },
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
