import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    setState(() {
      _passwordError = null;
      _isSubmitting = true;
    });

    final ok = await context.read<AuthProvider>().signup(
      _emailController.text.trim(),
      _passwordController.text,
      _nicknameController.text.trim(),
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
                'Fortune Fusion과 함께\n운명을 탐험해 보세요',
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
