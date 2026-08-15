import 'package:flutter/material.dart';

import '../../../core/auth/auth_token_store.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_button.dart';
import '../data/jeontong_profile_store.dart';
import '../domain/jeontong_input.dart';

/// [정통사주 80종 · MVP 라스트 마일 - Mission 1] 정통사주 전용 생년월일시
/// 입력 화면 — 라우트 `/jeontong/input`.
///
/// [목적] 지금까지 정통사주 80종은 계산 엔진([SajuEngine])과 결과 그리드
/// 화면(`/jeontong/eighty/grid`)이 이미 존재했지만, 사용자가 자신의
/// 생년월일시를 입력할 UI가 전혀 없어 "계산 라이브러리는 있지만 서비스는
/// 아닌" 상태였다. 이 화면이 그 마지막 빈 구멍(입력 창구)을 메운다.
///
/// [입력 항목] 생년월일(DatePicker, 1900-01-01~오늘) · 시각(TimePicker,
/// 24시간제) · 성별(라디오 남/여) · 음양력(Switch, 기본 양력) · 이름(선택,
/// 최대 20자).
///
/// [영속화] 입력값은 [JeontongInput]으로 변환해 [jeontongProfileStore]에
/// 저장한다(사용자당 1건, `AuthTokenStore.cachedUserIdOrNull ??
/// fallbackUserId` 패턴으로 userId를 얻는다 — 기존 즐겨찾기/히스토리 스토어와
/// 동일한 관례). 재방문 시 저장된 값을 자동으로 프리필한다.
///
/// [다음 화면] "결과 보기"를 누르면 `/jeontong/eighty/grid`로 이동한다.
/// (그리드가 개별 카테고리 결과 화면으로 categoryId만 전달하는 기존 라우팅
/// 계약은 이 미션에서 변경하지 않는다 — 4축을 결과 화면까지 관통시키는
/// 배선은 별도 후속 미션 범위.)
class JeontongInputScreen extends StatefulWidget {
  const JeontongInputScreen({super.key});

  @override
  State<JeontongInputScreen> createState() => _JeontongInputScreenState();
}

class _JeontongInputScreenState extends State<JeontongInputScreen> {
  final TextEditingController _nameController = TextEditingController();

  DateTime? _birthDate;
  TimeOfDay? _birthTime;
  String _gender = 'M';
  bool _isLunar = false;
  bool _loadingProfile = true;

  String get _userId =>
      (AuthTokenStore.cachedUserIdOrNull ?? AuthTokenStore.fallbackUserId)
          .toString();

  bool get _isValid => _birthDate != null && _birthTime != null;

  @override
  void initState() {
    super.initState();
    _loadSavedProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedProfile() async {
    final saved = await jeontongProfileStore.get(_userId);
    if (!mounted) return;
    if (saved != null) {
      setState(() {
        _birthDate = DateTime(
          saved.birthDateTimeLocal.year,
          saved.birthDateTimeLocal.month,
          saved.birthDateTimeLocal.day,
        );
        _birthTime = TimeOfDay(
          hour: saved.birthDateTimeLocal.hour,
          minute: saved.birthDateTimeLocal.minute,
        );
        _gender = saved.gender;
        _isLunar = saved.isLunar;
        _nameController.text = saved.name ?? '';
      });
    }
    setState(() => _loadingProfile = false);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _birthTime ?? const TimeOfDay(hour: 12, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthTime = picked);
  }

  Future<void> _onSubmit() async {
    if (!_isValid) return;
    final birthDate = _birthDate!;
    final birthTime = _birthTime!;
    final input = JeontongInput(
      birthDateTimeLocal: DateTime(
        birthDate.year,
        birthDate.month,
        birthDate.day,
        birthTime.hour,
        birthTime.minute,
      ),
      gender: _gender,
      isLunar: _isLunar,
      name: _nameController.text,
    );
    await jeontongProfileStore.save(_userId, input);
    if (!mounted) return;
    Navigator.of(context).pushNamed(
      '/jeontong/eighty/grid',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('정통사주 정보 입력', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: _loadingProfile
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(UnifiedTokens.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '정확한 사주 풀이를 위해 태어난 날짜와 시각을 입력해주세요.',
                      style: UnifiedText.body(color: UnifiedColors.textCaption),
                    ),
                    SizedBox(height: UnifiedTokens.spaceXl),

                    Text('이름 (선택)', style: UnifiedText.title()),
                    SizedBox(height: UnifiedTokens.spaceSm),
                    TextField(
                      controller: _nameController,
                      maxLength: 20,
                      decoration: const InputDecoration(
                        hintText: '이름을 입력해주세요',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: UnifiedTokens.spaceMd),

                    Text('성별', style: UnifiedText.title()),
                    SizedBox(height: UnifiedTokens.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            key: const ValueKey('jeontong_input_gender_male'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('남'),
                            value: 'M',
                            groupValue: _gender,
                            onChanged: (v) =>
                                setState(() => _gender = v ?? 'M'),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            key: const ValueKey(
                              'jeontong_input_gender_female',
                            ),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('여'),
                            value: 'F',
                            groupValue: _gender,
                            onChanged: (v) =>
                                setState(() => _gender = v ?? 'M'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: UnifiedTokens.spaceMd),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('음력', style: UnifiedText.title()),
                        Switch(
                          key: const ValueKey('jeontong_input_lunar_switch'),
                          value: _isLunar,
                          onChanged: (v) => setState(() => _isLunar = v),
                        ),
                      ],
                    ),
                    SizedBox(height: UnifiedTokens.spaceMd),

                    Text('생년월일', style: UnifiedText.title()),
                    SizedBox(height: UnifiedTokens.spaceSm),
                    _PickerTile(
                      key: const ValueKey('jeontong_input_date_tile'),
                      icon: Icons.calendar_today_rounded,
                      label: _birthDate == null
                          ? '생년월일을 선택해주세요'
                          : '${_birthDate!.year}년 ${_birthDate!.month}월 ${_birthDate!.day}일',
                      onTap: _pickDate,
                    ),
                    SizedBox(height: UnifiedTokens.spaceMd),

                    Text('태어난 시각', style: UnifiedText.title()),
                    SizedBox(height: UnifiedTokens.spaceSm),
                    _PickerTile(
                      key: const ValueKey('jeontong_input_time_tile'),
                      icon: Icons.access_time_rounded,
                      label: _birthTime == null
                          ? '태어난 시각을 선택해주세요'
                          : '${_birthTime!.hour.toString().padLeft(2, '0')}시 '
                                '${_birthTime!.minute.toString().padLeft(2, '0')}분',
                      onTap: _pickTime,
                    ),
                    SizedBox(height: UnifiedTokens.spaceXl),

                    AppButton(
                      key: const ValueKey('jeontong_input_submit_button'),
                      label: '결과 보기',
                      onPressed: _isValid ? _onSubmit : null,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: UnifiedColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: UnifiedTokens.iconMd, color: UnifiedColors.textPrimary),
            SizedBox(width: UnifiedTokens.spaceSm),
            Expanded(child: Text(label, style: UnifiedText.body())),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

/// 홈 화면 등에서 재사용할 정통사주 진입 헬퍼 — 저장된 프로필이 이미 있으면
/// 바로 그리드로, 없으면 입력 화면으로 보낸다.
///
/// [null-safety 안전망] 기존 아코디언 화면(`/jeontong/eighty`,
/// `JeontongEightyMatrix.browseRoute`)은 이 미션에서 전혀 건드리지 않는다 —
/// 이 헬퍼는 새 진입 버튼 전용이다.
Future<void> openJeontongEntry(BuildContext context) async {
  final userId =
      (AuthTokenStore.cachedUserIdOrNull ?? AuthTokenStore.fallbackUserId)
          .toString();
  final saved = await jeontongProfileStore.get(userId);
  if (!context.mounted) return;
  if (saved != null) {
    Navigator.of(context).pushNamed('/jeontong/eighty/grid');
  } else {
    Navigator.of(context).pushNamed('/jeontong/input');
  }
}
