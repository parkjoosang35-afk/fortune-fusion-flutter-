import 'package:flutter/material.dart';
import '../../../intro/presentation/intro_palette.dart';

/// [Phase B - 02_SignUp_Login.html 반영] `.checkbox` — 라벤더 glow 체크박스.
/// 약관 동의 행/로그인 상태 유지 체크 모두 이 위젯 하나로 재사용한다.
class AuthCheckbox extends StatelessWidget {
  final bool value;

  const AuthCheckbox({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: value ? IntroPalette.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: value
              ? IntroPalette.primary
              : const Color(0x59DCC8FF), // rgba(220,200,255,0.35)
          width: 1.5,
        ),
        boxShadow: value
            ? [BoxShadow(color: IntroPalette.glowShadow, blurRadius: 12)]
            : null,
      ),
      child: value
          ? const Icon(Icons.check, size: 12, color: IntroPalette.onPrimary)
          : null,
    );
  }
}
