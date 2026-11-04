// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_direct_input_screen.dart
// [궁합지도 Phase 4 — Flutter 개발 지시서 §2] 직접 궁합 입력 화면.
//
// 로그인 회원이 상대방에게 초대장을 보내지 않고, 상대방 정보를 직접
// 입력해 즉시 궁합 결과를 받는다(`POST /api/public/gunghap/direct`).
//
// [절대 금지] 이 화면은 초대장을 생성하지 않는다 — `GunghapProvider`의
// [GunghapProvider.createDirect]만 호출하며, `createInviteForUser`는
// 어떤 경로로도 호출하지 않는다. 기존 `GunghapInviteScreen`(초대장
// 생성 전용)과는 완전히 독립된 화면이다.
//
// [기존 흐름과의 관계] 홈의 "궁합 시작하기" CTA → `GunghapMajorScreen
// (method:'direct')` → `GunghapSubScreen(method:'direct')`까지는 기존
// 대분류/세부 카테고리 선택 UI를 그대로 재사용하고, 그 다음 단계에서만
// 이 화면으로 분기한다(`method == 'invite'`일 때는 기존
// `GunghapInviteScreen`으로, `method == 'direct'`일 때만 이 화면으로
// 연결 — `gunghap_sub_screen.dart` 분기 참고).
//
// [2026-11 궁합 주제 반영 지시서 — Section 1/2] 카테고리(majorId/subName)는
// 화면 타이틀 안내 문구뿐 아니라 `/direct` API 요청 본문에도 포함된다 —
// 서버가 이 값을 저장해 결과 화면/카카오 공유 메시지가 선택한 주제 1개만
// 노출하도록 필터링한다(과거에는 표시용 컨텍스트로만 쓰이고 요청 본문에는
// 포함되지 않았으나, 이번 지시서로 그 설계를 반대로 뒤집었다).
//
// [입력 UI 재사용] `GunghapGuestInputScreen`(게스트 본인 정보 입력)의
// 생년월일/양력·음력·윤달/출생시간/출생시간모름/성별 입력 패턴을 그대로
// 재사용한다 — 동일한 입력 요구사항(상대방 정보)이므로 새 입력 위젯을
// 발명하지 않는다. 차이점: 동의 체크박스(개인정보/연령) 없음(로그인
// 회원 본인이 입력), 이름 필드는 "별칭"도 허용하는 자유 텍스트.
//
// [멱등성 — requestKey] "궁합 확인하기" 버튼을 누르는 시점에
// [GunghapProvider.newDirectRequestKey]로 새 UUID를 발급받아 로컬 상태
// ([_requestKey])에 보관한다. 같은 버튼 클릭에 대한 네트워크 재시오는
// 이 값을 재사용하고, 제출이 성공하거나 사용자가 폼을 다시 바꿔 처음부터
// 다시 제출하면 값을 버리고 다음 제출 시 새로 발급한다 — "재시도"와
// "의도적 새 조회"를 requestKey 값으로 명확히 구분한다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/router/main_bottom_nav_bar.dart';
import '../../../core/widgets/app_toast.dart';
import '../../auth/application/auth_provider.dart';
import '../application/gunghap_provider.dart';
import '../domain/gunghap_data.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/gh_button.dart';
import '../widgets/gh_screen.dart';
import 'gunghap_result_screen.dart';

class GunghapDirectInputScreen extends StatefulWidget {
  const GunghapDirectInputScreen({super.key, this.majorId, this.subName});

  /// 대분류/세부 카테고리(표시 전용 — API 요청 본문에는 포함되지 않음).
  final String? majorId;
  final String? subName;

  @override
  State<GunghapDirectInputScreen> createState() =>
      _GunghapDirectInputScreenState();
}

class _GunghapDirectInputScreenState extends State<GunghapDirectInputScreen> {
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

  /// [멱등성] 현재 제출 시도에 사용 중인 requestKey. null이면 아직 발급
  /// 전(또는 이전 제출이 끝나 폐기됨) — 다음 제출 시 새로 발급한다.
  String? _requestKey;

  GHMajor? get _major =>
      widget.majorId == null ? null : ghMajorById(widget.majorId);

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
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      Navigator.of(context).pushNamed('/login');
      return;
    }
    final user = auth.currentUser;
    if (user == null) return;

    final name = _nameController.text.trim();
    final year = _yearController.text.trim();
    final month = _monthController.text.trim();
    final day = _dayController.text.trim();

    if (name.isEmpty) {
      setState(() => _formError = '상대방 이름(별칭)을 입력해주세요.');
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
      // [생년월일 유효성] DateTime은 2월 30일 같은 입력도 다음 달로
      // 자동 보정(overflow)해버리므로, 보정 여부를 직접 검사해 "정확히
      // 그 날짜"가 아니면 거부한다.
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
      setState(() => _formError = '상대방의 성별을 선택해주세요.');
      return;
    }

    String? birthTime;
    if (!_timeUnknown && _hourController.text.trim().isNotEmpty) {
      final hh = _hourController.text.trim().padLeft(2, '0');
      final mmRaw = _minuteController.text.trim();
      final mm = mmRaw.isEmpty ? '00' : mmRaw.padLeft(2, '0');
      birthTime = '$hh:$mm';
    }

    // [중복 요청 방지] 이미 제출 중이면 재진입하지 않는다(버튼 비활성화와
    // 이중 방어). requestKey가 아직 없으면(최초 제출) 새로 발급하고,
    // 있으면(동일 폼 재시도) 그대로 재사용한다.
    if (_submitting) return;
    _requestKey ??= context.read<GunghapProvider>().newDirectRequestKey();

    setState(() {
      _submitting = true;
      _formError = null;
    });

    final provider = context.read<GunghapProvider>();
    final result = await provider.createDirect(
      user: user,
      requestKey: _requestKey!,
      partnerName: name,
      partnerBirthDate: birthDate,
      partnerIsLunar: _calendarIndex != 0,
      partnerIsLeapMonth: _calendarIndex == 2,
      partnerBirthTime: birthTime,
      partnerGender: _gender!,
      majorId: widget.majorId,
      subName: widget.subName,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result == null) {
      final isNetworkError = provider.errorCode == 'NETWORK_ERROR';
      // [네트워크 오류 안내] 재시도 시 동일 requestKey를 유지한다(위
      // `_requestKey ??=` 로직이 이미 null이 아니므로 재발급하지 않음) —
      // 사용자가 다시 "궁합 확인하기"를 누르면 같은 요청으로 간주되어
      // 서버가 중복 생성 없이 안전하게 재시도를 처리한다.
      setState(() {
        _formError = isNetworkError
            ? (provider.error ?? '서비스 연결이 원활하지 않습니다.')
            : (provider.error ?? '궁합을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.');
      });
      AppToast.show(
        context,
        isNetworkError
            ? (provider.error ?? '서비스 연결이 원활하지 않습니다.')
            : (provider.error ?? '궁합을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.'),
        isError: true,
        onRetry: _handleSubmit,
      );
      return;
    }

    // [성공] 이 제출 시도는 완전히 끝났으므로 requestKey를 폐기한다 —
    // 사용자가 같은 화면에서 또 "궁합 확인하기"를 누르면(이론상 거의
    // 불가능하지만, 결과 화면으로 이동하기 전 재탭 등) 새 조회로 취급돼
    // 새 requestKey가 발급된다.
    _requestKey = null;

    final resultId = result['resultId'] as String?;
    if (resultId == null) {
      AppToast.show(context, '결과를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.', isError: true);
      return;
    }

    if (!mounted) return;
    // [실제 결과 화면으로 이동] 새로 계산/생성하지 않고, 방금 만든
    // resultId로 기존 `GunghapResultScreen`(소유자 전용 조회)에 진입한다
    // — 이 화면이 다시 `fetchResult(resultId)`를 호출해 데이터를
    // 가져오므로 추가 네트워크 트래픽이 1회 더 발생하지만, 캐시 없이도
    // "소유자 본인 조회" 권한 검증을 동일 경로로 통일할 수 있어
    // 일관성을 지킨다(회귀 위험 최소화 — 새로운 결과 렌더링 로직을
    // 만들지 않는다).
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GunghapResultScreen(resultId: resultId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final major = _major;
    return GHScreen(
      bottomNav: const MainBottomNavBar(currentIndex: 0),
      appBar: GHAppBar(
        title: '직접 입력하기',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      footer: GHButton(
        label: _submitting ? '궁합을 확인하는 중…' : '궁합 확인하기',
        onPressed: (_canSubmit && !_submitting) ? _handleSubmit : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GHSteps(step: 2, total: 3, labels: ['분야', '상대', '분석']),
          GHTitle(
            mono: 'DIRECT · PARTNER INFO',
            title: '상대방 정보를\n직접 입력해요',
            sub: major == null
                ? '초대장 없이 바로 두 사람의 궁합을 확인할 수 있어요.'
                : '${major.name}${widget.subName != null ? ' · ${widget.subName}' : ''}\n'
                      '초대장 없이 바로 두 사람의 궁합을 확인할 수 있어요.',
          ),
          _GhFieldLabel('상대방 이름 · 별칭'),
          const SizedBox(height: 8),
          _GhTextField(
            controller: _nameController,
            hint: '어떻게 불릴까요',
            maxLength: 20,
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

          if (_formError != null) ...[
            const SizedBox(height: 16),
            Text(
              _formError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: GHColors.rose),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: GHColors.lineSoft),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✦', style: TextStyle(fontSize: 13, color: GHColors.gold)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '내 사주 정보로 바로 궁합을 계산해요. 초대장은 발송되지 않아요.',
                    style: GHText.ui(size: 12, height: 1.6, color: GHColors.gray),
                  ),
                ),
              ],
            ),
          ),
          if (!context.read<AuthProvider>().isLoggedIn) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                '직접 궁합 입력은 로그인 후 이용할 수 있어요.',
                style: GHText.ui(size: 12, color: GHColors.gray),
              ),
            ),
          ],
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
