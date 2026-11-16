import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env_config.dart';
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
      MaterialPageRoute(builder: (_) => GuinjiInputScreen(initialDraft: draft)),
    );
  });
}

/// H2 · Input — `/guinji-map/new` — [design_handoff_guinji_map_v5]
/// `SPEC.md` §6 "H2 `/guinji-map/new` · `guinji_input_screen.dart`" +
/// `COPY.md` "H2 내 정보 입력" 전면 재작성.
///
/// [v5 핸드오프 전면 교체] 기존 구현에는 SPEC/COPY/QA_CHECKLIST.md가
/// 요구하는 다음 요소가 없었다 — 상단바 `STEP 1/1` 메타, `MY CHARACTER`
/// 캐릭터 카드(금 링 + 글로우 + 금 그라데이션), 각 필드의 `필수` 배지와
/// COPY 그대로의 placeholder/힌트 문구, **약관 박스 전체**(전체 동의 +
/// [필수] 서비스 이용약관 + [필수] 생년월일 정보 수집·이용 + [선택] 새
/// 귀인 알림), CTA 3단계 상태 문구(`cta.missing`/`cta.agree`/`cta.ok`),
/// 하단 고정 CTA(상단 `hair` 선 + `bgBottom`). 이번 작업에서 전부 추가해
/// `QA_CHECKLIST.md` "H2 | 캐릭터 미리보기 즉시 교체 · 성별 필드 · 약관
/// 4줄 · CTA 3단계 문구" 4항목을 모두 충족시킨다.
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

  /// 성별 — 캐릭터 미리보기 전용(엔진 입력 아님).
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

  /// [SPEC §6 H2 "약관 박스"] 전체 동의 + [필수] 서비스 이용약관 +
  /// [필수] 생년월일 정보 수집·이용 + [선택] 새 귀인 알림 받기.
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _agreeNotify = false;

  bool get _allRequiredAgreed => _agreeTerms && _agreePrivacy;
  bool get _allAgreed => _allRequiredAgreed && _agreeNotify;

  void _setAllAgreed(bool value) {
    setState(() {
      _agreeTerms = value;
      _agreePrivacy = value;
      _agreeNotify = value;
    });
  }

  Future<void> _openPolicyLink(String path) async {
    final uri = Uri.tryParse('${EnvConfig.adminApiBaseUrl}$path');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  /// [SPEC §6 H2 "CTA 상태 문구"] 필수값 입력 여부 → 약관 동의 여부 →
  /// 완료 순으로 판정한다. `cta.missing` / `cta.agree` / `cta.ok`
  /// (COPY.md 키 이름 그대로) 세 단계를 그대로 구현한다.
  bool get _requiredFieldsFilled =>
      _nicknameController.text.trim().isNotEmpty &&
      _yearController.text.trim().length == 4 &&
      _monthController.text.trim().isNotEmpty &&
      _dayController.text.trim().isNotEmpty;

  String get _ctaLabel {
    if (!_requiredFieldsFilled) return '정보를 모두 입력해 주세요';
    if (!_allRequiredAgreed) return '필수 약관에 동의해 주세요';
    return '내 귀인지도 만들기';
  }

  bool get _ctaEnabled => _requiredFieldsFilled && _allRequiredAgreed;

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
    if (!mounted) return;

    final provider = context.read<GuinjiProvider>();
    final ok = await provider.createMapWithInput(
      name: name,
      isLunar: _calendarIndex != 0,
      birthDate: birthDate,
      birthTime: birthTime,
      // [성별 캐릭터 버그 수정 — 2026-10-14] 미리보기에서 고른 성별을 지도
      // 생성에도 그대로 전달한다(기존엔 버려져서 지도가 항상 폴백 성별로 생성).
      gender: _gender == GuinjiGender.male ? 'male' : 'female',
      ownerFacePath: _previewCharacter.face,
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
      // [SPEC §6 H2 "상단바 (← · 제목 · `STEP 1/1`)"]
      appBar: const GmTopBar(
        back: true,
        title: '내 정보 입력',
        meta: 'STEP 1/1',
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── [SPEC §6 H2 "캐릭터 카드: 얼굴 62, 금 링 2.5 +
                  // 글로우, 금 그라데이션 배경"] ──
                  _CharacterPreviewCard(
                    character: character,
                    previewName: previewName,
                    gender: _gender,
                  ),
                  const SizedBox(height: 24),

                  _RequiredFieldLabel('이름 (별명)'),
                  const SizedBox(height: 6),
                  GmFieldShell(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: TextField(
                      controller: _nicknameController,
                      maxLength: 24,
                      style: const TextStyle(
                        fontFamily: GmText.ui,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: GmColors.fg,
                      ),
                      // [COPY.md H2 f.name] placeholder `지도에 표시될 이름`
                      decoration: const InputDecoration(
                        isDense: true,
                        counterText: '',
                        hintText: '지도에 표시될 이름',
                        hintStyle: TextStyle(color: GmColors.dim),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _RequiredFieldLabel('성별'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _GenderSegment(
                        label: '여성',
                        active: _gender == GuinjiGender.female,
                        onTap: () =>
                            setState(() => _gender = GuinjiGender.female),
                      ),
                      const SizedBox(width: 8),
                      _GenderSegment(
                        label: '남성',
                        active: _gender == GuinjiGender.male,
                        onTap: () =>
                            setState(() => _gender = GuinjiGender.male),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _RequiredFieldLabel('생년월일'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        // SPEC §6 H2 "생년월일(3칸 1.6:1:1)"
                        flex: 16,
                        child: _NumberBox(
                          controller: _yearController,
                          placeholder: '년',
                          maxLength: 4,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 10,
                        child: _NumberBox(
                          controller: _monthController,
                          placeholder: '월',
                          maxLength: 2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 10,
                        child: _NumberBox(
                          controller: _dayController,
                          placeholder: '일',
                          maxLength: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // [DESIGN_SPEC.md §6-② 필드 표 "달력" 행]
                  const GmFieldLabel('달력'),
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
                          placeholder: '시',
                          maxLength: 2,
                          enabled: !_timeUnknown,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _NumberBox(
                          controller: _minuteController,
                          placeholder: '분',
                          maxLength: 2,
                          enabled: !_timeUnknown,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _timeUnknown = !_timeUnknown),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              GmRadius.input,
                            ),
                            color: _timeUnknown
                                ? GmColors.gold
                                : Colors.transparent,
                            border: Border.all(
                              color: _timeUnknown
                                  ? GmColors.gold
                                  : GmColors.line,
                            ),
                          ),
                          // [COPY.md H2 f.time] 버튼 `모름` (선택 시 `✓ 모름`)
                          child: Text(
                            _timeUnknown ? '✓ 모름' : '모름',
                            style: TextStyle(
                              fontFamily: GmText.ui,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _timeUnknown
                                  ? GmColors.onFg
                                  : GmColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // [COPY.md H2 f.time.hint] — 항상 노출(모름 여부와 무관).
                  const Text(
                    '시간을 몰라도 관계는 볼 수 있어요. 알면 조금 더 정확해져요.',
                    style: TextStyle(
                      fontFamily: GmText.ui,
                      fontWeight: FontWeight.w500,
                      fontSize: 11.5,
                      color: GmColors.muted,
                      height: 1.5,
                    ),
                  ),

                  if (_formError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _formError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: GmColors.danger,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  // ── [SPEC §6 H2 "약관 박스"] ──
                  _AgreementBox(
                    allAgreed: _allAgreed,
                    agreeTerms: _agreeTerms,
                    agreePrivacy: _agreePrivacy,
                    agreeNotify: _agreeNotify,
                    onAllChanged: _setAllAgreed,
                    onTermsChanged: (v) => setState(() => _agreeTerms = v),
                    onPrivacyChanged: (v) => setState(() => _agreePrivacy = v),
                    onNotifyChanged: (v) => setState(() => _agreeNotify = v),
                    onOpenTerms: () => _openPolicyLink('/terms'),
                    onOpenPrivacy: () => _openPolicyLink('/privacy-policy'),
                  ),
                ],
              ),
            ),
          ),

          // ── [SPEC §6 H2 "하단 고정 CTA (상단 `hair` 선, 배경
          // bgBottom)"] ──
          DecoratedBox(
            decoration: const BoxDecoration(
              color: GmColors.bgBottom,
              border: Border(top: BorderSide(color: GmColors.hair)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: GmPrimaryButton(
                  label: _ctaLabel,
                  loading: _submitting,
                  onPressed: (_submitting || !_ctaEnabled)
                      ? null
                      : _handleSubmit,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [SPEC §6 H2 "캐릭터 카드: 얼굴 62, 금 링 2.5 + 글로우, 금 그라데이션
/// 배경"] + [COPY.md H2] `char.meta`="MY CHARACTER" ·
/// `char.title`="{별명}님의 캐릭터" ·
/// `char.sub`="{연령대} {여성/남성} · 성별과 나이에 맞춰 바뀌어요".
class _CharacterPreviewCard extends StatelessWidget {
  const _CharacterPreviewCard({
    required this.character,
    required this.previewName,
    required this.gender,
  });

  final GuinjiCharacter character;
  final String previewName;
  final GuinjiGender gender;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GmRadius.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GmColors.gold.withValues(alpha: 0.16),
            GmColors.card,
          ],
        ),
        border: Border.all(color: GmColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [GmColors.goldTop, GmColors.gold],
              ),
              boxShadow: [
                BoxShadow(
                  color: GmColors.goldShadow,
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                character.face,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: GmColors.card),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GmLabelMini('MY CHARACTER'),
                const SizedBox(height: 4),
                Text(
                  '$previewName님의 캐릭터',
                  style: const TextStyle(
                    fontFamily: GmText.ui,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: GmColors.fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${character.band} ${gender == GuinjiGender.female ? '여성' : '남성'} · 성별과 나이에 맞춰 바뀌어요',
                  style: const TextStyle(
                    fontFamily: GmText.ui,
                    fontWeight: FontWeight.w500,
                    fontSize: 11.5,
                    color: GmColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// [COPY.md H2] `f.name`/`f.gender`/`f.birth` 공통 — 라벨 뒤에 `필수`
/// 배지를 붙인 [GmFieldLabel] 확장형.
class _RequiredFieldLabel extends StatelessWidget {
  const _RequiredFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GmFieldLabel(text),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: GmColors.gold.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(GmRadius.chip),
          ),
          child: const Text(
            '필수',
            style: TextStyle(
              fontFamily: GmText.ui,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: GmColors.gold,
            ),
          ),
        ),
      ],
    );
  }
}

/// ── [SPEC §6 H2 "약관 박스"] + [COPY.md H2 agree.*] ──
/// `전체 동의하기` / `[필수] 서비스 이용약관 · 보기` /
/// `[필수] 생년월일 정보 수집·이용 · 보기` / `[선택] 새 귀인 알림 받기 · 보기`.
class _AgreementBox extends StatelessWidget {
  const _AgreementBox({
    required this.allAgreed,
    required this.agreeTerms,
    required this.agreePrivacy,
    required this.agreeNotify,
    required this.onAllChanged,
    required this.onTermsChanged,
    required this.onPrivacyChanged,
    required this.onNotifyChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool allAgreed;
  final bool agreeTerms;
  final bool agreePrivacy;
  final bool agreeNotify;
  final ValueChanged<bool> onAllChanged;
  final ValueChanged<bool> onTermsChanged;
  final ValueChanged<bool> onPrivacyChanged;
  final ValueChanged<bool> onNotifyChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: GmColors.cardTint,
        border: Border.all(color: GmColors.line),
        borderRadius: BorderRadius.circular(GmRadius.card),
      ),
      child: Column(
        children: [
          GmAgreeRow(
            checked: allAgreed,
            label: '전체 동의하기',
            emphasize: true,
            onChanged: onAllChanged,
          ),
          const Divider(height: 1, color: GmColors.hair),
          GmAgreeRow(
            checked: agreeTerms,
            badge: '[필수]',
            label: '서비스 이용약관',
            onChanged: onTermsChanged,
            onViewDetail: onOpenTerms,
          ),
          GmAgreeRow(
            checked: agreePrivacy,
            badge: '[필수]',
            label: '생년월일 정보 수집·이용',
            onChanged: onPrivacyChanged,
            onViewDetail: onOpenPrivacy,
          ),
          GmAgreeRow(
            checked: agreeNotify,
            badge: '[선택]',
            label: '새 귀인 알림 받기',
            onChanged: onNotifyChanged,
          ),
        ],
      ),
    );
  }
}

class _GenderSegment extends StatelessWidget {
  const _GenderSegment({
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
          color: active ? GmColors.gold : Colors.transparent,
          border: Border.all(color: active ? GmColors.gold : GmColors.line),
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
      opacity: enabled ? 1 : 0.4,
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

class _CalendarChip extends StatelessWidget {
  const _CalendarChip({
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
        background: active ? GmColors.gold : Colors.transparent,
        foreground: active ? GmColors.onFg : GmColors.muted,
        borderColor: active ? GmColors.gold : GmColors.line,
      ),
    );
  }
}
