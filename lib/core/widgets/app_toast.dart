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
        // [버그 수정 2026-12 — 토스트 글씨 안 보임, 앱 전체 공통 버그]
        // 원래 이 배경은 진짜 검정(#111111, 위 클래스 주석 "배경 #111111 +
        // 텍스트 화이트"가 그 설계 의도)이었는데, 나중에 `UnifiedColors.black`
        // 상수 자체가 "다크 전환" 작업(ef1217fa)에서 이름은 그대로 두고
        // 값만 CTA용 골드 포인트(#E9C46A)로 재활용되면서, 이 토스트만 코드를
        // 안 고친 채로 남아 흰 글씨(Colors.white)가 밝은 골드 배경 위에
        // 거의 안 보이게 됐다(궁합 초대장 "아직 상대방이 참여하지
        // 않았어요" 등 앱 전체 모든 토스트에서 재현). `UnifiedColors.black`
        // 참조를 제거하고 원래 설계 의도대로 고정된 어두운 배경색을 쓴다
        // (색상 이름 재활용에 의존하지 않아 향후 같은 사고를 구조적으로
        // 방지한다).
        backgroundColor: const Color(0xFF111111),
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
