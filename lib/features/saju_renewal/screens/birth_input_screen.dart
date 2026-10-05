import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/birthday_picker/birthday_picker_modal.dart';
import '../../auth/application/auth_provider.dart';
import '../state/saju_renewal_provider.dart';
import 'calculating_screen.dart';

/// [신통방통 정통사주 리뉴얼 — STEP 6.5] 화면② 출생정보 입력.
///
/// [절대 금지] 생년월일/출생시간/성별을 topics/select API의 요청바디로
/// 직접 보내지 않는다 — 서버가 User.profile(DB)에 저장된 값을 조회해
/// 사용하도록 설계되어 있으므로(topics/select route.ts §10), 이 화면은
/// 반드시 [AuthProvider.updateProfile]로 먼저 서버 프로필을 저장한 뒤에만
/// 다음 단계(계산중 화면)로 진행해야 한다.
///
/// [기존 모델 재사용] 생년월일 입력 UI 자체는 전체 앱이 공유하는
/// [showBirthdayPicker](BirthdayPickerModal)를 그대로 재사용한다(신규
/// 생년월일 입력 위젯을 새로 만들지 않음 — 매트릭스 문서 #13 "기존
/// data/domain 계층 유지" 원칙과 동일한 취지로 UI도 기존 공용 컴포넌트를
/// 따른다).
class BirthInputScreen extends StatefulWidget {
  const BirthInputScreen({super.key});

  @override
  State<BirthInputScreen> createState() => _BirthInputScreenState();
}

class _BirthInputScreenState extends State<BirthInputScreen> {
  BirthdayPickerValue? _birthValue;
  String _gender = 'male'; // 'male' | 'female'
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 로그인 사용자가 이미 프로필에 생년월일을 저장해둔 경우 초기값으로
    // 채워 다시 입력하지 않게 한다(기존 saju_input_screen과 동일 관례).
    final user = context.read<AuthProvider>().currentUser;
    if (user?.birthDate != null) {
      final parts = user!.birthDate!.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          BirthdayPickerTimeValue? time;
          if (user.birthTime != null && !user.birthTimeUnknown) {
            final t = user.birthTime!.split(':');
            final hour = int.tryParse(t.isNotEmpty ? t[0] : '');
            if (hour != null) {
              time = _zhiTimeForHour(hour);
            }
          }
          _birthValue = BirthdayPickerValue(
            year: y,
            month: m,
            day: d,
            weekday: DateTime(y, m, d).weekday % 7,
            time: time,
          );
        }
      }
      if (user.gender == 'male' || user.gender == 'female') {
        _gender = user.gender!;
      }
    }
  }

  BirthdayPickerTimeValue? _zhiTimeForHour(int hour) {
    for (final z in kBirthdayZhiTimes) {
      if (z.rangeStart == hour) {
        return BirthdayPickerTimeValue(
          zhi: z.zhi,
          hanja: z.hanja,
          rangeStart: z.rangeStart,
          rangeEnd: z.rangeEnd,
          label: '${z.label} (${z.hint})',
        );
      }
    }
    return null;
  }

  Future<void> _openPicker() async {
    final result = await showBirthdayPicker(
      context,
      requireTime: false,
      initialValue: _birthValue,
      title: '태어난 날을 알려주세요',
    );
    if (result == null) return;
    setState(() => _birthValue = result);
  }

  Future<void> _submit() async {
    final value = _birthValue;
    if (value == null) {
      setState(() => _error = '생년월일을 입력해주세요.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final birthDateStr = value.iso;
    final birthTimeUnknown = value.time == null;
    final birthTimeStr = value.time != null
        ? '${value.time!.rangeStart.toString().padLeft(2, '0')}:00'
        : null;

    // [핵심] 서버 프로필에 먼저 저장한다 — topics/select가 이 값을 읽어
    // 사용하므로, 저장 성공을 반드시 확인한 뒤에만 다음 단계로 간다.
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(
      birthDate: birthDateStr,
      birthTime: birthTimeStr,
      isLunar: false,
      birthTimeUnknown: birthTimeUnknown,
      gender: _gender,
    );

    if (!mounted) return;
    if (!ok) {
      setState(() {
        _submitting = false;
        _error = auth.lastProfileUpdateError ?? '출생정보를 저장하지 못했습니다. 다시 시도해주세요.';
      });
      return;
    }

    setState(() => _submitting = false);
    // 서버 프로필 저장이 끝난 뒤에만 계산중 화면으로 이동 →
    // SajuRenewalProvider.startCalculating()이 실제 topics/select를
    // 호출해 완료를 기다린다(단순 타이머가 아님).
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CalculatingScreen()));
    context.read<SajuRenewalProvider>().startCalculating();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('출생 정보 입력', style: UnifiedText.title()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('생년월일', style: UnifiedText.body()),
              const SizedBox(height: UnifiedTokens.spaceSm),
              InkWell(
                onTap: _openPicker,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: UnifiedTokens.spaceLg,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: UnifiedColors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 20),
                      const SizedBox(width: UnifiedTokens.spaceSm),
                      Text(
                        _birthValue == null
                            ? '생년월일을 선택해주세요'
                            : '${_birthValue!.iso}'
                                  '${_birthValue!.time != null ? ' · ${_birthValue!.time!.label}' : ' · 시간모름'}',
                        style: UnifiedText.body(
                          color: _birthValue == null
                              ? UnifiedColors.textCaption
                              : UnifiedColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: UnifiedTokens.spaceXl),
              Text('성별', style: UnifiedText.body()),
              const SizedBox(height: UnifiedTokens.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: _GenderChip(
                      label: '남성',
                      selected: _gender == 'male',
                      onTap: () => setState(() => _gender = 'male'),
                    ),
                  ),
                  const SizedBox(width: UnifiedTokens.spaceSm),
                  Expanded(
                    child: _GenderChip(
                      label: '여성',
                      selected: _gender == 'female',
                      onTap: () => setState(() => _gender = 'female'),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: UnifiedTokens.spaceLg),
                Text(_error!, style: UnifiedText.body(color: Colors.red)),
              ],
              const SizedBox(height: UnifiedTokens.spaceXl),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UnifiedColors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        UnifiedTokens.radiusPill,
                      ),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          '입력완료',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? UnifiedColors.black : Colors.transparent,
          border: Border.all(
            color: selected ? UnifiedColors.black : UnifiedColors.border,
          ),
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : UnifiedColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
