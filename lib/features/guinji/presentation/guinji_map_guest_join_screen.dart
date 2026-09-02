import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/guinji_provider.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_ui_kit.dart';
import 'guinji_calculating_screen.dart';
import 'guinji_guest_result_screen.dart';

/// 게스트 참여+입력 — `/g/:mapToken`
///
/// [design_handoff_guinji_web/Guinji Section.html] `flow-map`(2230~2245줄)
/// 게스트 플로우 스펙: `/g/:mapToken` → 참여 안내·사주 입력 → `/g/:mapToken/calc`
/// (C·Calculating 재사용) → `/g/:mapToken/result`(Y·Guest Result).
/// UI 구조는 원본 프로토타입(`GuinjiScreens.jsx` "SCREEN 7 · Guest Join
/// Page", 1135~1278줄)의 도령/선녀 greeting + 이름/생년월일/시간모름/
/// 성별/약관 폼을 재현한다.
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
      backgroundColor: GuinjiColors.backgroundDarker,
      body: GuinjiScreenScaffold(
        bgAlignment: const Alignment(0, -0.5),
        bgOpacity: 0.12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GuinjiTopBar(
              breadcrumb: 'GUEST · JOIN',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GreetingCard(),
                    const SizedBox(height: 20),
                    const Padding(
                      padding: EdgeInsets.only(left: 2, bottom: 8),
                      child: Text(
                        '당신의 사주',
                        style: TextStyle(
                          fontFamily: GuinjiFonts.mono,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 3,
                          color: GuinjiColors.textSecondary,
                        ),
                      ),
                    ),
                    GuinjiField(
                      label: '이름 · 닉네임',
                      required: true,
                      hint: '지도 소유자에게만 표시됩니다',
                      controller: _nameController,
                      placeholder: '어떻게 불릴까요',
                      maxLength: 24,
                    ),
                    GuinjiField(
                      label: '생년월일',
                      required: true,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 14,
                            child: GuinjiInputBox(
                              controller: _yearController,
                              placeholder: '2003',
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GuinjiInputBox(
                              controller: _monthController,
                              placeholder: '05',
                              keyboardType: TextInputType.number,
                              maxLength: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GuinjiInputBox(
                              controller: _dayController,
                              placeholder: '14',
                              keyboardType: TextInputType.number,
                              maxLength: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GuinjiField(
                      label: '달력',
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var i = 0; i < _calendarChips.length; i++)
                            GuinjiChip(
                              label: _calendarChips[i],
                              active: _calendarIndex == i,
                              onTap: () => setState(() => _calendarIndex = i),
                            ),
                        ],
                      ),
                    ),
                    GuinjiField(
                      label: '태어난 시간',
                      child: Row(
                        children: [
                          Expanded(
                            child: GuinjiInputBox(
                              controller: _hourController,
                              placeholder: '09',
                              keyboardType: TextInputType.number,
                              maxLength: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GuinjiInputBox(
                              controller: _minuteController,
                              placeholder: '20',
                              keyboardType: TextInputType.number,
                              maxLength: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    GuinjiToggle(
                      label: '태어난 시간을 몰라요',
                      description: '3기둥으로 계산 (정확도 다소 낮아짐)',
                      value: _timeUnknown,
                      onChanged: (v) => setState(() => _timeUnknown = v),
                    ),
                    const SizedBox(height: 14),
                    GuinjiField(
                      label: '성별',
                      required: true,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          GuinjiChip(
                            label: '여성',
                            active: _gender == 'female',
                            onTap: () => setState(() => _gender = 'female'),
                          ),
                          GuinjiChip(
                            label: '남성',
                            active: _gender == 'male',
                            onTap: () => setState(() => _gender = 'male'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
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
                        style: const TextStyle(
                          fontFamily: GuinjiFonts.body,
                          fontSize: 12,
                          color: GuinjiColors.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            GuinjiPrimaryButton(
              label: '관계 확인하기',
              loading: _submitting,
              onPressed: _submitting ? null : _handleSubmit,
            ),
            const SizedBox(height: 6),
            GuinjiGhostButton(
              label: '나도 내 지도 만들기',
              onPressed: () =>
                  Navigator.of(context).pushNamed('/guinji-map'),
            ),
            const SizedBox(height: 10),
            const Text(
              '입력한 정보는 지도 소유자에게만 공유돼요.\n'
              '상대방의 개인정보는 동의 없이 입력하지 말아 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 10,
                height: 1.5,
                color: GuinjiColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 도령/선녀 greeting 이미지 + 말풍선 카드.
///
/// [초대자 이름 표시 제약] 참고 — [fetchInvite]가 인증 필요 API라 제출 전엔
/// 실제 초대자 이름을 알 수 없으므로 일반화된 문구를 사용한다.
class _GreetingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: Image.asset(
            'assets/images/guinji/seonnyeo/greeting.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: GuinjiColors.surfaceCard,
            border: Border.all(color: GuinjiColors.surfaceCardBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            '친구가 당신을\n귀인지도에 초대했어요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: GuinjiFonts.body,
              fontSize: 13,
              height: 1.5,
              color: GuinjiColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 정사각 체크박스 + 라벨(개인정보/연령 동의) — 원본 JSX
/// (`GuinjiScreens.jsx` 1214~1230줄)의 "태어난 시간을 몰라요" 체크박스
/// 스타일을 그대로 이식.
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
          color: GuinjiColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: value ? GuinjiColors.lavender : Colors.transparent,
                border: Border.all(
                  color: value
                      ? GuinjiColors.lavender
                      : GuinjiColors.textSecondary,
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
                        color: GuinjiColors.ink,
                        height: 1,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: GuinjiFonts.body,
                  fontSize: 12,
                  color: GuinjiColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
