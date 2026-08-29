import 'package:flutter/material.dart';
import '../../../intro/presentation/intro_palette.dart';
import '../../../intro/presentation/intro_text_styles.dart';

/// [Phase B - 02_SignUp_Login.html 반영] `.form-header` — 뒤로가기 원형
/// 아이콘버튼 + `.form-eyebrow` mono 라벨(SIGN UP · N°01 / SIGN IN · WELCOME
/// BACK) 조합.
class AuthFormHeader extends StatelessWidget {
  final String eyebrow;
  final VoidCallback onBack;

  const AuthFormHeader({
    super.key,
    required this.eyebrow,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          // `.icon-btn`
          InkWell(
            onTap: onBack,
            customBorder: const CircleBorder(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: IntroPalette.primaryLight,
                border: Border.all(color: IntroPalette.cardBorder),
              ),
              child: Icon(
                Icons.arrow_back,
                size: 18,
                color: IntroPalette.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(eyebrow, style: IntroTextStyles.formEyebrow()),
        ],
      ),
    );
  }
}
