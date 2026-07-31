import 'package:flutter/material.dart';
import '../theme/app_unified_style.dart';

/// 03단계 §2 Component 원자단위 - Toast 표준
///
/// [서브 디자인 통일 확산 프롬프트] §7 공통 상호작용 규칙: 하단 중앙,
/// 배경 #111111 + 텍스트 화이트, Caption 12. 색상 남용 금지에 따라
/// 성공/에러 아이콘 색상도 팔레트 내 값(neon/white)만 사용한다.
class AppToast {
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: UnifiedColors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
        ),
        margin: const EdgeInsets.only(
          left: 48,
          right: 48,
          bottom: UnifiedTokens.spaceXxl,
        ),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: isError ? Colors.white : UnifiedColors.neon,
              size: UnifiedTokens.iconMd,
            ),
            const SizedBox(width: UnifiedTokens.spaceSm),
            Expanded(
              child: Text(
                message,
                style: UnifiedText.caption(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
