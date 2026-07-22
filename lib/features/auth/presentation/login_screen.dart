import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/auth_provider.dart';

/// 03단계 §3.3 공통/온보딩 - LoginScreen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(
    text: 'demo@fortunefusion.app',
  );
  final _passwordController = TextEditingController(text: 'password');
  bool _isSubmitting = false;

  Future<void> _login() async {
    setState(() => _isSubmitting = true);
    final ok = await context.read<AuthProvider>().login(
      _emailController.text.trim(),
      _passwordController.text,
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
        context.read<AuthProvider>().state.errorMessage ?? '로그인 실패',
        isError: true,
      );
    }
  }

  Future<void> _socialLogin(String provider) async {
    setState(() => _isSubmitting = true);
    final ok = await context.read<AuthProvider>().loginWithSocial(provider);
    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (ok) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/signup/profile-check', (route) => false);
    }
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              const Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Fortune Fusion',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _login,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('이메일로 로그인'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: const [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text(
                      '또는',
                      style: TextStyle(color: AppColors.textHint),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : () => _socialLogin('카카오'),
                icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                label: const Text('카카오로 계속하기'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : () => _socialLogin('구글'),
                icon: const Icon(Icons.g_mobiledata_rounded, size: 22),
                label: const Text('구글로 계속하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
