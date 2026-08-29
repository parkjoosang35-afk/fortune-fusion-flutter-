import 'package:flutter/material.dart';
import '../../../intro/presentation/intro_palette.dart';
import '../../../intro/presentation/intro_text_styles.dart';

/// [Phase B - 02_SignUp_Login.html 반영] `.btn-primary` — glow 배경 + inset
/// 하이라이트 + "✧" 아이콘 CTA 버튼. 인트로 CTA(`IntroCTASection`)의 Primary
/// 버튼과 톤이 같아 스타일을 재사용하되, 로딩 스피너 표시가 필요해 별도
/// 위젯으로 분리했다.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    this.isLoading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = isLoading || onPressed == null;
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: IntroPalette.primary,
          foregroundColor: IntroPalette.onPrimary,
          disabledBackgroundColor: IntroPalette.primaryLight,
          disabledForegroundColor: IntroPalette.textSecondary,
          elevation: 0,
          shadowColor: IntroPalette.glowShadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: IntroPalette.onPrimary,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('✧', style: IntroTextStyles.btnPrimary()),
                  const SizedBox(width: 8),
                  Text(label, style: IntroTextStyles.btnPrimary()),
                ],
              ),
      ),
    );
  }
}
