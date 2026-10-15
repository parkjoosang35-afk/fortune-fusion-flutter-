import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/router/main_bottom_nav_bar.dart';
import '../application/guinji_provider.dart';
import 'guinji_calculating_screen.dart';
import 'guinji_guest_result_screen.dart';
import 'guinji_invitation_letter.dart';
import 'guinji_invitation_story_hero.dart';
import 'guinji_invitation_theme.dart';

/// 게스트 참여+입력 — `/g/:mapToken`
///
/// [design_handoff_guinji_web/Guinji Section.html] `flow-map`(2230~2245줄)
/// 게스트 플로우 스펙: `/g/:mapToken` → 참여 안내·사주 입력 → `/g/:mapToken/calc`
/// (C·Calculating 재사용) → `/g/:mapToken/result`(Y·Guest Result).
///
/// [2026-10 귀인지도 초대장 리디자인 — design_handoff_guiin_invitation.zip]
/// 이 화면은 "심야의 신전(Midnight Temple)" 하이파이 디자인으로 전면
/// 재도색됐다. 이전(2026-09) 리스킨의 아이보리+로즈골드 팔레트
/// (`guinji_map_theme.dart`의 `GmColors`/`GmText`)는 더 이상 사용하지
/// 않으며, 이 화면 전용 토큰(`guinji_invitation_theme.dart`)을 새로 만들어
/// 사용한다. 추가된 구성 요소:
///   - [A] `GuinjiInvitationStoryHero` — 홈 StoryHero의 변형(풀블리드 430,
///     마법진·금가루 레이어, 하단 STORY 버튼)
///   - [B] `GuinjiInvitationLetter` — 한지 두루마리 초대 편지(緣 인장 애니메이션)
/// 데이터 흐름·API 호출·다음 화면 이동 로직([_handleSubmit])은 이번
/// 리디자인에서도 절대 변경하지 않았다 — 오직 시각 레이어만 교체했다.
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
/// [초대자 이름/성별 표시 제약] `GET /guinji/g/{token}`([fetchInvite])는
/// 인증이 필요한 API라 비로그인 게스트가 사전에 초대자 이름·성별을 조회할
/// 수 없다. 초대자 이름은 [joinAnonymous] 응답의 `ownerName` 필드로,
/// 초대한 사람(호스트)의 성별 기반 캐릭터는 같은 응답의 `ownerGender`
/// 필드로 제출 *이후*에만 알 수 있다(백엔드 `join/route.ts`에 `ownerGender`
/// 반환 추가 완료 — `User.gender` 필드를 select에 포함). 따라서:
///  - 이 화면(제출 전)의 편지 카드는 특정 이름 없이 일반화된 문구를 쓴다.
///  - 초대한 사람의 성별 캐릭터(도령/선녀)는 제출 *이후* 화면인
///    Y(Guest Result, [GuinjiGuestResultScreen])에서 `hostGender`로
///    표시한다 — 이 화면에는 호스트 캐릭터 이미지를 넣지 않는다.
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
  final _scrollController = ScrollController();

  int _calendarIndex = 0; // 0=양력, 1=음력
  bool _timeUnknown = false;
  String? _gender; // 'female' | 'male'
  bool _agreePolicy = false;
  bool _agreeAge14 = false;
  bool _submitting = false;
  String? _formError;
  bool _topBarSolid = false;

  static const _calendarChips = ['양력', '음력'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final solid = _scrollController.hasClients &&
        _scrollController.offset > 300;
    if (solid != _topBarSolid) {
      setState(() => _topBarSolid = solid);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
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

    final birthDate = '$year-${month.padLeft(2, '0')}-${day.padLeft(2, '0')}';
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
    // [초대한사람 캐릭터 부여] 백엔드 `join/route.ts`가 반환하는
    // `ownerGender`('male'/'female'/null) — 제출 이후에만 알 수 있어
    // Y(Guest Result) 화면으로 그대로 전달한다.
    final hostGender = result['ownerGender'] as String?;
    final relationKey = result['relationType'] as String? ?? 'CHEON_GWII';
    final score = (result['chemistryScore'] as num?)?.toInt() ?? 0;
    final mapSummary = result['mapSummary'] as Map<String, dynamic>?;
    final mapTotal = (mapSummary?['total'] as num?)?.toInt();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuinjiCalculatingScreen(
          onComplete: () {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => GuinjiGuestResultScreen(
                  hostName: hostName,
                  hostGender: hostGender,
                  relationKey: relationKey,
                  score: score,
                  guestName: name,
                  mapTotal: mapTotal,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showTermsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(GiRadius.sheet),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF24133D), GiColors.bg2],
              ),
              border: Border(
                top: BorderSide(color: Color(0x40F5CF6A)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '개인정보 수집 · 이용 안내',
                  style: TextStyle(
                    fontFamily: GiFonts.display,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: GiColors.fg,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '입력하신 이름(닉네임)·생년월일·태어난 시간·성별은 지도 '
                  '소유자와의 관계를 계산하는 용도로만 사용되며, 지도 '
                  '소유자에게만 결과 형태로 표시돼요. 수집된 정보는 관계 '
                  '계산 목적 외에는 사용되지 않아요.',
                  style: TextStyle(
                    fontFamily: GiFonts.body,
                    fontSize: 13.5,
                    height: 1.6,
                    color: GiColors.muted,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: GiColors.glow,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GiRadius.field),
                      ),
                    ),
                    child: const Text(
                      '확인했어요',
                      style: TextStyle(
                        fontFamily: GiFonts.body,
                        fontWeight: FontWeight.w700,
                        color: GiColors.bg1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty && _agreePolicy && _agreeAge14;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [GiColors.bg1, GiColors.bg2],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: _InvitationBackgroundOverlays()),
            ),
            const Positioned.fill(
              child: IgnorePointer(child: _InvitationStarField()),
            ),
            SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // [A] StoryHero — 풀블리드, 높이 430. 아래 Padding(bottom:-70)
                  // 트릭으로 [B] InvitationLetter가 자연스럽게 70px 겹친다.
                  Padding(
                    padding: const EdgeInsets.only(bottom: -70),
                    child: const GuinjiInvitationStoryHero(),
                  ),
                  // [B] InvitationLetter
                  const GuinjiInvitationLetter(),
                  // [C] SajuForm
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 34, 20, 0),
                    child: _buildSajuForm(),
                  ),
                  // [D] CTA + 보조 링크
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: _buildCta(),
                  ),
                  // [E] 하단 인용구
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 30, 20, 8),
                    child: Text(
                      '"닿을 인연은, 결국 닿게 되어 있어요"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: GiFonts.body,
                        fontSize: 12.5,
                        color: Color(0x66E8DCC8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _InvitationTopBar(
                solid: _topBarSolid,
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MainBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildSajuForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YOUR SAJU · 01',
          style: TextStyle(
            fontFamily: GiFonts.mono,
            fontSize: 10,
            letterSpacing: 10 * 0.32,
            color: Color(0xD9F5CF6A), // glow opacity .85
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '당신의 사주',
          style: TextStyle(
            fontFamily: GiFonts.display,
            fontWeight: FontWeight.w900,
            fontSize: 26,
            letterSpacing: -0.52,
            color: GiColors.fg,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '내 정보를 담으면\n초대한 친구와의 관계가 지도에 채워져요.',
          style: TextStyle(
            fontFamily: GiFonts.body,
            fontSize: 13.5,
            color: GiColors.muted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 22),

        _GiFieldLabel('이름 · 닉네임'),
        const SizedBox(height: 8),
        _GiTextField(
          controller: _nameController,
          hint: '어떻게 불릴까요',
          maxLength: 24,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        const Text(
          '지도 소유자에게만 표시돼요.',
          style: TextStyle(fontSize: 11, color: GiColors.mutedFaint),
        ),
        const SizedBox(height: 20),

        _GiFieldLabel('생년월일'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 15,
              child: _GiNumberUnit(
                controller: _yearController,
                placeholder: '2003',
                maxLength: 4,
                unit: '년',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 10,
              child: _GiNumberUnit(
                controller: _monthController,
                placeholder: '05',
                maxLength: 2,
                unit: '월',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 10,
              child: _GiNumberUnit(
                controller: _dayController,
                placeholder: '14',
                maxLength: 2,
                unit: '일',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _GiFieldLabel('달력'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < _calendarChips.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _GiChip(
                  label: _calendarChips[i],
                  active: _calendarIndex == i,
                  onTap: () => setState(() => _calendarIndex = i),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),

        _GiFieldLabel('태어난 시간'),
        const SizedBox(height: 8),
        AnimatedOpacity(
          opacity: _timeUnknown ? 0.35 : 1.0,
          duration: const Duration(milliseconds: 400),
          child: IgnorePointer(
            ignoring: _timeUnknown,
            child: Row(
              children: [
                Expanded(
                  child: _GiNumberUnit(
                    controller: _hourController,
                    placeholder: '09',
                    maxLength: 2,
                    unit: '시',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GiNumberUnit(
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
        const SizedBox(height: 12),
        _GiInlineCheck(
          value: _timeUnknown,
          onChanged: (v) => setState(() => _timeUnknown = v),
          title: '태어난 시간을 몰라요',
          subtitle: '3기둥으로 계산해요. 정확도가 조금 낮아질 수 있어요.',
        ),
        const SizedBox(height: 20),

        _GiFieldLabel('성별'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _GiChip(
                label: '여성',
                active: _gender == 'female',
                onTap: () => setState(() => _gender = 'female'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GiChip(
                label: '남성',
                active: _gender == 'male',
                onTap: () => setState(() => _gender = 'male'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        _GiConsentCard(
          children: [
            _GiConsentRow(
              value: _agreePolicy,
              onChanged: (v) => setState(() => _agreePolicy = v),
              label: '개인정보 수집 · 이용에 동의합니다',
              moreLabel: '보기',
              onMore: _showTermsSheet,
            ),
            const Divider(height: 1, color: GiColors.line),
            _GiConsentRow(
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
            style: const TextStyle(fontSize: 12, color: Color(0xFFEF7A55)),
          ),
        ],
      ],
    );
  }

  Widget _buildCta() {
    final enabled = _canSubmit && !_submitting;
    return Column(
      children: [
        _GiCtaButton(
          enabled: enabled,
          loading: _submitting,
          label: '관계 확인하기',
          onPressed: enabled ? _handleSubmit : null,
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/guinji-map'),
            child: const Text(
              '나도 내 지도 만들기 →',
              style: TextStyle(
                fontFamily: GiFonts.body,
                fontSize: 13.5,
                color: Color(0xD9F5CF6A),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '입력한 정보는 지도 소유자에게만 공유돼요.\n'
          '상대방의 개인정보는 동의 없이 입력하지 말아 주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            height: 1.5,
            color: GiColors.mutedFaintest,
          ),
        ),
      ],
    );
  }
}

/// 배경 오버레이 — 좌상단 보라빛 / 우하단 인장 빨강빛 radial gradient.
class _InvitationBackgroundOverlays extends StatelessWidget {
  const _InvitationBackgroundOverlays();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -40,
          left: -60,
          child: Container(
            width: 360,
            height: 260,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [GiColors.overlayTopLeft, Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          right: -60,
          child: Container(
            width: 340,
            height: 260,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [GiColors.overlayBottomRight, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 별 점 — 1px 흰 점 6개, 고정 위치.
class _InvitationStarField extends StatelessWidget {
  const _InvitationStarField();

  static const _stars = [
    (0.12, 0.08, 0.7),
    (0.78, 0.05, 0.5),
    (0.40, 0.22, 0.35),
    (0.88, 0.17, 0.5),
    (0.22, 0.30, 0.4),
    (0.64, 0.33, 0.35),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarFieldPainter(_stars), size: Size.infinite);
  }
}

class _StarFieldPainter extends CustomPainter {
  const _StarFieldPainter(this.stars);

  final List<(double, double, double)> stars;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (dx, dy, alpha) in stars) {
      final paint = Paint()..color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(dx * size.width, dy * size.height), 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// [F] TopBar — 투명 → 스크롤 300px 이후 블러 배경.
class _InvitationTopBar extends StatelessWidget {
  const _InvitationTopBar({required this.solid, required this.onBack});

  final bool solid;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: EdgeInsets.only(top: topInset),
      decoration: BoxDecoration(
        color: solid ? const Color(0xB80A0716) : Colors.transparent,
        border: solid
            ? const Border(bottom: BorderSide(color: GiColors.line))
            : null,
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: solid
              ? ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20)
              : ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 16,
                  child: _TopBarBackButton(onTap: onBack),
                ),
                const Text(
                  '귀인지도 참여',
                  style: TextStyle(
                    fontFamily: GiFonts.body,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.3,
                    color: GiColors.fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBarBackButton extends StatelessWidget {
  const _TopBarBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x730A0716),
              shape: BoxShape.circle,
              border: Border.all(color: GiColors.line),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.arrow_back, size: 16, color: GiColors.fg),
          ),
        ),
      ),
    );
  }
}

class _GiFieldLabel extends StatelessWidget {
  const _GiFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '◇ ',
          style: TextStyle(fontSize: 9, color: GiColors.glow),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: GiFonts.ui,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: GiColors.muted,
            letterSpacing: 0.02,
          ),
        ),
      ],
    );
  }
}

class _GiTextField extends StatelessWidget {
  const _GiTextField({
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
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: GiColors.card,
        borderRadius: BorderRadius.circular(GiRadius.field),
        border: Border.all(color: GiColors.line),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        onChanged: onChanged,
        style: const TextStyle(
          fontFamily: GiFonts.ui,
          fontSize: 14.5,
          color: GiColors.fg,
        ),
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          hintText: hint,
          hintStyle: const TextStyle(color: GiColors.mutedFaintest),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _GiNumberUnit extends StatelessWidget {
  const _GiNumberUnit({
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
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: GiColors.card,
        borderRadius: BorderRadius.circular(GiRadius.field),
        border: Border.all(color: GiColors.line),
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
              style: const TextStyle(
                fontFamily: GiFonts.ui,
                fontSize: 14.5,
                color: GiColors.fg,
              ),
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                hintText: placeholder,
                hintStyle: const TextStyle(color: GiColors.mutedFaintest),
                border: InputBorder.none,
              ),
            ),
          ),
          Positioned(
            right: 12,
            child: IgnorePointer(
              child: Text(
                unit,
                style: const TextStyle(fontSize: 11, color: GiColors.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiChip extends StatelessWidget {
  const _GiChip({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0x1FF5CF6A) : GiColors.card,
          borderRadius: BorderRadius.circular(GiRadius.field),
          border: Border.all(
            color: active ? const Color(0x8CF5CF6A) : GiColors.line,
          ),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x30F5CF6A),
                    blurRadius: 18,
                    spreadRadius: -6,
                  ),
                ]
              : null,
        ),
        child: Text(
          active ? '✦ $label' : label,
          style: TextStyle(
            fontFamily: GiFonts.ui,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: active ? GiColors.glow : GiColors.muted,
          ),
        ),
      ),
    );
  }
}

class _GiInlineCheck extends StatelessWidget {
  const _GiInlineCheck({
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GiCheckboxBox(value: value),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: GiColors.muted,
                    height: 1.4,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: GiColors.mutedFaint,
                        height: 1.4,
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
}

class _GiCheckboxBox extends StatelessWidget {
  const _GiCheckboxBox({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: value ? GiColors.glow : GiColors.card,
        borderRadius: BorderRadius.circular(GiRadius.checkbox),
        border: Border.all(
          color: value ? GiColors.glow : const Color(0x47FFEBC8),
        ),
        boxShadow: value
            ? const [BoxShadow(color: Color(0x59F5CF6A), blurRadius: 12)]
            : null,
      ),
      child: value
          ? const Text(
              '✓',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: GiColors.bg1,
                height: 1,
              ),
            )
          : null,
    );
  }
}

class _GiConsentCard extends StatelessWidget {
  const _GiConsentCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GiColors.card,
        borderRadius: BorderRadius.circular(GiRadius.consentCard),
        border: Border.all(color: GiColors.line),
      ),
      child: Column(children: children),
    );
  }
}

class _GiConsentRow extends StatelessWidget {
  const _GiConsentRow({
    required this.value,
    required this.onChanged,
    required this.label,
    this.moreLabel,
    this.onMore,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final String? moreLabel;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            _GiCheckboxBox(value: value),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: GiColors.fg),
              ),
            ),
            if (moreLabel != null)
              GestureDetector(
                onTap: onMore,
                child: Text(
                  moreLabel!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: GiColors.muted,
                    decoration: TextDecoration.underline,
                    decorationColor: GiColors.muted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GiCtaButton extends StatefulWidget {
  const _GiCtaButton({
    required this.enabled,
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final String label;
  final VoidCallback? onPressed;

  @override
  State<_GiCtaButton> createState() => _GiCtaButtonState();
}

class _GiCtaButtonState extends State<_GiCtaButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1.0 : 0.32,
          duration: const Duration(milliseconds: 600),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: GiColors.glow,
              borderRadius: BorderRadius.circular(GiRadius.field),
              boxShadow: widget.enabled
                  ? const [
                      BoxShadow(
                        color: Color(0x59F5CF6A),
                        blurRadius: 24,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: widget.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: GiColors.bg1,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '緣',
                        style: TextStyle(
                          fontFamily: GiFonts.display,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: GiColors.bg1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontFamily: GiFonts.body,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.02,
                          color: GiColors.bg1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
