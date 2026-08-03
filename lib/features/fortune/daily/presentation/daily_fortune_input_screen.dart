import 'package:flutter/material.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../../../core/widgets/fortune/form_card.dart';
import '../../../../core/widgets/fortune/labeled_field.dart';
import '../../../../core/widgets/fortune/primary_cta.dart';
import '../data/fortune_profile_store.dart';
import '../domain/fortune_report_model.dart';

/// [오늘의 운세 표준 플로우] §2 정보 입력 화면 — /fortune/today/input
///
/// 필드: 이름/닉네임(필수), 생년월일(필수), 성별(필수), 태어난시간(선택+모름),
/// 양력/음력(선택, 기본 양력). 최초 입력값은 [FortuneProfileStore]에 저장되어
/// 다음 방문 시 자동 채워진다.
class DailyFortuneInputScreen extends StatefulWidget {
  const DailyFortuneInputScreen({super.key});

  @override
  State<DailyFortuneInputScreen> createState() =>
      _DailyFortuneInputScreenState();
}

class _DailyFortuneInputScreenState extends State<DailyFortuneInputScreen> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();

  DateTime? _birthDate;
  String? _gender;
  TimeOfDay? _birthTime;
  bool _birthTimeUnknown = true;
  bool _isLunar = false;

  String? _nameError;
  String? _birthDateError;
  String? _genderError;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // §4 입력 화면 "필수값이 모두 입력되어야 CTA가 활성화된다" 정책. 이름 필드가
    // 바뀔 때마다 다시 빌드되도록 리스너를 걸어 CTA 활성 상태를 실시간으로 반영한다.
    _nameController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final saved = await FortuneProfileStore.load();
      if (!mounted) return;
      if (saved != null) {
        setState(() {
          _nameController.text = saved.name;
          _birthDate = saved.birthDate;
          _gender = saved.gender;
          _isLunar = saved.isLunar;
          _birthTimeUnknown = saved.birthTimeUnknown;
          if (saved.birthTime != null) {
            _birthTime = TimeOfDay(
              hour: saved.birthTime!.hour,
              minute: saved.birthTime!.minute,
            );
          }
          _loaded = true;
        });
      } else {
        // 자동 포커스는 첫 필드에만.
        _nameFocus.requestFocus();
        setState(() => _loaded = true);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// §4 "비활성 상태" 규칙 — 이름/생년월일/성별(필수 3항목)이 모두 채워져야
  /// CTA가 활성화된다. 태어난 시간·양력/음력은 선택 항목이라 검사하지 않는다.
  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _birthDate != null &&
      _gender != null;

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1930),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickBirthTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _birthTime ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _birthTime = picked;
        _birthTimeUnknown = false;
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    setState(() {
      _nameError = name.isEmpty ? '이름 또는 닉네임을 입력해주세요' : null;
      _birthDateError = _birthDate == null ? '생년월일을 선택해주세요' : null;
      _genderError = _gender == null ? '성별을 선택해주세요' : null;
    });
    if (_nameError != null || _birthDateError != null || _genderError != null) {
      return;
    }

    final input = FortuneInputModel(
      name: name,
      birthDate: _birthDate!,
      gender: _gender!,
      birthTime: (_birthTimeUnknown || _birthTime == null)
          ? null
          : DateTime(2000, 1, 1, _birthTime!.hour, _birthTime!.minute),
      birthTimeUnknown: _birthTimeUnknown,
      isLunar: _isLunar,
    );
    await FortuneProfileStore.save(input);
    if (!mounted) return;
    Navigator.of(context).pushNamed('/fortune/today/loading', arguments: input);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: UnifiedTokens.spaceXl,
                vertical: UnifiedTokens.spaceSm,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: UnifiedTokens.iconLg,
                      color: UnifiedColors.textPrimary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text('정보 입력', style: UnifiedText.titleLarge()),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: UnifiedTokens.spaceXl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: UnifiedTokens.spaceLg),
                    // §4 입력 화면 히어로 카드 — 왜 정보를 입력해야 하는지 담백하게 안내.
                    PremiumCard(
                      backgroundColor: UnifiedColors.cardMain,
                      borderColor: Colors.transparent,
                      showShadow: false,
                      borderRadius: BorderRadius.circular(
                        UnifiedTokens.radiusLg,
                      ),
                      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('오늘의 운세를 확인해보세요', style: UnifiedText.title()),
                          const SizedBox(height: UnifiedTokens.spaceXs),
                          Text(
                            '기본 정보를 입력하면 오늘의 흐름을 자세히 알려드릴게요.',
                            style: UnifiedText.body(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: UnifiedTokens.spaceMd),
                    PremiumCard(
                      backgroundColor: UnifiedColors.cardSection,
                      borderColor: Colors.transparent,
                      showShadow: false,
                      borderRadius: BorderRadius.circular(
                        UnifiedTokens.radiusMd,
                      ),
                      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
                      child: Text(
                        '한 번 입력하면 다음부터는 바로 볼 수 있어요',
                        style: UnifiedText.caption(),
                      ),
                    ),
                    const SizedBox(height: UnifiedTokens.spaceMd),
                    FormCard(
                      children: [
                        LabeledField(
                          label: '이름 / 닉네임',
                          errorText: _nameError,
                          child: FieldInputBox(
                            child: TextField(
                              controller: _nameController,
                              focusNode: _nameFocus,
                              autofocus: !_loaded
                                  ? false
                                  : _nameController.text.isEmpty,
                              style: UnifiedText.body(
                                color: UnifiedColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                hintText: '이름 또는 닉네임',
                              ),
                            ),
                          ),
                        ),
                        LabeledField(
                          label: '생년월일',
                          errorText: _birthDateError,
                          child: FieldInputBox(
                            onTap: _pickBirthDate,
                            child: Text(
                              _birthDate == null
                                  ? '생년월일을 선택해주세요'
                                  : '${_birthDate!.year}.${_birthDate!.month.toString().padLeft(2, '0')}.${_birthDate!.day.toString().padLeft(2, '0')}',
                              style: UnifiedText.body(
                                color: _birthDate == null
                                    ? UnifiedColors.textCaption
                                    : UnifiedColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        LabeledField(
                          label: '성별',
                          errorText: _genderError,
                          child: Row(
                            children: [
                              Expanded(
                                child: FieldChoiceChip(
                                  label: '여성',
                                  selected: _gender == '여',
                                  onTap: () => setState(() => _gender = '여'),
                                ),
                              ),
                              const SizedBox(width: UnifiedTokens.spaceSm),
                              Expanded(
                                child: FieldChoiceChip(
                                  label: '남성',
                                  selected: _gender == '남',
                                  onTap: () => setState(() => _gender = '남'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        LabeledField(
                          label: '태어난 시간 (선택)',
                          child: Row(
                            children: [
                              Expanded(
                                child: FieldInputBox(
                                  onTap: _pickBirthTime,
                                  child: Text(
                                    _birthTimeUnknown || _birthTime == null
                                        ? '시간 선택'
                                        : _birthTime!.format(context),
                                    style: UnifiedText.body(
                                      color:
                                          (_birthTimeUnknown ||
                                              _birthTime == null)
                                          ? UnifiedColors.textCaption
                                          : UnifiedColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: UnifiedTokens.spaceSm),
                              FieldChoiceChip(
                                label: '모름',
                                selected: _birthTimeUnknown,
                                onTap: () =>
                                    setState(() => _birthTimeUnknown = true),
                              ),
                            ],
                          ),
                        ),
                        LabeledField(
                          label: '양력 / 음력',
                          child: Row(
                            children: [
                              Expanded(
                                child: FieldChoiceChip(
                                  label: '양력',
                                  selected: !_isLunar,
                                  onTap: () => setState(() => _isLunar = false),
                                ),
                              ),
                              const SizedBox(width: UnifiedTokens.spaceSm),
                              Expanded(
                                child: FieldChoiceChip(
                                  label: '음력',
                                  selected: _isLunar,
                                  onTap: () => setState(() => _isLunar = true),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: UnifiedTokens.spaceXxl),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                UnifiedTokens.spaceXl,
                0,
                UnifiedTokens.spaceXl,
                UnifiedTokens.spaceXl,
              ),
              child: Column(
                children: [
                  PrimaryCTA(
                    label: '운세 보기',
                    onPressed: _canSubmit ? _submit : null,
                  ),
                  const SizedBox(height: UnifiedTokens.spaceSm),
                  Text(
                    '입력한 정보는 운세 해석에만 사용돼요',
                    style: UnifiedText.caption(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
