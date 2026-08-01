import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
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
              SizedBox(height: UnifiedTokens.spaceSm),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: '이름'),
              ),
              SizedBox(height: UnifiedTokens.spaceSm),
              Wrap(
                spacing: UnifiedTokens.spaceSm,
                children: sajuRelationshipLabel.entries.map((e) {
                  final selected = relationship == e.key;
                  return ChoiceChip(
                    label: Text(e.value, style: UnifiedText.chipLabel()),
                    selected: selected,
                    backgroundColor: UnifiedColors.chipInactiveBg,
                    selectedColor: UnifiedColors.cardAllMenu,
                    side: BorderSide.none,
                    onSelected: (_) =>
                        setSheetState(() => relationship = e.key),
                  );
                }).toList(),
              ),
              SizedBox(height: UnifiedTokens.spaceSm),
              Row(
                children: [
                  Text('성별', style: UnifiedText.body()),
                  SizedBox(width: UnifiedTokens.spaceMd),
                  ChoiceChip(
                    label: Text('남', style: UnifiedText.chipLabel()),
                    selected: gender == '남',
                    backgroundColor: UnifiedColors.chipInactiveBg,
                    selectedColor: UnifiedColors.cardAllMenu,
                    side: BorderSide.none,
                    onSelected: (_) => setSheetState(() => gender = '남'),
                  ),
                  SizedBox(width: UnifiedTokens.spaceSm),
                  ChoiceChip(
                    label: Text('여', style: UnifiedText.chipLabel()),
                    selected: gender == '여',
                    backgroundColor: UnifiedColors.chipInactiveBg,
                    selectedColor: UnifiedColors.cardAllMenu,
                    side: BorderSide.none,
                    onSelected: (_) => setSheetState(() => gender = '여'),
                  ),
                ],
              ),
              SizedBox(height: UnifiedTokens.spaceSm),
              Row(
                children: [
                  Text('음력', style: UnifiedText.body()),
                  Switch(
                    value: pickerIsLunar,
                    onChanged: (v) => setSheetState(() => pickerIsLunar = v),
                    activeThumbColor: UnifiedColors.black,
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
              SizedBox(height: UnifiedTokens.spaceMd),
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
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('AI 사주', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(UnifiedTokens.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // [웹→앱 이식] saju.html "내 사주함" - 저장된 프로필이 있을 때만 노출
              if (profiles.isNotEmpty) ...[
                Text('내 사주함', style: UnifiedText.title()),
                SizedBox(height: UnifiedTokens.spaceSm),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: profiles.length + 1,
                    separatorBuilder: (_, __) =>
                        SizedBox(width: UnifiedTokens.spaceSm),
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
                SizedBox(height: UnifiedTokens.spaceXl),
              ] else
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _openAddProfileSheet,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text('내 사주함에 추가'),
                  ),
                ),
              Text('생년월일시', style: UnifiedText.title()),
              SizedBox(height: UnifiedTokens.spaceSm),
              _FieldTile(
                icon: Icons.cake_outlined,
                label: _birthDate == null
                    ? '생년월일 선택'
                    : '${_birthDate!.year}년 ${_birthDate!.month}월 ${_birthDate!.day}일',
                onTap: _pickDate,
              ),
              SizedBox(height: UnifiedTokens.spaceSm),
              _FieldTile(
                icon: Icons.access_time_rounded,
                label: _birthTime == null
                    ? '태어난 시간(선택)'
                    : _birthTime!.format(context),
                onTap: _pickTime,
              ),
              Row(
                children: [
                  Text('음력', style: UnifiedText.body()),
                  Switch(
                    value: _isLunar,
                    onChanged: (v) => setState(() => _isLunar = v),
                    activeThumbColor: UnifiedColors.black,
                  ),
                ],
              ),
              SizedBox(height: UnifiedTokens.spaceXl),
              Text('관심 주제 (다중 선택 가능)', style: UnifiedText.title()),
              SizedBox(height: UnifiedTokens.spaceSm),
              Wrap(
                spacing: UnifiedTokens.spaceSm,
                runSpacing: UnifiedTokens.spaceSm,
                children: _allTopics.map((t) {
                  final selected = _topics.contains(t);
                  return FilterChip(
                    label: Text(t, style: UnifiedText.chipLabel()),
                    selected: selected,
                    backgroundColor: UnifiedColors.chipInactiveBg,
                    selectedColor: UnifiedColors.cardAllMenu,
                    checkmarkColor: UnifiedColors.black,
                    side: BorderSide.none,
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
                  title: Text('이 정보를 내 사주함에 저장', style: UnifiedText.body()),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              SizedBox(height: UnifiedTokens.spaceXxl),
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
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
      onTap: onTap,
      child: Container(
        width: 92,
        padding: EdgeInsets.all(UnifiedTokens.spaceSm),
        decoration: BoxDecoration(
          color: selected
              ? UnifiedColors.cardAllMenu
              : UnifiedColors.cardSection,
          border: Border.all(
            color: selected ? UnifiedColors.black : UnifiedColors.border,
          ),
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (profile.isPrimary)
                  Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: UnifiedColors.black,
                  ),
                Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: selected
                      ? UnifiedColors.black
                      : UnifiedColors.textCaption,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              profile.profileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: UnifiedText.bodySmall(
                color: selected
                    ? UnifiedColors.textPrimary
                    : UnifiedColors.textSecondary,
              ),
            ),
            Text(
              sajuRelationshipLabel[profile.relationship] ?? '',
              style: UnifiedText.caption(color: UnifiedColors.textCaption),
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
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
      onTap: onTap,
      child: Container(
        width: 92,
        padding: EdgeInsets.all(UnifiedTokens.spaceSm),
        decoration: BoxDecoration(
          border: Border.all(color: UnifiedColors.border),
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              color: UnifiedColors.textCaption,
            ),
            const SizedBox(height: 4),
            Text(
              '추가',
              style: UnifiedText.bodySmall(color: UnifiedColors.textSecondary),
            ),
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
      padding: EdgeInsets.only(bottom: UnifiedTokens.spaceSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
        child: Container(
          padding: EdgeInsets.all(UnifiedTokens.spaceXl),
          decoration: BoxDecoration(
            border: Border.all(color: UnifiedColors.border),
            borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
          ),
          child: Row(
            children: [
              Icon(icon, color: UnifiedColors.textPrimary),
              SizedBox(width: UnifiedTokens.spaceMd),
              Text(
                label,
                style: UnifiedText.body(color: UnifiedColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
