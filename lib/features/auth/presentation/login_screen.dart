import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/luck_pouch_toast.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../home/domain/jeontong_local_to_server_migration.dart';
import '../../intro/presentation/intro_palette.dart';
import '../../intro/presentation/intro_text_styles.dart';
import '../../intro/presentation/widgets/intro_character.dart';
import '../../intro/presentation/widgets/intro_title_text.dart';
import '../application/auth_provider.dart';
import '../data/social_auth_service.dart';
import 'widgets/auth_checkbox.dart';
import 'widgets/auth_form_field.dart';
import 'widgets/auth_form_header.dart';
import 'widgets/auth_primary_button.dart';

/// 03단계 §3.3 공통/온보딩 - LoginScreen
///
/// [Phase B - 2026 디자인 핸드오프 콘텐츠 반영] `screens/02_SignUp_Login.html`
/// PAGE 2(로그인)의 정확한 카피·구조·톤(Moonlit Crystal 팔레트, 신통도령
/// greeting 히어로)을 1:1로 이식한다.
///
/// [기존 로직 불변 원칙] `_login()`/`_socialLogin()`의 AuthProvider 연동,
/// 로컬→서버 마이그레이션 호출, 첫로그인 보상 토스트, 소셜로그인 501
/// "추후 지원 예정" 처리 로직은 전혀 손대지 않고 `build()`(순수 UI)만
/// 교체했다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  // [Phase B 핸드오프 반영 - UI 전용 상태] 핸드오프 `.checkbox.checked`가
  // 기본 체크 상태인 "로그인 상태 유지" 토글. 서버/리포지토리에 세션
  // 유지기간을 구분하는 파라미터가 없어(항상 `_persistSession` 호출) 이
  // 값은 현재 시각적 표시 전용이다 — 향후 실제 세션 정책이 추가되면 이
  // 상태를 `_login()` 호출에 연결하면 된다.
  bool _rememberMe = true;

  Future<void> _login() async {
    setState(() => _isSubmitting = true);
    final ok = await context.read<AuthProvider>().login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (ok) {
      // [신통방통 2단계 - 로컬 → 서버 1회성 마이그레이션] 로그인이 방금
      // 성공해 로그인 상태가 확정된 시점에도(스플래시의 세션 복원 경로와
      // 별개로 앱을 켜둔 채 로그인만 새로 하는 경우) 동일하게 1회 시도한다.
      // 함수 내부에서 이미 서버 데이터가 있으면 스킵하므로 중복 호출에도
      // 안전하다.
      await migrateLocalJeontongProfileToServer(context.read<AuthProvider>());
      if (!mounted) return;
      // [복주머니 정책표 §3 - 첫로그인10(1회)] signup_screen.dart의
      // SignupRewardHandler와 동일한 패턴: 서버가 첫 로그인 보상을 지급했으면
      // (amount>0) WalletProvider를 갱신하고 전용 토스트를 띄운다. 이미
      // 로그인한 적 있거나 정책 비활성이면 firstLoginReward가 null이라
      // 조용히 건너뛴다(로그인 자체는 그대로 성공 처리).
      final reward = context.read<AuthProvider>().lastFirstLoginReward;
      final rewardAmount = reward?['amount'] as int?;
      if (rewardAmount != null && rewardAmount > 0) {
        await context.read<WalletProvider>().load();
        if (!mounted) return;
        LuckPouchToastController.instance.showFirstLoginReward(rewardAmount);
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/signup/profile-check', (route) => false);
    } else {
      AppToast.show(
        context,
        context.read<AuthProvider>().state.errorMessage ?? '로그인 실패',
        isError: true,
      );
    }
  }

  /// [로드맵④] 카카오/구글 실제 SDK 로그인 연동.
  /// SocialAuthService가 각 사 SDK로 로그인해 액세스 토큰을 받아오고,
  /// 그 토큰을 AuthProvider.loginWithSocial()를 통해 서버(admin_web)로
  /// 전달해 서버가 각 사 API로 다시 검증하는 방식이다(가짜 성공 처리 금지
  /// 원칙 유지 — 클라이언트는 위조된 토큰으로 로그인을 성립시킬 수 없다).
  Future<void> _socialLogin(String label, String provider) async {
    setState(() => _isSubmitting = true);
    try {
      final authResult = provider == 'google'
          ? await SocialAuthService.signInWithGoogle()
          : await SocialAuthService.signInWithKakao();
      if (authResult == null) {
        // 사용자가 로그인 창에서 취소함 — 에러 안내 없이 조용히 종료.
        setState(() => _isSubmitting = false);
        return;
      }
      if (!mounted) return;
      final ok = await context.read<AuthProvider>().loginWithSocial(
        authResult.provider,
        authResult.accessToken,
      );
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      if (ok) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/signup/profile-check', (route) => false);
      } else {
        AppToast.show(
          context,
          context.read<AuthProvider>().state.errorMessage ??
              '$label 로그인에 실패했습니다.',
          isError: true,
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      AppToast.show(context, '$label 로그인 중 오류가 발생했습니다.', isError: true);
    }
  }

  void _forgotPassword() {
    // [기존 소셜로그인과 동일한 정직성 원칙] 비밀번호 재설정 서버 API가
    // 아직 없어 가짜 성공/이동 없이 "추후 지원 예정" 안내만 띄운다.
    AppToast.show(context, '비밀번호 찾기는 추후 지원 예정입니다.');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // [버그 수정 - 회원가입 화면과 동일한 원인] DecoratedBox는 자식(스크롤
      // 콘텐츠)의 실제 높이에만 맞춰 그려지므로, 콘텐츠가 화면보다 짧은
      // 경우(작은 화면/큰 폰트스케일 등) 그 아래로 Scaffold 기본 배경색
      // (흰색)이 노출될 수 있다. Stack + Positioned.fill로 배경을 화면
      // 전체에 강제로 채워 콘텐츠 길이와 무관하게 항상 꽉 차게 한다.
      //
      // [1차 수정 실패 원인 - 추가 수정] Stack은 기본적으로 포지션 없는
      // 자식(SafeArea)의 실제 렌더링 크기에 맞춰 자기 크기를 정하므로,
      // Positioned.fill만으로는 부족했다. `fit: StackFit.expand`를 지정해
      // Stack이 항상 부모(Scaffold body)의 최대 크기로 확장되도록 한다.
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
                    eyebrow: 'SIGN IN · WELCOME BACK',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  // Hero character (doryeong greeting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: IntroCharacter(
                        asset: 'assets/images/home/doryeong/greeting.png',
                        size: 140,
                        haloSize: 160,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // `.title-block` (중앙정렬)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 26),
                    child: Column(
                      children: [
                        IntroTitleText(
                          '다시 오셨네요\n신통도령이 기다리고 있었어요',
                          style: IntroTextStyles.formTitle(),
                          highlight: '신통도령',
                          highlightColors: const [
                            IntroPalette.gold,
                            IntroPalette.primary,
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '이메일과 비밀번호를 입력해주세요.',
                          textAlign: TextAlign.center,
                          style: IntroTextStyles.formSubtitle(),
                        ),
                      ],
                    ),
                  ),
                  AuthFormField(
                    controller: _emailController,
                    label: '이메일',
                    hintText: 'example@fortunefusion.app',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  AuthFormField(
                    controller: _passwordController,
                    label: '비밀번호',
                    hintText: '비밀번호를 입력해주세요',
                    obscureText: true,
                  ),
                  // Remember + forgot
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () =>
                              setState(() => _rememberMe = !_rememberMe),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AuthCheckbox(value: _rememberMe),
                                const SizedBox(width: 8),
                                Text(
                                  '로그인 상태 유지',
                                  style: IntroTextStyles.bottomLink(
                                    color: IntroPalette.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _forgotPassword,
                          child: Text(
                            '비밀번호 찾기',
                            style: IntroTextStyles.bottomLink().copyWith(
                              decoration: TextDecoration.underline,
                              decorationColor: IntroPalette.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  AuthPrimaryButton(
                    label: '로그인',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _login,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: Divider(color: IntroPalette.cardBorder)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('또는', style: IntroTextStyles.fieldHint()),
                      ),
                      Expanded(child: Divider(color: IntroPalette.cardBorder)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // [로드맵④ 완료] 카카오/구글 실제 SDK 연동 완료 - "준비 중"
                  // 라벨 제거.
                  _SocialButton(
                    icon: Icons.chat_bubble_rounded,
                    label: '카카오로 계속하기',
                    onTap: _isSubmitting
                        ? null
                        : () => _socialLogin('카카오', 'kakao'),
                  ),
                  const SizedBox(height: 10),
                  _SocialButton(
                    icon: Icons.g_mobiledata_rounded,
                    label: '구글로 계속하기',
                    onTap: _isSubmitting
                        ? null
                        : () => _socialLogin('구글', 'google'),
                  ),
                  const SizedBox(height: 18),
                  // `.bottom-link`
                  Center(
                    child: GestureDetector(
                      onTap: () =>
                          Navigator.of(context).pushReplacementNamed('/signup'),
                      child: RichText(
                        text: TextSpan(
                          style: IntroTextStyles.bottomLink(),
                          children: [
                            const TextSpan(text: '계정이 없으신가요?'),
                            TextSpan(
                              text: ' 회원가입',
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

/// [Phase B 핸드오프 반영] 소셜 로그인 버튼 — 카드 배경 + 옅은 테두리의
/// outlined 스타일(핸드오프에는 소셜 로그인 UI가 없어 기존 톤을 그대로
/// Moonlit Crystal 팔레트로만 재도색했다).
class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: IntroPalette.primaryLight,
          side: const BorderSide(color: IntroPalette.cardBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 18, color: IntroPalette.textPrimary),
        label: Text(label, style: IntroTextStyles.btnGhost()),
      ),
    );
  }
}
