import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/application/auth_provider.dart';
import '../application/saju_provider.dart';
import '../domain/saju_model.dart';

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
  String? _selectedProfileId;
  String? _selectedProfileName;
  bool _saveAsProfile = false;

  static const _allTopics = ['종합', '재물', '애정', '직업', '건강'];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user?.birthDate != null) {
      final parts = user!.birthDate!.split('-');
      _birthDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      _isLunar = user.isLunar;
      if (user.birthTime != null) {
        final t = user.birthTime!.split(':');
        _birthTime = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
      }
    }
    // [웹→앱 이식] saju.html "내 사주함" - 화면 진입 시 저장된 프로필 목록 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SajuProvider>().loadProfiles();
    });
  }

  void _applyProfile(SajuProfileModel p) {
    final parts = p.birthDate.split('-');
    setState(() {
      _selectedProfileId = p.id;
      _selectedProfileName = p.profileName;
      _birthDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      _isLunar = p.isLunar;
      if (p.birthTime != null) {
        final t = p.birthTime!.split(':');
        _birthTime = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
      } else {
        _birthTime = null;
      }
    });
  }

  /// [웹→앱 이식] saju.html `openSajuProfileModal` 대응 - 새 프로필 등록 바텀시트
  Future<void> _openAddProfileSheet() async {
    final nameController = TextEditingController();
    final aliasController = TextEditingController();
    String gender = '남';
    DateTime? pickerBirthDate = _birthDate;
    TimeOfDay? pickerBirthTime = _birthTime;
    bool pickerIsLunar = _isLunar;
    SajuRelationship relationship = SajuRelationship.self;

    await showAppBottomSheet(
      context,
      title: '새 프로필 등록',
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: aliasController,
                decoration: const InputDecoration(hintText: '별칭 (예: 엄마 사주)'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: '이름'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: sajuRelationshipLabel.entries.map((e) {
                  final selected = relationship == e.key;
                  return ChoiceChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) =>
                        setSheetState(() => relationship = e.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Text('성별'),
                  const SizedBox(width: AppSpacing.md),
                  ChoiceChip(
                    label: const Text('남'),
                    selected: gender == '남',
                    onSelected: (_) => setSheetState(() => gender = '남'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ChoiceChip(
                    label: const Text('여'),
                    selected: gender == '여',
                    onSelected: (_) => setSheetState(() => gender = '여'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Text('음력'),
                  Switch(
                    value: pickerIsLunar,
                    onChanged: (v) => setSheetState(() => pickerIsLunar = v),
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
              _FieldTile(
                icon: Icons.cake_outlined,
                label: pickerBirthDate == null
                    ? '생년월일 선택'
                    : '${pickerBirthDate!.year}년 ${pickerBirthDate!.month}월 ${pickerBirthDate!.day}일',
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: pickerBirthDate ?? DateTime(2000, 1, 1),
                    firstDate: DateTime(1930, 1, 1),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setSheetState(() => pickerBirthDate = picked);
                  }
                },
              ),
              _FieldTile(
                icon: Icons.access_time_rounded,
                label: pickerBirthTime == null
                    ? '태어난 시간(선택)'
                    : pickerBirthTime!.format(sheetContext),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: sheetContext,
                    initialTime:
                        pickerBirthTime ?? const TimeOfDay(hour: 12, minute: 0),
                  );
                  if (picked != null) {
                    setSheetState(() => pickerBirthTime = picked);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: '프로필 저장',
                onPressed:
                    pickerBirthDate == null || nameController.text.isEmpty
                    ? null
                    : () async {
                        final birthDateStr =
                            '${pickerBirthDate!.year}-${pickerBirthDate!.month.toString().padLeft(2, '0')}-${pickerBirthDate!.day.toString().padLeft(2, '0')}';
                        final birthTimeStr = pickerBirthTime != null
                            ? '${pickerBirthTime!.hour.toString().padLeft(2, '0')}:${pickerBirthTime!.minute.toString().padLeft(2, '0')}'
                            : null;
                        final ok = await context
                            .read<SajuProvider>()
                            .createProfile(
                              profileName: aliasController.text.isEmpty
                                  ? nameController.text
                                  : aliasController.text,
                              name: nameController.text,
                              gender: gender,
                              birthDate: birthDateStr,
                              birthTime: birthTimeStr,
                              isLunar: pickerIsLunar,
                              relationship: relationship,
                            );
                        if (ok && sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
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
    final picked = await showTimePicker(
      context: context,
      initialTime: _birthTime ?? const TimeOfDay(hour: 12, minute: 0),
    );
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
      profileId: _selectedProfileId,
      profileName: _selectedProfileName,
    );
    if (_saveAsProfile && _selectedProfileId == null) {
      context.read<SajuProvider>().createProfile(
        profileName: '나',
        name: context.read<AuthProvider>().currentUser?.nickname ?? '나',
        gender: '남',
        birthDate: birthDateStr,
        birthTime: birthTimeStr,
        isLunar: _isLunar,
      );
    }
    Navigator.of(context).pushNamed('/ai-fortune/saju/loading');
  }

  @override
  Widget build(BuildContext context) {
    final profiles = context.watch<SajuProvider>().profiles;
    return Scaffold(
      appBar: AppBar(title: const Text('AI 사주')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // [웹→앱 이식] saju.html "내 사주함" - 저장된 프로필이 있을 때만 노출
              if (profiles.isNotEmpty) ...[
                Text('내 사주함', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: profiles.length + 1,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      if (index == profiles.length) {
                        return _ProfileAddChip(onTap: _openAddProfileSheet);
                      }
                      final p = profiles[index];
                      return _ProfileChip(
                        profile: p,
                        selected: _selectedProfileId == p.id,
                        onTap: () => _applyProfile(p),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ] else
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _openAddProfileSheet,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text('내 사주함에 추가'),
                  ),
                ),
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
                label: _birthTime == null
                    ? '태어난 시간(선택)'
                    : _birthTime!.format(context),
                onTap: _pickTime,
              ),
              Row(
                children: [
                  const Text('음력'),
                  Switch(
                    value: _isLunar,
                    onChanged: (v) => setState(() => _isLunar = v),
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '관심 주제 (다중 선택 가능)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
              if (_selectedProfileId == null)
                CheckboxListTile(
                  value: _saveAsProfile,
                  onChanged: (v) => setState(() => _saveAsProfile = v ?? false),
                  title: const Text('이 정보를 내 사주함에 저장'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
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

/// [웹→앱 이식] saju.html "내 사주함" 빠른선택 칩 - `renderProfilePicker()` 대응
class _ProfileChip extends StatelessWidget {
  final SajuProfileModel profile;
  final bool selected;
  final VoidCallback onTap;
  const _ProfileChip({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.buttonSmall),
      onTap: onTap,
      child: Container(
        width: 92,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.containerOf(context)
              : Theme.of(context).cardTheme.color,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.dividerOf(context),
          ),
          borderRadius: BorderRadius.circular(AppRadius.buttonSmall),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (profile.isPrimary)
                  const Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: AppColors.secondary,
                  ),
                Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondaryOf(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              profile.profileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            Text(
              sajuRelationshipLabel[profile.relationship] ?? '',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textHintOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAddChip extends StatelessWidget {
  final VoidCallback onTap;
  const _ProfileAddChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.buttonSmall),
      onTap: onTap,
      child: Container(
        width: 92,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.dividerOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.buttonSmall),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.textSecondaryOf(context),
            ),
            const SizedBox(height: 4),
            Text('추가', style: Theme.of(context).textTheme.bodySmall),
          ],
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
