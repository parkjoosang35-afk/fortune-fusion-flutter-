import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_navigator_key.dart';
import '../../auth/application/auth_provider.dart';
import '../../guinji/domain/pending_guinji_join.dart';
import '../application/guinji_provider.dart';
import '../character/guinji_character.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_widgets.dart';

/// [2026 디자인 핸드오프 — `/guinji-map/*`] 로그인 완료 후 저장된
/// "I(Input) 화면 재진입" 요청이 있으면, 원래 열려던
/// [GuinjiInputScreen]으로 자동 복귀시킨다.
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

/// I · Input — `/guinji-map/new` — "02 정보입력"(§05-1).
///
/// [2026 디자인 핸드오프] 검정 테마 전면 재작성 + 캐릭터 미리보기 +
/// 성별(신규) 입력 추가. "나의 정보" · 캐릭터 미리보기("{별명}님의
/// 캐릭터 / {연령대} {성별} · 지도 가운데에 표시돼요", 입력이 바뀌면
/// 즉시 교체) · 별명 · 성별 · 생년월일 · 양력/음력/음력(윤달) · 태어난
/// 시간 + "시간 모름" 토글 · CTA "지도 만들기".
///
/// [로그인 게이트] `createMap`은 백엔드에서 인증(`requireUser`)을
/// 요구하므로, "다음" 제출 시점에 [AuthProvider.isLoggedIn]을 먼저
/// 확인한다. 비로그인이면 입력값을 [GuinjiMapEntryDraft]로
/// [PendingGuinjiMapEntryStore]에 저장하고 `/login`으로 이동시키며,
/// 로그인 완료 후 [replayPendingGuinjiMapEntry]가 이 화면으로 자동
/// 복귀시키면서 입력값을 그대로 복원한다.
///
/// [성별 필드 — 클라이언트 전용] 성별은 `createMapWithInput`가 호출하는
/// `JeontongReportBuilder`/`RelationJudger` 엔진 입력과 무관하다(엔진은
/// gender를 사용하지 않음 — 기존 `joinMap`과 동일 관례, 엔진 계약 변경
/// 금지 원칙 준수). 이 화면에서는 오직 [GuinjiCharacter.of]의 캐릭터
/// 자동 지정(캐릭터 미리보기 표시용)에만 사용한다.
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

  /// [신규] 성별 — 캐릭터 미리보기 전용(엔진 입력 아님).
  /// [P4-hotfix 2026-10-13] 기본값을 하드코딩 female에서 사용자 프로필
  /// 성별로 시드한다 — 회원가입에서 남자를 골랐는데 지도 입력 화면이 항상
  /// '여성'으로 시작해 캐릭터가 여자로 바뀌어 보이던 버그.
  /// 프로필 성별이 없으면(null) 기존 기본값 female 유지.
  late GuinjiGender _gender = _seedGender();

  GuinjiGender _seedGender() {
    try {
      final g = context.read<AuthProvider>().currentUser?.gender;
      if (g == 'M' || g == 'male') return GuinjiGender.male;
    } catch (_) {}
    return GuinjiGender.female;
  }

  bool _submitting = false;
  String? _formError;

  static const _calendarChips = ['양력', '음력', '음력(윤달)'];

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(_onPreviewInputChanged);
    _yearController.addListener(_onPreviewInputChanged);
  }

  void _onPreviewInputChanged() => setState(() {});

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

  /// 캐릭터 미리보기용 — 입력된 출생연도(없으면 1996)로 임시 [DateTime]을
  /// 만들어 [GuinjiCharacter.of]에 전달한다. 실제 지도 생성 시 전달되는
  /// 사주 입력과는 별개(미리보기 전용, 엔진 비관여).
  GuinjiCharacter get _previewCharacter {
    final yearText = _yearController.text.trim();
    final year = int.tryParse(yearText) ?? 1996;
    final birth = DateTime(year.clamp(1900, DateTime.now().year), 6, 1);
    final stableKey = _nicknameController.text.trim().isEmpty
        ? 'preview'
        : _nicknameController.text.trim();
    return GuinjiCharacter.of(
      birth: birth,
      gender: _gender,
      stableKey: stableKey,
    );
  }

  Future<void> _handleSubmit() async {
    final auth = context.read<AuthProvider>();

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
    // [백지 화면 버그수정 — 사용자 피드백] createMapWithInput 내부의 전통사주
    // 엔진(Phase 1→4)은 수 초간 동기로 도는 무거운 작업이라, 웹(CanvasKit)
    // 에서는 로딩 상태가 그려지기도 전에 메인 스레드가 봉쇄돼 아이보리 백지
    // 화면이 노출됐다. 로딩 프레임을 먼저 제출한 뒤 계산에 들어간다.
    await WidgetsBinding.instance.endOfFrame;

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
    final nickname = _nicknameController.text.trim();
    final previewName = nickname.isEmpty ? '나' : nickname;
    final character = _previewCharacter;

    return Scaffold(
      backgroundColor: GmColors.bg,
      appBar: GmTopBar(back: true, title: '정보 입력', onBack: () => Navigator.of(context).maybePop()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '나의 정보',
              style: TextStyle(
                fontFamily: GmText.display,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: GmColors.fg,
              ),
            ),
            const SizedBox(height: 20),

            // 캐릭터 미리보기
            Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    character.face,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 52,
                      height: 52,
                      color: GmColors.card,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontFamily: GmText.ui,
                        fontSize: 13.5,
                        height: 1.5,
                        color: GmColors.muted,
                      ),
                      children: [
                        TextSpan(
                          text: '$previewName님의 캐릭터\n',
                          style: const TextStyle(
                            color: GmColors.fg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text:
                              '${character.band} ${_gender == GuinjiGender.female ? '여성' : '남성'} · 지도 가운데에 표시돼요',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const GmFieldLabel('별명'),
            const SizedBox(height: 6),
            GmFieldShell(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _nicknameController,
                maxLength: 24,
                style: const TextStyle(fontFamily: GmText.ui, fontSize: 14, color: GmColors.fg),
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
                _GenderSegment(
                  label: '여성',
                  active: _gender == GuinjiGender.female,
                  onTap: () => setState(() => _gender = GuinjiGender.female),
                ),
                const SizedBox(width: 8),
                _GenderSegment(
                  label: '남성',
                  active: _gender == GuinjiGender.male,
                  onTap: () => setState(() => _gender = GuinjiGender.male),
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _calendarChips.length; i++)
                  _CalendarChip(
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
                  child: _NumberBox(
                    controller: _hourController,
                    placeholder: '09',
                    maxLength: 2,
                    enabled: !_timeUnknown,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _NumberBox(
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
                        fontWeight: FontWeight.w500,
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
                  fontSize: 11.5,
                  color: GmColors.muted,
                  height: 1.5,
                ),
              ),
            ],

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
              label: '지도 만들기',
              loading: _submitting,
              onPressed: _submitting ? null : _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderSegment extends StatelessWidget {
  const _GenderSegment({required this.label, required this.active, required this.onTap});

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
            fontWeight: FontWeight.w500,
            color: active ? GmColors.onFg : GmColors.muted,
          ),
        ),
      ),
    );
  }
}

class _NumberBox extends StatelessWidget {
  const _NumberBox({
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
          style: const TextStyle(fontFamily: GmText.ui, fontSize: 14, color: GmColors.fg),
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
        background: active ? GmColors.fg : Colors.transparent,
        foreground: active ? GmColors.onFg : GmColors.muted,
        borderColor: active ? GmColors.fg : GmColors.line,
      ),
    );
  }
}
