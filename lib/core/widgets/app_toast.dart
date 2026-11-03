import 'package:flutter/material.dart';
import '../theme/app_unified_style.dart';

/// 03단계 §2 Component 원자단위 - Toast 표준
///
/// [서브 디자인 통일 확산 프롬프트] §7 공통 상호작용 규칙: 하단 중앙,
/// 배경 #111111 + 텍스트 화이트, Caption 12. 색상 남용 금지에 따라
/// 성공/에러 아이콘 색상도 팔레트 내 값(neon/white)만 사용한다.
///
/// [긴급 검수 지시 §4 — API 연결 실패 UX 보완] [onRetry]를 넘기면
/// SnackBar에 "재시도" 액션 버튼이 추가된다 — 네트워크/서버 연결
/// 실패처럼 사용자가 즉시 다시 시도할 수 있는 실패 유형에 사용한다.
/// (로그인 필요/잔액 부족처럼 재시도만으로 해결되지 않는 실패에는
/// [onRetry]를 넘기지 않는다.)
class AppToast {
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    VoidCallback? onRetry,
    String retryLabel = '재시도',
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: UnifiedColors.black,
        elevation: 0,
        duration: Duration(seconds: onRetry != null ? 6 : 4),
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
        action: onRetry == null
            ? null
            : SnackBarAction(
                label: retryLabel,
                textColor: UnifiedColors.neon,
                onPressed: onRetry,
              ),
      ),
    );
  }
}
