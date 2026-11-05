import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/app_toast.dart';
import '../../bokju_coupon/presentation/bokju_coupon_resolve_screen.dart';
import '../../fortune_period/domain/fortune_saju_profile.dart';
import '../../guinji/presentation/guinji_input_screen.dart';
import '../../guinji/presentation/guinji_join_screen.dart';
import '../../guinji/presentation/guinji_onboarding_screen.dart';
import '../../intro/presentation/intro_palette.dart';
import '../../intro/presentation/intro_text_styles.dart';
import '../../intro/presentation/widgets/intro_title_text.dart';
import '../../pass/presentation/pass_gate_helper.dart';
import '../../result_access/presentation/result_access_gate_sheet.dart';
import '../../saju_renewal/screens/birth_input_screen.dart';
import '../application/auth_provider.dart';
import '../data/social_auth_service.dart';
import 'signup_screen.dart';
import 'login_screen.dart';

/// 02 "회원가입 선택" / "로그인 선택" 화면.
///
/// [신통방통 회원가입·본인 사주정보 통합 흐름 — 전면 검수 지시서, 2026-11]
/// `design_handoff_signup_saju_profile/README.md` §02, `dev-spec.md` §2(화면
/// 목록) 및 `design_files/flow-auth.jsx`의 `SignupChoose` 컴포넌트를 기준으로
/// 신규 구현한다.
///
/// [검수에서 발견한 문제 — 이 화면이 이번까지 전혀 존재하지 않았음]
/// 과거 구현(`93338e07`)은 "02_SignUp_Login.html PAGE 1(회원가입)"을
/// 그대로 `signup_screen.dart`의 `build()`로 이식했는데, 실제로 PAGE 1은
/// 이 "02 회원가입 선택"이 아니라 그다음 단계인 "03 이메일 회원가입"
/// (카카오/구글 없이 이름·이메일·비밀번호 폼만 있는 화면)이었다. 그 결과
/// 가입 플로우에 카카오/구글 진입 지점이 아예 없었고(로그인 화면에만
/// "계속하기" 문구로 존재), `/signup`에 진입하면 곧바로 이메일 폼이
/// 떴다. 이 화면을 새로 만들어 `/signup`·`/login` 라우트의 실제 목적지로
/// 삼고, 기존 `/signup`(이메일 폼)·`/login`(이메일 로그인 폼)은
/// `/signup/email`·`/login/email`로 그대로 보존한 채 "이메일" 버튼에서만
/// 연결한다 — 두 화면의 코드/로직은 1바이트도 건드리지 않는다.
///
/// [모드 분기] [isLogin]=false(기본)면 "회원가입 선택", true면 "로그인
/// 선택" — 레이아웃은 동일하고 제목/버튼 문구/하단 링크만 바뀐다
/// (dev-spec.md §2의 "02 로그인 선택"과 README.md "로그인 모드" 동일 구조).
///
/// [맥락 칩] [contextMenuLabel]/[contextMenuGlyph]가 주어지면(운세 메뉴에서
/// 비로그인 상태로 진입한 경우) "[命] 정통사주을(를) 보려면 가입이
/// 필요해요" 형태의 pill을 노출한다. 현재 각 메뉴의 게이트(pass_gate_helper
/// 등)는 아직 메뉴 이름을 이 화면까지 전달하지 않으므로 기본값은 null(칩
/// 미노출)이며, 메뉴별 전달 배선은 향후 별도 작업이다(이번 범위는 카카오/
/// 구글/이메일 3버튼 화면 자체의 존재 여부 수정).
class SignupChoiceScreen extends StatefulWidget {
  const SignupChoiceScreen({
    super.key,
    this.isLogin = false,
    this.contextMenuLabel,
    this.contextMenuGlyph,
  });

  final bool isLogin;
  final String? contextMenuLabel;
  final String? contextMenuGlyph;

  @override
  State<SignupChoiceScreen> createState() => _SignupChoiceScreenState();
}

class _SignupChoiceScreenState extends State<SignupChoiceScreen> {
  bool _isSubmitting = false;
  String? _errorText;

  bool get _isLogin => widget.isLogin;

  /// [로드맵④/⑤ 재사용] `login_screen.dart`의 `_socialLogin()`과 완전히
  /// 동일한 "SDK 로그인 → 서버 토큰 검증 → 사주정보 유무 분기" 로직이다.
  /// 회원가입 선택 화면에서 카카오/구글을 눌러도, 로그인 선택 화면에서
  /// 눌러도(신규/기존 사용자 여부는 서버만 알 수 있으므로) 동일한 한
  /// 엔드포인트(`/social-login`)를 호출하고 그 결과로 분기한다 — 가짜
  /// 성공 처리 금지 원칙 유지.
  Future<void> _socialAuth(String label, String provider) async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      final authResult = provider == 'google'
          ? await SocialAuthService.signInWithGoogle()
          : await SocialAuthService.signInWithKakao();
      if (authResult == null) {
        // 사용자가 인증 창에서 취소함 — 에러 없이 조용히 종료.
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }
      if (!mounted) return;
      final ok = await context.read<AuthProvider>().loginWithSocial(
        authResult.provider,
        authResult.accessToken,
        tokenType: authResult.tokenType,
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (ok) {
        final user = context.read<AuthProvider>().currentUser;
        if (!isFortuneSajuComplete(user)) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const BirthInputScreen(isSignupFlow: true),
            ),
          );
          replayPendingPassRequest();
          replayPendingGuinjiJoin();
          replayPendingGuinjiOnboarding();
          replayPendingGuinjiMapEntry();
          replayPendingBokjuCoupon();
          return;
        }
        final restoredResultAccess = await restorePendingResultAccessAfterLogin(
          context,
        );
        if (!mounted) return;
        if (!restoredResultAccess) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/home', (route) => false);
        }
        replayPendingPassRequest();
        replayPendingGuinjiJoin();
        replayPendingGuinjiOnboarding();
        replayPendingGuinjiMapEntry();
        replayPendingSajuEntry();
        replayPendingBokjuCoupon();
      } else {
        final msg =
            context.read<AuthProvider>().state.errorMessage ??
            '$label ${_isLogin ? '로그인' : '가입'}에 실패했습니다.';
        setState(() => _errorText = msg);
        if (mounted) {
          AppToast.show(context, msg, isError: true);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = '$label ${_isLogin ? '로그인' : '가입'} 중 오류가 발생했습니다.';
      });
      AppToast.show(context, _errorText!, isError: true);
    }
  }

  void _goEmail() {
    if (_isLogin) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SignupScreen()));
    }
  }

  void _switchMode() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SignupChoiceScreen(
          isLogin: !_isLogin,
          contextMenuLabel: widget.contextMenuLabel,
          contextMenuGlyph: widget.contextMenuGlyph,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLogin ? '다시 오셨네요\n로그인해 주세요' : '신통방통과 함께\n운명을 탐험해보세요';
    final highlight = _isLogin ? '로그인' : '운명';
    final desc = _isLogin
        ? '가입하신 방식으로 로그인해 주세요.'
        : '가입 후 한 번만 사주정보를 입력하면\n모든 운세 메뉴에서 함께 사용돼요.';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    IntroPalette.backgroundTop,
                    IntroPalette.backgroundBottom,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // `.sj-topbar` — 뒤로가기 + mono eyebrow 라벨.
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.of(context).maybePop(),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: IntroPalette.primaryLight,
                              border: Border.all(
                                color: IntroPalette.cardBorder,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              size: 18,
                              color: IntroPalette.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _isLogin ? 'LOG IN' : 'SIGN UP · N°01',
                            style: IntroTextStyles.formEyebrow(),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (!_isLogin) ...[
                          const Spacer(),
                          _StepDots(active: 1, total: 3),
                        ],
                      ],
                    ),
                  ),
                  // `.su-hero`
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 30),
                    child: Column(
                      children: [
                        // `.su-seal` — 神 도장.
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: IntroPalette.primary,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: IntroPalette.glowShadow,
                                blurRadius: 30,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            '神',
                            style: TextStyle(
                              fontFamily: IntroTextStyles.title().fontFamily,
                              fontWeight: FontWeight.w800,
                              fontSize: 30,
                              color: IntroPalette.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        IntroTitleText(
                          title,
                          style: IntroTextStyles.title(fontSize: 26),
                          highlight: highlight,
                          highlightColors: const [
                            IntroPalette.gold,
                            IntroPalette.primary,
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          desc,
                          textAlign: TextAlign.center,
                          style: IntroTextStyles.formSubtitle(),
                        ),
                        if (widget.contextMenuLabel != null) ...[
                          const SizedBox(height: 16),
                          _ContextChip(
                            glyph: widget.contextMenuGlyph ?? '✦',
                            label: widget.contextMenuLabel!,
                            isLogin: _isLogin,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // `.su-btns`
                  _SocialChoiceButton(
                    backgroundColor: const Color(0xFFFEE500),
                    foregroundColor: const Color(0xFF191600),
                    iconLabel: 'K',
                    label: _isLogin ? '카카오로 로그인' : '카카오로 시작하기',
                    onTap: _isSubmitting
                        ? null
                        : () => _socialAuth('카카오', 'kakao'),
                  ),
                  const SizedBox(height: 10),
                  _SocialChoiceButton(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1F1F1F),
                    iconLabel: 'G',
                    iconBorder: const Color(0xFFDDDDDD),
                    iconColor: const Color(0xFF4285F4),
                    label: _isLogin ? '구글로 로그인' : '구글로 시작하기',
                    onTap: _isSubmitting
                        ? null
                        : () => _socialAuth('구글', 'google'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Divider(color: IntroPalette.cardBorder),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('또는', style: IntroTextStyles.fieldHint()),
                        ),
                        Expanded(
                          child: Divider(color: IntroPalette.cardBorder),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _goEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IntroPalette.primary,
                        foregroundColor: IntroPalette.onPrimary,
                        elevation: 0,
                        shadowColor: IntroPalette.glowShadow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('✧', style: IntroTextStyles.btnPrimary()),
                          const SizedBox(width: 8),
                          Text(
                            _isLogin ? '이메일로 로그인' : '회원가입',
                            style: IntroTextStyles.btnPrimary(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0x73FFAAAA),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Text(
                        _errorText!,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12.5,
                          height: 1.5,
                          color: Color(0xFFFFD4D4),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  // `.su-foot`
                  Center(
                    child: GestureDetector(
                      onTap: _switchMode,
                      child: RichText(
                        text: TextSpan(
                          style: IntroTextStyles.bottomLink(),
                          children: [
                            TextSpan(
                              text: _isLogin
                                  ? '아직 계정이 없으신가요?'
                                  : '이미 계정이 있으신가요?',
                            ),
                            TextSpan(
                              text: _isLogin ? ' 회원가입' : ' 로그인',
                              style: IntroTextStyles.bottomLink(
                                color: IntroPalette.primary,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_isSubmitting) ...[
                    const SizedBox(height: 18),
                    const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: IntroPalette.primary,
                        ),
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

/// `.su-btn.kakao` / `.su-btn.google` — 좌측 원형 아이콘 뱃지 + 중앙 라벨.
class _SocialChoiceButton extends StatelessWidget {
  const _SocialChoiceButton({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.iconLabel,
    required this.label,
    required this.onTap,
    this.iconBorder,
    this.iconColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final String iconLabel;
  final String label;
  final VoidCallback? onTap;
  final Color? iconBorder;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return SizedBox(
      height: 54,
      child: Material(
        color: disabled
            ? backgroundColor.withValues(alpha: 0.5)
            : backgroundColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 18,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor == null
                        ? foregroundColor
                        : Colors.transparent,
                    border: iconBorder != null
                        ? Border.all(color: iconBorder!)
                        : null,
                  ),
                  child: Text(
                    iconLabel,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: iconColor ?? backgroundColor,
                    ),
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.su-ctx` — 운세 메뉴에서 진입한 경우의 맥락 칩(pill).
class _ContextChip extends StatelessWidget {
  const _ContextChip({
    required this.glyph,
    required this.label,
    required this.isLogin,
  });

  final String glyph;
  final String label;
  final bool isLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
      decoration: BoxDecoration(
        color: IntroPalette.primaryLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: IntroPalette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: IntroPalette.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              glyph,
              style: TextStyle(
                fontFamily: IntroTextStyles.title().fontFamily,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: IntroPalette.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label을(를) 보려면 ${isLogin ? '로그인' : '가입'}이 필요해요',
            style: IntroTextStyles.fieldHint(color: IntroPalette.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// `.sj-step` — 단계 표시(18×3 바 3개, 활성 1개).
class _StepDots extends StatelessWidget {
  const _StepDots({required this.active, required this.total});

  final int active;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final on = i < active;
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
          child: Container(
            width: 18,
            height: 3,
            decoration: BoxDecoration(
              color: on ? IntroPalette.primary : IntroPalette.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
