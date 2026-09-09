import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/birthday_picker/birthday_picker_modal.dart';
import '../application/compatibility_provider.dart';
import '../domain/compatibility_model.dart';

/// [궁합(C그룹) 신규 구현] CompatibilityInputScreen (입력형 패턴)
/// 나(이름+생년월일)와 상대방(이름+생년월일) + 궁합 유형(애정/우정/사업/가족)을
/// 입력받는다 — NameFortuneInputScreen과 동일한 입력형 패턴을 그대로 재사용한다.
///
/// arguments로 [CompatibilityType]을 전달하면 해당 유형이 미리 선택된 채로
/// 시작한다(예: T-그룹 궁합 항목별 딥링크). 없으면 기본값 love.
class CompatibilityInputScreen extends StatefulWidget {
  const CompatibilityInputScreen({super.key, this.initialType});

  final CompatibilityType? initialType;

  @override
  State<CompatibilityInputScreen> createState() =>
      _CompatibilityInputScreenState();
}

class _CompatibilityInputScreenState extends State<CompatibilityInputScreen> {
  final _nameAController = TextEditingController(text: '나');
  final _nameBController = TextEditingController();
  DateTime? _birthDateA;
  DateTime? _birthDateB;
  late CompatibilityType _type;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? CompatibilityType.love;
  }

  @override
  void dispose() {
    _nameAController.dispose();
    _nameBController.dispose();
    super.dispose();
  }

  /// [BirthdayPickerModal 적용] 궁합은 dev-spec.md 매핑상 midnight 팔려트
  /// + 시간 선택(requireTime=false) — 나/상대방 각각 동일한 공용
  /// 모달을 호출하며, isA로 어려 대상을 구분한다.
  Future<void> _openBirthdayPicker(bool isA) async {
    final current = isA ? _birthDateA : _birthDateB;
    final initial = current == null
        ? null
        : BirthdayPickerValue(
            year: current.year,
            month: current.month,
            day: current.day,
            weekday: current.weekday == 7 ? 0 : current.weekday,
          );
    final result = await showBirthdayPicker(
      context,
      palette: BirthdayPickerPalette.midnight,
      requireTime: false,
      initialValue: initial,
      sourceLabel: isA ? 'COMPAT · 나' : 'COMPAT · 상대방',
      title: '알려주세요',
      ctaLabel: '저장하기',
    );
    if (result == null) return;
    setState(() {
      final picked = DateTime(result.year, result.month, result.day);
      if (isA) {
        _birthDateA = picked;
      } else {
        _birthDateB = picked;
      }
    });
  }

  String _fmt(DateTime? d) => d == null
      ? ''
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _canSubmit =>
      _nameAController.text.trim().isNotEmpty &&
      _nameBController.text.trim().isNotEmpty &&
      _birthDateA != null &&
      _birthDateB != null;

  void _submit() {
    if (!_canSubmit) return;
    context.read<CompatibilityProvider>().request(
      type: _type,
      nameA: _nameAController.text.trim(),
      nameB: _nameBController.text.trim(),
      birthDateA: _fmt(_birthDateA),
      birthDateB: _fmt(_birthDateB),
    );
    Navigator.of(context).pushNamed('/compatibility/result');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('궁합 보기', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(UnifiedTokens.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('두 사람의 인연을 풀이해드려요', style: UnifiedText.title()),
              SizedBox(height: UnifiedTokens.spaceSm),
              Text(
                '궁합 유형과 두 분의 이름·생년월일을 입력해주세요.',
                style: UnifiedText.bodySmall(color: UnifiedColors.textCaption),
              ),
              SizedBox(height: UnifiedTokens.spaceXl),
              Text('궁합 유형', style: UnifiedText.bodyStrong()),
              SizedBox(height: UnifiedTokens.spaceSm),
              Wrap(
                spacing: UnifiedTokens.spaceSm,
                runSpacing: UnifiedTokens.spaceSm,
                children: [
                  for (final t in CompatibilityType.values)
                    ChoiceChip(
                      label: Text(t.label, style: UnifiedText.chipLabel()),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                      backgroundColor: UnifiedColors.chipInactiveBg,
                      selectedColor: UnifiedColors.cardAllMenu,
                      side: BorderSide.none,
                    ),
                ],
              ),
              SizedBox(height: UnifiedTokens.spaceXl),
              _PersonSection(
                title: '나',
                nameController: _nameAController,
                birthDate: _birthDateA,
                onPickDate: () => _openBirthdayPicker(true),
                onChanged: () => setState(() {}),
              ),
              SizedBox(height: UnifiedTokens.spaceLg),
              _PersonSection(
                title: '상대방',
                nameController: _nameBController,
                birthDate: _birthDateB,
                onPickDate: () => _openBirthdayPicker(false),
                onChanged: () => setState(() {}),
              ),
              SizedBox(height: UnifiedTokens.spaceXxl),
              ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                child: const Text('궁합 보기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonSection extends StatelessWidget {
  const _PersonSection({
    required this.title,
    required this.nameController,
    required this.birthDate,
    required this.onPickDate,
    required this.onChanged,
  });

  final String title;
  final TextEditingController nameController;
  final DateTime? birthDate;
  final VoidCallback onPickDate;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(UnifiedTokens.spaceMd),
      decoration: BoxDecoration(
        color: UnifiedColors.cardSection,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: UnifiedText.bodyStrong()),
          SizedBox(height: UnifiedTokens.spaceSm),
          TextField(
            controller: nameController,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(hintText: '$title 이름'),
          ),
          SizedBox(height: UnifiedTokens.spaceSm),
          InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
            child: Container(
              padding: EdgeInsets.all(UnifiedTokens.spaceMd),
              decoration: BoxDecoration(
                border: Border.all(color: UnifiedColors.border),
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cake_outlined,
                    color: UnifiedColors.textPrimary,
                    size: 18,
                  ),
                  SizedBox(width: UnifiedTokens.spaceSm),
                  Text(
                    birthDate == null
                        ? '생년월일 선택 (필수)'
                        : '${birthDate!.year}년 ${birthDate!.month}월 ${birthDate!.day}일',
                    style: UnifiedText.body(color: UnifiedColors.textPrimary),
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
