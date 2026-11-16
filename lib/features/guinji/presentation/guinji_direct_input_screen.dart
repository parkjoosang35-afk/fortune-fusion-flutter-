import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_navigator_key.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/guinji_provider.dart';
import '../domain/guinji_relation_meta.dart';
import '../navigation/guinji_page_route.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_widgets.dart';
import 'guinji_map_relation_detail_screen.dart';
import 'guinji_node_sheet.dart';

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
  const GuinjiDirectInputScreen({super.key, this.initialName});

  static const routeName = '/guinji-map/m/add-direct';

  /// [H4-a → H10 이름 미리 채움] SPEC §6 H4-a footer `cta.2`("생년월일을
  /// 알아요 · 직접 입력")는 빈 자리 슬롯 이름(예: "엄마")을 이름 필드에
  /// 미리 채워서 이 화면으로 이동해야 한다. null이면 기존처럼 빈 칸.
  final String? initialName;

  @override
  State<GuinjiDirectInputScreen> createState() =>
      _GuinjiDirectInputScreenState();
}

class _GuinjiDirectInputScreenState extends State<GuinjiDirectInputScreen> {
  late final _nameController = TextEditingController(
    text: widget.initialName ?? '',
  );
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

    // [SPEC §6 H10 "POST /members/direct → 시트 닫힘 → 토스트 toast.done →
    // 0.9s 뒤 H5 자동 오픈" + COPY.md toast.done "{이름}님이 지도에 떴어요 ·
    // {유형} {점수}"] addMemberDirect() 내부에서 이미 loadMyMap()을 호출해
    // 서버가 createdAt asc로 재조회한 최신 members가 provider.people에
    // 반영돼 있다 — 방금 등록한 멤버는 항상 그 목록의 마지막 원소다.
    final people = provider.people;
    final newPerson = people.isNotEmpty ? people.last : null;
    final toastMessage = newPerson != null
        ? '$name님이 지도에 떴어요 · ${guinjiRelationMetaOf(newPerson.relation).label} ${newPerson.score}'
        : '$name님을 지도에 등록했어요.';

    // [성공] 새 멤버가 반영된 M(내 지도) 화면으로 돌아간다 — 결과는
    // provider.people에 이미 포함돼 있으므로 별도 결과 화면 없이 바로
    // 이전 화면으로 복귀한다.
    AppToast.show(context, toastMessage);
    Navigator.of(context).maybePop();

    // [H5 자동 오픈] 이 화면(바텀시트)은 곧 pop되어 dispose되므로, 0.9초
    // 지연 콜백에서는 이 State의 context 대신 전역 [appNavigatorKey]의
    // 루트 context를 사용한다(M화면의 _handleNodeTap()과 동일한 방식으로
    // showGuinjiNodeSheet를 호출 — 함수 시그니처 변경 없음).
    if (newPerson != null) {
      Future.delayed(const Duration(milliseconds: 900), () {
        final rootContext = appNavigatorKey.currentContext;
        if (rootContext == null) return;
        final meta = guinjiRelationMetaOf(newPerson.relation);
        final ohaengMeta = guinjiOhaengTypes[newPerson.ohaeng];
        showGuinjiNodeSheet(
          context: rootContext,
          name: newPerson.name,
          birthLabel: newPerson.birth,
          relationKey: newPerson.relation,
          score: newPerson.score,
          narratorText:
              '${newPerson.name}님은 ${meta.description}. 곁에 두면 결이 자연스레 풀리는 관계예요.',
          evidenceRows: [
            (
              '오행',
              '${ohaengMeta?.label ?? ''} ${ohaengMeta?.name ?? ''}'.trim(),
            ),
            if (newPerson.note.isNotEmpty) ('판정 근거', newPerson.note),
          ],
          unlocked: newPerson.unlocked,
          onShare: () {
            Navigator.of(rootContext).maybePop();
            Navigator.of(rootContext).pushNamed('/guinji-map/m/share');
          },
          onSeeMore: () {
            Navigator.of(rootContext).maybePop();
            Navigator.of(rootContext).push(
              guinjiPageRoute(
                GuinjiMapRelationDetailScreen(person: newPerson),
              ),
            );
          },
        );
      });
    }
  }

  // [v5 QA 대조 — SPEC §6 H10 "바텀시트" 구성: 제목22+✕ / 서브 / 이름 /
  // 성별 / 생년월일3칸 / 달력3세그 / 안내 / footer Primary] 폼 본문은
  // 기존 위젯을 그대로 재사용하고, 헤더만 GmTopBar(전체화면 바)에서
  // "제목22+✕" 한 줄 + 핸들바로 교체한다. H9(guinji_map_share_screen.dart)
  // 와 동일하게 footer(Primary 버튼)는 하단 고정(바텀시트 바깥 스크롤
  // 영향 없음)으로 분리한다.
  @override
  Widget build(BuildContext context) {
    // [SPEC "바텀시트"] 전체화면 PageRouteBuilder(opaque:true, app_router.dart
    // `_guinjiNamed`)는 그대로 두되, 내부를 투명 Scaffold + 하단 정렬 카드로
    // 그려 시각적으로 바텀시트처럼 보이게 한다 — H9와 동일한 패턴.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.92,
                ),
                decoration: BoxDecoration(
                  color: GmColors.bg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: GmColors.gold.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 14),
                                  decoration: BoxDecoration(
                                    color: GmColors.line,
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      '지인 정보 직접 입력',
                                      style: TextStyle(
                                        fontFamily: GmText.display,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.4,
                                        color: GmColors.fg,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        Navigator.of(context).maybePop(),
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: GmColors.line,
                                        ),
                                        color: const Color(0x800A0716),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        '✕',
                                        style: TextStyle(
                                          color: GmColors.fg,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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
                              _buildFormFields(),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: GmColors.hair)),
                        ),
                        child: GmPrimaryButton(
                          label: _submitting ? '등록하는 중…' : '관계 확인하기',
                          loading: _submitting,
                          onPressed: (_canSubmit && !_submitting)
                              ? _handleSubmit
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
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
