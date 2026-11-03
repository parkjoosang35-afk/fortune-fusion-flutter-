// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_guest_input_screen.dart
// [신통방통 궁합지도 개발 지시서 §2③] 게스트 본인 사주정보 입력 화면.
// `/gh/{token}` 딥링크로 진입한다.
//
// [절대 원칙 — 비회원 완결] 이 화면은 로그인 상태와 완전히 무관하게
// 도달·완료 가능해야 한다([GunghapProvider.joinAnonymous]는
// AuthTokenStore.authHeader()를 사용하지 않는 순수 비로그인 API).
// 로그인 게이트를 절대 추가하지 않는다 — guinji_map_guest_join_screen.dart와
// 동일한 원칙.
//
// [윤달 UI] guinji_input_screen.dart의 3단계 패턴(양력/음력/음력(윤달))을
// 그대로 따른다 — 백엔드 `g/[token]/join`이 isLeapMonth를 지원하기 때문에
// (guinji_map_guest_join_screen.dart의 2단계 패턴과는 다름, §6 투두 내역 참고).
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/router/main_bottom_nav_bar.dart';
import '../application/gunghap_provider.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/gh_button.dart';
import '../widgets/gh_screen.dart';
import 'gunghap_guest_result_screen.dart';

class GunghapGuestInputScreen extends StatefulWidget {
  const GunghapGuestInputScreen({super.key, required this.token});

  final String token;

  @override
  State<GunghapGuestInputScreen> createState() =>
      _GunghapGuestInputScreenState();
}

class _GunghapGuestInputScreenState extends State<GunghapGuestInputScreen> {
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
  bool _agreePolicy = false;
  bool _agreeAge14 = false;
  bool _submitting = false;
  bool _loadingInvite = true;
  String? _formError;
  String? _ownerName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInvite());
  }

  bool _inviteLoadFailed = false;

  Future<void> _loadInvite() async {
    setState(() {
      _loadingInvite = true;
      _inviteLoadFailed = false;
    });
    final provider = context.read<GunghapProvider>();
    final data = await provider.fetchInviteToken(widget.token);
    if (!mounted) return;
    if (data == null) {
      // [긴급 검수 지시 §4] 초대 링크 확인 실패 시(네트워크 오류 포함)
      // 빈 입력폼만 보여준 채 방치하지 않고, 전용 오류 화면 + 재시도
      // 버튼을 노출한다.
      setState(() {
        _loadingInvite = false;
        _inviteLoadFailed = true;
      });
      return;
    }
    setState(() {
      _ownerName = data['ownerName'] as String?;
      _loadingInvite = false;
    });
  }

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

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty && _agreePolicy && _agreeAge14;

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    final year = _yearController.text.trim();
    final month = _monthController.text.trim();
    final day = _dayController.text.trim();

    if (name.isEmpty) {
      setState(() => _formError = '이름(닉네임)을 입력해주세요.');
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
    } catch (_) {
      setState(() => _formError = '생년월일을 정확히 입력해주세요.');
      return;
    }
    if (_gender == null) {
      setState(() => _formError = '성별을 선택해주세요.');
      return;
    }
    if (!_agreePolicy || !_agreeAge14) {
      setState(() => _formError = '개인정보 처리 및 연령 확인에 동의해주세요.');
      return;
    }

    String? birthTime;
    if (!_timeUnknown && _hourController.text.trim().isNotEmpty) {
      final hh = _hourController.text.trim().padLeft(2, '0');
      final mmRaw = _minuteController.text.trim();
      final mm = mmRaw.isEmpty ? '00' : mmRaw.padLeft(2, '0');
      birthTime = '$hh:$mm';
    }

    setState(() {
      _submitting = true;
      _formError = null;
    });

    final provider = context.read<GunghapProvider>();
    final result = await provider.joinAnonymous(
      token: widget.token,
      name: name,
      birthDate: birthDate,
      isLunar: _calendarIndex != 0,
      isLeapMonth: _calendarIndex == 2,
      birthTime: birthTime,
      gender: _gender!,
      agreePolicy: _agreePolicy,
      agreeAge14: _agreeAge14,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result == null) {
      // [긴급 검수 지시 §4] 연결 실패(NETWORK_ERROR)는 전용 문구로 구분해
      // 보여준다 — 이 화면은 비회원 전용 입력 폼이라 원문 입력값이 그대로
      // 유지되므로("다시 시도" = 같은 버튼 재클릭) 별도 재시도 버튼 없이도
      // 바로 재시도가 가능하다.
      final isNetworkError = provider.errorCode == 'NETWORK_ERROR';
      setState(() {
        _formError = isNetworkError
            ? (provider.error ?? '서비스 연결이 원활하지 않습니다.')
            : (provider.error ?? '제출하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      });
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GunghapGuestResultScreen(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GHScreen(
      bottomNav: const MainBottomNavBar(currentIndex: 0),
      appBar: GHAppBar(
        title: '궁합 초대 참여',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      footer: GHButton(
        label: _submitting ? '제출하는 중…' : '내 궁합 확인하기',
        onPressed: (_canSubmit && !_submitting) ? _handleSubmit : null,
      ),
      child: _loadingInvite
          ? const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: CircularProgressIndicator(color: GHColors.gold),
              ),
            )
          : _inviteLoadFailed
          ? Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Column(
                children: [
                  Text(
                    '초대 정보를 불러오지 못했어요.\n서비스 연결이 원활하지 않습니다.',
                    textAlign: TextAlign.center,
                    style: GHText.ui(
                      size: 14,
                      height: 1.6,
                      color: GHColors.gray,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GHButton(
                    label: '다시 시도',
                    onPressed: _loadInvite,
                    expand: false,
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const GHSteps(step: 3, labels: ['분야', '나', '상대', '분석']),
                GHTitle(
                  mono: 'STEP 03 · YOUR STAR',
                  title: (_ownerName != null && _ownerName!.isNotEmpty)
                      ? '$_ownerName님이\n궁합을 물어봤어요'
                      : '궁합지도에\n초대받았어요',
                  sub:
                      '당신의 생년월일만 입력하면 바로 궁합을 확인할 수 있어요.\n'
                      '회원가입은 필요하지 않아요.',
                ),
                _GhFieldLabel('이름 · 닉네임'),
                const SizedBox(height: 8),
                _GhTextField(
                  controller: _nameController,
                  hint: '어떻게 불릴까요',
                  maxLength: 24,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 18),

                _GhFieldLabel('생년월일'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 15,
                      child: _GhNumberUnit(
                        controller: _yearController,
                        placeholder: '1998',
                        maxLength: 4,
                        unit: '년',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 10,
                      child: _GhNumberUnit(
                        controller: _monthController,
                        placeholder: '05',
                        maxLength: 2,
                        unit: '월',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 10,
                      child: _GhNumberUnit(
                        controller: _dayController,
                        placeholder: '14',
                        maxLength: 2,
                        unit: '일',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                _GhFieldLabel('양력/음력'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < _calendarChips.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _GhChip(
                          label: _calendarChips[i],
                          active: _calendarIndex == i,
                          onTap: () => setState(() => _calendarIndex = i),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),

                _GhFieldLabel('태어난 시간'),
                const SizedBox(height: 8),
                AnimatedOpacity(
                  opacity: _timeUnknown ? 0.35 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: _timeUnknown,
                    child: Row(
                      children: [
                        Expanded(
                          child: _GhNumberUnit(
                            controller: _hourController,
                            placeholder: '09',
                            maxLength: 2,
                            unit: '시',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _GhNumberUnit(
                            controller: _minuteController,
                            placeholder: '20',
                            maxLength: 2,
                            unit: '분',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _GhInlineCheck(
                  value: _timeUnknown,
                  onChanged: (v) => setState(() => _timeUnknown = v),
                  title: '태어난 시간을 몰라요',
                  subtitle: '3기둥으로 계산해요. 정확도가 조금 낮아질 수 있어요.',
                ),
                const SizedBox(height: 18),

                _GhFieldLabel('성별'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _GhChip(
                        label: '여성',
                        active: _gender == 'female',
                        onTap: () => setState(() => _gender = 'female'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _GhChip(
                        label: '남성',
                        active: _gender == 'male',
                        onTap: () => setState(() => _gender = 'male'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _GhConsentCard(
                  children: [
                    _GhConsentRow(
                      value: _agreePolicy,
                      onChanged: (v) => setState(() => _agreePolicy = v),
                      label: '개인정보 수집 · 이용에 동의합니다',
                    ),
                    const Divider(height: 1, color: GHColors.lineSoft),
                    _GhConsentRow(
                      value: _agreeAge14,
                      onChanged: (v) => setState(() => _agreeAge14 = v),
                      label: '만 14세 이상입니다',
                    ),
                  ],
                ),

                if (_formError != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _formError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: GHColors.rose),
                  ),
                ],
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '입력한 정보는 초대한 사람에게만 공유돼요.',
                    style: GHText.ui(size: 11, color: GHColors.gray),
                  ),
                ),
              ],
            ),
    );
  }
}

class _GhFieldLabel extends StatelessWidget {
  const _GhFieldLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 0),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('◇ ', style: TextStyle(fontSize: 9, color: GHColors.gold)),
        Text(
          label,
          style: GHText.ui(
            size: 12,
            weight: FontWeight.w600,
            color: GHColors.gray,
          ),
        ),
      ],
    ),
  );
}

class _GhTextField extends StatelessWidget {
  const _GhTextField({
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: GHColors.card,
      borderRadius: BorderRadius.circular(GHRadius.input),
      border: Border.all(color: GHColors.lineSoft),
    ),
    alignment: Alignment.center,
    child: TextField(
      controller: controller,
      maxLength: maxLength,
      onChanged: onChanged,
      style: GHText.ui(size: 14.5),
      decoration: InputDecoration(
        isDense: true,
        counterText: '',
        hintText: hint,
        hintStyle: GHText.ui(
          size: 14.5,
          color: GHColors.gray.withValues(alpha: .6),
        ),
        border: InputBorder.none,
      ),
    ),
  );
}

class _GhNumberUnit extends StatelessWidget {
  const _GhNumberUnit({
    required this.controller,
    required this.placeholder,
    required this.maxLength,
    required this.unit,
  });
  final TextEditingController controller;
  final String placeholder;
  final int maxLength;
  final String unit;
  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    decoration: BoxDecoration(
      color: GHColors.card,
      borderRadius: BorderRadius.circular(GHRadius.input),
      border: Border.all(color: GHColors.lineSoft),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: maxLength,
            textAlign: TextAlign.center,
            style: GHText.ui(size: 14.5),
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              hintText: placeholder,
              hintStyle: GHText.ui(
                size: 14.5,
                color: GHColors.gray.withValues(alpha: .6),
              ),
              border: InputBorder.none,
            ),
          ),
        ),
        Positioned(
          right: 12,
          child: IgnorePointer(
            child: Text(unit, style: GHText.ui(size: 11, color: GHColors.gray)),
          ),
        ),
      ],
    ),
  );
}

class _GhChip extends StatelessWidget {
  const _GhChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? GHColors.gold.withValues(alpha: .12) : GHColors.card,
        borderRadius: BorderRadius.circular(GHRadius.input),
        border: Border.all(color: active ? GHColors.gold : GHColors.lineSoft),
      ),
      child: Text(
        active ? '✦ $label' : label,
        style: GHText.ui(
          size: 13.5,
          weight: FontWeight.w600,
          color: active ? GHColors.gold : GHColors.gray,
        ),
      ),
    ),
  );
}

class _GhInlineCheck extends StatelessWidget {
  const _GhInlineCheck({
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!value),
    behavior: HitTestBehavior.opaque,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GhCheckboxBox(value: value),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GHText.ui(size: 12.5, color: GHColors.gray)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: GHText.ui(
                      size: 11,
                      color: GHColors.gray.withValues(alpha: .7),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _GhCheckboxBox extends StatelessWidget {
  const _GhCheckboxBox({required this.value});
  final bool value;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: value ? GHColors.gold : GHColors.card,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: value ? GHColors.gold : GHColors.lineSoft),
    ),
    child: value
        ? const Text(
            '✓',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: GHColors.ink,
            ),
          )
        : null,
  );
}

class _GhConsentCard extends StatelessWidget {
  const _GhConsentCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: GHColors.card,
      borderRadius: BorderRadius.circular(GHRadius.cardSm),
      border: Border.all(color: GHColors.lineSoft),
    ),
    child: Column(children: children),
  );
}

class _GhConsentRow extends StatelessWidget {
  const _GhConsentRow({
    required this.value,
    required this.onChanged,
    required this.label,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onChanged(!value),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          _GhCheckboxBox(value: value),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: GHText.ui(size: 13))),
        ],
      ),
    ),
  );
}
