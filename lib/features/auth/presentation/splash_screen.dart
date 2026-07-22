import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../application/auth_provider.dart';

/// 03단계 §3.3 공통/온보딩 - SplashScreen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.restoreSession();
    await Future.delayed(const Duration(milliseconds: 900));

    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool('onboarding_completed') ?? false;
    final isLoggedIn = authProvider.isLoggedIn;

    if (!mounted) return;
    if (!onboarded) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    } else if (isLoggedIn) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.mysticGradient),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, color: AppColors.secondary, size: 64),
              SizedBox(height: 16),
              Text(
                'Fortune Fusion',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8),
              Text('AI 종합 운세 슈퍼앱', style: TextStyle(color: Colors.white70, fontSize: 14)),
              SizedBox(height: 40),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
