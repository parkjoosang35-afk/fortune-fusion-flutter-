import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/env_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/luck_pouch_toast.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/auth_provider.dart';

/// 02번 §1.1 "이메일 가입" - 로그인과 분리된 회원가입 화면
/// 03단계 §3.3 SignupProfileStepScreen(1단계: 계정정보) 대응
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
      // [인트로 전면 개편 - SignupRewardHandler] 서버가 회원가입 보상을
      // 지급했으면(amount>0) WalletProvider를 즉시 갱신해 잔액을 최신화하고,
      // "회원가입 보상 +100 복주머니" 토스트를 띄운다. 정책 비활성 등으로
      // signupReward가 null이면 조용히 건너뛴다(가입 자체는 그대로 성공 처리).
      final reward = context.read<AuthProvider>().lastSignupReward;
      final rewardAmount = reward?['amount'] as int?;
      if (rewardAmount != null && rewardAmount > 0) {
        await context.read<WalletProvider>().load();
        if (!mounted) return;
        LuckPouchToastController.instance.showSignupReward(rewardAmount);
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
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '신통방통과 함께\n운명을 탐험해 보세요',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _nicknameController,
                label: '닉네임',
                hintText: '앱에서 사용할 닉네임',
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _emailController,
                label: '이메일',
                hintText: 'example@fortunefusion.app',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _passwordController,
                label: '비밀번호',
                hintText: '8자 이상 입력해 주세요',
                obscureText: true,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _passwordConfirmController,
                label: '비밀번호 확인',
                hintText: '비밀번호를 다시 입력해 주세요',
                obscureText: true,
                errorText: _passwordError,
              ),
              const SizedBox(height: AppSpacing.xl),
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
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: '회원가입',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  '이미 계정이 있으신가요? 로그인',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [6-7-4-B-4] 회원가입 필수 약관 동의 섹션.
/// 전체동의 체크박스 1개 + 이용약관/개인정보처리방침 개별 체크박스 2개로 구성하며,
/// 각 항목의 "보기" 텍스트를 탭하면 admin_web의 공개 페이지(/terms, /privacy-policy)를
/// 외부 브라우저로 연다.
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(AppRadius.buttonSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AgreementRow(
            value: allAgreed,
            label: '전체 동의',
            emphasize: true,
            onChanged: onAllChanged,
          ),
          const Divider(height: AppSpacing.md),
          _AgreementRow(
            value: termsAgreed,
            label: '[필수] 이용약관 동의',
            onChanged: onTermsChanged,
            onViewDetail: onOpenTerms,
          ),
          _AgreementRow(
            value: privacyAgreed,
            label: '[필수] 개인정보처리방침 동의',
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
    this.emphasize = false,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onViewDetail;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (onViewDetail != null)
              TextButton(
                onPressed: onViewDetail,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 32),
                ),
                child: const Text(
                  '보기',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
