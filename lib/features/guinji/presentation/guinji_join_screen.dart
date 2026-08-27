import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_navigator_key.dart';
import '../../auth/application/auth_provider.dart';
import '../application/guinji_provider.dart';
import '../domain/guinji_relation_meta.dart';
import '../domain/pending_guinji_join.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_bg_atmosphere.dart';
import 'guinji_onboarding_screen.dart';

/// [버그 수정 — 딥링크 비로그인 진입] 로그인 완료 후 저장된 귀인지도 참여
/// 요청(공유 링크 토큰)이 있으면, 원래 열려던 참여 화면([GuinjiJoinScreen])
/// 으로 자동 복귀시킨다.
///
/// `pass_gate_helper.dart`의 `replayPendingPassRequest()`와 동일한 타이밍
/// 전략(홈으로의 스택 교체가 끝난 *다음 프레임*에 전역 [appNavigatorKey]로
/// push)을 따르되, 귀인지도 참여는 결제도 패스 소비도 없는 완전 별개
/// 플로우이므로(절대 원칙: 결제없음) `navigateWithPassGate` 같은 패스 게이트
/// 로직 없이 단순히 [GuinjiJoinScreen]을 push하기만 한다. 저장된 요청이
/// 없으면(=귀인지도와 무관한 일반 로그인) 아무 동작도 하지 않는다.
void replayPendingGuinjiJoin() {
  final token = PendingGuinjiJoinStore.consume();
  if (token == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final navState = appNavigatorKey.currentState;
    if (navState == null) return;
    navState.push(
      MaterialPageRoute(builder: (_) => GuinjiJoinScreen(inviteToken: token)),
    );
  });
}

/// 귀인지도(Guinji Map) — 09. 지인 참여(Guest Join) 화면.
///
/// [귀인지도 실구현] 공유(S8)에서 받은 초대 토큰([inviteToken])으로
/// `GET /guinji/g/{token}`을 호출해 mapId·초대자 이름을 확인한 뒤, 지인이
/// 이름·생년월일을 입력하면 `POST /guinji/maps/{mapId}/members`로 실제 참여
/// 처리한다(RelationJudger 판정 결과를 곧바로 받아 화면에 표시). 어떤
/// 재화 지급(초대자 20P 등)도 이 화면 코드에서는 직접 다루지 않는다
/// (실제 지급은 서버 트랜잭션 내부에서만 발생 — 절대 원칙). "나도 내
/// 지도 만들기" Ghost 버튼은 온보딩(S2) 화면으로 실제 이동한다.
class GuinjiJoinScreen extends StatefulWidget {
  const GuinjiJoinScreen({super.key, this.inviteToken});

  /// 공유 링크의 토큰(초대 랜딩페이지 `/g/{token}`의 마지막 세그먼트). null이면
  /// (라우터 직접 진입 등) 초대 정보를 확인할 수 없어 제출 시 안내만 표시한다.
  final String? inviteToken;

  @override
  State<GuinjiJoinScreen> createState() => _GuinjiJoinScreenState();
}

class _GuinjiJoinScreenState extends State<GuinjiJoinScreen> {
  final _nameController = TextEditingController();
  final _yearController = TextEditingController();
  final _monthController = TextEditingController();
  final _dayController = TextEditingController();
  bool _noTime = false;

  bool _loadingInvite = false;
  bool _inviteInvalid = false;
  // [버그 수정 — 딥링크 비로그인 진입] 카톡 등으로 공유받은 초대 링크를
  // 로그인하지 않은 상태로 열었을 때(가장 흔한 실제 진입 경로) 표시하는
  // 전용 상태. `_inviteInvalid`(NOT_FOUND/EXPIRED)와 분리해, "링크가
  // 잘못됐다"는 오해 대신 정확히 "로그인이 필요하다"는 안내와 로그인
  // 버튼을 보여준다.
  bool _needsLogin = false;
  bool _submitting = false;
  String? _mapId;
  String _ownerName = '지인';

  @override
  void initState() {
    super.initState();
    final token = widget.inviteToken;
    if (token == null) return;

    // 비로그인 상태면 서버 호출(항상 401) 자체를 생략하고 즉시 로그인 유도
    // UI를 보여준다 — 불필요한 왕복 요청을 피하고, 에러 코드 매핑에 의존하지
    // 않는 더 확실한 1차 방어선이다.
    if (!context.read<AuthProvider>().isLoggedIn) {
      _needsLogin = true;
      return;
    }

    _loadingInvite = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<GuinjiProvider>();
      final data = await provider.fetchInvite(token);
      if (!mounted) return;
      setState(() {
        _loadingInvite = false;
        if (data == null) {
          // [2차 방어선] initState 시점엔 로그인 상태였지만 그 사이 세션이
          // 만료되는 등 경합 상황을 대비해, 서버가 실제로 401을 반환한
          // 경우에도 동일하게 로그인 유도 UI로 분기한다.
          if (provider.errorCode == 'UNAUTHORIZED') {
            _needsLogin = true;
          } else {
            _inviteInvalid = true;
          }
        } else {
          _mapId = data['mapId'] as String?;
          _ownerName = data['ownerName'] as String? ?? '지인';
        }
      });
    });
  }

  void _goToLogin() {
    final token = widget.inviteToken;
    if (token != null) {
      // 로그인 완료 후 스플래시가 다시 홈으로 넘어가더라도(splash_screen.dart
      // 콜드 부팅 경로) 이 값을 참조해 원래 참여하려던 딥링크로 자동
      // 복귀시킨다(app_router.dart 딥링크 분기가 그대로 재사용 가능).
      PendingGuinjiJoinStore.save(token);
    }
    Navigator.of(context).pushNamed('/login');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    final year = int.tryParse(_yearController.text.trim());
    final month = int.tryParse(_monthController.text.trim());
    final day = int.tryParse(_dayController.text.trim());

    if (name.isEmpty || year == null || month == null || day == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름과 생년월일을 모두 입력해 주세요.')),
      );
      return;
    }
    if (_mapId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초대 링크 정보를 확인할 수 없습니다. 링크를 다시 확인해 주세요.')),
      );
      return;
    }

    DateTime birthDate;
    try {
      birthDate = DateTime(year, month, day);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('생년월일을 다시 확인해 주세요.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final provider = context.read<GuinjiProvider>();
    final result = await provider.joinMap(
      mapId: _mapId!,
      name: name,
      isLunar: false,
      birthDate: birthDate,
      birthTime: _noTime ? null : null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? '참여에 실패했습니다.')),
      );
      return;
    }

    final relationship = result['relationship'] as Map<String, dynamic>?;
    final relationType = relationship?['relationType'] as String? ?? 'inyeon';
    final chemistryScore =
        (relationship?['chemistryScore'] as num?)?.toInt() ?? 0;
    final meta = guinjiRelationTypes[relationType];

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: GuinjiColors.surfaceCard,
        title: const Text(
          '참여 완료',
          style: TextStyle(
            fontFamily: GuinjiFonts.body,
            color: GuinjiColors.textPrimary,
          ),
        ),
        content: Text(
          meta == null
              ? '관계 판정이 완료되었습니다.'
              : '$_ownerName님과 당신은 ${meta.hanja} ${meta.label}의 결이에요.\n케미 점수 $chemistryScore점',
          style: const TextStyle(
            fontFamily: GuinjiFonts.body,
            color: GuinjiColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: GuinjiBgAtmosphere()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _IconButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: _MonoLabel("INVITE · YOU'RE JOINING"),
                      ),
                    ],
                  ),
                  // [버그 수정 — 딥링크 비로그인 진입] 로그인이 필요한 경우
                  // 초대 정보 카드/입력 폼 전체를 로그인 유도 카드로 대체한다
                  // (참여 폼을 채워도 결국 제출 시점에 401로 실패하는 것보다,
                  // 처음부터 정확한 다음 행동을 안내하는 편이 낫다).
                  if (_needsLogin)
                    Expanded(child: _LoginRequiredCard(onLogin: _goToLogin))
                  else
                    Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Image.asset(
                            'assets/images/home/doryeong/greeting.png',
                            width: 110,
                            height: 110,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: GuinjiColors.surfaceCard,
                              border: Border.all(
                                color: GuinjiColors.surfaceCardBorder,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: _ownerName,
                                    style: const TextStyle(
                                      color: GuinjiColors.lavender,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const TextSpan(text: '님이\n당신을 귀인지도에 초대했어요'),
                                ],
                                style: const TextStyle(
                                  fontFamily: GuinjiFonts.body,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  height: 1.5,
                                  color: GuinjiColors.textPrimary,
                                ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: _MonoLabel('당신의 사주', fontSize: 9),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _JoinFormCard(
                            nameController: _nameController,
                            yearController: _yearController,
                            monthController: _monthController,
                            dayController: _dayController,
                            noTime: _noTime,
                            onNoTimeChanged: (v) => setState(() => _noTime = v),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  // [버그 수정 — 딥링크 비로그인 진입] 로그인 유도 카드가
                  // 이미 안내와 CTA(로그인/회원가입)를 모두 담당하므로,
                  // _needsLogin일 때는 기존 하단 CTA(관계 확인하기/나도 내
                  // 지도 만들기)와 하단 고지 문구를 노출하지 않는다.
                  if (!_needsLogin) ...[
                    if (_loadingInvite)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: GuinjiColors.lavender,
                            ),
                          ),
                        ),
                      )
                    else if (_inviteInvalid)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '초대 링크를 확인할 수 없습니다. 링크가 만료되었거나 잘못되었을 수 있어요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: GuinjiFonts.ui,
                            fontSize: 11,
                            color: GuinjiColors.textSecondary,
                          ),
                        ),
                      ),
                    _PrimaryCta(
                      label: _submitting ? '확인하는 중' : '관계 확인하기',
                      onPressed: _submitting ? () {} : _handleSubmit,
                    ),
                    const SizedBox(height: 6),
                    _GhostCta(
                      label: '나도 내 지도 만들기',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GuinjiOnboardingScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '입력한 정보는 지도 소유자에게만 공유돼요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: GuinjiFonts.ui,
                        fontSize: 10,
                        color: GuinjiColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [버그 수정 — 딥링크 비로그인 진입] 카톡 등으로 공유받은 초대 링크를
/// 비로그인 상태로 열었을 때 보여주는 안내 카드. 기존 프리패스 게이트
/// (`showLoginRequiredSheet`)와 톤은 다르지만 동일한 목적(로그인 유도 후
/// 원래 하려던 동작으로 자동 복귀)을 수행한다 — 이 화면은 바텀시트가 아닌
/// 상시 노출 카드로 구현해, "링크가 잘못됐다"는 오해 없이 다음 행동이
/// 항상 눈에 보이도록 한다.
class _LoginRequiredCard extends StatelessWidget {
  const _LoginRequiredCard({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/home/doryeong/greeting.png',
              width: 96,
              height: 96,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: GuinjiColors.surfaceCard,
                border: Border.all(color: GuinjiColors.surfaceCardBorder),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Text(
                    '로그인하고\n귀인지도에 참여해요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: GuinjiFonts.body,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: GuinjiColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '초대장을 확인하려면 로그인이 필요해요.\n로그인 후 이 초대로 자동으로 돌아와요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: GuinjiFonts.body,
                      fontSize: 12,
                      height: 1.5,
                      color: GuinjiColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PrimaryCta(label: '로그인 / 회원가입', onPressed: onLogin),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuinjiColors.surfaceCard,
      shape: const CircleBorder(
        side: BorderSide(color: GuinjiColors.surfaceCardBorder),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: GuinjiColors.textPrimary),
        ),
      ),
    );
  }
}

class _MonoLabel extends StatelessWidget {
  const _MonoLabel(this.text, {this.fontSize = 10});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: GuinjiFonts.mono,
        fontSize: fontSize,
        letterSpacing: 3.0,
        fontWeight: FontWeight.w500,
        color: GuinjiColors.textSecondary,
      ),
    );
  }
}

/// 입력 폼 카드 — 이름/닉네임 + 생년월일 3칸 + "시간 몰라요" 체크박스.
class _JoinFormCard extends StatelessWidget {
  const _JoinFormCard({
    required this.nameController,
    required this.yearController,
    required this.monthController,
    required this.dayController,
    required this.noTime,
    required this.onNoTimeChanged,
  });

  final TextEditingController nameController;
  final TextEditingController yearController;
  final TextEditingController monthController;
  final TextEditingController dayController;
  final bool noTime;
  final ValueChanged<bool> onNoTimeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GuinjiColors.backgroundDeep.withValues(alpha: 0.75),
        border: Border.all(color: GuinjiColors.surfaceCardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MonoLabel('이름 · 닉네임', fontSize: 8),
          const SizedBox(height: 4),
          _UnderlineTextField(
            controller: nameController,
            hintText: '어떻게 불릴까요',
            textAlign: TextAlign.left,
            fontFamily: GuinjiFonts.body,
          ),
          const SizedBox(height: 12),
          const _MonoLabel('생년월일 · 양력', fontSize: 8),
          const SizedBox(height: 4),
          Row(
            children: [
              SizedBox(
                width: 64,
                child: _UnderlineTextField(
                  controller: yearController,
                  hintText: '2003',
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  fontFamily: GuinjiFonts.mono,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: _UnderlineTextField(
                  controller: monthController,
                  hintText: '05',
                  maxLength: 2,
                  textAlign: TextAlign.center,
                  fontFamily: GuinjiFonts.mono,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: _UnderlineTextField(
                  controller: dayController,
                  hintText: '14',
                  maxLength: 2,
                  textAlign: TextAlign.center,
                  fontFamily: GuinjiFonts.mono,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => onNoTimeChanged(!noTime),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: GuinjiColors.backgroundDeep.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: GuinjiColors.textSecondary,
                          width: 1.5,
                        ),
                        color: noTime
                            ? GuinjiColors.lavender
                            : Colors.transparent,
                      ),
                      child: noTime
                          ? const Icon(
                              Icons.check,
                              size: 13,
                              color: GuinjiColors.ink,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '태어난 시간을 몰라요',
                      style: TextStyle(
                        fontFamily: GuinjiFonts.body,
                        fontSize: 12,
                        color: GuinjiColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 밑줄만 있는 투명 입력창(디자인 스펙의 `borderBottom` 스타일 재현).
class _UnderlineTextField extends StatelessWidget {
  const _UnderlineTextField({
    required this.controller,
    required this.hintText,
    required this.textAlign,
    required this.fontFamily,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hintText;
  final TextAlign textAlign;
  final String fontFamily;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: textAlign,
      maxLength: maxLength,
      keyboardType: maxLength != null
          ? TextInputType.number
          : TextInputType.text,
      style: TextStyle(
        fontFamily: fontFamily,
        fontWeight: maxLength != null ? FontWeight.w500 : FontWeight.w400,
        fontSize: 15,
        letterSpacing: maxLength != null ? 1.5 : 0,
        color: GuinjiColors.textPrimary,
      ),
      cursorColor: GuinjiColors.lavender,
      decoration: InputDecoration(
        hintText: hintText,
        counterText: '',
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          color: GuinjiColors.textSecondary.withValues(alpha: 0.5),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: GuinjiColors.surfaceCardBorder),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: GuinjiColors.lavender),
        ),
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: GuinjiColors.lavender,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: GuinjiColors.glowShadow,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '✧ ',
                  style: TextStyle(fontSize: 15, color: GuinjiColors.ink),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: GuinjiFonts.body,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: GuinjiColors.ink,
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

class _GhostCta extends StatelessWidget {
  const _GhostCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: GuinjiColors.surfaceCardBorder),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: GuinjiFonts.ui,
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: GuinjiColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
