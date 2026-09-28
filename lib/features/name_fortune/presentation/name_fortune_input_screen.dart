import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../result_access/domain/result_access_model.dart';
import '../../result_access/presentation/result_access_gate_sheet.dart';
import '../application/name_fortune_provider.dart';

/// [운세 카테고리 확장] NameFortuneInputScreen (입력형 패턴)
/// 이름/한자(선택)/생년월일(선택)/성별(선택) 입력 → 결과화면에서 로딩 처리
/// (CompatibilityInputScreen과 동일한 입력형 패턴을 그대로 재사용)
class NameFortuneInputScreen extends StatefulWidget {
  const NameFortuneInputScreen({super.key, this.restoredInput});

  /// [결과보기 통합 권한 시스템 v1.0, §7 쿠팡 이동 후 상태 복원] 스플래시
  /// 부트스트랩이 [PendingResultAccessReturnStore]에서 소비한 저장값을 그대로
  /// 전달한다. null(기존 진입 경로)이면 기존 동작과 완전히 동일하다.
  final Map<String, dynamic>? restoredInput;

  @override
  State<NameFortuneInputScreen> createState() => _NameFortuneInputScreenState();
}

class _NameFortuneInputScreenState extends State<NameFortuneInputScreen> {
  final _nameController = TextEditingController();
  final _hanjaController = TextEditingController();
  DateTime? _birthDate;
  String? _gender;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreFromPendingReturn());
  }

  /// [§7] [widget.restoredInput]이 있으면 사용자가 입력했던 값을 그대로
  /// 복원한 뒤 [_submit]을 다시 호출한다 — 쿠팡 이동으로 결과보기가 중단된
  /// 지점부터 이어서 진행하는 효과. 값이 없으면(대부분의 일반 진입) 아무
  /// 것도 하지 않는다(회귀 없음).
  void _restoreFromPendingReturn() {
    final restored = widget.restoredInput;
    if (restored == null) return;

    final nameStr = restored['name'] as String?;
    if (nameStr == null || nameStr.isEmpty) return;

    setState(() {
      _nameController.text = nameStr;
      _hanjaController.text = restored['hanja'] as String? ?? '';
      final birthDateStr = restored['birthDate'] as String?;
      if (birthDateStr != null) {
        final parts = birthDateStr.split('-');
        if (parts.length == 3) {
          _birthDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      }
      _gender = restored['gender'] as String?;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _submit();
    });
  }

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

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    String? fmt(DateTime? d) => d == null
        ? null
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final hanja = _hanjaController.text.trim().isEmpty
        ? null
        : _hanjaController.text.trim();
    final birthDateStr = fmt(_birthDate);

    // [결과보기 통합 권한 시스템 v1.0, §6/§8.5] 입력 자체는 자유 이용
    // (P1/P2)이므로 게이트 없이 진행하고, "이름 운세 보기" 버튼(=곧
    // 결과보기로 이어지는 지점)을 누른 이 시점에만 3택 게이트를 띄운다.
    // §7 대비 — 쿠팡으로 이동할 경우 복원에 필요한 입력값을
    // userInputForRestore에 그대로 담아 둔다.
    final beginResult = await showResultAccessGateSheet(
      context,
      contentType: 'name',
      categoryKey: 'name',
      contentTitle: '이름 운세',
      returnRoute: '/ai-fortune/name/input',
      userInputForRestore: {
        'name': name,
        'hanja': hanja,
        'birthDate': birthDateStr,
        'gender': _gender,
      },
    );
    if (!mounted || beginResult == null) return;

    context.read<NameFortuneProvider>().request(
      name: name,
      hanja: hanja,
      birthDate: birthDateStr,
      gender: _gender,
      paymentMethod: beginResult.paymentMethod.code,
      transactionId: beginResult.transactionId,
    );
    if (!mounted) return;
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
