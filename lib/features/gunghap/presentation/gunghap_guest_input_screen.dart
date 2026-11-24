// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_guest_input_screen.dart
// [귀인지도 궁합지도 개발 지시서 §2③] 게스트 본인 사주정보 입력 화면.
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
//
// [v4 핸드오프 반영 — S14] 00_DEV_MAPPING.md §5 S14 명세·§3-2 표(「웹·
// 비로그인」 분류: 상단 URL 바 · 하단바 없음) 기준으로 시각 레이어를
// 교체했다. 변경 지점:
//   - 하단바(MainBottomNavBar)·GHAppBar 제거 → 상단 잠금 URL 바 +
//     「궁합지도」 로고 + 초대자 소개 배지 + StarMap(두 별)으로 교체.
//   - 동의 박스 문구를 [필수]/[선택] 라벨로 명확히 분리하고, [선택]
//     항목(생년월일 공개)을 신설했다 — 단, 서버 `g/[token]/join`
//     API(gunghap_repository.dart)는 이 선택 동의 필드를 받지 않으므로
//     (요청 바디 스키마 참고) 현재는 클라이언트 전용 안내용 체크박스로만
//     동작한다(서버 계약을 변경하지 않는 "로직 유지" 원칙).
//   - 「귀인지도 앱 설치하기」 보조 버튼, 개인정보 안내 시트(§5 S14,
//     02_DATA_APPENDIX.md §5) 추가.
// 폼 필드 구성·검증·제출 로직([_handleSubmit], [joinAnonymous] 호출)은
// 이번 리디자인에서 전혀 손대지 않았다 — 오직 시각 레이어만 교체했다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/gunghap_provider.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/gh_button.dart';
import '../widgets/gh_error_view.dart';
import '../widgets/gh_screen.dart';
import '../widgets/star_map.dart';
import 'gunghap_calculating_screen.dart';
import 'gunghap_guest_result_screen.dart';
import 'gunghap_result_screen.dart';

/// [S14 명세] 「귀인지도 앱 설치하기」 보조 버튼 타깃.
const _kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.guinjido.app';

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
  // [S14 명세] 「[선택] {초대자} 님에게 내 생년월일 공개」 — 현재 백엔드
  // `POST /g/{token}/join`(gunghap_repository.dart) 요청 바디에는 대응
  // 필드가 없어(요청 스키마 참고) 아직 서버로 전송되지 않는다. UI 동의
  // 문구만 명세대로 우선 노출해 두고, 서버 필드가 추가되면 그대로
  // `joinAnonymous(...)` 호출부에 값을 실어 보내면 된다 — 로직 변경은
  // 이번 작업 범위 밖(시각 레이어만 교체).
  bool _agreeDiscloseBirth = false;
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

  /// [2026-11 궁합 주제 반영 지시서 — Section 3] 초대 링크의 4가지 상태.
  /// 'pending'=응답 대기(정상, 입력폼 표시) / 'completed'=이미 응답 완료
  /// (영구 보존, 재제출 불가) / 'cancelled'=소유자가 중단 / 'expired'=발급
  /// 후 7일 경과(미응답 상태에서만 발생 — completed는 절대 expired로
  /// 전환되지 않음). null=아직 판정 전(로딩 중) 또는 네트워크 오류로
  /// 상태 자체를 알 수 없는 경우(이 경우 [_inviteLoadFailed] 경로 사용).
  String? _inviteStatus;
  String? _resultId;

  Future<void> _loadInvite() async {
    setState(() {
      _loadingInvite = true;
      _inviteLoadFailed = false;
      _inviteStatus = null;
    });
    final provider = context.read<GunghapProvider>();
    final data = await provider.fetchInviteToken(widget.token);
    if (!mounted) return;
    if (data == null) {
      // [2026-11 지시서 — Section 3] 서버가 4xx/410으로 응답한 경우
      // errorCode로 cancelled/expired/not_found를 구분한다. 그 외
      // (네트워크 오류 등)는 기존처럼 일반 오류+재시도 화면을 보여준다.
      final code = provider.errorCode;
      if (code == 'REVOKED') {
        setState(() {
          _loadingInvite = false;
          _inviteStatus = 'cancelled';
        });
        return;
      }
      if (code == 'EXPIRED') {
        setState(() {
          _loadingInvite = false;
          _inviteStatus = 'expired';
        });
        return;
      }
      // [S31 잘못된 링크 — 00_DEV_MAPPING.md §5 598-625줄, 화면매핑표
      // 67줄 "S31 잘못된 링크 | 21 | 공통 에러 | 토큰 무효"] 토큰 자체가
      // 없거나 삭제된 경우(NOT_FOUND)는 재시도해도 결과가 같으므로
      // 네트워크 오류([_inviteLoadFailed])와 구분되는 전용 안내를 보여준다.
      if (code == 'NOT_FOUND') {
        setState(() {
          _loadingInvite = false;
          _inviteLoadFailed = false;
          _inviteStatus = 'invalid';
        });
        return;
      }
      // [긴급 검수 지시 §4] 그 외 실패(네트워크 오류 등)는 빈 입력폼만
      // 보여준 채 방치하지 않고, 전용 오류 화면 + 재시도 버튼을 노출한다.
      setState(() {
        _loadingInvite = false;
        _inviteLoadFailed = true;
      });
      return;
    }
    final status = data['status'] as String?;
    setState(() {
      _ownerName = data['ownerName'] as String?;
      _inviteStatus = status ?? (data['joined'] == true ? 'completed' : 'pending');
      _resultId = data['resultId'] as String?;
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
    // [S15 명세 — 00_DEV_MAPPING.md §5] 제출 직후 공용 "분석 로딩" 화면을
    // 끼워넣는다. `joinAnonymous(...)`가 반환하는 Future는 아직
    // await하지 않고 그대로 [GunghapCalculatingScreen]에 넘겨, 그 화면이
    // 최소 표시 시간(4.3s)을 채운 뒤 [_handleJoinResult]로 결과를 돌려주게
    // 한다 — 기존 `joinAnonymous` 호출 로직·파라미터는 전혀 변경하지
    // 않았다.
    final future = provider.joinAnonymous(
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GunghapCalculatingScreen(
          future: future,
          aName: _ownerName,
          bName: name,
          onResult: _handleJoinResult,
        ),
      ),
    );
  }

  /// [S15] [GunghapCalculatingScreen]이 최소 표시 시간을 채운 뒤 호출하는
  /// 콜백 — 기존 `_handleSubmit`에 있던 성공/실패 분기 로직을 그대로
  /// 옮겨 왔다(로직 변경 없음, 호출 시점만 로딩 화면 뒤로 이동).
  void _handleJoinResult(Map<String, dynamic>? result) {
    final provider = context.read<GunghapProvider>();
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result == null) {
      // 로딩 화면(최상단 라우트)을 닫고 입력 폼으로 돌아간 뒤 오류를 안내한다.
      Navigator.of(context).pop();
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

    // 로딩 화면(최상단 라우트)을 결과 화면으로 교체한다.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GunghapGuestResultScreen(result: result),
      ),
    );
  }

  /// [S26·S27·S28 — 00_DEV_MAPPING.md §5(594-599줄) "초대 링크 상태(웹)"]
  /// completed/cancelled/expired 3가지 "입력폼을 보여줄 수 없는" 상태를
  /// 위한 공용 안내 카드. pending(정상)은 이 메서드를 호출하지 않는다.
  /// 공통 명세: 흐린 StarMap 240(45%) · 제목 21/700 2줄 · 설명 13.5 ·
  /// Footer Primary 1개 · 하단바 없음(이 화면은 애초에 GHScreen에
  /// bottomNav를 전달하지 않으므로 이미 충족).
  Widget _buildStatusCard({
    required String emoji,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        children: [
          Opacity(
            opacity: .45,
            child: SizedBox(
              height: 240,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: StarMap(draw: false, labels: false),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GHText.title(size: 21, color: GHColors.fg).copyWith(height: 1.35),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GHText.ui(size: 13.5, height: 1.6, color: GHColors.gray),
          ),
          if (action != null) ...[const SizedBox(height: 22), action],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // [2026-11 지시서 — Section 3] 4상태 중 입력폼을 보여줄 수 있는 것은
    // 'pending'뿐이다. 나머지 상태는 전용 안내 카드로 대체한다.
    final isBlockedStatus =
        !_loadingInvite &&
        !_inviteLoadFailed &&
        _inviteStatus != null &&
        _inviteStatus != 'pending';

    return GHScreen(
      // [S14 명세 — §3-2] 「웹 · 비로그인」 화면: 하단바 없음, 상단은
      // 자체 URL 바(44, r12, fieldBg)로 대체한다. GHAppBar 대신 child
      // 맨 위에 [_GhUrlBar]를 넣고, 뒤로가기는 OS/브라우저 제스처에
      // 맡긴다(앱 경유 진입 시에는 [_GhUrlBar]에 ← 를 별도로 두지 않고
      // 상단 URL 자물쇠 표시로 통일 — 모든 플랫폼에서 동일한 웹 경험).
      appBar: null,
      footer: isBlockedStatus
          ? null
          : GHButton(
              label: _submitting ? '제출하는 중…' : '나의 정보 입력하고 궁합 확인하기',
              onPressed: (_canSubmit && !_submitting) ? _handleSubmit : null,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GHUrlBar(),
          const SizedBox(height: 18),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return _loadingInvite
          ? const Padding(
              padding: EdgeInsets.only(top: 60),
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
          : _inviteStatus == 'completed'
          ? _buildStatusCard(
              emoji: '✅',
              title: '이미 이어진\n초대장이에요',
              message:
                  (_ownerName != null && _ownerName!.isNotEmpty)
                      ? '$_ownerName님과의 궁합 결과가\n이미 만들어졌어요.'
                      : '이 초대장으로 궁합 결과가\n이미 만들어졌어요.',
              action: _resultId == null
                  ? null
                  : GHButton(
                      label: '결과 다시 보기',
                      expand: false,
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) =>
                                GunghapResultScreen(resultId: _resultId!),
                          ),
                        );
                      },
                    ),
            )
          : _inviteStatus == 'cancelled'
          ? _buildStatusCard(
              emoji: '🚫',
              title: '초대한 분이\n초대장을 거두었어요',
              message:
                  (_ownerName != null && _ownerName!.isNotEmpty)
                      ? '$_ownerName님이 이 링크를 중단했어요.\n새 초대장을 요청해 주세요.'
                      : '초대한 분이 이 링크를 중단했어요.\n새 초대장을 요청해 주세요.',
              action: GHButton(
                label: '나도 궁합 보러 가기',
                expand: false,
                onPressed: () => launchUrl(
                  Uri.parse(_kPlayStoreUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            )
          : _inviteStatus == 'expired'
          ? _buildStatusCard(
              emoji: '⌛',
              title: '초대장의 별빛이\n사라졌어요',
              message:
                  (_ownerName != null && _ownerName!.isNotEmpty)
                      ? '유효기간 7일이 지났어요.\n$_ownerName님에게 새 초대장을 요청해 주세요.'
                      : '유효기간 7일이 지났어요.\n초대한 분에게 새 초대장을 요청해 주세요.',
              action: GHButton(
                label: '나도 궁합 보러 가기',
                expand: false,
                onPressed: () => launchUrl(
                  Uri.parse(_kPlayStoreUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            )
          : _inviteStatus == 'invalid'
          // [S31 잘못된 링크 — 00_DEV_MAPPING.md §5 598-625줄] mono
          // 「ERR·LINK」· 제목「열 수 없는 초대장이에요」· 버튼 1개(→ 홈
          // 이동) · 보조버튼 없음 · ←/하단바 없음(이 화면 자체가 웹
          // 게스트 전용이라 애초에 둘 다 없음 — 명세 요구사항을 이미
          // 충족한다).
          ? GHErrorView(
              topPadding: 56,
              monoLabel: 'ERR · LINK',
              title: '열 수 없는\n초대장이에요',
              message: '링크 주소가 잘렸거나 잘못되었어요.\n초대한 분에게 링크를 다시 요청해 주세요.',
              primaryLabel: '궁합지도 둘러보기',
              onPrimary: () => launchUrl(
                Uri.parse(_kPlayStoreUrl),
                mode: LaunchMode.externalApplication,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // [S14 명세] 「궁합지도」 로고 · 초대자 소개 배지 · 타이틀 ·
                // StarMap(두 별 — 상대는 "?", 나는 아직 비어있는 자리).
                const _GhLogoRow(),
                const SizedBox(height: 18),
                if (_ownerName != null && _ownerName!.isNotEmpty) ...[
                  _GhOwnerBadge(ownerName: _ownerName!),
                  const SizedBox(height: 14),
                ],
                Text(
                  '나와 당신의 궁합이\n궁금하지 않으세요?',
                  style: GHText.display(size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  '초대장을 보낸 사람과의 궁합을 확인해 보세요.\n'
                  '나의 출생 정보를 입력하면 두 사람의 궁합을 확인할 수 있습니다.',
                  style: GHText.ui(size: 13, height: 1.6, color: GHColors.gray),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 170,
                  child: StarMap(
                    aName: _ownerName ?? '초대자',
                    bName: '나',
                    big: false,
                  ),
                ),
                const SizedBox(height: 22),
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

                // [S14 명세] 동의 박스(필수 1 + 선택 2) — 1.5px 테두리,
                // 미동의 제출 시 rose 테두리로 바뀐다. 「[필수]」/「[선택]」
                // 배지로 명확히 구분한다(기존 두 체크박스만 있던 구성에서
                // 명세대로 보정).
                _GhConsentCard(
                  hasError: _formError != null && (!_agreePolicy || !_agreeAge14),
                  children: [
                    _GhConsentRow(
                      value: _agreePolicy,
                      onChanged: (v) => setState(() => _agreePolicy = v),
                      label: '개인정보 수집 · 이용에 동의합니다',
                      badge: '필수',
                      moreLabel: '보기',
                      onMore: _showPrivacySheet,
                    ),
                    const Divider(height: 1, color: GHColors.lineSoft),
                    _GhConsentRow(
                      value: _agreeAge14,
                      onChanged: (v) => setState(() => _agreeAge14 = v),
                      label: '만 14세 이상입니다',
                      badge: '필수',
                    ),
                    const Divider(height: 1, color: GHColors.lineSoft),
                    _GhConsentRow(
                      value: _agreeDiscloseBirth,
                      onChanged: (v) => setState(() => _agreeDiscloseBirth = v),
                      label: (_ownerName != null && _ownerName!.isNotEmpty)
                          ? '$_ownerName님에게 내 생년월일 공개'
                          : '초대한 사람에게 내 생년월일 공개',
                      badge: '선택',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '동의하지 않아도 궁합 결과는 함께 볼 수 있어요. '
                    '입력한 정보는 궁합 결과를 만드는 데만 쓰여요.',
                    style: GHText.ui(size: 12, color: GHColors.gray, height: 1.5),
                  ),
                ),

                if (_formError != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _formError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: GHColors.rose),
                  ),
                ],
                const SizedBox(height: 20),
                // [S14 명세] 「귀인지도 앱 설치하기」 보조 버튼.
                GHButton(
                  label: '귀인지도 앱 설치하기',
                  variant: GHButtonVariant.secondary,
                  onPressed: () => launchUrl(
                    Uri.parse(_kPlayStoreUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
  }

  /// [S14 명세] 동의 체크박스 「보기」 → 개인정보 안내 시트
  /// (`02_DATA_APPENDIX.md` §5: 수집 항목/이용 목적/공개 범위/보관 기간/삭제).
  void _showPrivacySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: GHColors.scrim,
      builder: (_) => _GhPrivacySheet(ownerName: _ownerName),
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
  const _GhConsentCard({required this.children, this.hasError = false});
  final List<Widget> children;
  // [S14 명세] 동의 박스(1.5px, 오류 시 rose) — 필수 동의 누락 상태로
  // 제출 시도했을 때만 테두리를 rose로 바꿔 알려준다.
  final bool hasError;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: GHColors.card,
      borderRadius: BorderRadius.circular(GHRadius.cardSm),
      border: Border.all(
        color: hasError ? GHColors.rose : GHColors.lineSoft,
        width: 1.5,
      ),
    ),
    child: Column(children: children),
  );
}

class _GhConsentRow extends StatelessWidget {
  const _GhConsentRow({
    required this.value,
    required this.onChanged,
    required this.label,
    this.badge,
    this.moreLabel,
    this.onMore,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  // [S14 명세] 「[필수]」 핑크 12% 배경 / 「[선택]」 lineSoft 테두리 배지.
  final String? badge;
  final String? moreLabel;
  final VoidCallback? onMore;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onChanged(!value),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          _GhCheckboxBox(value: value),
          const SizedBox(width: 10),
          if (badge != null) ...[
            _GhBadge(badge!),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(label, style: GHText.ui(size: 13))),
          if (moreLabel != null)
            GestureDetector(
              onTap: onMore,
              child: Text(
                moreLabel!,
                style: GHText.ui(size: 11, color: GHColors.gray).copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: GHColors.gray,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// [S14 명세] 「[필수]」 핑크 12% 배경 · 「[선택]」 lineSoft 테두리 작은 배지.
class _GhBadge extends StatelessWidget {
  const _GhBadge(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final isRequired = label == '필수';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isRequired ? GHColors.accent.withValues(alpha: .12) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isRequired ? null : Border.all(color: GHColors.lineSoft),
      ),
      child: Text(
        label,
        style: GHText.ui(
          size: 10,
          weight: FontWeight.w700,
          color: isRequired ? GHColors.accent : GHColors.gray,
        ),
      ),
    );
  }
}

/// [S14 명세] 「궁합지도」 로고 행(↗ 아이콘 + mono 타이틀).
class _GhLogoRow extends StatelessWidget {
  const _GhLogoRow();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: GHGradients.primary,
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Text('↗', style: TextStyle(color: Colors.white, fontSize: 14)),
      ),
      const SizedBox(width: 8),
      Text(
        '궁합지도',
        style: GHText.ui(size: 14.5, weight: FontWeight.w800, color: GHColors.fg),
      ),
    ],
  );
}

/// [S14 명세] 「{초대자} 님이 보낸 초대장」 핑크 배지.
class _GhOwnerBadge extends StatelessWidget {
  const _GhOwnerBadge({required this.ownerName});
  final String ownerName;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: GHColors.accent.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: ownerName,
            style: GHText.ui(size: 12.5, weight: FontWeight.w800, color: GHColors.accent),
          ),
          TextSpan(
            text: ' 님이 보낸 초대장',
            style: GHText.ui(size: 12.5, weight: FontWeight.w700, color: GHColors.accent),
          ),
        ],
      ),
    ),
  );
}

/// [S14 명세] 개인정보 안내 시트 — `02_DATA_APPENDIX.md` §5 5항목(수집
/// 항목 · 이용 목적 · 공개 범위 · 보관 기간 · 삭제) · Footer 「확인했어요」.
class _GhPrivacySheet extends StatelessWidget {
  const _GhPrivacySheet({this.ownerName});
  final String? ownerName;

  @override
  Widget build(BuildContext context) {
    final name = (ownerName != null && ownerName!.isNotEmpty) ? ownerName! : '초대자';
    final rows = <(String, String)>[
      ('수집 항목', '생년월일 · 양력/음력 · 윤달 여부 · 출생 시간(선택) · 성별 · 닉네임(선택)'),
      ('이용 목적', '$name님과의 궁합 결과 생성'),
      (
        '공개 범위',
        '$name님에게는 궁합 결과만 보여요. 생년월일과 출생 정보는 아래 선택 '
            '동의 시에만 공개돼요.',
      ),
      ('보관 기간', '귀인지도 개인정보 처리방침에 따름 · 확정 후 표기'),
      ('삭제', '결과 화면의 「내 정보 삭제」에서 언제든지 지울 수 있어요'),
    ];
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .8),
        child: Container(
          decoration: BoxDecoration(
            gradient: GHGradients.sheet,
            border: Border.all(color: GHColors.line),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(GHRadius.sheet)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                decoration: BoxDecoration(
                  color: GHColors.gray.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('개인정보 안내', style: GHText.sheetTitle(size: 18)),
                      const SizedBox(height: 16),
                      for (final (label, value) in rows) ...[
                        Text(
                          label,
                          style: GHText.ui(size: 12, weight: FontWeight.w700, color: GHColors.gold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: GHText.ui(size: 13, height: 1.6, color: GHColors.fg),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + MediaQuery.of(context).padding.bottom),
                child: GHButton(
                  label: '확인했어요',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
