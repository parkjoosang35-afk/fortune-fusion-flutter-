import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/env_config.dart';
import '../../../core/widgets/app_toast.dart';
import '../../intro/presentation/intro_palette.dart';
import '../../intro/presentation/intro_text_styles.dart';
import '../../intro/presentation/widgets/intro_title_text.dart';
import '../../wallet/application/wallet_provider.dart';
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
/// [약관 항목 수 - 기존 확정사항 우선 적용] 핸드오프 원문은 4개 항목(만
/// 14세 이상/이용약관/개인정보/마케팅)을 그리지만, 이 프로젝트는 이전
/// 세션에서 "약관 2개(이용약관+개인정보) 유지"가 이미 확정된 사항이고
/// `AuthProvider.signup()`도 `termsAgreed`/`privacyAgreed` 2개 파라미터만
/// 받는다. 필드 구조를 함부로 4개로 늘리면 서버 계약(AuthRepository)까지
/// 건드려야 해 이번 Phase B 범위를 벗어난다 — 시각 톤만 핸드오프 스타일로
/// 바꾸고 약관 항목 수는 기존 2개(전체동의 포함 3행)를 유지한다.
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

  // [6-7-4-B-4] 이용약관/개인정보처리방침 동의는 회원가입의 필수 요건이다.
  // 개별 동의 항목 + "전체 동의"를 함께 제공한다.
  bool _termsAgreed = false;
  bool _privacyAgreed = false;

  bool get _allAgreed => _termsAgreed && _privacyAgreed;

  void _setAllAgreed(bool value) {
    setState(() {
      _termsAgreed = value;
      _privacyAgreed = value;
    });
  }

  Future<void> _openPolicyLink(String path) async {
    final uri = Uri.tryParse('${EnvConfig.adminApiBaseUrl}$path');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nicknameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      AppToast.show(context, '필수 정보를 모두 입력해 주세요.', isError: true);
      return;
    }
    if (_passwordController.text != _passwordConfirmController.text) {
      setState(() => _passwordError = '비밀번호가 일치하지 않습니다.');
      return;
    }
    if (!_termsAgreed || !_privacyAgreed) {
      AppToast.show(context, '이용약관 및 개인정보처리방침에 동의해 주세요.', isError: true);
      return;
    }
    setState(() {
      _passwordError = null;
      _isSubmitting = true;
    });

    final ok = await context.read<AuthProvider>().signup(
      _emailController.text.trim(),
      _passwordController.text,
      _nicknameController.text.trim(),
      termsAgreed: _termsAgreed,
      privacyAgreed: _privacyAgreed,
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
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/signup/profile-check', (route) => false);
    } else {
      AppToast.show(
        context,
        context.read<AuthProvider>().state.errorMessage ?? '회원가입에 실패했습니다.',
        isError: true,
      );
    }
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
      body: Stack(
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
                    label: '이메일',
                    required: true,
                    hintText: 'example@fortunefusion.app',
                    hint: '로그인 시 사용됩니다',
                    keyboardType: TextInputType.emailAddress,
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
                    termsAgreed: _termsAgreed,
                    privacyAgreed: _privacyAgreed,
                    onAllChanged: _setAllAgreed,
                    onTermsChanged: (v) => setState(() => _termsAgreed = v),
                    onPrivacyChanged: (v) => setState(() => _privacyAgreed = v),
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
                  Center(
                    child: GestureDetector(
                      onTap: () =>
                          Navigator.of(context).pushReplacementNamed('/login'),
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
/// (glow 체크) 스타일로 재구성. 항목 수(2개)와 콜백 시그니처는 기존 그대로.
class _TermsAgreementSection extends StatelessWidget {
  const _TermsAgreementSection({
    required this.allAgreed,
    required this.termsAgreed,
    required this.privacyAgreed,
    required this.onAllChanged,
    required this.onTermsChanged,
    required this.onPrivacyChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool allAgreed;
  final bool termsAgreed;
  final bool privacyAgreed;
  final ValueChanged<bool> onAllChanged;
  final ValueChanged<bool> onTermsChanged;
  final ValueChanged<bool> onPrivacyChanged;
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
