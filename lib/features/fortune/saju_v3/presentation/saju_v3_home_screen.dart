// 신통방통 정통사주 v3 — 홈(생년월일시 입력) 화면
// 라우트 '/saju/v3'의 진입점. img1_라우트배치가이드.png의 흐름을 따른다:
//   기존 메뉴 → [정통사주 v3] 버튼 → '/saju/v3' → SajuV3HomeScreen
//     → (생년월일시 입력) → Jeontong69ListScreen(69종 목록)
//
// [주의] 기존 정통사주 80종(jeontong_eighty_*, `/jeontong/eighty` 계열)과는
// 완전히 별개의 신규 진입점이다. 그 화면/라우트는 이 작업에서 절대
// 수정하지 않는다(4차 지침 "하지 말 것" 항목).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/birthday_picker/birthday_picker_modal.dart';
import '../application/saju_v3_provider.dart';
import '../domain/birth_input.dart';
import 'jeontong69_list_screen.dart';
import 'jeontong_v3_theme.dart';
import 'saju_v3_report_screen.dart';

class SajuV3HomeScreen extends StatefulWidget {
  const SajuV3HomeScreen({super.key});

  @override
  State<SajuV3HomeScreen> createState() => _SajuV3HomeScreenState();
}

class _SajuV3HomeScreenState extends State<SajuV3HomeScreen> {
  final TextEditingController _nameController = TextEditingController();
  DateTime? _birthDate;
  TimeOfDay? _birthTime;
  String _gender = 'male';
  bool _isLunar = false;

  bool get _isValid => _birthDate != null && _birthTime != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _openBirthdayPicker() async {
    final initial = _birthDate == null
        ? null
        : BirthdayPickerValue(
            year: _birthDate!.year,
            month: _birthDate!.month,
            day: _birthDate!.day,
            weekday: _birthDate!.weekday == 7 ? 0 : _birthDate!.weekday,
            time: _birthTime == null
                ? null
                : _zhiTimeValueFromTimeOfDay(_birthTime!),
          );
    final result = await showBirthdayPicker(
      context,
      palette: BirthdayPickerPalette.midnight,
      requireTime: true,
      initialValue: initial,
      sourceLabel: 'SAJU v3 · 정보 입력',
      title: '알려주세요',
      ctaLabel: '69종 사주 보기',
    );
    if (result == null) return;
    setState(() {
      _birthDate = DateTime(result.year, result.month, result.day);
      final t = result.time;
      _birthTime = t == null
          ? null
          : TimeOfDay(hour: t.rangeStart == 23 ? 23 : t.rangeStart, minute: 0);
    });
  }

  BirthdayPickerTimeValue? _zhiTimeValueFromTimeOfDay(TimeOfDay t) {
    for (final z in kBirthdayZhiTimes) {
      if (z.rangeStart == t.hour) {
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

  BirthInput _buildBirthInput() {
    final birthDate = _birthDate!;
    final birthTime = _birthTime!;
    return BirthInput(
      name: _nameController.text.isEmpty ? null : _nameController.text,
      year: birthDate.year,
      month: birthDate.month,
      day: birthDate.day,
      hour: birthTime.hour,
      minute: birthTime.minute,
      gender: _gender,
      isLunar: _isLunar,
    );
  }

  void _onSubmit() {
    if (!_isValid) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Jeontong69ListScreen(birth: _buildBirthInput()),
      ),
    );
  }

  // [5차 지시서] AI 정통사주 해석 엔진 v1.0 — 9 PART 장문 리포트 진입.
  // 69종 목록과 달리 별도의 birth 파라미터 전달 구조가 없으므로(SajuV3Provider가
  // 상태로 보관), 여기서 Provider에 먼저 birthInput을 심어두고 리포트 화면으로 push한다.
  void _onOpenReport() {
    if (!_isValid) return;
    context.read<SajuV3Provider>().setBirthInput(_buildBirthInput());
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SajuV3ReportScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Jt3Colors.inkBlack,
      appBar: AppBar(
        backgroundColor: Jt3Colors.inkBlack,
        foregroundColor: Jt3Colors.royalGold,
        title: const Text(
          '정통사주 (베타)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '정통사주 엔진 v3.3',
                style: TextStyle(
                  color: Jt3Colors.royalGold,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '만세력 기반 69종 사주 풀이를 실계산으로 확인해보세요.\n'
                '(베타 · 신규 엔진 서버 연동)',
                style: TextStyle(
                  color: Jt3Colors.moonSilver.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              _Label('이름 (선택)'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                maxLength: 20,
                style: const TextStyle(color: Jt3Colors.starWhite),
                decoration: InputDecoration(
                  hintText: '이름을 입력해주세요',
                  hintStyle: TextStyle(
                    color: Jt3Colors.moonSilver.withValues(alpha: 0.6),
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: Jt3Colors.charcoal,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Jt3Radii.chip),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _Label('성별'),
              const SizedBox(height: 8),
              _SegmentGroup(
                options: const [('male', '남'), ('female', '여')],
                value: _gender,
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 20),

              _Label('달력'),
              const SizedBox(height: 8),
              _SegmentGroup(
                options: const [('S', '양력'), ('L', '음력')],
                value: _isLunar ? 'L' : 'S',
                onChanged: (v) => setState(() => _isLunar = v == 'L'),
              ),
              const SizedBox(height: 20),

              _Label('생년월일시'),
              const SizedBox(height: 8),
              InkWell(
                onTap: _openBirthdayPicker,
                borderRadius: BorderRadius.circular(Jt3Radii.card),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Jt3Colors.charcoal,
                    borderRadius: BorderRadius.circular(Jt3Radii.card),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                        color: Jt3Colors.royalGold,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _birthDate == null
                              ? '생년월일과 태어난 시각을 입력해주세요'
                              : '${_birthDate!.year}년 ${_birthDate!.month}월 ${_birthDate!.day}일'
                                    '${_birthTime == null ? '' : ' · ${_birthTime!.hour.toString().padLeft(2, '0')}시 ${_birthTime!.minute.toString().padLeft(2, '0')}분'}',
                          style: const TextStyle(
                            color: Jt3Colors.starWhite,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Jt3Colors.moonSilver,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isValid ? _onSubmit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Jt3Colors.royalGold,
                    foregroundColor: Jt3Colors.inkBlack,
                    disabledBackgroundColor: Jt3Colors.moonSilver.withValues(
                      alpha: 0.25,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Jt3Radii.button),
                    ),
                  ),
                  child: const Text(
                    '69종 사주 보기',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _isValid ? _onOpenReport : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Jt3Colors.royalGold,
                    disabledForegroundColor: Jt3Colors.moonSilver.withValues(
                      alpha: 0.4,
                    ),
                    side: BorderSide(
                      color: _isValid
                          ? Jt3Colors.royalGold
                          : Jt3Colors.moonSilver.withValues(alpha: 0.25),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Jt3Radii.button),
                    ),
                  ),
                  child: const Text(
                    'AI 장문 리포트 보기 (베타)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Jt3Colors.moonSilver.withValues(alpha: 0.85),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SegmentGroup extends StatelessWidget {
  const _SegmentGroup({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (v, label) in options) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                margin: EdgeInsets.only(
                  right: v == options.first.$1 ? 8 : 0,
                ),
                decoration: BoxDecoration(
                  color: value == v
                      ? Jt3Colors.royalGold
                      : Jt3Colors.charcoal,
                  borderRadius: BorderRadius.circular(Jt3Radii.chip),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: value == v
                        ? Jt3Colors.inkBlack
                        : Jt3Colors.starWhite,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
