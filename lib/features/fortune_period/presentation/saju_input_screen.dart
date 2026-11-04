/// [기간별 운세 — 화면 A] 사주정보 등록/수정 화면.
///
/// `design_handoff_fortune_v4/design_files/saju-input.jsx`의 `SajuInput`을
/// 백자 팔레트로 그대로 재현한다 — 성별 세그, 양/음력 세그 + 윤달 체크,
/// 년/월/일 드롭다운, 12지신 그리드 + "태어난 시를 몰라요", 실시간
/// 원국(년주/일주) 미리보기, 최초 입력 시 정책 안내(policy-note).
///
/// [절대 금지] 생년월일시/성별은 saju_engine에 직접 보내지 않는다 — 기존
/// `AuthProvider.updateProfile()`을 통해 서버 `User.profile`에 저장하고,
/// 운세 API(`FortunePeriodRepository`)는 그 저장된 값을 서버가 조회해
/// 계산한다(기획 원칙 그대로 재사용, 신규 계산 경로 추가 없음).
///
/// mode:
/// - first: 운세 최초 진입 시 사주정보가 없을 때(이름 필드 숨김, 정책
///   안내 노출, 저장 후 호출부가 넘긴 콜백으로 바로 운세 화면 진행).
/// - edit: 마이 › 사주정보에서 진입(이름 필드 숨김, "그대로 두기" 버튼,
///   값이 실제로 바뀐 경우에만 저장 버튼 활성화).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/birthday_picker/birthday_picker_types.dart';
import '../../auth/application/auth_provider.dart';
import '../../saju_renewal/data/saju_visual_adapter.dart';
import '../domain/fortune_saju_profile.dart';
import '../theme/fortune_period_theme.dart';
import '../widgets/fortune_common_widgets.dart';
import '../widgets/fortune_pillar_preview.dart';

enum SajuInputMode { first, edit }

class SajuInputScreen extends StatefulWidget {
  const SajuInputScreen({
    super.key,
    this.mode = SajuInputMode.first,
    this.onSaved,
  });

  final SajuInputMode mode;

  /// 저장 성공 후 호출(예: 운세 화면으로 이동). edit 모드에서는 보통
  /// null(저장 후 그냥 이전 화면으로 pop).
  final VoidCallback? onSaved;

  @override
  State<SajuInputScreen> createState() => _SajuInputScreenState();
}

class _SajuInputScreenState extends State<SajuInputScreen> {
  String _gender = '';
  String _cal = 'solar'; // solar | lunar
  bool _leap = false;
  int? _y;
  int? _m;
  int? _d;
  String? _time; // zhi 한글(예: '자') | 'unknown' | null

  bool _submitting = false;
  String? _error;

  // edit 모드 "변경됨" 판정용 원본값.
  String? _origGender;
  String? _origCal;
  bool _origLeap = false;
  int? _origY, _origM, _origD;
  String? _origTime;

  bool get _isEdit => widget.mode == SajuInputMode.edit;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      if (user.gender == 'male' || user.gender == 'female') {
        _gender = user.gender!;
      }
      _cal = user.isLunar ? 'lunar' : 'solar';
      _leap = user.isLunar ? user.isLeapMonth : false;
      final bd = user.birthDate;
      if (bd != null && bd.isNotEmpty) {
        final parts = bd.split('-');
        if (parts.length == 3) {
          _y = int.tryParse(parts[0]);
          _m = int.tryParse(parts[1]);
          _d = int.tryParse(parts[2]);
        }
      }
      if (user.birthTimeUnknown) {
        _time = 'unknown';
      } else {
        final zhi = zhiTimeForBirthTime(user.birthTime);
        _time = zhi?.zhi;
      }
      _origGender = _gender.isEmpty ? null : _gender;
      _origCal = _cal;
      _origLeap = _leap;
      _origY = _y;
      _origM = _m;
      _origD = _d;
      _origTime = _time;
    }
  }

  int get _maxDay {
    if (_y == null || _m == null) return 31;
    if (_cal == 'solar') return DateTime(_y!, _m! + 1, 0).day;
    return 30;
  }

  bool get _dateOk => _y != null && _m != null && _d != null && _d! <= _maxDay;

  bool get _formOk => _gender.isNotEmpty && _dateOk && _time != null;

  bool get _changed {
    if (!_isEdit) return true;
    return _gender != (_origGender ?? '') ||
        _cal != _origCal ||
        _leap != _origLeap ||
        _y != _origY ||
        _m != _origM ||
        _d != _origD ||
        _time != _origTime;
  }

  BirthdayZhiTime? get _selectedZhi {
    if (_time == null || _time == 'unknown') return null;
    for (final z in kBirthdayZhiTimes) {
      if (z.zhi == _time) return z;
    }
    return null;
  }

  SajuVisualProfile? get _preview {
    if (!_dateOk) return null;
    final zhi = _selectedZhi;
    final hour = zhi?.rangeStart ?? 0;
    return SajuVisualAdapter.build(
      kst: DateTime(_y!, _m!, _d!, hour, 0),
      gender: _gender.isEmpty ? 'female' : _gender,
      isLunar: _cal == 'lunar',
      isLeapMonth: _leap,
      timeUnknown: zhi == null,
      referenceDate: DateTime.now(),
    );
  }

  Future<void> _submit() async {
    if (!_formOk) return;
    final auth = context.read<AuthProvider>();
    final birthDateStr =
        '${_y!.toString().padLeft(4, '0')}-${_m!.toString().padLeft(2, '0')}-${_d!.toString().padLeft(2, '0')}';
    final zhi = _selectedZhi;
    final birthTimeUnknown = zhi == null;
    final birthTimeStr = zhi != null
        ? '${zhi.rangeStart.toString().padLeft(2, '0')}:00'
        : null;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final ok = await auth.updateProfile(
      birthDate: birthDateStr,
      birthTime: birthTimeStr,
      isLunar: _cal == 'lunar',
      isLeapMonth: _cal == 'lunar' ? _leap : false,
      birthTimeUnknown: birthTimeUnknown,
      gender: _gender,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!ok) {
      setState(() {
        _error = auth.lastProfileUpdateError ?? '사주정보를 저장하지 못했습니다. 다시 시도해주세요.';
      });
      return;
    }

    if (_isEdit) {
      AppToast.show(context, '사주정보를 고쳐 담았습니다.');
      Navigator.of(context).pop(true);
      return;
    }

    if (widget.onSaved != null) {
      widget.onSaved!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FortunePeriodColors.bg1,
      appBar: AppBar(
        backgroundColor: FortunePeriodColors.bg1,
        elevation: 0,
        foregroundColor: FortunePeriodColors.fg,
        title: Text(
          _isEdit ? '사주정보 수정' : '사주정보 입력',
          style: const TextStyle(
            fontFamily: FortunePeriodType.serif,
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: FortunePeriodColors.fg,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit ? 'PROFILE · 修正' : 'FIRST VISIT · 命',
                style: FortunePeriodType.mono10,
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  children: _isEdit
                      ? [
                          const TextSpan(text: '사주정보를\n'),
                          TextSpan(
                            text: '고쳐 담을게요',
                            style: TextStyle(
                              color: FortunePeriodColors.glow,
                            ),
                          ),
                        ]
                      : [
                          const TextSpan(text: '그대의 사주를\n'),
                          TextSpan(
                            text: '알려주세요',
                            style: TextStyle(
                              color: FortunePeriodColors.glow,
                            ),
                          ),
                        ],
                ),
                style: const TextStyle(
                  fontFamily: FortunePeriodType.serif,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  height: 1.3,
                  color: FortunePeriodColors.fg,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isEdit
                    ? '바뀐 사주로 오늘 · 주간 · 월간 운세를\n모두 새로 풀어드려요'
                    : '처음 한 번만 담아두시면\n다음부터는 바로 운세가 열려요',
                style: const TextStyle(
                  fontFamily: FortunePeriodType.body,
                  fontSize: 13.5,
                  height: 1.7,
                  color: FortunePeriodColors.muted,
                ),
              ),
              const SizedBox(height: 24),

              // 사주 미리보기 (時/日/月/年)
              FortunePillarPreview(
                columns: [
                  FortunePillarColumn(
                    label: '時',
                    value: _preview != null && _preview!.pillars[0] != null
                        ? '${_preview!.pillars[0]!.stemHanja}${_preview!.pillars[0]!.branchHanja}'
                        : null,
                  ),
                  FortunePillarColumn(
                    label: '日',
                    value: _preview != null && _preview!.pillars[1] != null
                        ? '${_preview!.pillars[1]!.stemHanja}${_preview!.pillars[1]!.branchHanja}'
                        : null,
                  ),
                  FortunePillarColumn(
                    label: '月',
                    value: _preview != null && _preview!.pillars[2] != null
                        ? '${_preview!.pillars[2]!.stemHanja}${_preview!.pillars[2]!.branchHanja}'
                        : null,
                  ),
                  FortunePillarColumn(
                    label: '年',
                    value: _preview != null && _preview!.pillars[3] != null
                        ? '${_preview!.pillars[3]!.stemHanja}${_preview!.pillars[3]!.branchHanja}'
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (!_isEdit)
                FortunePolicyNote(
                  items: const [
                    '한 번 담은 사주로 오늘 · 주간 · 월간 운세를 함께 풀어요',
                    '운세는 모두 무료예요 · 복주머니 차감도, 광고 시청 조건도 없어요',
                    '사주정보는 언제든 마이 › 사주정보에서 고칠 수 있어요',
                  ],
                ),
              if (!_isEdit) const SizedBox(height: 24),

              FortuneCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FortuneFieldLabel(no: '01', label: '성별'),
                    FortuneSeg(
                      value: _gender,
                      options: const [
                        MapEntry('female', '여성'),
                        MapEntry('male', '남성'),
                      ],
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 22),

                    FortuneFieldLabel(no: '02', label: '생년월일'),
                    FortuneSeg(
                      value: _cal,
                      options: const [
                        MapEntry('solar', '양력'),
                        MapEntry('lunar', '음력'),
                      ],
                      onChanged: (v) => setState(() {
                        _cal = v;
                        if (v == 'solar') _leap = false;
                      }),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 14,
                          child: _DateDropdown<int>(
                            value: _y,
                            hint: '년',
                            items: List.generate(
                              2026 - 1930 + 1,
                              (i) => 2026 - i,
                            ),
                            labelOf: (v) => '$v년',
                            onChanged: (v) => setState(() => _y = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 10,
                          child: _DateDropdown<int>(
                            value: _m,
                            hint: '월',
                            items: List.generate(12, (i) => i + 1),
                            labelOf: (v) => '$v월',
                            onChanged: (v) => setState(() => _m = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 10,
                          child: _DateDropdown<int>(
                            value: _d,
                            hint: '일',
                            items: List.generate(_maxDay, (i) => i + 1),
                            labelOf: (v) => '$v일',
                            onChanged: (v) => setState(() => _d = v),
                          ),
                        ),
                      ],
                    ),
                    if (_cal == 'lunar')
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: InkWell(
                          onTap: () => setState(() => _leap = !_leap),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: _leap
                                      ? FortunePeriodColors.glow
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: _leap
                                        ? FortunePeriodColors.glow
                                        : FortunePeriodColors.line,
                                  ),
                                ),
                                child: _leap
                                    ? const Icon(
                                        Icons.check,
                                        size: 13,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '윤달에 태어났어요',
                                style: TextStyle(
                                  fontFamily: FortunePeriodType.body,
                                  fontSize: 13.5,
                                  color: _leap
                                      ? FortunePeriodColors.fg
                                      : FortunePeriodColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 22),

                    const FortuneFieldLabel(
                      no: '03',
                      label: '태어난 시',
                      hint: '열두 시진',
                    ),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 0.95,
                      children: kBirthdayZhiTimes.map((z) {
                        final active = _time == z.zhi;
                        return _SijinCell(
                          zhi: z,
                          active: active,
                          onTap: () => setState(() => _time = z.zhi),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => setState(() => _time = 'unknown'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _time == 'unknown'
                              ? FortunePeriodColors.glow.withValues(
                                  alpha: 0.08,
                                )
                              : Colors.transparent,
                          side: BorderSide(
                            color: _time == 'unknown'
                                ? FortunePeriodColors.glow
                                : FortunePeriodColors.line,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          '☾ 태어난 시를 몰라요',
                          style: TextStyle(
                            fontFamily: FortunePeriodType.body,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: _time == 'unknown'
                                ? FortunePeriodColors.glow
                                : FortunePeriodColors.muted,
                          ),
                        ),
                      ),
                    ),
                    if (_time == 'unknown')
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '시주를 제외한 여섯 글자로 풀어드려요. 나중에 언제든 고칠 수 있어요.',
                          style: TextStyle(
                            fontFamily: FortunePeriodType.body,
                            fontSize: 12,
                            height: 1.6,
                            color: FortunePeriodColors.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: FortunePeriodType.ui,
                    fontSize: 13,
                    color: FortunePeriodColors.accent,
                  ),
                ),
              ],

              const SizedBox(height: 24),
              if (_isEdit) ...[
                FortunePrimaryButton(
                  label: '🕯 사주정보 고쳐 담기',
                  loading: _submitting,
                  onPressed: (_formOk && _changed && !_submitting)
                      ? _submit
                      : null,
                ),
                const SizedBox(height: 10),
                FortuneGhostButton(
                  label: '그대로 두기',
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
              ] else
                FortunePrimaryButton(
                  label: '🕯 사주 담고 운세 펼치기',
                  loading: _submitting,
                  onPressed: (_formOk && !_submitting) ? _submit : null,
                ),
              const SizedBox(height: 12),
              const Text(
                '입력한 정보는 운세 풀이에만 쓰이고\n공유되지 않아요',
                textAlign: TextAlign.center,
                style: FortunePeriodType.noteMono,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateDropdown<T> extends StatelessWidget {
  const _DateDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    // ignore: unused_element_parameter
    super.key,
  });

  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FortunePeriodColors.line),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: const TextStyle(
              fontFamily: FortunePeriodType.body,
              fontSize: 14,
              color: FortunePeriodColors.muted,
            ),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: FortunePeriodColors.muted,
          ),
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(
                    labelOf(e),
                    style: const TextStyle(
                      fontFamily: FortunePeriodType.body,
                      fontSize: 14,
                      color: FortunePeriodColors.fg,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _SijinCell extends StatelessWidget {
  const _SijinCell({
    required this.zhi,
    required this.active,
    required this.onTap,
  });

  final BirthdayZhiTime zhi;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? FortunePeriodColors.glow : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? Colors.transparent : FortunePeriodColors.line,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: FortunePeriodColors.glow.withValues(alpha: 0.35),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                zhi.hanja,
                style: TextStyle(
                  fontFamily: FortunePeriodType.serif,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: active ? Colors.white : FortunePeriodColors.fg,
                ),
              ),
              Text(
                zhi.label,
                style: TextStyle(
                  fontFamily: FortunePeriodType.body,
                  fontSize: 11,
                  color: active
                      ? Colors.white.withValues(alpha: 0.9)
                      : FortunePeriodColors.fg.withValues(alpha: 0.8),
                ),
              ),
              Text(
                zhi.hint,
                style: TextStyle(
                  fontFamily: FortunePeriodType.mono,
                  fontSize: 8,
                  color: active
                      ? Colors.white.withValues(alpha: 0.75)
                      : FortunePeriodColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
