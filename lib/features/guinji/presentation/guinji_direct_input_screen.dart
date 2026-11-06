import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_toast.dart';
import '../application/guinji_provider.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_widgets.dart';

/// [귀인지도 DIRECT — 궁합지도 DIRECT 방식과 동일한 개념] 지도 소유자가
/// 초대 링크 없이 지인의 정보를 직접 입력해 즉시 관계를 확인한다.
///
/// [배경] 궁합지도(gunghap)는 INVITE(상대가 링크로 직접 입력) + DIRECT
/// (로그인 당사자가 상대 정보를 바로 입력) 두 방식을 모두 제공한다
/// (`GunghapDirectInputScreen` 참고). 귀인지도는 그동안 INVITE에 해당하는
/// 두 경로(로그인 지인 참여·비로그인 지인 참여)만 있었고, "소유자가 바로
/// 입력"하는 DIRECT 방식이 없었다 — 사용자 확인("귀인지도에도 궁합지도
/// DIRECT와 동일한 개념을 추가 개발")에 따라 이 화면을 신설한다.
///
/// [절대 금지] 이 화면은 초대 링크를 생성하지 않는다 —
/// [GuinjiProvider.addMemberDirect]만 호출하며, 공유/초대 관련 플로우와는
/// 완전히 독립적이다(`GuinjiMapShareScreen`과는 무관).
///
/// [입력 UI 재사용] [GuinjiInputScreen]("나의 정보" 입력 폼)과 동일한
/// `Gm*` 다크 테마 위젯 조합(별명/성별/생년월일/양력·음력·윤달/태어난
/// 시간/시간 모름)을 그대로 재사용한다 — 이름 필드만 "지인의 이름(별칭)"
/// 으로 문구를 바꾼다. [GuinjiInputScreen]의 `_NumberBox`/`_CalendarChip`/
/// `_GenderSegment`는 파일-스코프 private 위젯이라 import할 수 없으므로
/// 이 파일에 동일한 모양으로 다시 정의한다(의도적 복제 — 위젯 자체의
/// 동작·룩은 100% 동일).
///
/// [B안 비대칭 신뢰 모델] 이 화면은 지인의 사주를 클라이언트에서 계산하지
/// 않는다 — [GuinjiProvider.addMemberDirect]가 보내는 생년월일/시간/성별
/// 원본 값을 서버(`POST /guinji/maps/{mapId}/members/direct`)가 그대로
/// 받아 직접 계산한다(`joinAnonymous`와 동일한 방식 — `joinMap`처럼
/// 클라이언트가 사주를 계산해 올리지 않는다).
///
/// [포인트 미지급] 소유자가 입력한 멤버는 "참여"가 아니므로
/// `guinji_join`(+20P) 포인트가 지급되지 않는다 — 이 화면도 포인트 관련
/// UI를 노출하지 않는다.
class GuinjiDirectInputScreen extends StatefulWidget {
  const GuinjiDirectInputScreen({super.key});

  static const routeName = '/guinji-map/m/add-direct';

  @override
  State<GuinjiDirectInputScreen> createState() =>
      _GuinjiDirectInputScreenState();
}

class _GuinjiDirectInputScreenState extends State<GuinjiDirectInputScreen> {
  final _nameController = TextEditingController();
  final _yearController = TextEditingController();
  final _monthController = TextEditingController();
  final _dayController = TextEditingController();
  final _hourController = TextEditingController();
  final _minuteController = TextEditingController();

  static const _calendarChips = ['양력', '음력', '음력(윤달)'];
  int _calendarIndex = 0; // 0=양력, 1=음력, 2=음력(윤달)
  bool _timeUnknown = false;
  String? _gender; // 'male' | 'female'
  bool _submitting = false;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _nameController.text.trim().isNotEmpty;

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    final year = _yearController.text.trim();
    final month = _monthController.text.trim();
    final day = _dayController.text.trim();

    if (name.isEmpty) {
      setState(() => _formError = '지인의 이름(별칭)을 입력해주세요.');
      return;
    }
    if (name.length > 20) {
      setState(() => _formError = '이름은 20자 이내로 입력해주세요.');
      return;
    }
    final yearNum = int.tryParse(year);
    final monthNum = int.tryParse(month);
    final dayNum = int.tryParse(day);
    if (year.length != 4 ||
        yearNum == null ||
        monthNum == null ||
        dayNum == null) {
      setState(() => _formError = '생년월일을 정확히 입력해주세요.');
      return;
    }

    DateTime birthDate;
    try {
      birthDate = DateTime(yearNum, monthNum, dayNum);
      // [생년월일 유효성] DateTime은 2월 30일 같은 입력도 다음 달로 자동
      // 보정(overflow)해버리므로, 보정 여부를 직접 검사해 "정확히 그
      // 날짜"가 아니면 거부한다(gunghap_direct_input_screen.dart와 동일).
      if (birthDate.year != yearNum ||
          birthDate.month != monthNum ||
          birthDate.day != dayNum) {
        setState(() => _formError = '존재하지 않는 날짜예요. 생년월일을 다시 확인해주세요.');
        return;
      }
    } catch (_) {
      setState(() => _formError = '생년월일을 정확히 입력해주세요.');
      return;
    }
    if (birthDate.isAfter(DateTime.now())) {
      setState(() => _formError = '생년월일은 오늘 이전 날짜여야 해요.');
      return;
    }
    if (_gender == null) {
      setState(() => _formError = '지인의 성별을 선택해주세요.');
      return;
    }

    String? birthTime;
    if (!_timeUnknown && _hourController.text.trim().isNotEmpty) {
      final hh = _hourController.text.trim().padLeft(2, '0');
      final mmRaw = _minuteController.text.trim();
      final mm = mmRaw.isEmpty ? '00' : mmRaw.padLeft(2, '0');
      birthTime = '$hh:$mm';
    }

    if (_submitting) return;
    setState(() {
      _submitting = true;
      _formError = null;
    });

    final provider = context.read<GuinjiProvider>();
    final ok = await provider.addMemberDirect(
      name: name,
      gender: _gender!,
      isLunar: _calendarIndex != 0,
      birthDate: birthDate,
      birthTime: birthTime,
      isLeapMonth: _calendarIndex == 2,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!ok) {
      final message = provider.error ?? '등록하지 못했습니다. 잠시 후 다시 시도해주세요.';
      setState(() => _formError = message);
      AppToast.show(context, message, isError: true, onRetry: _handleSubmit);
      return;
    }

    if (!mounted) return;
    // [성공] 새 멤버가 반영된 M(내 지도) 화면으로 돌아간다 — 결과는
    // provider.people에 이미 포함돼 있으므로 별도 결과 화면 없이 바로
    // 이전 화면으로 복귀한다.
    AppToast.show(context, '$name님을 지도에 등록했어요.');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GmColors.bg,
      appBar: GmTopBar(
        back: true,
        title: '지인 직접 추가',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '지인 정보 직접 입력',
              style: TextStyle(
                fontFamily: GmText.display,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: GmColors.fg,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '초대 링크 없이 지인의 정보를 바로 입력하면\n곧바로 관계를 확인할 수 있어요.',
              style: TextStyle(
                fontFamily: GmText.ui,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.5,
                color: GmColors.muted,
              ),
            ),
            const SizedBox(height: 24),

            const GmFieldLabel('지인의 이름 · 별칭'),
            const SizedBox(height: 6),
            GmFieldShell(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _nameController,
                maxLength: 20,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontFamily: GmText.ui,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: GmColors.fg,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  counterText: '',
                  hintText: '어떻게 불릴까요',
                  hintStyle: TextStyle(color: GmColors.dim),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            const GmFieldLabel('성별'),
            const SizedBox(height: 8),
            Row(
              children: [
                _GdGenderSegment(
                  label: '여성',
                  active: _gender == 'female',
                  onTap: () => setState(() => _gender = 'female'),
                ),
                const SizedBox(width: 8),
                _GdGenderSegment(
                  label: '남성',
                  active: _gender == 'male',
                  onTap: () => setState(() => _gender = 'male'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const GmFieldLabel('생년월일'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: 7,
                  child: _GdNumberBox(
                    controller: _yearController,
                    placeholder: '1998',
                    maxLength: 4,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 5,
                  child: _GdNumberBox(
                    controller: _monthController,
                    placeholder: '05',
                    maxLength: 2,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 5,
                  child: _GdNumberBox(
                    controller: _dayController,
                    placeholder: '14',
                    maxLength: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const GmFieldLabel('양력/음력'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _calendarChips.length; i++)
                  _GdCalendarChip(
                    label: _calendarChips[i],
                    active: _calendarIndex == i,
                    onTap: () => setState(() => _calendarIndex = i),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            const GmFieldLabel('태어난 시간'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _GdNumberBox(
                    controller: _hourController,
                    placeholder: '09',
                    maxLength: 2,
                    enabled: !_timeUnknown,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _GdNumberBox(
                    controller: _minuteController,
                    placeholder: '20',
                    maxLength: 2,
                    enabled: !_timeUnknown,
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => setState(() => _timeUnknown = !_timeUnknown),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: _timeUnknown ? GmColors.fg : Colors.transparent,
                      border: Border.all(
                        color: _timeUnknown ? GmColors.fg : GmColors.line,
                      ),
                    ),
                    child: Text(
                      _timeUnknown ? '✓ 시간 모름' : '시간 모름',
                      style: TextStyle(
                        fontFamily: GmText.ui,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _timeUnknown ? GmColors.onFg : GmColors.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_timeUnknown) ...[
              const SizedBox(height: 8),
              const Text(
                '태어난 시간을 몰라요. 3기둥으로 계산합니다(정확도 다소 낮아짐).',
                style: TextStyle(
                  fontFamily: GmText.ui,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                  color: GmColors.muted,
                  height: 1.5,
                ),
              ),
            ],

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: GmColors.line),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✦',
                    style: TextStyle(fontSize: 13, color: GmColors.gold),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '지인의 생년월일로 바로 관계를 계산해요. 초대 링크는 발송되지 않아요.',
                      style: TextStyle(
                        fontFamily: GmText.ui,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.6,
                        color: GmColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_formError != null) ...[
              const SizedBox(height: 12),
              Text(
                _formError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: GmColors.danger),
              ),
            ],

            const SizedBox(height: 28),
            GmPrimaryButton(
              label: _submitting ? '등록하는 중…' : '관계 확인하기',
              loading: _submitting,
              onPressed: (_canSubmit && !_submitting) ? _handleSubmit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _GdGenderSegment extends StatelessWidget {
  const _GdGenderSegment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: active ? GmColors.fg : Colors.transparent,
          border: Border.all(color: active ? GmColors.fg : GmColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: GmText.ui,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: active ? GmColors.onFg : GmColors.muted,
          ),
        ),
      ),
    );
  }
}

class _GdNumberBox extends StatelessWidget {
  const _GdNumberBox({
    required this.controller,
    required this.placeholder,
    required this.maxLength,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String placeholder;
  final int maxLength;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: GmFieldShell(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.number,
          maxLength: maxLength,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: GmText.ui,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: GmColors.fg,
          ),
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
            hintText: placeholder,
            hintStyle: const TextStyle(color: GmColors.dim),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

class _GdCalendarChip extends StatelessWidget {
  const _GdCalendarChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GmChip(
        label: label,
        background: active ? GmColors.fg : Colors.transparent,
        foreground: active ? GmColors.onFg : GmColors.muted,
        borderColor: active ? GmColors.fg : GmColors.line,
      ),
    );
  }
}
