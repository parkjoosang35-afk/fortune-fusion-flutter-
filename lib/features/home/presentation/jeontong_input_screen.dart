import 'package:flutter/material.dart';

import '../../../core/auth/auth_token_store.dart';
import '../../../core/widgets/birthday_picker/birthday_picker_modal.dart';
import '../data/jeontong_profile_store.dart';
import '../domain/jeontong_eighty_matrix.dart';
import '../domain/jeontong_input.dart';
import 'jeontong_design/hanji_background.dart';
import 'jeontong_design/hanji_card.dart';
import 'jeontong_design/hanji_design_tokens.dart';
import 'jeontong_design/saju_seal.dart';
import '../../pass/presentation/pass_gate_helper.dart';

/// [정통사주 · MVP 라스트 마일 - Mission 1] 정통사주 전용 생년월일시
/// 입력 화면 — 라우트 `/jeontong/input`.
///
/// [2026 · 운세 섹션 Dawn Hanji 디자인 통합] handoff 원본
/// `screens/saju_input_screen.dart`와 동일한 팔레트/구성(HanjiBackground +
/// SajuCtxBar + 세그먼트 + 날짜/시간 피커)으로 재스킨한다. 저장 로직
/// ([jeontongProfileStore.save])과 라우팅 계약(제출 후 이동)은 그대로다.
///
/// [entry.id 관통 배선] [JeontongEightyScreen]에서 프로필이 없는 상태로
/// 카테고리를 탭하면 이 화면으로 `arguments: entry.id`(String)와 함께
/// 넘어온다. 제출이 끝나면:
/// - `categoryId`가 있으면(=특정 카테고리를 보려다 입력하러 온 경우)
///   곧바로 그 카테고리의 결과 화면으로 게이트 체크 후 이동한다
///   (`navigateWithPassGate` 재사용 — 신규 게이트 로직 없음).
/// - `categoryId`가 없으면(=그리드 등에서 직접 입력 화면으로 온 경우)
///   기존과 동일하게 `/jeontong/eighty/grid`로 이동한다(회귀 없음).
class JeontongInputScreen extends StatefulWidget {
  const JeontongInputScreen({super.key, this.categoryId});

  /// 입력 완료 후 곧장 결과를 보여줄 카테고리 id(예: 'A01'). null이면
  /// 기존과 동일하게 그리드 화면으로 이동한다.
  final String? categoryId;

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
  bool _submitting = false;

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

  /// [BirthdayPickerModal 적용] 정통사주는 dev-spec.md 매핑상 hanji 팔레트 +
  /// 시간 필수(requireTime=true) — 기존 OS 기본 `showDatePicker`/
  /// `showTimePicker` 2단계 흐름을 이 공용 모달 1개로 통일한다.
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
      palette: BirthdayPickerPalette.hanji,
      requireTime: true,
      initialValue: initial,
      sourceLabel: 'SAJU · 정보 입력',
      title: '알려주세요',
      ctaLabel: '저장하기',
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

  Future<void> _onSubmit() async {
    if (!_isValid || _submitting) return;
    setState(() => _submitting = true);
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

    final categoryId = widget.categoryId;
    if (categoryId != null) {
      final entry = JeontongEightyMatrix.byId(categoryId);
      if (entry != null) {
        // [운세 섹션 4단계 흐름 - 화면3 로딩] "만세력으로 사주 뽑기" 제출
        // 직후 결과로 곧장 가지 않고, 반드시 로딩 화면을 먼저 보여준다
        // (handoff 원본 saju_input_screen.dart `_submit()`이 결과가 아닌
        // '/saju/$code/loading'으로 이동하던 것과 동일한 설계 의도).
        await navigateWithPassGate(
          context,
          title: entry.title,
          route: JeontongEightyMatrix.loadingRoute,
          requiresPass: true,
          arguments: entry.id,
        );
        if (mounted) setState(() => _submitting = false);
        return;
      }
    }
    Navigator.of(context).pushReplacementNamed('/jeontong/eighty/grid');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HanjiBackground(
        sigilOpacity: 0.12,
        child: SafeArea(
          child: Column(
            children: [
              SajuCtxBar(
                tag: 'SAJU · 정보 입력',
                code: 'INPUT',
                title: '만세력 뽑기',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: _loadingProfile
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          HanjiSpacing.xl,
                          HanjiSpacing.sm,
                          HanjiSpacing.xl,
                          HanjiSpacing.xxxl,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '정확한 사주 풀이를 위해\n태어난 날짜와 시각을 입력해주세요.',
                              style: HanjiTextStyles.body(
                                color: HanjiColors.muted,
                              ),
                            ),
                            const SizedBox(height: HanjiSpacing.xl),

                            _Field(
                              label: '이름 (선택)',
                              child: TextField(
                                controller: _nameController,
                                maxLength: 20,
                                style: HanjiTextStyles.body(),
                                decoration: InputDecoration(
                                  hintText: '이름을 입력해주세요',
                                  counterText: '',
                                  filled: true,
                                  fillColor: HanjiColors.card,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      HanjiRadii.chip,
                                    ),
                                    borderSide: const BorderSide(
                                      color: HanjiColors.line,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      HanjiRadii.chip,
                                    ),
                                    borderSide: const BorderSide(
                                      color: HanjiColors.line,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      HanjiRadii.chip,
                                    ),
                                    borderSide: const BorderSide(
                                      color: HanjiColors.glow,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: HanjiSpacing.lg),

                            _Field(
                              label: '성별',
                              child: _SegmentGroup(
                                options: const [('M', '남 · 乾'), ('F', '여 · 坤')],
                                value: _gender,
                                onChanged: (v) => setState(() => _gender = v),
                                keyPrefix: 'jeontong_input_gender',
                              ),
                            ),
                            const SizedBox(height: HanjiSpacing.lg),

                            _Field(
                              label: '달력',
                              child: _SegmentGroup(
                                options: const [('S', '양력'), ('L', '음력')],
                                value: _isLunar ? 'L' : 'S',
                                onChanged: (v) =>
                                    setState(() => _isLunar = v == 'L'),
                                keyPrefix: 'jeontong_input_calendar',
                              ),
                            ),
                            const SizedBox(height: HanjiSpacing.lg),

                            _Field(
                              label: '생년월일시',
                              child: _PickerTile(
                                key: const ValueKey(
                                  'jeontong_input_birthday_tile',
                                ),
                                icon: Icons.calendar_today_rounded,
                                label: _birthDate == null
                                    ? '생년월일과 태어난 시각을 입력해주세요'
                                    : '${_birthDate!.year}년 ${_birthDate!.month}월 ${_birthDate!.day}일'
                                          '${_birthTime == null ? '' : ' · ${_birthTime!.hour.toString().padLeft(2, '0')}시 ${_birthTime!.minute.toString().padLeft(2, '0')}분'}',
                                onTap: _openBirthdayPicker,
                              ),
                            ),
                            const SizedBox(height: HanjiSpacing.xxl),

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                key: const ValueKey(
                                  'jeontong_input_submit_button',
                                ),
                                onPressed: _isValid && !_submitting
                                    ? _onSubmit
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: HanjiColors.accent,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: HanjiColors.muted
                                      .withValues(alpha: 0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      HanjiRadii.chip,
                                    ),
                                  ),
                                ),
                                child: _submitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        '만세력으로 사주 뽑기',
                                        style: HanjiTextStyles.button(
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
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

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoLabel(label, color: HanjiColors.muted),
        const SizedBox(height: HanjiSpacing.sm),
        child,
      ],
    );
  }
}

class _SegmentGroup extends StatelessWidget {
  const _SegmentGroup({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.keyPrefix,
  });

  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (v, label) in options) ...[
          Expanded(
            child: GestureDetector(
              key: ValueKey('${keyPrefix}_$v'),
              onTap: () => onChanged(v),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                margin: EdgeInsets.only(
                  right: v == options.first.$1 ? HanjiSpacing.sm : 0,
                ),
                decoration: BoxDecoration(
                  color: value == v ? HanjiColors.accent : HanjiColors.card,
                  border: Border.all(
                    color: value == v ? HanjiColors.accent : HanjiColors.line,
                  ),
                  borderRadius: BorderRadius.circular(HanjiRadii.chip),
                ),
                child: Text(
                  label,
                  style: HanjiTextStyles.ui(
                    color: value == v ? Colors.white : HanjiColors.fg,
                    weight: FontWeight.w700,
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
      borderRadius: BorderRadius.circular(HanjiRadii.chip),
      child: HanjiCard(
        padding: const EdgeInsets.symmetric(
          horizontal: HanjiSpacing.md,
          vertical: HanjiSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: HanjiColors.accent),
            const SizedBox(width: HanjiSpacing.sm),
            Expanded(child: Text(label, style: HanjiTextStyles.body())),
            const Icon(Icons.chevron_right_rounded, color: HanjiColors.muted),
          ],
        ),
      ),
    );
  }
}

/// 홈 화면 등에서 재사용할 정통사주 진입 헬퍼 — 저장된 프로필이 이미 있으면
/// 바로 그리드로, 없으면 입력 화면으로 보낸다.
///
/// [null-safety 안전망] [JeontongEightyScreen](`/jeontong/eighty`)은 카테고리
/// 탭 시점에 직접 프로필 유무를 확인하므로 이 헬퍼를 사용하지 않는다 — 이
/// 헬퍼는 그 외 신규 진입 버튼을 위해 남겨둔다(하위 호환).
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
