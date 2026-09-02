import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_navigator_key.dart';
import '../../auth/application/auth_provider.dart';
import '../../guinji/domain/pending_guinji_join.dart';
import '../application/guinji_provider.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_widgets.dart';

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
/// [2026-09 새 디자인 리스킨] 시각 구조를 새 디자인 zip
/// `lib/guiindo/screens/input_form_screen.dart`의 아이보리+로즈골드 폼으로
/// 전면 교체했다. 데이터 흐름은 그대로 유지: 별명·생년월일(3분할)·
/// 양음력 칩·태어난 시간(모름 토글)을 입력받아 "다음"을 누르면 실제
/// `POST /guinji/maps`(호스트 지도 생성, [GuinjiProvider.createMapWithInput])를
/// 호출한 뒤 C(Calculating)로 이동한다.
///
/// [로그인 게이트] `createMap`은 백엔드에서 인증(`requireUser`)을 요구하므로,
/// 이 화면은 "다음" 제출 시점에 [AuthProvider.isLoggedIn]을 먼저 확인한다.
/// 비로그인이면 그 시점에 입력된 값을 [GuinjiMapEntryDraft]로
/// [PendingGuinjiMapEntryStore]에 저장하고 `/login`으로 이동시키며, 로그인
/// 완료 후 [replayPendingGuinjiMapEntry]가 이 화면으로 자동 복귀시키면서
/// 입력값을 그대로 복원한다.
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

  late int _calendarIndex =
      widget.initialDraft?.calendarIndex ?? 0; // 0=양력, 1=음력, 2=음력(윤달)
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
    if (!auth.isLoggedIn) {
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
      setState(
        () => _formError = provider.error ?? '지도 생성에 실패했습니다. 다시 시도해주세요.',
      );
      return;
    }

    Navigator.of(context).pushNamed('/guinji-map/calc');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GmColors.bgIvory,
      appBar: GmTopBar(back: true, title: '정보 입력', onBack: () => Navigator.of(context).maybePop()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '내 지도의 시작',
              style: TextStyle(
                fontFamily: GmFonts.serif,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: GmColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '정확한 관계 지도를 위해 정보를 입력해주세요.',
              style: TextStyle(fontSize: 12, color: GmColors.inkSoft),
            ),
            const SizedBox(height: 24),

            const GmFieldLabel('별명'),
            const SizedBox(height: 6),
            GmFieldShell(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _nicknameController,
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
            const SizedBox(height: 12),

            const GmFieldLabel('생년월일'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: 7,
                  child: _NumberBox(controller: _yearController, placeholder: '1998', maxLength: 4),
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

            const GmFieldLabel('양력/음력'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < _calendarChips.length; i++)
                  _CalendarChip(
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
            const SizedBox(height: 12),

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
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 11.5, color: GmColors.inkSoft, height: 1.5),
                        children: [
                          TextSpan(text: '태어난 시간을 몰라요. ', style: TextStyle(color: GmColors.ink, fontWeight: FontWeight.w700)),
                          TextSpan(text: '3기둥으로 계산합니다(정확도 다소 낮아짐).'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_formError != null) ...[
              const SizedBox(height: 8),
              Text(
                _formError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ],

            const SizedBox(height: 24),
            GmPrimaryButton(
              label: '관계 결과 확인하기',
              loading: _submitting,
              onPressed: _submitting ? null : _handleSubmit,
            ),
          ],
        ),
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

class _CalendarChip extends StatelessWidget {
  const _CalendarChip({required this.label, required this.active, required this.onTap});

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
