import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../application/name_fortune_provider.dart';

/// [운세 카테고리 확장] NameFortuneInputScreen (입력형 패턴)
/// 이름/한자(선택)/생년월일(선택)/성별(선택) 입력 → 결과화면에서 로딩 처리
/// (CompatibilityInputScreen과 동일한 입력형 패턴을 그대로 재사용)
class NameFortuneInputScreen extends StatefulWidget {
  const NameFortuneInputScreen({super.key});

  @override
  State<NameFortuneInputScreen> createState() => _NameFortuneInputScreenState();
}

class _NameFortuneInputScreenState extends State<NameFortuneInputScreen> {
  final _nameController = TextEditingController();
  final _hanjaController = TextEditingController();
  DateTime? _birthDate;
  String? _gender;

  @override
  void dispose() {
    _nameController.dispose();
    _hanjaController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1930, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    String? fmt(DateTime? d) => d == null
        ? null
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    context.read<NameFortuneProvider>().request(
      name: name,
      hanja: _hanjaController.text.trim().isEmpty
          ? null
          : _hanjaController.text.trim(),
      birthDate: fmt(_birthDate),
      gender: _gender,
    );
    Navigator.of(context).pushNamed('/ai-fortune/name/result');
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _nameController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('이름 운세', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(UnifiedTokens.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('이름에 담긴 기운을 풀이해드려요', style: UnifiedText.title()),
              SizedBox(height: UnifiedTokens.spaceSm),
              Text(
                '이름(필수)과 한자·생년월일·성별(선택)을 입력해주세요.',
                style: UnifiedText.bodySmall(color: UnifiedColors.textCaption),
              ),
              SizedBox(height: UnifiedTokens.spaceXl),
              Text('이름', style: UnifiedText.bodyStrong()),
              SizedBox(height: UnifiedTokens.spaceSm),
              TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: '예) 홍길동'),
              ),
              SizedBox(height: UnifiedTokens.spaceLg),
              Text('한자 (선택)', style: UnifiedText.bodyStrong()),
              SizedBox(height: UnifiedTokens.spaceSm),
              TextField(
                controller: _hanjaController,
                decoration: const InputDecoration(hintText: '예) 洪吉童'),
              ),
              SizedBox(height: UnifiedTokens.spaceLg),
              Text('생년월일 (선택)', style: UnifiedText.bodyStrong()),
              SizedBox(height: UnifiedTokens.spaceSm),
              InkWell(
                onTap: _pickDate,
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
                        _birthDate == null
                            ? '생년월일 선택'
                            : '${_birthDate!.year}년 ${_birthDate!.month}월 ${_birthDate!.day}일',
                        style: UnifiedText.body(
                          color: UnifiedColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: UnifiedTokens.spaceLg),
              Text('성별 (선택)', style: UnifiedText.bodyStrong()),
              SizedBox(height: UnifiedTokens.spaceSm),
              Wrap(
                spacing: UnifiedTokens.spaceSm,
                children: [
                  ChoiceChip(
                    label: Text('남성', style: UnifiedText.chipLabel()),
                    selected: _gender == 'male',
                    onSelected: (_) => setState(
                      () => _gender = _gender == 'male' ? null : 'male',
                    ),
                    backgroundColor: UnifiedColors.chipInactiveBg,
                    selectedColor: UnifiedColors.cardAllMenu,
                    side: BorderSide.none,
                  ),
                  ChoiceChip(
                    label: Text('여성', style: UnifiedText.chipLabel()),
                    selected: _gender == 'female',
                    onSelected: (_) => setState(
                      () => _gender = _gender == 'female' ? null : 'female',
                    ),
                    backgroundColor: UnifiedColors.chipInactiveBg,
                    selectedColor: UnifiedColors.cardAllMenu,
                    side: BorderSide.none,
                  ),
                ],
              ),
              SizedBox(height: UnifiedTokens.spaceXxl),
              ElevatedButton(
                onPressed: canSubmit ? _submit : null,
                child: const Text('이름 운세 보기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
