import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
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
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('AI 궁합', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(UnifiedTokens.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('관계유형', style: UnifiedText.title()),
              SizedBox(height: UnifiedTokens.spaceSm),
              Wrap(
                spacing: UnifiedTokens.spaceSm,
                runSpacing: UnifiedTokens.spaceSm,
                children: CompatibilityType.values.map((t) {
                  final selected = _type == t;
                  return ChoiceChip(
                    label: Text(t.label, style: UnifiedText.chipLabel()),
                    selected: selected,
                    onSelected: (_) => setState(() => _type = t),
                    backgroundColor: UnifiedColors.chipInactiveBg,
                    selectedColor: UnifiedColors.cardAllMenu,
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
              SizedBox(height: UnifiedTokens.spaceXl),
              _PersonCard(
                title: '나',
                nameController: _nameAController,
                birthDate: _birthDateA,
                onPickDate: () => _pickDate(true),
              ),
              SizedBox(height: UnifiedTokens.spaceMd),
              Center(
                child: Icon(
                  Icons.favorite_rounded,
                  color: UnifiedColors.black,
                  size: 28,
                ),
              ),
              SizedBox(height: UnifiedTokens.spaceMd),
              _PersonCard(
                title: '상대방',
                nameController: _nameBController,
                birthDate: _birthDateB,
                onPickDate: () => _pickDate(false),
                hint: '상대방 이름(선택)',
              ),
              SizedBox(height: UnifiedTokens.spaceXxl),
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
      padding: EdgeInsets.all(UnifiedTokens.spaceXl),
      decoration: BoxDecoration(
        color: UnifiedColors.cardSection,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: UnifiedText.title()),
          SizedBox(height: UnifiedTokens.spaceSm),
          TextField(
            controller: nameController,
            decoration: InputDecoration(hintText: hint ?? '이름'),
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
                        ? '생년월일 선택'
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
