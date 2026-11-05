import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/env_config.dart';
import '../../../core/utils/email_validator.dart';
import '../../../core/widgets/app_toast.dart';
import '../../bokju_coupon/presentation/bokju_coupon_resolve_screen.dart';
import '../../guinji/presentation/guinji_input_screen.dart';
import '../../guinji/presentation/guinji_join_screen.dart';
import '../../guinji/presentation/guinji_onboarding_screen.dart';
import '../../intro/presentation/intro_palette.dart';
import '../../intro/presentation/intro_text_styles.dart';
import '../../intro/presentation/onboarding_gate_screen.dart';
import '../../intro/presentation/onboarding_video_screen.dart';
import '../../intro/presentation/widgets/intro_title_text.dart';
import '../../pass/presentation/pass_gate_helper.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../saju_renewal/screens/birth_input_screen.dart';
import '../application/auth_provider.dart';
import 'widgets/auth_checkbox.dart';
import 'widgets/auth_form_field.dart';
import 'widgets/auth_form_header.dart';
import 'widgets/auth_primary_button.dart';

/// 02번 §1.1 "이메일 가입" - 로그인과 분리된 회원가입 화면
/// 03단계 §3.3 SignupProfileStepScreen(1단계: 계정정보) 대응
///
/// [Phase B - 2026 디자인 핸드오프 콘텐츠 반영] 기존 화면은 앱 전역 화이트
/// 테마(AppColors/AppTextField/AppButton)를 그대로 쓰고 있어 인트로
/// 3화면(스플래시/페이저/CTA)과 시각적으로 단절돼 있었다. `screens/
/// 02_SignUp_Login.html` PAGE 1(회원가입)의 정확한 카피·구조·톤(Moonlit
/// Crystal 팔레트)을 1:1로 이식한다.
///
/// [기존 로직 불변 원칙] 컨트롤러/유효성검사/`_submit()`의 AuthProvider·
/// WalletProvider 연동·보상 토스트 처리·네비게이션은 전혀 손대지 않고
/// `build()`(순수 UI)만 교체했다.
///
/// [6-7-4-B-4 전면개정 — 2026-10-29] 사용자가 제공한
/// `신통방통_이용약관_개인정보처리방침_개정판.md`의 "A-1. 가입 화면 동의
/// 항목 재구성" 지시에 따라 기존 2개(이용약관+개인정보) 구조를 4개로
/// 확장했다: [필수] 만14세 이상 / [필수] 이용약관 / [필수] 개인정보처리방침 /
/// [선택] 마케팅·광고성 정보 수신(기본값 해제). 필수 3개 미동의 시 가입
/// 차단, 선택(마케팅)은 미동의해도 가입 가능하다. 이에 맞춰
/// `AuthProvider.signup()`/`AuthRepository.emailSignup()` 시그니처에도
/// `age14Confirmed`/`marketingAgreed` 파라미터를 추가했다.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _isSubmitting = false;
  String? _passwordError;
  // [이메일 회원가입 오류 수정 지시서] `abc`, `abc123`, `abc@` 같은 잘못된
  // 형식을 가입 직전에 선제 차단하고, 비밀번호 확인 필드(_passwordError)와
  // 동일한 인라인 에러 표시 패턴(AuthFormField.errorText)을 그대로 재사용한다.
  String? _emailError;

  // [회원가입·본인 사주정보 통합 흐름 전면 검수 지시서 §4] 이메일 blur 시
  // 중복확인 — README.md "확인하고 있어요… / 사용할 수 있는 이메일이에요 /
  // 이미 가입된 이메일이에요. 로그인해 주세요. / 이메일 형식을 확인해
  // 주세요" 4가지 상태를 그대로 구현한다. `_emailError`(danger 톤, 제출
  // 차단용)와는 별개로 `_emailCheckMessage`/`_emailAvailable`로 상태를
  // 보관해 success(민트) 톤도 표시할 수 있게 한다.
  final _emailFocusNode = FocusNode();
  Timer? _emailCheckDebounce;
  bool _emailChecking = false;
  String? _emailCheckMessage;
  bool? _emailAvailable;
  // blur 체크가 끝난 이메일 값을 기억해, 그 값을 그대로 제출할 때는
  // 네트워크 재확인 없이 바로 통과시킨다(제출 시 서버가 최종 검증하므로
  // 중복 호출일 뿐, 막을 필요는 없다).
  String? _lastCheckedEmail;

  // [6-7-4-B-4] 이용약관/개인정보처리방침 동의는 회원가입의 필수 요건이다.
  // 개별 동의 항목 + "전체 동의"를 함께 제공한다.
  bool _termsAgreed = false;
  bool _privacyAgreed = false;
  // [6-7-4-B-4 전면개정] 만14세 확인은 필수, 마케팅 수신동의는 선택(기본값 false).
  bool _age14Confirmed = false;
  bool _marketingAgreed = false;

  bool get _allRequiredAgreed =>
      _age14Confirmed && _termsAgreed && _privacyAgreed;
  bool get _allAgreed => _allRequiredAgreed && _marketingAgreed;

  void _setAllAgreed(bool value) {
    setState(() {
      _age14Confirmed = value;
      _termsAgreed = value;
      _privacyAgreed = value;
      _marketingAgreed = value;
    });
  }

  Future<void> _openPolicyLink(String path) async {
    final uri = Uri.tryParse('${EnvConfig.adminApiBaseUrl}$path');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void initState() {
    super.initState();
    // [회원가입·본인 사주정보 통합 흐름 전면 검수 지시서 §4] blur 시점
    // 감지 — 포커스를 잃는 순간(hasFocus: true -> false)에만 서버 중복확인을
    // 호출한다. 입력 중(각 키 입력마다) 호출하지 않아 서버 부하를 줄인다.
    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus) {
        _checkEmailAvailability();
      }
    });
    // 이메일 값을 수정하면(마지막으로 확인했던 값과 달라지면) 이전 확인
    // 결과(성공/중복/형식오류 메시지)를 즉시 지운다 — 더 이상 유효하지
    // 않은 결과를 계속 보여주지 않기 위함.
    _emailController.addListener(_handleEmailTextChanged);
  }

  void _handleEmailTextChanged() {
    final email = _emailController.text.trim();
    if (email == _lastCheckedEmail) return;
    if (_emailCheckMessage == null && _emailError == null) return;
    _emailCheckDebounce?.cancel();
    setState(() {
      _emailChecking = false;
      _emailCheckMessage = null;
      _emailAvailable = null;
      _emailError = null;
    });
  }

  @override
  void dispose() {
    _emailCheckDebounce?.cancel();
    _emailController.removeListener(_handleEmailTextChanged);
    _emailFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  /// [§4] 이메일 blur 시 중복확인. 짧은 디바운스(300ms)를 둬서, 포커스가
  /// 아주 빠르게 들어왔다 나가는 경우(예: 탭 이동 중) 불필요한 API 호출을
  /// 한 번 더 줄인다.
  void _checkEmailAvailability() {
    final email = _emailController.text.trim();
    _emailCheckDebounce?.cancel();
    if (email.isEmpty) {
      setState(() {
        _emailCheckMessage = null;
        _emailAvailable = null;
      });
      return;
    }
    // 이미 같은 값으로 확인을 마쳤으면 재호출하지 않는다(화면 안에서 다른
    // 필드를 탭했다가 다시 돌아오는 경우 등).
    if (email == _lastCheckedEmail && _emailCheckMessage != null) return;

    _emailCheckDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      if (!EmailValidator.isValid(email)) {
        setState(() {
          _emailChecking = false;
          _emailAvailable = null;
          _emailCheckMessage = '이메일 형식을 확인해 주세요';
        });
        return;
      }
      setState(() {
        _emailChecking = true;
        _emailCheckMessage = '확인하고 있어요…';
        _emailAvailable = null;
      });
      final result = await context.read<AuthProvider>().checkEmailAvailable(
        email,
      );
      if (!mounted) return;
      _lastCheckedEmail = email;
      if (!result.success) {
        setState(() {
          _emailChecking = false;
          _emailAvailable = null;
          // INVALID_EMAIL 등 서버 메시지를 그대로 보여준다 — 형식 오류는
          // 이미 위에서 클라이언트가 먼저 걸렀으므로, 여기 도달하는 실패는
          // 주로 네트워크 오류다.
          _emailCheckMessage = result.errorMessage ?? '이메일 확인 중 오류가 발생했습니다.';
        });
        return;
      }
      final available = result.data ?? false;
      setState(() {
        _emailChecking = false;
        _emailAvailable = available;
        _emailCheckMessage = available
            ? '사용할 수 있는 이메일이에요'
            : '이미 가입된 이메일이에요. 로그인해 주세요.';
      });
    });
  }

  Future<void> _submit() async {
    if (_nicknameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      AppToast.show(context, '필수 정보를 모두 입력해 주세요.', isError: true);
      return;
    }
    // [이메일 회원가입 오류 수정 지시서] `abc`, `abc123`, `abc@` 등 잘못된
    // 형식은 서버에 보내기 전에 여기서 차단한다. 비밀번호 확인 필드와 동일하게
    // 인라인 에러(AuthFormField.errorText)로 표시하고 토스트는 띄우지 않는다
    // (필드 바로 아래 안내가 더 명확한 기존 UX 패턴을 그대로 따름).
    if (!EmailValidator.isValid(_emailController.text.trim())) {
      setState(() => _emailError = EmailValidator.errorMessage);
      return;
    }
    if (_passwordController.text != _passwordConfirmController.text) {
      setState(() => _passwordError = '비밀번호가 일치하지 않습니다.');
      return;
    }
    if (!_age14Confirmed) {
      AppToast.show(context, '만 14세 이상만 가입할 수 있습니다.', isError: true);
      return;
    }
    if (!_termsAgreed || !_privacyAgreed) {
      AppToast.show(context, '이용약관 및 개인정보처리방침에 동의해 주세요.', isError: true);
      return;
    }
    setState(() {
      _passwordError = null;
      _emailError = null;
      _isSubmitting = true;
    });

    final ok = await context.read<AuthProvider>().signup(
      _emailController.text.trim(),
      _passwordController.text,
      _nicknameController.text.trim(),
      termsAgreed: _termsAgreed,
      privacyAgreed: _privacyAgreed,
      age14Confirmed: _age14Confirmed,
      marketingAgreed: _marketingAgreed,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      // [Phase C - WelcomeRewardModal로 통합] 서버가 회원가입 보상을
      // 지급했으면(amount>0) WalletProvider를 즉시 갱신해 잔액을 최신화한다.
      // 과거에는 여기서 "회원가입 보상 +N 복주머니" 토스트를 함께 띄웠지만,
      // 이제 HomeScreen 진입 시 WelcomeRewardModal(팝업)이 동일한 정보를
      // 더 풍성하게 보여주므로 중복 알림을 제거했다(토스트+팝업 동시 노출 방지).
      final reward = context.read<AuthProvider>().lastSignupReward;
      final rewardAmount = reward?['amount'] as int?;
      if (rewardAmount != null && rewardAmount > 0) {
        await context.read<WalletProvider>().load();
        if (!mounted) return;
      }
      if (!mounted) return;
      // [회원가입 통합 사주정보 — 전면 재도입, 2026-11]
      // 과거(42180cc4, 2026-09-17)에는 "프로필체크 강제 화면"을 완전히
      // 제거하고 사주/운세 첫 이용 시점의 선택적 체크박스로 대체했으나,
      // `design_handoff_review/`(사용자 업로드 디자인 핸드오프) 지시에
      // 따라 "가입 후 한 번만 사주정보를 입력하면 모든 운세 메뉴에서
      // 함께 사용"하는 흐름을 다시 도입한다. 이번에는 전용 화면을 새로
      // 만들지 않고, 기존 `BirthInputScreen`(수정 모드에서 이미
      // 생년월일/시간/음양력/윤달/성별 전체를 다루는 검증된 화면)에
      // `isSignupFlow: true`를 주어 재사용한다 — "기존 패턴과 통합"
      // 원칙(dev-spec.md) 및 "신규 화면을 만들지 말고 기존 화면에
      // 연결" 원칙(README.md)을 모두 지킨다.
      await _goToSajuProfileInput(context);
      if (!mounted) return;
      // 로그인 화면과 동일하게, 회원가입 화면으로 오게 만든 대기 중인
      // 재진입 요청(프리패스/귀인지도 등)이 있으면 함께 재생한다.
      // [궁합지도 영향 분석 — dev-spec.md §5] replayPendingGuinjiMapEntry
      // 등 궁합/귀인지도 재진입 로직은 그대로 유지한다(삭제 금지).
      replayPendingPassRequest();
      replayPendingGuinjiJoin();
      replayPendingGuinjiOnboarding();
      replayPendingGuinjiMapEntry();
      replayPendingSajuEntry();
      replayPendingBokjuCoupon();
    } else {
      AppToast.show(
        context,
        context.read<AuthProvider>().state.errorMessage ?? '회원가입에 실패했습니다.',
        isError: true,
      );
    }
  }

  /// [온보딩 영상 적용 가이드 §4 + 회원가입 통합 사주정보] 회원가입 성공
  /// 직후 호출. 온보딩 영상을 아직 안 봤으면 먼저 보여준 뒤(건너뛰기
  /// 가능), 공통 본인 사주정보 입력 화면(`BirthInputScreen`,
  /// `isSignupFlow: true`)으로 `pushReplacement`한다 — 뒤로가기로 가입
  /// 화면에 되돌아갈 수 없다(가입 자체는 이미 서버에 완료됐으므로).
  ///
  /// [비로그인 결과보기 복귀 지시서 R2와의 관계] 과거에는 이 시점에
  /// pending 결과보기 복귀를 먼저 확인했으나, 이제는 "가입 직후 1회
  /// 사주정보 입력"이 더 우선순위 높은 필수 단계다 — 사주정보 입력을
  /// 마친 뒤(SignupCompleteScreen "홈으로 가기") pending 복귀 로직이
  /// 자연스럽게 다시 확인되도록 홈 이동 지점을 그쪽으로 옮긴다. 결과보기
  /// 복귀 자체를 삭제하지 않는다 — 단지 사주정보 입력 다음으로 순서만
  /// 미뤄진다.
  Future<void> _goToSajuProfileInput(BuildContext context) async {
    bool alreadySeen = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      alreadySeen = prefs.getBool(OnboardingGateScreen.prefsKey) ?? false;
    } catch (_) {
      // 조회 실패 시 기존 동작(곧바로 다음 단계)과 동일하게 안전 폴백.
      alreadySeen = true;
    }
    if (!context.mounted) return;

    if (!alreadySeen) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OnboardingVideoScreen(
            onFinished: () async {
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(OnboardingGateScreen.prefsKey, true);
              } catch (_) {}
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
      );
      if (!context.mounted) return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const BirthInputScreen(isSignupFlow: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // [버그 수정 - 회원가입 화면 하단 거대한 흰 빈 공간]
      // 기존 코드는 `DecoratedBox(그라디언트) > SafeArea > SingleChildScrollView`
      // 순서였다. DecoratedBox는 스스로 크기를 정하지 않고 자식(스크롤
      // 콘텐츠)의 "실제 렌더링 높이"에만 맞춰 그려진다. 이 화면의 폼
      // 콘텐츠(입력 4칸 + 약관 카드 + 버튼)는 화면 전체 높이보다 짧기 때문에,
      // 그라디언트는 콘텐츠 높이까지만 그려지고 그 아래 남는 공간은
      // Scaffold의 기본 배경색인 AppColors.hcBackground(순백색, #FFFFFF)가
      // 그대로 노출되어 "거대한 흰 빈 공간"으로 보였다(로그인 화면은 우연히
      // 콘텐츠가 화면 높이에 가까워 증상이 눈에 덜 띄었을 뿐, 동일한 결함을
      // 갖고 있었다). 해결: Stack + Positioned.fill로 그라디언트 배경을
      // Scaffold body 전체 영역(화면 높이)에 강제로 채우고, 그 위에
      // SafeArea/SingleChildScrollView를 올려 콘텐츠 길이와 무관하게
      // 배경이 항상 화면을 꽉 채우게 한다.
      //
      // [1차 수정 실패 원인 - 추가 수정] `Stack`의 기본 크기 결정 규칙은
      // "포지션 지정 안 된(non-positioned) 자식"의 실제 렌더링 크기를
      // 기준으로 Stack 자체의 크기를 정한다(Positioned.fill 자식은 크기
      // 계산에서 제외됨). 즉 SafeArea/SingleChildScrollView가 화면보다
      // 짧으면 Stack 자체가 그 짧은 높이로 줄어들고, Positioned.fill은
      // 그 "줄어든 Stack" 안에서만 꽉 채울 뿐이라 문제가 그대로 재현됐다.
      // `fit: StackFit.expand`를 지정하면 Stack이 항상 부모(Scaffold body)가
      // 제공하는 최대 크기로 확장되고, 그 안의 모든 자식(포지션 없는
      // SafeArea 포함)도 그 크기에 맞춰 강제로 레이아웃되므로 배경이
      // 콘텐츠 길이와 완전히 무관하게 항상 화면 전체를 채운다.
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
                  AuthFormHeader(
                    eyebrow: 'SIGN UP · N°01',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  // `.title-block`
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 22,
                      left: 2,
                      right: 2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IntroTitleText(
                          '신통방통과 함께\n운명을 탐험해보세요',
                          style: IntroTextStyles.formTitle(),
                          highlight: '운명',
                          highlightColors: const [
                            IntroPalette.gold,
                            IntroPalette.primary,
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '이메일과 비밀번호만 있으면 시작할 수 있어요.',
                          style: IntroTextStyles.formSubtitle(),
                        ),
                      ],
                    ),
                  ),
                  AuthFormField(
                    controller: _nicknameController,
                    label: '이름',
                    required: true,
                    hintText: '사주 풀이에 사용될 이름',
                    hint: '한글 · 영문 이름 (본명 권장)',
                  ),
                  AuthFormField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    label: '이메일',
                    required: true,
                    hintText: 'example@fortunefusion.app',
                    // [§4 이메일 중복확인] blur 직후 확인 메시지가 있으면
                    // 그것을 우선 표시하고, 아직 확인 전이면 기존 기본
                    // 안내 문구('로그인 시 사용됩니다')를 그대로 보여준다.
                    hint: _emailCheckMessage ?? '로그인 시 사용됩니다',
                    hintColor: _emailCheckMessage == null
                        ? null
                        : (_emailAvailable == true
                              ? IntroPalette.success
                              : (_emailChecking ? null : IntroPalette.danger)),
                    keyboardType: TextInputType.emailAddress,
                    // [이메일 회원가입 오류 수정 지시서] 잘못된 형식 제출 시
                    // 비밀번호 확인 필드와 동일한 인라인 에러 표시.
                    errorText: _emailError,
                  ),
                  AuthFormField(
                    controller: _passwordController,
                    label: '비밀번호',
                    required: true,
                    hintText: '8자 이상 입력해 주세요',
                    hint: '영문·숫자·특수문자 중 2가지 이상 조합',
                    obscureText: true,
                  ),
                  AuthFormField(
                    controller: _passwordConfirmController,
                    label: '비밀번호 확인',
                    required: true,
                    hintText: '비밀번호를 다시 입력해 주세요',
                    obscureText: true,
                    errorText: _passwordError,
                  ),
                  const SizedBox(height: 6),
                  _TermsAgreementSection(
                    allAgreed: _allAgreed,
                    age14Confirmed: _age14Confirmed,
                    termsAgreed: _termsAgreed,
                    privacyAgreed: _privacyAgreed,
                    marketingAgreed: _marketingAgreed,
                    onAllChanged: _setAllAgreed,
                    onAge14Changed: (v) => setState(() => _age14Confirmed = v),
                    onTermsChanged: (v) => setState(() => _termsAgreed = v),
                    onPrivacyChanged: (v) => setState(() => _privacyAgreed = v),
                    onMarketingChanged: (v) =>
                        setState(() => _marketingAgreed = v),
                    onOpenTerms: () => _openPolicyLink('/terms'),
                    onOpenPrivacy: () => _openPolicyLink('/privacy-policy'),
                  ),
                  const SizedBox(height: 20),
                  AuthPrimaryButton(
                    label: '회원가입',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                  const SizedBox(height: 14),
                  // `.bottom-link`
                  // [02 회원가입 선택 화면 신설] 핸드오프 flow-main.jsx의
                  // EmailSignup.onLogin()은 "02 선택"이 아니라 바로
                  // "이메일 로그인"(emailLogin)으로 연결된다 — 이메일로
                  // 가입하다가 "로그인"을 누르면 다시 카카오/구글 선택을
                  // 거치지 않고 곧장 이메일 로그인 폼으로 가야 한다.
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.of(
                        context,
                      ).pushReplacementNamed('/login/email'),
                      child: RichText(
                        text: TextSpan(
                          style: IntroTextStyles.bottomLink(),
                          children: [
                            const TextSpan(text: '이미 계정이 있으신가요?'),
                            TextSpan(
                              text: ' 로그인',
                              style: IntroTextStyles.bottomLink(
                                color: IntroPalette.primary,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [6-7-4-B-4] 회원가입 필수 약관 동의 섹션.
/// 전체동의 체크박스 1개 + 이용약관/개인정보처리방침 개별 체크박스 2개로 구성하며,
/// 각 항목의 "보기" 텍스트를 탭하면 admin_web의 공개 페이지(/terms, /privacy-policy)를
/// 외부 브라우저로 연다.
///
/// [Phase B 핸드오프 반영] `.terms` 카드(라벤더 카드 배경 + border) + `.checkbox`
/// (glow 체크) 스타일.
/// [6-7-4-B-4 전면개정] 만14세 확인(필수) + 마케팅 수신동의(선택)를 추가해
/// 4개 항목으로 확장했다.
class _TermsAgreementSection extends StatelessWidget {
  const _TermsAgreementSection({
    required this.allAgreed,
    required this.age14Confirmed,
    required this.termsAgreed,
    required this.privacyAgreed,
    required this.marketingAgreed,
    required this.onAllChanged,
    required this.onAge14Changed,
    required this.onTermsChanged,
    required this.onPrivacyChanged,
    required this.onMarketingChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool allAgreed;
  final bool age14Confirmed;
  final bool termsAgreed;
  final bool privacyAgreed;
  final bool marketingAgreed;
  final ValueChanged<bool> onAllChanged;
  final ValueChanged<bool> onAge14Changed;
  final ValueChanged<bool> onTermsChanged;
  final ValueChanged<bool> onPrivacyChanged;
  final ValueChanged<bool> onMarketingChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: IntroPalette.primaryLight,
        border: Border.all(color: IntroPalette.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _AgreementRow(
            value: allAgreed,
            label: '전체 동의',
            emphasize: true,
            onChanged: onAllChanged,
          ),
          const Divider(height: 20, color: IntroPalette.cardBorder),
          _AgreementRow(
            value: age14Confirmed,
            label: '만 14세 이상입니다',
            requiredMark: true,
            onChanged: onAge14Changed,
          ),
          _AgreementRow(
            value: termsAgreed,
            label: '이용약관 동의',
            requiredMark: true,
            onChanged: onTermsChanged,
            onViewDetail: onOpenTerms,
          ),
          _AgreementRow(
            value: privacyAgreed,
            label: '개인정보 처리방침 동의',
            requiredMark: true,
            onChanged: onPrivacyChanged,
            onViewDetail: onOpenPrivacy,
          ),
          _AgreementRow(
            value: marketingAgreed,
            label: '마케팅·광고성 정보 수신',
            requiredMark: false,
            onChanged: onMarketingChanged,
          ),
        ],
      ),
    );
  }
}

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.value,
    required this.label,
    required this.onChanged,
    this.onViewDetail,
    this.requiredMark = false,
    this.emphasize = false,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onViewDetail;
  final bool requiredMark;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            AuthCheckbox(value: value),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    if (requiredMark)
                      TextSpan(
                        text: '[필수] ',
                        style: IntroTextStyles.termsLabel(
                          color: IntroPalette.primary,
                          fontSize: emphasize ? 13 : 12,
                          weight: FontWeight.w700,
                        ),
                      )
                    else if (!emphasize)
                      // [6-7-4-B-4 전면개정] 선택 항목(마케팅 수신동의)에는
                      // "[선택]" prefix를 붙여 필수 항목과 구분한다.
                      TextSpan(
                        text: '[선택] ',
                        style: IntroTextStyles.termsLabel(
                          color: IntroPalette.textSecondary,
                          fontSize: 12,
                          weight: FontWeight.w700,
                        ),
                      ),
                    TextSpan(
                      text: label,
                      style: IntroTextStyles.termsLabel(
                        fontSize: emphasize ? 13 : 12,
                        weight: emphasize ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onViewDetail != null)
              GestureDetector(
                onTap: onViewDetail,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    '보기',
                    style: IntroTextStyles.termsView().copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: IntroPalette.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
