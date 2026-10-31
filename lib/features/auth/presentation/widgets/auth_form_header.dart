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
          // [반응형 화면 규격 통일 지시서] eyebrow 라벨이 Expanded/Flexible
          // 없이 배치돼 있어 텍스트스케일이 커지거나 화면 폭이 좁아지면
          // (예: 320x568@2.0+) RenderFlex 오버플로가 발생했다. 기존
          // 디자인(모노 폰트, letter-spacing)은 그대로 두고 Flexible +
          // ellipsis로 넘치는 부분만 "..."로 자연스럽게 축약한다.
          Flexible(
            child: Text(
              eyebrow,
              style: IntroTextStyles.formEyebrow(),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
