import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_navigator_key.dart';
import '../../auth/application/auth_provider.dart';
import '../../guinji/domain/pending_guinji_join.dart';
import '../application/guinji_provider.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_ui_kit.dart';

/// [2026 디자인 핸드오프 — `/guinji-map/*` 신규 8화면] 로그인 완료 후
/// 저장된 "I(Input) 화면 재진입" 요청이 있으면, 원래 열려던
/// [GuinjiInputScreen]으로 자동 복귀시킨다.
/// `guinji_onboarding_screen.dart`의 [replayPendingGuinjiOnboarding]과
/// 동일한 타이밍 전략을 따르되, 재진입 대상 화면만 신규 네임스페이스의
/// 것으로 바꾼다(두 네임스페이스는 서로의 재진입 로직/화면을 공유하지
/// 않는다는 원칙 유지).
///
/// [버그 수정 — 사주 재입력] 저장된 [GuinjiMapEntryDraft]가 있으면 그대로
/// [GuinjiInputScreen]의 `initialDraft`로 전달해, 사용자가 로그인 전에
/// 입력했던 별명/생년월일/시간이 화면에 그대로 복원되도록 한다.
void replayPendingGuinjiMapEntry() {
  final draft = PendingGuinjiMapEntryStore.consume();
  if (draft == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final navState = appNavigatorKey.currentState;
    if (navState == null) return;
    navState.push(
      MaterialPageRoute(
        builder: (_) => GuinjiInputScreen(initialDraft: draft),
      ),
    );
  });
}

/// I · Input — `/guinji-map/new`
///
/// [design_handoff_guinji_web/Guinji Section.html] 1341~1436줄 마크업을
/// 재현한다. 별명·생년월일(3분할)·양음력 칩·태어난 시간(모름 토글)을
/// 입력받아 "다음"을 누르면 실제 `POST /guinji/maps`(호스트 지도 생성)를
/// 호출한 뒤 C(Calculating)로 이동한다.
///
/// [로그인 게이트 — Task 3] `createMap`은 백엔드에서 인증(`requireUser`)을
/// 요구하므로, 이 화면은 "다음" 제출 시점에 [AuthProvider.isLoggedIn]을
/// 먼저 확인한다. 비로그인이면 그 시점에 입력된 값을 [GuinjiMapEntryDraft]로
/// [PendingGuinjiMapEntryStore]에 저장하고 `/login`으로 이동시키며, 로그인
/// 완료 후 `profile_check_screen.dart`가 이 draft를 감지해 이 화면으로
/// 자동 복귀시키면서 입력값을 그대로 복원한다(기존 `/guinji`(온보딩)
/// 네임스페이스의 `PendingGuinjiOnboardingStore`/
/// `replayPendingGuinjiOnboarding` 패턴과 동일한 전략이나, 완전히 별개의
/// 전용 스토어를 사용해 두 네임스페이스가 서로의 재진입 로직을 공유하지
/// 않도록 한다).
///
/// [버그 수정 — 사주 재입력] "회원가입/로그인을 안 하고 내 귀인지도
/// 만들기를 하면 사주를 넣으려고 하고, 클릭 시 로그인/회원가입 페이지로
/// 넘어가고, 로그인이나 회원가입 시 다시 사주를 넣으라고 한다"는 버그
/// 리포트의 원인이 여기 있었다 — 재진입 시 완전히 빈 화면 인스턴스를
/// 새로 만들었기 때문. [initialDraft]를 받아 컨트롤러를 미리 채우는
/// 것으로 해결한다.
class GuinjiInputScreen extends StatefulWidget {
  const GuinjiInputScreen({super.key, this.initialDraft});

  static const routeName = '/guinji-map/new';

  /// 로그인 리다이렉트 전에 저장해 둔 입력값(있으면 복원, 없으면 빈 폼).
  final GuinjiMapEntryDraft? initialDraft;

  @override
  State<GuinjiInputScreen> createState() => _GuinjiInputScreenState();
}

class _GuinjiInputScreenState extends State<GuinjiInputScreen> {
  late final _nicknameController = TextEditingController(
    text: widget.initialDraft?.nickname ?? '',
  );
  late final _yearController = TextEditingController(
    text: widget.initialDraft?.year ?? '',
  );
  late final _monthController = TextEditingController(
    text: widget.initialDraft?.month ?? '',
  );
  late final _dayController = TextEditingController(
    text: widget.initialDraft?.day ?? '',
  );
  late final _hourController = TextEditingController(
    text: widget.initialDraft?.hour ?? '',
  );
  late final _minuteController = TextEditingController(
    text: widget.initialDraft?.minute ?? '',
  );

  late int _calendarIndex = widget.initialDraft?.calendarIndex ?? 0; // 0=양력, 1=음력, 2=음력(윤달)
  late bool _timeUnknown = widget.initialDraft?.timeUnknown ?? false;
  bool _submitting = false;
  String? _formError;

  static const _calendarChips = ['양력', '음력', '음력 (윤달)'];

  @override
  void dispose() {
    _nicknameController.dispose();
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final auth = context.read<AuthProvider>();

    // [로그인 게이트] 비로그인 상태면 지도 생성 API를 호출할 수 없으므로
    // (백엔드 `requireUser`), 재진입 플래그를 저장하고 로그인으로 안내한다.
    // "회원가입 자동 유도 금지" 원칙은 게스트(viral) 참여 플로우에만
    // 적용되며, 이 I 화면은 "지도를 직접 만드는" 호스트 플로우이므로
    // 로그인 요구가 절대 원칙 위반이 아니다.
    if (!auth.isLoggedIn) {
      // [버그 수정 — 사주 재입력] 로그인 화면으로 보내기 전, 지금까지
      // 입력된 값을 그대로 draft로 저장한다. 아직 필드 검증 전이라 값이
      // 비어 있거나 형식이 틀려도 그대로 저장해 두고(재진입 시 복원만
      // 목적이므로 검증은 다시 "다음"을 누를 때 동일하게 수행됨), 사용자가
      // 로그인/회원가입을 마치고 돌아왔을 때 처음부터 다시 입력하지
      // 않도록 한다.
      PendingGuinjiMapEntryStore.save(
        GuinjiMapEntryDraft(
          nickname: _nicknameController.text,
          year: _yearController.text,
          month: _monthController.text,
          day: _dayController.text,
          hour: _hourController.text,
          minute: _minuteController.text,
          calendarIndex: _calendarIndex,
          timeUnknown: _timeUnknown,
        ),
      );
      Navigator.of(context).pushNamed('/login');
      return;
    }

    final name = _nicknameController.text.trim();
    final year = _yearController.text.trim();
    final month = _monthController.text.trim();
    final day = _dayController.text.trim();

    if (name.isEmpty) {
      setState(() => _formError = '별명을 입력해주세요.');
      return;
    }
    final yearNum = int.tryParse(year);
    final monthNum = int.tryParse(month);
    final dayNum = int.tryParse(day);
    if (year.length != 4 || yearNum == null || monthNum == null || dayNum == null) {
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
    final ok = await provider.createMapWithInput(
      name: name,
      isLunar: _calendarIndex != 0,
      birthDate: birthDate,
      birthTime: birthTime,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!ok) {
      setState(() => _formError = provider.error ?? '지도 생성에 실패했습니다. 다시 시도해주세요.');
      return;
    }

    Navigator.of(context).pushNamed('/guinji-map/calc');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDarker,
      body: GuinjiScreenScaffold(
        bgAlignment: const Alignment(0, -0.6),
        bgOpacity: 0.1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GuinjiTopBar(
              breadcrumb: 'I · INPUT',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GuinjiTitleBlock(
                      titleSpans: [
                        TextSpan(text: '당신의\n'),
                        TextSpan(
                          text: '사주',
                          style: TextStyle(color: GuinjiColors.lavender),
                        ),
                        TextSpan(text: '를 알려주세요'),
                      ],
                      subtitle: '오행의 결을 정확히 짚기 위해 필요합니다.',
                    ),
                    GuinjiField(
                      label: '별명',
                      required: true,
                      hint: '최대 24자 · 지도에 표시됩니다',
                      controller: _nicknameController,
                      placeholder: '어떻게 불릴까요',
                      maxLength: 24,
                    ),
                    GuinjiField(
                      label: '생년월일',
                      required: true,
                      child: Row(
                        children: [
                          // [실제 버그 수정 — 사용자 리포트: "생년월일이 왜
                          // 안돼"] 디자인 원본(`Guinji Section.html` 1374줄)은
                          // `flex: 1.4`인데, 예전 구현에서 오타로 `flex: 14`
                          // (10배)가 들어가 있었다. `Expanded.flex`는 정수만
                          // 허용하므로 1.4 : 1 : 1 비율을 정수로 스케일링한
                          // 7 : 5 : 5로 재현한다. 기존 flex:14 상태에서는
                          // "연도" 칸이 전체 폭의 87%를 차지해 "월"/"일" 칸이
                          // 손톱만큼만 남아 실제 기기에서 거의 탭이 되지
                          // 않았다 — 이것이 "생년월일 입력이 안 된다"는
                          // 체감의 실제 원인이었다.
                          Expanded(
                            flex: 7,
                            child: GuinjiInputBox(
                              controller: _yearController,
                              placeholder: '1998',
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 5,
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
                            flex: 5,
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
                    const SizedBox(height: 8),
                    GuinjiToggle(
                      label: '태어난 시간을 몰라요',
                      description: '3기둥으로 계산 (정확도 다소 낮아짐)',
                      value: _timeUnknown,
                      onChanged: (v) => setState(() => _timeUnknown = v),
                    ),
                    if (_formError != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _formError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: GuinjiFonts.body,
                          fontSize: 12,
                          color: Color(0xFFF5A8BD),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            GuinjiPrimaryButton(
              label: '다음',
              loading: _submitting,
              onPressed: _submitting ? null : _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
