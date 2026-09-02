import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/guinji_provider.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_widgets.dart';
import 'guinji_calculating_screen.dart';
import 'guinji_guest_result_screen.dart';

/// 게스트 참여+입력 — `/g/:mapToken`
///
/// [design_handoff_guinji_web/Guinji Section.html] `flow-map`(2230~2245줄)
/// 게스트 플로우 스펙: `/g/:mapToken` → 참여 안내·사주 입력 → `/g/:mapToken/calc`
/// (C·Calculating 재사용) → `/g/:mapToken/result`(Y·Guest Result).
///
/// [2026-09 새 디자인 리스킨] 이 화면은 8화면(L/I/C/M/N/F/S/Y) 리스킨
/// 당시 누락되어 구버전 다크·라벤더 톤(`guinji_theme.dart`)에 남아있었다.
/// "귀인지도 흐름이 실제로 확실히 동작하는가"를 재검증하는 과정에서 발견,
/// 새 디자인의 아이보리+로즈골드 팔레트·공용 위젯(`GmTopBar`/`GmFieldLabel`/
/// `GmFieldShell`/`GmChip`/`GmPrimaryButton`)으로 I(Input) 화면과 동일한
/// 시각 언어로 재도색했다. 데이터 흐름·API 호출·다음 화면 이동 로직은
/// 절대 변경하지 않았다(아래 [_handleSubmit] 그대로 유지).
///
/// [절대 원칙 — 바이럴 게스트 플로우] 이 화면은:
///  (a) 회원가입 없이 도달·완료 가능해야 하고([GuinjiProvider.joinAnonymous]는
///      `AuthTokenStore.authHeader()`를 사용하지 않는 순수 비로그인 API),
///  (b) 결과(Y화면)까지 완결된 경험을 제공하며,
///  (c) "나도 내 지도 만들기" CTA는 게스트가 스스로 원할 때만 누르는 선택적
///      전환일 뿐, 자동 리다이렉트는 절대 포함하지 않는다.
///
/// [기존 로그인-필요 GuinjiJoinScreen과의 관계] `guinji_join_screen.dart`의
/// `GuinjiJoinScreen`은 로그인을 요구하는 완전히 별개의 지인 참여 플로우
/// (`POST /guinji/maps/{mapId}/members`, 인증 필수)를 위한 화면이다. 이
/// 화면은 그 파일/클래스를 전혀 참조하지 않으며, 오직 인증이 필요 없는
/// `POST /guinji/g/{token}/join`([GuinjiProvider.joinAnonymous])만 사용한다.
///
/// [초대자 이름 표시 제약] `GET /guinji/g/{token}`([fetchInvite])는 인증이
/// 필요한 API라 비로그인 게스트가 사전에 초대자 이름을 조회할 수 없다.
/// 초대자 이름은 [joinAnonymous] 응답의 `ownerName` 필드로만 제출 *이후*에
/// 알 수 있으므로, 이 화면의 상단 greeting 문구는 특정 이름 없이 일반화된
/// 문구를 사용한다(실제 이름은 Y·Guest Result 화면에서 노출).
class GuinjiMapGuestJoinScreen extends StatefulWidget {
  const GuinjiMapGuestJoinScreen({super.key, required this.token});

  final String token;

  @override
  State<GuinjiMapGuestJoinScreen> createState() =>
      _GuinjiMapGuestJoinScreenState();
}

class _GuinjiMapGuestJoinScreenState extends State<GuinjiMapGuestJoinScreen> {
  final _nameController = TextEditingController();
  final _yearController = TextEditingController();
  final _monthController = TextEditingController();
  final _dayController = TextEditingController();
  final _hourController = TextEditingController();
  final _minuteController = TextEditingController();

  int _calendarIndex = 0; // 0=양력, 1=음력
  bool _timeUnknown = false;
  String? _gender; // 'female' | 'male'
  bool _agreePolicy = false;
  bool _agreeAge14 = false;
  bool _submitting = false;
  String? _formError;

  static const _calendarChips = ['양력', '음력'];

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

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    final year = _yearController.text.trim();
    final month = _monthController.text.trim();
    final day = _dayController.text.trim();

    if (name.isEmpty) {
      setState(() => _formError = '이름(닉네임)을 입력해주세요.');
      return;
    }
    if (year.length != 4 || month.isEmpty || day.isEmpty) {
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

    final birthDate =
        '$year-${month.padLeft(2, '0')}-${day.padLeft(2, '0')}';
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

    final provider = context.read<GuinjiProvider>();
    final result = await provider.joinAnonymous(
      token: widget.token,
      name: name,
      birthDate: birthDate,
      calendarType: _calendarIndex == 0 ? 'solar' : 'lunar',
      birthTime: birthTime,
      gender: _gender!,
      agreePolicy: _agreePolicy,
      agreeAge14: _agreeAge14,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result == null) {
      setState(() => _formError = provider.error ?? '참여에 실패했습니다. 다시 시도해주세요.');
      return;
    }

    // [절대 원칙] joinAnonymous 성공 직후에만 다음 화면(C→Y)으로 진행한다.
    // 타이머/딜레이로 자동 진행되는 코드가 아니라 사용자가 직접 제출한
    // 결과이므로 이 흐름은 "자동 리다이렉트 금지" 원칙을 위반하지 않는다.
    final hostName = result['ownerName'] as String? ?? '지도 주인';
    final relationKey = result['relationType'] as String? ?? 'CHEON_GWII';
    final score = (result['chemistryScore'] as num?)?.toInt() ?? 0;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuinjiCalculatingScreen(
          onComplete: () {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => GuinjiGuestResultScreen(
                  hostName: hostName,
                  relationKey: relationKey,
                  score: score,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GmColors.bgIvory,
      appBar: GmTopBar(
        back: true,
        title: '귀인지도 참여',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _GreetingCard(),
            const SizedBox(height: 24),
            const Text(
              '당신의 사주',
              style: TextStyle(
                fontFamily: GmFonts.serif,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: GmColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '내 정보를 입력하면 초대한 친구와의 관계가 채워져요.',
              style: TextStyle(fontSize: 12, color: GmColors.inkSoft),
            ),
            const SizedBox(height: 24),

            const GmFieldLabel('이름 · 닉네임'),
            const SizedBox(height: 6),
            GmFieldShell(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _nameController,
                maxLength: 24,
                style: const TextStyle(fontSize: 14, color: GmColors.ink),
                decoration: const InputDecoration(
                  isDense: true,
                  counterText: '',
                  hintText: '어떻게 불릴까요',
                  hintStyle: TextStyle(color: GmColors.inkFaint),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '지도 소유자에게만 표시돼요.',
              style: TextStyle(fontSize: 10.5, color: GmColors.inkFaint),
            ),
            const SizedBox(height: 12),

            const GmFieldLabel('생년월일'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: 7,
                  child: _NumberBox(controller: _yearController, placeholder: '2003', maxLength: 4),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 5,
                  child: _NumberBox(controller: _monthController, placeholder: '05', maxLength: 2),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 5,
                  child: _NumberBox(controller: _dayController, placeholder: '14', maxLength: 2),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const GmFieldLabel('달력'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < _calendarChips.length; i++)
                  _ChoiceChip(
                    label: _calendarChips[i],
                    active: _calendarIndex == i,
                    onTap: () => setState(() => _calendarIndex = i),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            const GmFieldLabel('태어난 시간'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _NumberBox(controller: _hourController, placeholder: '09', maxLength: 2),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _NumberBox(controller: _minuteController, placeholder: '20', maxLength: 2),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Checkbox(
                  value: _timeUnknown,
                  activeColor: GmColors.rose500,
                  onChanged: (v) => setState(() => _timeUnknown = v ?? false),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      '태어난 시간을 몰라요 (3기둥으로 계산, 정확도 다소 낮아짐)',
                      style: TextStyle(fontSize: 11.5, color: GmColors.inkSoft, height: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            const GmFieldLabel('성별'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _ChoiceChip(
                  label: '여성',
                  active: _gender == 'female',
                  onTap: () => setState(() => _gender = 'female'),
                ),
                _ChoiceChip(
                  label: '남성',
                  active: _gender == 'male',
                  onTap: () => setState(() => _gender = 'male'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _ConsentCheckbox(
              label: '개인정보 수집·이용에 동의합니다',
              value: _agreePolicy,
              onChanged: (v) => setState(() => _agreePolicy = v),
            ),
            const SizedBox(height: 8),
            _ConsentCheckbox(
              label: '만 14세 이상입니다',
              value: _agreeAge14,
              onChanged: (v) => setState(() => _agreeAge14 = v),
            ),

            if (_formError != null) ...[
              const SizedBox(height: 12),
              Text(
                _formError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ],

            const SizedBox(height: 24),
            GmPrimaryButton(
              label: '관계 확인하기',
              loading: _submitting,
              onPressed: _submitting ? null : _handleSubmit,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/guinji-map'),
                child: const Text(
                  '나도 내 지도 만들기',
                  style: TextStyle(fontSize: 12.5, color: GmColors.rose700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '입력한 정보는 지도 소유자에게만 공유돼요.\n'
              '상대방의 개인정보는 동의 없이 입력하지 말아 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, height: 1.5, color: GmColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// 상단 greeting 카드 — 새 디자인 팔레트로 재도색.
///
/// [초대자 이름 표시 제약] 참고 — [fetchInvite]가 인증 필요 API라 제출 전엔
/// 실제 초대자 이름을 알 수 없으므로 일반화된 문구를 사용한다.
class _GreetingCard extends StatelessWidget {
  const _GreetingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: Border.all(color: GmColors.line),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x26A6795E), blurRadius: 20, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Image.asset(
              'assets/images/guinji/seonnyeo/greeting.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.favorite,
                color: GmColors.rose500,
                size: 32,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              '친구가 당신을\n귀인지도에 초대했어요',
              style: TextStyle(
                fontFamily: GmFonts.serif,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: GmColors.ink,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberBox extends StatelessWidget {
  const _NumberBox({required this.controller, required this.placeholder, required this.maxLength});

  final TextEditingController controller;
  final String placeholder;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return GmFieldShell(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: maxLength,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: GmColors.ink),
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          hintText: placeholder,
          hintStyle: const TextStyle(color: GmColors.inkFaint),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GmChip(
        label: label,
        background: active ? GmColors.ink : Colors.white,
        foreground: active ? GmColors.ivory : GmColors.inkSoft,
        borderColor: active ? GmColors.ink : GmColors.line,
      ),
    );
  }
}

/// 정사각 체크박스 + 라벨(개인정보/연령 동의) — 새 디자인 팔레트로 재도색.
class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          border: Border.all(color: GmColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: value ? GmColors.rose500 : Colors.transparent,
                border: Border.all(
                  color: value ? GmColors.rose500 : GmColors.inkSoft,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: value
                  ? const Text(
                      '✓',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: GmColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
