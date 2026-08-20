import 'package:flutter/material.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../intro_palette.dart';

/// [인트로 전면 개편] 4단계 시작화면 - 타이틀/서브카피/가입보상 배지 +
/// 메인버튼(바로시작하기)/보조버튼(가입하고 복주머니 받기)/로그인 링크/
/// 비회원 안내 문구.
///
/// [UX 금지사항 준수] 강제 모달 없음, 긴 약관 없음, 유료/포인트/구독 느낌의
/// 문구 없음 — 오직 사용자가 지정한 정확한 카피만 노출한다.
///
/// [2026-08-21 인트로 3종 색상 정리] 로고 원/가입보상 배지/메인버튼을
/// 브랜드 컬러 #90035C(IntroPalette) 톤으로 교체했다. 보조버튼(아웃라인)과
/// 로그인 링크는 테두리·텍스트 색만 브랜드 톤으로 바꾸고 구조는 유지한다.
class IntroCTASection extends StatelessWidget {
  final String title;
  final String subtitle;
  final String signupRewardText;
  final bool showGuestHint;
  final VoidCallback onStartAsGuest;
  final VoidCallback onSignup;
  final VoidCallback onLogin;

  const IntroCTASection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.signupRewardText,
    required this.showGuestHint,
    required this.onStartAsGuest,
    required this.onSignup,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UnifiedTokens.screenPadding,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [IntroPalette.primary, IntroPalette.primaryDark],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 40,
              color: IntroPalette.onPrimary,
            ),
          ),
          const SizedBox(height: UnifiedTokens.spaceXxl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: UnifiedText.titleLarge().copyWith(fontSize: 20),
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: UnifiedText.body().copyWith(fontSize: 14),
          ),
          const SizedBox(height: UnifiedTokens.spaceXxl),
          // 가입 보상 배지 — "지금 가입하면 복주머니 100개 지급"
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: UnifiedTokens.spaceLg,
              vertical: UnifiedTokens.spaceMd,
            ),
            decoration: BoxDecoration(
              color: IntroPalette.primaryLight,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.card_giftcard_rounded,
                  size: UnifiedTokens.iconMd,
                  color: IntroPalette.primaryDark,
                ),
                const SizedBox(width: UnifiedTokens.spaceSm),
                Flexible(
                  child: Text(
                    signupRewardText,
                    style: UnifiedText.bodyStrong(
                      color: IntroPalette.primaryDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: UnifiedTokens.spaceXxl),
          // 메인버튼 - 바로시작하기(비회원 홈 진입)
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: onStartAsGuest,
              style: ElevatedButton.styleFrom(
                backgroundColor: IntroPalette.primary,
                foregroundColor: IntroPalette.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                ),
              ),
              child: Text(
                '바로 시작하기',
                style: UnifiedText.bodyStrong(color: IntroPalette.onPrimary),
              ),
            ),
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          // 보조버튼 - 가입하고 복주머니 100개 받기
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: onSignup,
              style: OutlinedButton.styleFrom(
                foregroundColor: IntroPalette.primaryDark,
                side: const BorderSide(color: IntroPalette.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                ),
              ),
              child: Text(
                '가입하고 복주머니 100개 받기',
                style: UnifiedText.bodyStrong(color: IntroPalette.primaryDark),
              ),
            ),
          ),
          const SizedBox(height: UnifiedTokens.spaceLg),
          TextButton(
            onPressed: onLogin,
            child: Text(
              '이미 계정이 있으신가요? 로그인',
              style: UnifiedText.bodySmall(color: UnifiedColors.textSecondary),
            ),
          ),
          if (showGuestHint) ...[
            const SizedBox(height: UnifiedTokens.spaceSm),
            Text(
              '회원가입 없이도 대부분의 기능을 자유롭게 둘러볼 수 있어요.',
              textAlign: TextAlign.center,
              style: UnifiedText.caption(),
            ),
          ],
        ],
      ),
    );
  }
}
